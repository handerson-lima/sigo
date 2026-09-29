import hashlib
import json
import pytest
from unittest.mock import patch, MagicMock
from firestore_utils import (
    consolidate_approved_draft,
    save_draft_to_firestore,
    DraftPersistenceError,
)

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
    mock_doc.set.assert_called_once()

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


class _FakeDocument:
    def __init__(self, path):
        self.path = path


class _FakeCollection:
    def __init__(self, name):
        self.name = name

    def document(self, identifier):
        return _FakeDocument(f'{self.name}/{identifier}')


class _FakeBatch:
    def __init__(self, db, fail=False):
        self.db = db
        self.fail = fail
        self.operations = []

    def set(self, reference, document):
        self.operations.append((reference.path, document))

    def commit(self):
        if self.fail:
            raise RuntimeError('batch failed')
        self.db.commits.append(self.operations)


class _FakeDb:
    def __init__(self, fail_batch_number=None):
        self.collections = {}
        self.commits = []
        self.fail_batch_number = fail_batch_number
        self.batch_count = 0

    def collection(self, name):
        return self.collections.setdefault(name, _FakeCollection(name))

    def batch(self):
        self.batch_count += 1
        return _FakeBatch(self, self.batch_count == self.fail_batch_number)


def _documents(db):
    documents = {}
    for batch in db.commits:
        for path, document in batch:
            documents[path] = document
    return documents


GEOMETRY = {
    'type': 'Polygon',
    'coordinates': [[[0, 0], [10, 0], [10, 10], [0, 0]]],
}


def _approved_draft(lote_count=1, geometry=None, lote_status='resolvido', quadra_feature=False):
    features = []
    if quadra_feature:
        feature = {'properties': {'tipo': 'quadra', 'nome': 'Q 1'}}
        if geometry is not None:
            feature['geometry'] = geometry
        features.append(feature)
    for index in range(lote_count):
        feature = {
            'properties': {
                'tipo': 'lote', 'nome': f'L {index}',
                'quadra': 'Q 1', 'status': lote_status,
            },
        }
        if geometry is not None:
            feature['geometry'] = geometry
        features.append(feature)
    return {
        'construtoraId': 'construtora-1',
        'loteamentoName': 'LOTEAMENTO_APROVADO',
        'features': features,
    }


def test_consolidate_creates_top_level_documents_with_foreign_keys():
    db = _FakeDb()
    consolidate_approved_draft('draft-1', _approved_draft(lote_count=2), db=db)

    documents = _documents(db)
    loteamento_id = 'draft-1--loteamento'
    loteamento = documents[f'loteamentos/{loteamento_id}']
    assert loteamento['id'] == loteamento_id
    assert loteamento['construtoraId'] == 'construtora-1'
    assert loteamento['name'] == 'LOTEAMENTO_APROVADO'
    assert isinstance(loteamento['createdAt'], str)
    assert isinstance(loteamento['updatedAt'], str)

    quadra_paths = [p for p in documents if p.startswith('quadras/')]
    assert len(quadra_paths) == 1
    quadra = documents[quadra_paths[0]]
    assert quadra['construtoraId'] == 'construtora-1'
    assert quadra['loteamentoId'] == loteamento_id
    assert quadra['name'] == 'Q 1'

    lote_paths = sorted(p for p in documents if p.startswith('lotes/'))
    assert lote_paths == ['lotes/draft-1--lote--0', 'lotes/draft-1--lote--1']
    for path in lote_paths:
        assert documents[path]['construtoraId'] == 'construtora-1'
        assert documents[path]['loteamentoId'] == loteamento_id
        assert documents[path]['quadraId'] == quadra['id']


def test_consolidate_reads_geometry_serialized_as_string_in_the_draft():
    db = _FakeDb()
    serialized = json.dumps(GEOMETRY)
    consolidate_approved_draft('draft-1', _approved_draft(geometry=serialized), db=db)

    documents = _documents(db)
    lote = documents['lotes/draft-1--lote--0']
    assert lote['geometry'] == json.dumps(GEOMETRY)
    assert json.loads(lote['geometry']) == GEOMETRY


def test_consolidate_reads_geometry_as_map():
    db = _FakeDb()
    consolidate_approved_draft('draft-1', _approved_draft(geometry=GEOMETRY), db=db)

    documents = _documents(db)
    lote = documents['lotes/draft-1--lote--0']
    assert json.loads(lote['geometry']) == GEOMETRY


def test_consolidate_uses_quadra_feature_when_present():
    db = _FakeDb()
    consolidate_approved_draft(
        'draft-1', _approved_draft(quadra_feature=True), db=db,
    )

    documents = _documents(db)
    assert 'quadras/draft-1--quadra--0' in documents
    assert documents['lotes/draft-1--lote--1']['quadraId'] == 'draft-1--quadra--0'


