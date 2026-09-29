"""Fim a fim da consolidação sobre o DXF de referência sem cotas (sem Firestore).

Reproduz a matriz ``APROVAR_COM_AMBIGUOS``: extrai o rascunho do fixture, aprova
sem resolver os nomes dos lotes (aceitando os ambíguos) e materializa os
documentos top-level. Garante que quadras com nome duplicado são mescladas em um
único documento, que lotes sem nome viram ``name: ''`` e que todo lote recebe uma
FK de quadra válida.
"""
import os

from dxf_extraction import extract_dxf_geojson
from firestore_utils import consolidate_approved_draft

FIXTURE = os.path.join(
    os.path.dirname(__file__),
    '..',
    '..',
    'dwg_dxf',
    '00a-LOTEAMENTO_HR_R13A-Model_SEM_COTAS.dxf',
)
DRAFT_ID = '00a-LOTEAMENTO_HR_R13A-Model_SEM_COTAS.dxf'


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


def _approved_reference_draft():
    """Aprova o rascunho do fixture sem resolver nomes (matriz de ambíguos)."""
    draft = extract_dxf_geojson(FIXTURE)
    draft['construtoraId'] = 'construtora-1'
    draft['loteamentoName'] = '00a-LOTEAMENTO_HR_R13A-Model_SEM_COTAS'
    return draft


def test_reference_dxf_consolidates_with_ambiguous_lotes_and_merged_quadras():
    draft = _approved_reference_draft()
    lote_features = [
        f for f in draft['features'] if f['properties']['tipo'] == 'lote'
    ]
    assert lote_features, 'o fixture precisa produzir lotes'
    assert any(
        f['properties']['status'] == 'ambiguo' for f in lote_features
    ), 'o fixture precisa produzir lotes ambíguos'

    db = _FakeDb()
    consolidate_approved_draft(DRAFT_ID, draft, db=db)

    documents = db.documents()
    loteamento = documents[f'loteamentos/{DRAFT_ID}--loteamento']
    assert loteamento['construtoraId'] == 'construtora-1'
    assert loteamento['name'] == '00a-LOTEAMENTO_HR_R13A-Model_SEM_COTAS'

    quadras = {
        path: document
        for path, document in documents.items()
        if path.startswith('quadras/')
    }
    lotes = {
        path: document
        for path, document in documents.items()
        if path.startswith('lotes/')
    }
    assert len(lotes) == len(lote_features)
    assert quadras, 'deve materializar ao menos uma quadra'

    # Toda quadra tem nome único (duplicados mesclados) e nenhum lote fica sem FK.
    named = [d['name'] for d in quadras.values() if d['name']]
    assert len(named) == len(set(named)), 'nomes de quadra devem ser únicos'
    assert 'Q-09' in named and 'Q-11' in named and 'Q-17' in named

    sem_nome = [d for d in lotes.values() if d['name'] == '']
    assert sem_nome, 'lotes ambíguos devem ser materializados com nome vazio'
    for lote in lotes.values():
        assert isinstance(lote['quadraId'], str) and lote['quadraId']
        assert f'quadras/{lote["quadraId"]}' in documents
