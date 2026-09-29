import os
from unittest.mock import MagicMock, patch

import pytest

from main import (
    _claim_consolidation_request,
    _complete_consolidation_request,
    _release_consolidation_request,
    consolidar_loteamento_aprovado,
    firestore,
    processar_dwf,
)


class MockCloudEvent:
    def __init__(self, data):
        self.data = data


class MockStorageObjectData:
    def __init__(self, name, bucket='sigo.appspot.com', size='1024', generation='12345', metadata=None):
        self.name = name
        self.bucket = bucket
        self.size = size
        self.generation = generation
        self.metadata = metadata or {'construtoraId': 'construtora-1', 'loteamentoName': 'arquivo'}


class MockSnapshot:
    def __init__(self, data):
        self._data = data

    def to_dict(self):
        return self._data


class MockApprovalEvent:
    def __init__(self, before, after, draft_id='draft-1'):
        self.data = MagicMock(before=MockSnapshot(before), after=MockSnapshot(after))
        self.params = {'draft_id': draft_id}


class _FakeSnapshot:
    def __init__(self, data):
        self._data = data
        self.exists = data is not None

    def to_dict(self):
        return dict(self._data) if self._data is not None else None


class _FakeDraftReference:
    def __init__(self, data):
        self.data = data

    def get(self, transaction=None):
        return _FakeSnapshot(self.data)


class _FakeTransaction:
    def update(self, reference, values):
        for key, value in values.items():
            if value is firestore.DELETE_FIELD:
                reference.data.pop(key, None)
            else:
                reference.data[key] = value


class _FakeDb:
    def __init__(self, data):
        self.reference = _FakeDraftReference(data)

    def collection(self, _):
        return self

    def document(self, _):
        return self.reference

    def transaction(self):
        return _FakeTransaction()


def _immediate_transactional(function):
    return function


def _event(filename='123_arquivo.dwf'):
    return MockCloudEvent(MockStorageObjectData(f'loteamentos_drafts_uploads/user/{filename}'))


@patch('main.storage.Client')
def test_processar_dwf_ignora_rota_e_formatos_antigos(mock_storage):
    processar_dwf(MockCloudEvent(MockStorageObjectData('uploads/user/arquivo.dwf')))
    for filename in ('arquivo.dxf', 'arquivo.dwg', 'arquivo.pdf'):
        processar_dwf(_event(filename))
    mock_storage.assert_not_called()


@patch('main.storage.Client')
def test_processar_dwf_valida_tamanho_antes_do_download(mock_storage):
    event = _event()
    event.data.size = str(51 * 1024 * 1024)
    processar_dwf(event)
    mock_storage.assert_not_called()


@patch('main.save_draft_to_firestore')
@patch('main.extract_dwf_geojson')
@patch('main.storage.Client')
def test_processar_dwf_cria_rascunho_revisavel(mock_storage, mock_extract, mock_save):
    mock_extract.return_value = {'type': 'FeatureCollection', 'features': [{'type': 'Feature'}]}
    blob = MagicMock()
    mock_storage.return_value.bucket.return_value.blob.return_value = blob

    processar_dwf(_event())

    mock_extract.assert_called_once()
    mock_save.assert_called_once_with('123_arquivo.dwf', mock_extract.return_value, {
        'construtoraId': 'construtora-1', 'loteamentoName': 'arquivo',
        'status': 'pendente', 'sourceFormat': 'dwf',
    })
    temporary_path = blob.download_to_filename.call_args.args[0]
    assert not os.path.exists(temporary_path)


@patch('main.save_draft_to_firestore')
@patch('main.extract_dwf_geojson')
@patch('main.storage.Client')
def test_processar_dwf_gera_erro_terminal_sem_geometria(mock_storage, mock_extract, mock_save):
    from dwf_extraction import DwfExtractionError
    mock_extract.side_effect = DwfExtractionError('O DWF não possui contornos utilizáveis para loteamento.')
    mock_storage.return_value.bucket.return_value.blob.return_value = MagicMock()

    processar_dwf(_event())

    _, geojson, metadata = mock_save.call_args.args
    assert geojson == {'type': 'FeatureCollection', 'features': []}
    assert metadata['status'] == 'erro'
    assert 'contornos utilizáveis' in metadata['processingError']


@patch('main.extract_dwf_geojson')
@patch('main.storage.Client')
def test_processar_dwf_limpa_temporario_em_falha_transitoria(mock_storage, mock_extract):
    blob = MagicMock()
    blob.download_to_filename.side_effect = OSError('network down')
    mock_storage.return_value.bucket.return_value.blob.return_value = blob

    with pytest.raises(OSError):
        processar_dwf(_event())

    assert not os.path.exists(blob.download_to_filename.call_args.args[0])
    mock_extract.assert_not_called()