def test_consolidate_creates_reference_quadra_with_stable_hash():
    db = _FakeDb()
    consolidate_approved_draft('draft-1', _approved_draft(), db=db)

    expected_hash = hashlib.sha256('Q 1'.encode('utf-8')).hexdigest()[:16]
    quadra_id = f'draft-1--quadra--ref--{expected_hash}'
    documents = _documents(db)
    assert f'quadras/{quadra_id}' in documents
    assert documents['lotes/draft-1--lote--0']['quadraId'] == quadra_id


def test_consolidate_is_idempotent_for_duplicate_delivery():
    draft = _approved_draft(lote_count=2)
    first = _FakeDb()
    second = _FakeDb()
    consolidate_approved_draft('draft-1', draft, db=first)
    consolidate_approved_draft('draft-1', draft, db=second)

    assert set(_documents(first)) == set(_documents(second))


def test_consolidate_accepts_valido_lote_status():
    db = _FakeDb()
    consolidate_approved_draft(
        'draft-1', _approved_draft(lote_status='valido'), db=db,
    )
    assert 'lotes/draft-1--lote--0' in _documents(db)


def test_consolidate_rejects_ambiguous_lote_without_writing():
    db = _FakeDb()
    with pytest.raises(ValueError, match='ambíguo'):
        consolidate_approved_draft(
            'draft-1', _approved_draft(lote_status='ambiguo'), db=db,
        )
    assert db.commits == []


def test_consolidate_rejects_draft_without_lotes():
    db = _FakeDb()
    with pytest.raises(ValueError, match='sem lotes'):
        consolidate_approved_draft(
            'draft-1',
            {'construtoraId': 'construtora-1', 'loteamentoName': 'X', 'features': []},
            db=db,
        )
    assert db.commits == []


def test_consolidate_splits_writes_into_batches_of_500():
    db = _FakeDb()
    consolidate_approved_draft('draft-1', _approved_draft(lote_count=600), db=db)

    # 1 loteamento + 1 quadra + 600 lotes = 602 documentos -> 2 batches.
    assert len(db.commits) == 2
    assert len(db.commits[0]) == 500
    assert len(db.commits[1]) == 102


def test_consolidate_never_touches_the_draft_document():
    db = _FakeDb()
    consolidate_approved_draft('draft-1', _approved_draft(), db=db)
    # A retenção do rascunho é o que permite a retentativa.
    assert 'loteamentos_drafts' not in db.collections


def test_consolidate_failure_keeps_no_completed_marker_and_raises():
    db = _FakeDb(fail_batch_number=1)
    with pytest.raises(RuntimeError, match='batch failed'):
        consolidate_approved_draft('draft-1', _approved_draft(lote_count=600), db=db)
    # Nenhum batch concluído: o chamador decide reter o rascunho para retry.
    assert db.commits == []


def test_consolidate_assigns_lote_without_quadra_to_containing_quadra():
    db = _FakeDb()
    quadra_geometry = {
        'type': 'Polygon',
        'coordinates': [[[0, 0], [100, 0], [100, 100], [0, 100], [0, 0]]],
    }
    lote_geometry = {
        'type': 'Polygon',
        'coordinates': [[[10, 10], [20, 10], [20, 20], [10, 20], [10, 10]]],
    }
    draft = {
        'construtoraId': 'construtora-1',
        'loteamentoName': 'LOTEAMENTO',
        'features': [
            {'properties': {'tipo': 'quadra', 'nome': 'A'}, 'geometry': quadra_geometry},
            {
                'properties': {'tipo': 'lote', 'nome': 'L 1', 'quadra': '', 'status': 'resolvido'},
                'geometry': lote_geometry,
            },
        ],
    }
    consolidate_approved_draft('draft-1', draft, db=db)

    documents = _documents(db)
    assert documents['lotes/draft-1--lote--1']['quadraId'] == 'draft-1--quadra--0'


def test_consolidate_falls_back_to_default_quadra_when_unassigned():
    db = _FakeDb()
    draft = _approved_draft()
    for feature in draft['features']:
        feature['properties']['quadra'] = ''
    consolidate_approved_draft('draft-1', draft, db=db)

    documents = _documents(db)
    lote = documents['lotes/draft-1--lote--0']
    assert lote['quadraId'] == 'draft-1--quadra--geral'
    assert documents['quadras/draft-1--quadra--geral']['name'] == 'Geral'


def test_consolidate_allows_quadra_feature_without_name():
    db = _FakeDb()
    draft = _approved_draft()
    draft['features'].insert(0, {
        'properties': {'tipo': 'quadra', 'nome': '', 'status': 'resolvido'},
        'geometry': GEOMETRY,
    })
    consolidate_approved_draft('draft-1', draft, db=db)

    documents = _documents(db)
    assert documents['quadras/draft-1--quadra--0']['name'] == ''
