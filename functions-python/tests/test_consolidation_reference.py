"""Fim a fim da consolidação sobre o DXF de referência (sem Firestore).

Reproduz a matriz ``APROVACAO``: extrai o rascunho do fixture, aplica a revisão
humana (resolve os lotes ambíguos com nome), aprova e materializa os documentos
top-level. O DXF de referência não traz rótulos de quadra, então o teste também
garante que todo lote recebe uma FK de quadra válida (contenção espacial ou a
quadra ``Geral``).
"""
import os

from dxf_extraction import extract_dxf_geojson
from firestore_utils import consolidate_approved_draft

FIXTURE = os.path.join(
    os.path.dirname(__file__), '..', '..', 'dwg_dxf', '00a-LOTEAMENTO_HR_R13A-Model.dxf'
)
DRAFT_ID = '00a-LOTEAMENTO_HR_R13A-Model.dxf'


class _FakeDocument:
    def __init__(self, path):
        self.path = path


class _FakeCollection:
    def __init__(self, name):
        self.name = name

    def document(self, identifier):
        return _FakeDocument(f'{self.name}/{identifier}')


class _FakeBatch:
    def __init__(self, db):
        self.db = db
        self.operations = []

    def set(self, reference, document):
        self.operations.append((reference.path, document))

    def commit(self):
        self.db.commits.append(self.operations)


class _FakeDb:
    def __init__(self):
        self.collections = {}
        self.commits = []

    def collection(self, name):
        return self.collections.setdefault(name, _FakeCollection(name))

    def batch(self):
        return _FakeBatch(self)

    def documents(self):
        documents = {}
        for batch in self.commits:
            for path, document in batch:
                documents[path] = document
        return documents


def _revised_reference_draft():
    draft = extract_dxf_geojson(FIXTURE)
    draft['construtoraId'] = 'construtora-1'
    draft['loteamentoName'] = '00a-LOTEAMENTO_HR_R13A-Model'
    for index, feature in enumerate(draft['features']):
        properties = feature['properties']
        if properties.get('tipo') != 'lote':
            continue
        properties['status'] = 'resolvido'
        if not (properties.get('nome') or '').strip():
            properties['nome'] = f'LOTE {index}'
    return draft


def test_reference_dxf_consolidates_every_lote_with_a_quadra_fk():
    draft = _revised_reference_draft()
    lote_features = [
        f for f in draft['features'] if f['properties']['tipo'] == 'lote'
    ]
    assert lote_features, 'o fixture precisa produzir lotes'

    db = _FakeDb()
    consolidate_approved_draft(DRAFT_ID, draft, db=db)

    documents = db.documents()
    loteamento = documents[f'loteamentos/{DRAFT_ID}--loteamento']
    assert loteamento['construtoraId'] == 'construtora-1'
    assert loteamento['name'] == '00a-LOTEAMENTO_HR_R13A-Model'

    quadras = [
        path for path in documents if path.startswith('quadras/')
    ]
    lotes = {path: doc for path, doc in documents.items() if path.startswith('lotes/')}
    assert len(lotes) == len(lote_features)
    assert quadras, 'deve materializar ao menos uma quadra'
    for lote in lotes.values():
        assert isinstance(lote['quadraId'], str) and lote['quadraId']
        assert f'quadras/{lote["quadraId"]}' in documents
