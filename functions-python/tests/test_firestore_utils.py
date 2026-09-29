import json
import pytest
from unittest.mock import patch, MagicMock
from firestore_utils import save_draft_to_firestore, DraftPersistenceError

class MockServiceUnavailable(Exception):
    pass


def _has_nested_array(value):
    """Detecta arrays dentro de arrays, que o Firestore rejeita no ``set``."""
    if isinstance(value, list):
        if any(isinstance(item, list) for item in value):
            return True
        return any(_has_nested_array(item) for item in value)
    if isinstance(value, dict):
        return any(_has_nested_array(item) for item in value.values())
    return False


def _draft_with_geometry():
    geometry = {
        "type": "Polygon",
        "coordinates": [[[0, 0], [1, 0], [1, 1], [0, 0]]],
    }
    geojson = {
        "type": "FeatureCollection",
        "features": [
            {
                "type": "Feature",
                "geometry": geometry,
                "properties": {
                    "tipo": "lote",
                    "nome": "1",
                    "status": "valido",
                    "quadra": "Q 1",
                },
            }
        ],
    }
    return geojson, geometry


@patch('firestore_utils.firestore.client')
def test_save_draft_success(mock_client):
    mock_db = MagicMock()
    mock_client.return_value = mock_db
    mock_collection = MagicMock()
    mock_db.collection.return_value = mock_collection
    mock_doc = MagicMock()
    mock_collection.document.return_value = mock_doc

    geojson, geometry = _draft_with_geometry()
    save_draft_to_firestore("test_id", geojson)

    mock_db.collection.assert_called_once_with('loteamentos_drafts')
    mock_collection.document.assert_called_once_with('test_id')

    payload = mock_doc.set.call_args.args[0]
    assert isinstance(payload['features'][0]['geometry'], str)
    assert payload['features'][0]['geometry'] == json.dumps(geometry)
    assert json.loads(payload['features'][0]['geometry']) == geometry
    assert not _has_nested_array(payload)
    # A entrada não é mutada: o contrato Map de build_geojson é preservado.
    assert isinstance(geojson['features'][0]['geometry'], dict)


@patch('firestore_utils.firestore.client')
def test_save_draft_is_idempotent_for_serialized_geometry(mock_client):
    mock_db = MagicMock()
    mock_client.return_value = mock_db
    mock_db.collection.return_value.document.return_value = MagicMock()

    _, geometry = _draft_with_geometry()
    serialized = json.dumps(geometry)
    geojson = {
        "type": "FeatureCollection",
        "features": [
            {"type": "Feature", "geometry": serialized, "properties": {}}
        ],
    }

    save_draft_to_firestore("test_id", geojson)

    payload = mock_db.collection.return_value.document.return_value.set.call_args.args[0]
    assert payload['features'][0]['geometry'] == serialized
    assert not _has_nested_array(payload)


@patch('firestore_utils.firestore.client')
def test_save_draft_serializes_geometry_and_merges_metadata(mock_client):
    mock_db = MagicMock()
    mock_client.return_value = mock_db
    mock_doc = mock_db.collection.return_value.document.return_value

    geojson, geometry = _draft_with_geometry()
    metadata = {
        'construtoraId': 'construtora-1',
        'loteamentoName': 'arquivo',
        'status': 'pendente',
    }
    save_draft_to_firestore("test_id", geojson, metadata)

    payload = mock_doc.set.call_args.args[0]
    assert payload['status'] == 'pendente'
    assert payload['construtoraId'] == 'construtora-1'
    assert payload['features'][0]['geometry'] == json.dumps(geometry)
    assert not _has_nested_array(payload)

@patch('firestore_utils.firestore.client')
def test_save_draft_transient_error(mock_client):
    mock_db = MagicMock()
    mock_client.return_value = mock_db
    mock_collection = MagicMock()
    mock_db.collection.return_value = mock_collection
    mock_doc = MagicMock()
    mock_collection.document.return_value = mock_doc
    
    # We use a custom exception named MockServiceUnavailable to mimic google.api_core
    mock_doc.set.side_effect = type('ServiceUnavailable', (Exception,), {})("Unavailable")

    with pytest.raises(Exception) as exc:
        save_draft_to_firestore("test_id", {})
    assert "ServiceUnavailable" in type(exc.value).__name__

@patch('firestore_utils.firestore.client')
def test_save_draft_fatal_error(mock_client):
    mock_db = MagicMock()
    mock_client.return_value = mock_db
    mock_collection = MagicMock()
    mock_db.collection.return_value = mock_collection
    mock_doc = MagicMock()
    mock_collection.document.return_value = mock_doc
    
    # Generic exception that should be wrapped
    mock_doc.set.side_effect = ValueError("Invalid data")

    with pytest.raises(DraftPersistenceError) as exc:
        save_draft_to_firestore("test_id", {})
    assert "Failed to persist draft to Firestore" in str(exc.value)
