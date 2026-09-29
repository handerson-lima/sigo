import os
import time
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest
import firebase_functions

from main import (
    _claim_consolidation_request,
    _complete_consolidation_request,
    _release_consolidation_request,
    consolidar_loteamento_aprovado,
    consolidar_loteamento_manual,
    firestore,
    processar_dxf,
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


def _event(filename='123_arquivo.dxf'):
    return MockCloudEvent(MockStorageObjectData(f'loteamentos_drafts_uploads/user/{filename}'))


@patch('main.storage.Client')
def test_processar_dxf_ignora_rota_e_formatos_antigos(mock_storage):
    processar_dxf(MockCloudEvent(MockStorageObjectData('uploads/user/arquivo.dxf')))
    for filename in ('arquivo.dwf', 'arquivo.dwg', 'arquivo.pdf'):
        processar_dxf(_event(filename))
    mock_storage.assert_not_called()


@patch('main.storage.Client')
def test_processar_dxf_valida_tamanho_antes_do_download(mock_storage):
    event = _event()
    event.data.size = str(51 * 1024 * 1024)
    processar_dxf(event)
    mock_storage.assert_not_called()


@patch('main.save_draft_to_firestore')
@patch('main.extract_dxf_geojson')
@patch('main.storage.Client')
def test_processar_dxf_cria_rascunho_revisavel(mock_storage, mock_extract, mock_save):
    mock_extract.return_value = {'type': 'FeatureCollection', 'features': [{'type': 'Feature'}]}
    blob = MagicMock()
    mock_storage.return_value.bucket.return_value.blob.return_value = blob

    processar_dxf(_event())

    mock_extract.assert_called_once()
    mock_save.assert_called_once_with('123_arquivo.dxf', mock_extract.return_value, {
        'construtoraId': 'construtora-1', 'loteamentoName': 'arquivo',
        'status': 'pendente', 'sourceFormat': 'dxf',
    })
    temporary_path = blob.download_to_filename.call_args.args[0]
    assert not os.path.exists(temporary_path)


@patch('main.save_draft_to_firestore')
@patch('main.extract_dxf_geojson')
@patch('main.storage.Client')
def test_processar_dxf_aceita_extensao_maiuscula(mock_storage, mock_extract, mock_save):
    mock_extract.return_value = {'type': 'FeatureCollection', 'features': [{'type': 'Feature'}]}
    mock_storage.return_value.bucket.return_value.blob.return_value = MagicMock()

    processar_dxf(_event('123_ARQUIVO.DXF'))

    mock_extract.assert_called_once()


@patch('main.save_draft_to_firestore')
@patch('main.extract_dxf_geojson')
@patch('main.storage.Client')
def test_processar_dxf_gera_erro_terminal_sem_geometria(mock_storage, mock_extract, mock_save):
    from dxf_extraction import DxfExtractionError
    mock_extract.side_effect = DxfExtractionError('O DXF não possui contornos utilizáveis para loteamento.')
    mock_storage.return_value.bucket.return_value.blob.return_value = MagicMock()

    processar_dxf(_event())

    _, geojson, metadata = mock_save.call_args.args
    assert geojson == {'type': 'FeatureCollection', 'features': []}
    assert metadata['status'] == 'erro'
    assert metadata['sourceFormat'] == 'dxf'
    assert 'contornos utilizáveis' in metadata['processingError']


@patch('main.extract_dxf_geojson')
@patch('main.storage.Client')
def test_processar_dxf_limpa_temporario_em_falha_transitoria(mock_storage, mock_extract):
    blob = MagicMock()
    blob.download_to_filename.side_effect = OSError('network down')
    mock_storage.return_value.bucket.return_value.blob.return_value = blob

    with pytest.raises(OSError):
        processar_dxf(_event())

    assert not os.path.exists(blob.download_to_filename.call_args.args[0])
    mock_extract.assert_not_called()


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


@patch('main.firestore.transactional', side_effect=_immediate_transactional)
@patch('main.firestore.client')
def test_claim_rejects_an_already_claimed_request(mock_client, _):
    db = _FakeDb({
        'consolidationRequestId': 'request-1',
        'consolidationProcessingRequestId': 'request-1',
        'consolidationProcessingStartedAt': time.time(),
    })
    mock_client.return_value = db

    assert not _claim_consolidation_request('draft-1', 'request-1')
    assert db.reference.data['consolidationProcessingRequestId'] == 'request-1'


@patch('main.time.time', return_value=1_000.0)
@patch('main.firestore.transactional', side_effect=_immediate_transactional)
@patch('main.firestore.client')
def test_claim_recovers_an_expired_request(mock_client, _, __):
    db = _FakeDb({
        'consolidationRequestId': 'request-1',
        'consolidationProcessingRequestId': 'request-1',
        'consolidationProcessingStartedAt': 800.0,
    })
    mock_client.return_value = db

    assert _claim_consolidation_request('draft-1', 'request-1')
    assert db.reference.data['consolidationProcessingStartedAt'] == 1_000.0


@patch('main.firestore.transactional', side_effect=_immediate_transactional)
@patch('main.firestore.client')
def test_claim_rejects_a_completed_request(mock_client, _):
    db = _FakeDb({
        'consolidationRequestId': 'request-1',
        'consolidationCompletedRequestId': 'request-1',
    })
    mock_client.return_value = db

    assert not _claim_consolidation_request('draft-1', 'request-1')


@patch('main.firestore.transactional', side_effect=_immediate_transactional)
@patch('main.firestore.client')
def test_release_only_clears_its_matching_request(mock_client, _):
    db = _FakeDb({
        'consolidationProcessingRequestId': 'request-2',
        'consolidationProcessingStartedAt': time.time(),
    })
    mock_client.return_value = db

    _release_consolidation_request('draft-1', 'request-1')
    assert db.reference.data['consolidationProcessingRequestId'] == 'request-2'

    _release_consolidation_request('draft-1', 'request-2')
    assert 'consolidationProcessingRequestId' not in db.reference.data
    assert 'consolidationProcessingStartedAt' not in db.reference.data


@patch('main.firestore.transactional', side_effect=_immediate_transactional)
@patch('main.firestore.client')
def test_complete_only_marks_its_matching_claim(mock_client, _):
    db = _FakeDb({'consolidationProcessingRequestId': 'request-2'})
    mock_client.return_value = db

    assert not _complete_consolidation_request('draft-1', 'request-1')
    assert db.reference.data['consolidationProcessingRequestId'] == 'request-2'

    assert _complete_consolidation_request('draft-1', 'request-2')
    assert db.reference.data['consolidationCompletedRequestId'] == 'request-2'
    assert 'consolidationProcessingRequestId' not in db.reference.data


@patch('main.consolidate_approved_draft')
@patch('main._complete_consolidation_request', return_value=True)
@patch('main._claim_consolidation_request', return_value=True)
def test_consolidar_loteamento_aprovado_processes_new_request_and_marks_completion(
    mock_claim, mock_complete, mock_consolidate,
):
    event = MockApprovalEvent(
        {'status': 'pendente'},
        {'status': 'aprovado', 'consolidationRequestId': 'request-1'},
    )
    consolidar_loteamento_aprovado(event)
    mock_consolidate.assert_called_once_with('draft-1', {
        'status': 'aprovado', 'consolidationRequestId': 'request-1',
    })
    mock_complete.assert_called_once_with('draft-1', 'request-1')


@patch('main.consolidate_approved_draft')
@patch('main._complete_consolidation_request', return_value=True)
@patch('main._claim_consolidation_request', return_value=True)
def test_consolidar_loteamento_aprovado_retries_approved_draft_with_new_request(
    mock_claim, mock_complete, mock_consolidate,
):
    consolidar_loteamento_aprovado(MockApprovalEvent(
        {'status': 'aprovado', 'consolidationRequestId': 'request-1'},
        {'status': 'aprovado', 'consolidationRequestId': 'request-2'},
    ))
    mock_consolidate.assert_called_once()
    mock_complete.assert_called_once_with('draft-1', 'request-2')


@patch('main.consolidate_approved_draft')
@patch('main._claim_consolidation_request', return_value=True)
def test_consolidar_loteamento_aprovado_ignores_duplicate_delivery(mock_claim, mock_consolidate):
    # Reentrega da solicitação já concluída: não reclama nem materializa.
    consolidar_loteamento_aprovado(MockApprovalEvent(
        {
            'status': 'aprovado',
            'consolidationRequestId': 'request-1',
            'consolidationCompletedRequestId': 'request-1',
        },
        {
            'status': 'aprovado',
            'consolidationRequestId': 'request-1',
            'consolidationCompletedRequestId': 'request-1',
        },
    ))
    mock_consolidate.assert_not_called()
    mock_claim.assert_not_called()


@patch('main.consolidate_approved_draft')
def test_consolidar_loteamento_aprovado_ignores_draft_without_request(mock_consolidate):
    consolidar_loteamento_aprovado(MockApprovalEvent(
        {'status': 'pendente'},
        {'status': 'aprovado'},
    ))
    mock_consolidate.assert_not_called()


@patch('main.consolidate_approved_draft')
@patch('main._claim_consolidation_request', return_value=False)
def test_consolidar_loteamento_aprovado_ignores_request_claimed_by_another_delivery(
    mock_claim, mock_consolidate,
):
    consolidar_loteamento_aprovado(MockApprovalEvent(
        {'status': 'pendente'},
        {'status': 'aprovado', 'consolidationRequestId': 'request-1'},
    ))
    mock_consolidate.assert_not_called()


@patch('main._release_consolidation_request')
@patch('main.consolidate_approved_draft', side_effect=RuntimeError('batch failed'))
@patch('main._claim_consolidation_request', return_value=True)
def test_consolidar_loteamento_aprovado_propagates_failure_without_completion(
    mock_claim, mock_consolidate, mock_release,
):
    with pytest.raises(RuntimeError, match='batch failed'):
        consolidar_loteamento_aprovado(MockApprovalEvent(
            {'status': 'pendente'},
            {'status': 'aprovado', 'consolidationRequestId': 'request-1'},
        ))
    mock_consolidate.assert_called_once()
    mock_release.assert_called_once_with('draft-1', 'request-1')


@patch('main.consolidate_approved_draft')
def test_consolidar_loteamento_aprovado_ignores_unchanged_request_id(mock_consolidate):
    # Um update aprovado sem nova solicitação não redispara a consolidação.
    consolidar_loteamento_aprovado(MockApprovalEvent(
        {'status': 'aprovado', 'consolidationRequestId': 'request-1'},
        {'status': 'aprovado', 'consolidationRequestId': 'request-1'},
    ))
    mock_consolidate.assert_not_called()


@patch('main._release_consolidation_request')
@patch('main.consolidate_approved_draft', side_effect=ValueError('Lote ambíguo'))
@patch('main._claim_consolidation_request', return_value=True)
def test_consolidar_loteamento_aprovado_acks_permanent_validation_error(
    mock_claim, mock_consolidate, mock_release,
):
    # Erro permanente: libera a reserva e dá ack (não deve virar poison message).
    consolidar_loteamento_aprovado(MockApprovalEvent(
        {'status': 'pendente'},
        {'status': 'aprovado', 'consolidationRequestId': 'request-1'},
    ))
    mock_release.assert_called_once_with('draft-1', 'request-1')


def test_consolidar_loteamento_aprovado_enables_event_retry():
    assert consolidar_loteamento_aprovado.__firebase_endpoint__.eventTrigger['retry'] is True


def test_processar_dxf_declara_1_gib_e_cpu():
    kwargs = firebase_functions.recorded['storage']
    assert kwargs['memory'] is firebase_functions.options.MemoryOption.GB_1
    assert kwargs['cpu'] == 1


class _CallableRequest:
    def __init__(self, data, auth=None):
        self.data = data
        self.auth = auth


_CALLER = SimpleNamespace(uid='user-1')


class _CallableSnapshot:
    def __init__(self, data):
        self._data = data
        self.exists = data is not None

    def to_dict(self):
        return self._data


class _CallableDb:
    def __init__(self, data):
        self._snapshot = _CallableSnapshot(data)

    def collection(self, _):
        return self

    def document(self, _):
        return self

    def get(self):
        return self._snapshot


def _callable_db(draft):
    return _CallableDb(draft)


@patch('main._complete_consolidation_request', return_value=True)
@patch('main._claim_consolidation_request', return_value=True)
@patch('main._is_active_member', return_value=True)
@patch('main.consolidate_approved_draft')
@patch('main.firestore.client')
def test_manual_callable_consolidates_approved_draft(
    mock_client, mock_consolidate, mock_member, mock_claim, mock_complete,
):
    draft = {
        'status': 'aprovado', 'consolidationRequestId': 'request-1',
        'construtoraId': 'const-1',
    }
    mock_client.return_value = _callable_db(draft)

    result = consolidar_loteamento_manual(
        _CallableRequest({'draftId': 'draft-1'}, auth=_CALLER)
    )

    assert result == {'status': 'completed'}
    mock_member.assert_called_once_with('user-1', 'const-1')
    mock_consolidate.assert_called_once_with('draft-1', draft)
    mock_complete.assert_called_once_with('draft-1', 'request-1')


@patch('main.consolidate_approved_draft')
@patch('main._is_active_member', return_value=True)
@patch('main.firestore.client')
def test_manual_callable_returns_already_completed(mock_client, mock_member, mock_consolidate):
    draft = {
        'status': 'aprovado',
        'consolidationRequestId': 'request-1',
        'consolidationCompletedRequestId': 'request-1',
        'construtoraId': 'const-1',
    }
    mock_client.return_value = _callable_db(draft)

    result = consolidar_loteamento_manual(
        _CallableRequest({'draftId': 'draft-1'}, auth=_CALLER)
    )

    assert result == {'status': 'already_completed'}
    mock_consolidate.assert_not_called()


@patch('main._claim_consolidation_request', return_value=False)
@patch('main._is_active_member', return_value=True)
@patch('main.firestore.client')
def test_manual_callable_returns_already_processing(mock_client, mock_member, mock_claim):
    draft = {
        'status': 'aprovado', 'consolidationRequestId': 'request-1',
        'construtoraId': 'const-1',
    }
    mock_client.return_value = _callable_db(draft)

    result = consolidar_loteamento_manual(
        _CallableRequest({'draftId': 'draft-1'}, auth=_CALLER)
    )

    assert result == {'status': 'already_processing'}


def test_manual_callable_requires_draft_id():
    mock_https = firebase_functions.https_fn
    with pytest.raises(mock_https.HttpsError) as exc:
        consolidar_loteamento_manual(_CallableRequest({}, auth=_CALLER))
    assert exc.value.code == mock_https.FunctionsErrorCode.INVALID_ARGUMENT


@patch('main.firestore.client')
def test_manual_callable_denies_unauthenticated_caller(mock_client):
    mock_client.return_value = _callable_db({
        'status': 'aprovado', 'consolidationRequestId': 'request-1',
        'construtoraId': 'const-1',
    })
    mock_https = firebase_functions.https_fn
    with pytest.raises(mock_https.HttpsError) as exc:
        consolidar_loteamento_manual(_CallableRequest({'draftId': 'draft-1'}))
    assert exc.value.code == mock_https.FunctionsErrorCode.PERMISSION_DENIED


@patch('main.consolidate_approved_draft')
@patch('main._is_active_member', return_value=False)
@patch('main.firestore.client')
def test_manual_callable_denies_non_member(mock_client, mock_member, mock_consolidate):
    mock_client.return_value = _callable_db({
        'status': 'aprovado', 'consolidationRequestId': 'request-1',
        'construtoraId': 'const-1',
    })
    mock_https = firebase_functions.https_fn
    with pytest.raises(mock_https.HttpsError) as exc:
        consolidar_loteamento_manual(
            _CallableRequest({'draftId': 'draft-1'}, auth=_CALLER)
        )
    assert exc.value.code == mock_https.FunctionsErrorCode.PERMISSION_DENIED
    mock_member.assert_called_once_with('user-1', 'const-1')
    mock_consolidate.assert_not_called()


@patch('main.firestore.client')
def test_manual_callable_rejects_unknown_draft(mock_client):
    mock_client.return_value = _callable_db(None)
    mock_https = firebase_functions.https_fn
    with pytest.raises(mock_https.HttpsError) as exc:
        consolidar_loteamento_manual(
            _CallableRequest({'draftId': 'missing'}, auth=_CALLER)
        )
    assert exc.value.code == mock_https.FunctionsErrorCode.NOT_FOUND


@patch('main._is_active_member', return_value=True)
@patch('main.firestore.client')
def test_manual_callable_requires_approved_status(mock_client, mock_member):
    mock_client.return_value = _callable_db({
        'status': 'pendente', 'construtoraId': 'const-1',
    })
    mock_https = firebase_functions.https_fn
    with pytest.raises(mock_https.HttpsError) as exc:
        consolidar_loteamento_manual(
            _CallableRequest({'draftId': 'draft-1'}, auth=_CALLER)
        )
    assert exc.value.code == mock_https.FunctionsErrorCode.FAILED_PRECONDITION


@patch('main._is_active_member', return_value=True)
@patch('main.firestore.client')
def test_manual_callable_requires_request_id(mock_client, mock_member):
    mock_client.return_value = _callable_db({
        'status': 'aprovado', 'construtoraId': 'const-1',
    })
    mock_https = firebase_functions.https_fn
    with pytest.raises(mock_https.HttpsError) as exc:
        consolidar_loteamento_manual(
            _CallableRequest({'draftId': 'draft-1'}, auth=_CALLER)
        )
    assert exc.value.code == mock_https.FunctionsErrorCode.FAILED_PRECONDITION


@patch('main._release_consolidation_request')
@patch('main.consolidate_approved_draft', side_effect=RuntimeError('boom'))
@patch('main._claim_consolidation_request', return_value=True)
@patch('main._is_active_member', return_value=True)
@patch('main.firestore.client')
def test_manual_callable_releases_claim_on_failure(
    mock_client, mock_member, mock_claim, mock_consolidate, mock_release,
):
    mock_client.return_value = _callable_db({
        'status': 'aprovado', 'consolidationRequestId': 'request-1',
        'construtoraId': 'const-1',
    })
    mock_https = firebase_functions.https_fn
    with pytest.raises(mock_https.HttpsError) as exc:
        consolidar_loteamento_manual(
            _CallableRequest({'draftId': 'draft-1'}, auth=_CALLER)
        )
    assert exc.value.code == mock_https.FunctionsErrorCode.INTERNAL
    mock_release.assert_called_once_with('draft-1', 'request-1')
