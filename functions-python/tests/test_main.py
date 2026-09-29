import os
from unittest.mock import MagicMock, patch

import pytest

from main import processar_dxf


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
