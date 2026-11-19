"""Fim a fim da consolidação tabular sobre o DXF de referência (sem Firestore).

Extrai o rascunho tabular do fixture, aprova sem resolver os lotes ambíguos e
materializa loteamento, quadras, lotes e as 5 etapas padrão de cada lote em
múltiplos WriteBatches (respeitando o teto de 500 operações por batch), sem
qualquer campo ``geometry``.
"""
import os

from dxf_extraction import extract_dxf_draft
from firestore_utils import DEFAULT_ETAPAS, MAX_BATCH_OPERATIONS, consolidate_approved_draft

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
    draft = extract_dxf_draft(FIXTURE)
    draft['construtoraId'] = 'construtora-1'
    draft['loteamento'] = {'name': '00a-LOTEAMENTO_HR_R13A-Model_SEM_COTAS'}
    return draft


def test_reference_dxf_consolidates_tabular_with_etapas_and_multi_batches():
    draft = _approved_reference_draft()
    items = draft['items']
    assert items, 'o fixture precisa produzir lotes'
    assert any(i['status'] == 'ambiguo' for i in items), 'o fixture precisa produzir lotes ambíguos'

    db = _FakeDb()
    consolidate_approved_draft(DRAFT_ID, draft, db=db)

    # Todos os batches respeitam o limite de 500 operações.
    assert len(db.commits) >= 3
    assert all(len(batch) <= MAX_BATCH_OPERATIONS for batch in db.commits)

    documents = db.documents()
    loteamento = documents[f'loteamentos/{DRAFT_ID}--loteamento']
    assert loteamento['construtoraId'] == 'construtora-1'
    assert loteamento['name'] == '00a-LOTEAMENTO_HR_R13A-Model_SEM_COTAS'
    assert 'geometry' not in loteamento

    quadras = {p: d for p, d in documents.items() if p.startswith('quadras/')}
    lotes = {p: d for p, d in documents.items() if p.startswith('lotes/')}
    etapas = {p: d for p, d in documents.items() if p.startswith('etapas/')}

    assert len(lotes) == len(items)
    assert len(etapas) == len(items) * len(DEFAULT_ETAPAS)
    assert quadras, 'deve materializar ao menos uma quadra'

    named = [d['name'] for d in quadras.values() if d['name']]
    assert len(named) == len(set(named)), 'nomes de quadra devem ser únicos'
    assert 'Q-09' in named and 'Q-11' in named and 'Q-17' in named and 'Q-19' in named
    assert all('geometry' not in q for q in quadras.values())

    sem_nome = [d for d in lotes.values() if d['name'] == '']
    assert sem_nome, 'lotes ambíguos devem ser materializados com nome vazio'
    for lote in lotes.values():
        assert 'geometry' not in lote
        assert isinstance(lote['quadraId'], str) and lote['quadraId']
        assert f'quadras/{lote["quadraId"]}' in documents
        assert lote['progressoPercentual'] == 0
        assert lote['etapasConcluidasCount'] == 0
        assert lote['etapasTotalCount'] == 5
        for tipo, _nome, _ordem in DEFAULT_ETAPAS:
            assert f'etapas/{lote["id"]}_{tipo}' in etapas
