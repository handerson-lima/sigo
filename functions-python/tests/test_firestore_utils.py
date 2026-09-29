import pytest
from unittest.mock import patch, MagicMock
from firestore_utils import (
    DraftPersistenceError,
    consolidate_approved_draft,
    save_draft_to_firestore,
)

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
    metadata = {'construtoraId': 'construtora-1', 'loteamentoName': 'Loteamento'}
    save_draft_to_firestore("test_id", geojson, metadata)

    mock_db.collection.assert_called_once_with('loteamentos_drafts')
    mock_collection.document.assert_called_once_with('test_id')
    mock_doc.set.assert_called_once_with({**geojson, **metadata})

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


class FakeDocument:
    def __init__(self, path):
        self.path = path
        self.deleted = False

    def delete(self):
        self.deleted = True


class FakeCollection:
    def __init__(self, name):
        self.name = name
        self.documents = {}

    def document(self, identifier):
        return self.documents.setdefault(identifier, FakeDocument(f'{self.name}/{identifier}'))


class FakeBatch:
    def __init__(self, db, fail=False):
        self.db = db
        self.fail = fail
        self.operations = []

    def set(self, reference, document):
        self.operations.append((reference, document))

    def commit(self):
        if self.fail:
            raise RuntimeError('batch failed')
        self.db.commits.append(self.operations)


class FakeDb:
    def __init__(self, fail_batch_number=None):
        self.collections = {}
        self.commits = []
        self.fail_batch_number = fail_batch_number
        self.batch_count = 0

    def collection(self, name):
        return self.collections.setdefault(name, FakeCollection(name))

    def batch(self):
        self.batch_count += 1
        return FakeBatch(self, self.batch_count == self.fail_batch_number)


def approved_draft(lote_count=1):
    features = [
        {'properties': {'tipo': 'quadra', 'nome': 'Q 1'}},
    ]
    features.extend(
        {'properties': {'tipo': 'lote', 'nome': f'L {index}', 'quadra': 'Q 1', 'status': 'resolvido'}}
        for index in range(lote_count)
    )
    return {
        'construtoraId': 'construtora-1',
        'loteamentoName': 'LOTEAMENTO_APROVADO',
        'features': features,
    }


def test_consolidate_creates_final_hierarchy_and_retains_draft_for_retry_tracking():
    db = FakeDb()
    consolidate_approved_draft('draft-1', approved_draft(), db)

    writes = [operation for commit in db.commits for operation in commit]
    documents = {reference.path: document for reference, document in writes}
    assert set(documents) == {
        'loteamentos/draft-1--loteamento',
        'quadras/draft-1--quadra--0',
        'lotes/draft-1--lote--1',
    }
    assert documents['lotes/draft-1--lote--1']['construtoraId'] == 'construtora-1'
    assert documents['lotes/draft-1--lote--1']['loteamentoId'] == 'draft-1--loteamento'
    assert documents['lotes/draft-1--lote--1']['quadraId'] == 'draft-1--quadra--0'
    assert not db.collection('loteamentos_drafts').document('draft-1').deleted


def test_consolidate_is_idempotent_for_repeated_event():
    db = FakeDb()
    draft = approved_draft()
    consolidate_approved_draft('draft-1', draft, db)
    consolidate_approved_draft('draft-1', draft, db)

    all_paths = [reference.path for commit in db.commits for reference, _ in commit]
    assert set(all_paths) == {
        'loteamentos/draft-1--loteamento',
        'quadras/draft-1--quadra--0',
        'lotes/draft-1--lote--1',
    }


def test_consolidate_splits_writes_at_firestore_batch_limit():
    db = FakeDb()
    consolidate_approved_draft('draft-1', approved_draft(lote_count=1000), db)

    assert [len(commit) for commit in db.commits] == [500, 500, 2]
    assert not db.collection('loteamentos_drafts').document('draft-1').deleted


def test_consolidate_does_not_delete_draft_after_partial_batch_failure():
    db = FakeDb(fail_batch_number=2)
    with pytest.raises(RuntimeError, match='batch failed'):
        consolidate_approved_draft('draft-1', approved_draft(lote_count=1000), db)

    assert not db.collection('loteamentos_drafts').document('draft-1').deleted


def test_consolidate_infers_missing_quadra_feature_from_lote_reference():
    db = FakeDb()
    draft = approved_draft()
    draft['features'] = [{
        'properties': {
            'tipo': 'lote',
            'nome': 'L 1',
            'quadra': 'Q 1',
            'status': 'resolvido',
        },
    }]

    consolidate_approved_draft('draft-1', draft, db)

    writes = [operation for commit in db.commits for operation in commit]
    documents = {reference.path: document for reference, document in writes}
    quadra = next(document for path, document in documents.items() if path.startswith('quadras/'))
    lote = next(document for path, document in documents.items() if path.startswith('lotes/'))
    assert quadra['name'] == 'Q 1'
    assert lote['quadraId'] == quadra['id']


@pytest.mark.parametrize('features', [
    [{'properties': {'tipo': 'rua', 'nome': 'Rua 1'}}],
    [{'properties': {'tipo': 'quadra', 'nome': 'Q 1'}}],
])
def test_consolidate_rejects_invalid_or_lotless_draft_before_commits(features):
    db = FakeDb()
    draft = approved_draft()
    draft['features'] = features

    with pytest.raises(ValueError):
        consolidate_approved_draft('draft-1', draft, db)

    assert db.commits == []
    assert not db.collection('loteamentos_drafts').document('draft-1').deleted


def test_consolidate_rejects_lote_not_resolvido_before_commits():
    db = FakeDb()
    draft = approved_draft()
    draft['features'][1]['properties']['status'] = 'ambiguo'

    with pytest.raises(ValueError, match='não está resolvido'):
        consolidate_approved_draft('draft-1', draft, db)

    assert db.commits == []
