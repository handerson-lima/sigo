import pytest
from unittest.mock import patch, MagicMock
from firestore_utils import save_draft_to_firestore, DraftPersistenceError

class MockServiceUnavailable(Exception):
    pass

@patch('firestore_utils.firestore.client')
def test_save_draft_success(mock_client):
    mock_db = MagicMock()
    mock_client.return_value = mock_db
    mock_collection = MagicMock()
    mock_db.collection.return_value = mock_collection
    mock_doc = MagicMock()
    mock_collection.document.return_value = mock_doc

    geojson = {"type": "FeatureCollection", "features": []}
    save_draft_to_firestore("test_id", geojson)

    mock_db.collection.assert_called_once_with('loteamentos_drafts')
    mock_collection.document.assert_called_once_with('test_id')
    mock_doc.set.assert_called_once_with(geojson)

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