@patch('main.firestore.transactional', side_effect=_immediate_transactional)
@patch('main.firestore.client')
def test_claim_rejects_an_already_claimed_request(mock_client, _):
    db = _FakeDb({
        'consolidationRequestId': 'request-1',
        'consolidationProcessingRequestId': 'request-1',
        'consolidationProcessingStartedAt': __import__('time').time(),
    })
    mock_client.return_value = db
    assert not _claim_consolidation_request('draft-1', 'request-1')
    assert db.reference.data['consolidationProcessingRequestId'] == 'request-1'


@patch('main.firestore.transactional', side_effect=_immediate_transactional)
@patch('main.firestore.client')
def test_release_only_clears_its_matching_request(mock_client, _):
    db = _FakeDb({'consolidationProcessingRequestId': 'request-2', 'consolidationProcessingStartedAt': 1})
    mock_client.return_value = db
    _release_consolidation_request('draft-1', 'request-1')
    assert db.reference.data['consolidationProcessingRequestId'] == 'request-2'
    _release_consolidation_request('draft-1', 'request-2')
    assert 'consolidationProcessingRequestId' not in db.reference.data


@patch('main.time.time', return_value=1_000.0)
@patch('main.firestore.transactional', side_effect=_immediate_transactional)
@patch('main.firestore.client')
def test_claim_recovers_an_expired_request(mock_client, _, __):
    db = _FakeDb({'consolidationRequestId': 'request-1', 'consolidationProcessingRequestId': 'request-1', 'consolidationProcessingStartedAt': 800.0})
    mock_client.return_value = db
    assert _claim_consolidation_request('draft-1', 'request-1')
    assert db.reference.data['consolidationProcessingStartedAt'] == 1_000.0


@patch('main.consolidate_approved_draft')
@patch('main._complete_consolidation_request', return_value=True)
@patch('main._claim_consolidation_request', return_value=True)
def test_consolidar_loteamento_aprovado_processes_new_request_and_marks_completion(mock_claim, mock_complete, mock_consolidate):
    event = MockApprovalEvent({'status': 'pendente'}, {'status': 'aprovado', 'consolidationRequestId': 'request-1'})
    consolidar_loteamento_aprovado(event)
    mock_consolidate.assert_called_once_with('draft-1', {'status': 'aprovado', 'consolidationRequestId': 'request-1'})
    mock_complete.assert_called_once_with('draft-1', 'request-1')


@patch('main.consolidate_approved_draft', side_effect=RuntimeError('batch failed'))
@patch('main.firestore.client')
@patch('main._release_consolidation_request')
@patch('main._claim_consolidation_request', return_value=True)
def test_consolidar_loteamento_aprovado_propagates_failure_without_marking_completion(mock_claim, mock_release, mock_client, mock_consolidate):
    with pytest.raises(RuntimeError, match='batch failed'):
        consolidar_loteamento_aprovado(MockApprovalEvent({'status': 'pendente'}, {'status': 'aprovado', 'consolidationRequestId': 'request-1'}))
    mock_release.assert_called_once_with('draft-1', 'request-1')


@patch('main.consolidate_approved_draft')
@patch('main._complete_consolidation_request', return_value=True)
@patch('main._claim_consolidation_request', return_value=True)
def test_consolidar_loteamento_aprovado_retries_approved_draft_with_new_request(mock_claim, mock_complete, mock_consolidate):
    consolidar_loteamento_aprovado(MockApprovalEvent({'status': 'aprovado', 'consolidationRequestId': 'old'}, {'status': 'aprovado', 'consolidationRequestId': 'new'}))
    mock_consolidate.assert_called_once()
    mock_complete.assert_called_once_with('draft-1', 'new')


@patch('main.firestore.transactional', side_effect=_immediate_transactional)
@patch('main.firestore.client')
def test_complete_only_marks_its_matching_claim(mock_client, _):
    db = _FakeDb({'consolidationProcessingRequestId': 'request-2'})
    mock_client.return_value = db
    assert not _complete_consolidation_request('draft-1', 'request-1')
    assert _complete_consolidation_request('draft-1', 'request-2')
    assert db.reference.data['consolidationCompletedRequestId'] == 'request-2'


@patch('main._claim_consolidation_request', return_value=False)
@patch('main.consolidate_approved_draft')
def test_consolidar_loteamento_aprovado_ignores_request_claimed_by_another_delivery(mock_consolidate, mock_claim):
    consolidar_loteamento_aprovado(MockApprovalEvent({'status': 'pendente'}, {'status': 'aprovado', 'consolidationRequestId': 'request-1'}))
    mock_consolidate.assert_not_called()


def test_consolidar_loteamento_aprovado_enables_event_retry():
    assert consolidar_loteamento_aprovado.__firebase_endpoint__.eventTrigger['retry'] is True
