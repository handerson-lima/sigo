import hashlib
from unittest.mock import patch

import pytest

from firestore_utils import (
    DEFAULT_ETAPAS,
    DEFAULT_STATUS_ETAPAS_MAP,
    MAX_BATCH_OPERATIONS,
    DraftPersistenceError,
    consolidate_approved_draft,
    save_draft_to_firestore,
)


def _immediate_transactional(function):
    return function


class _FakeSnapshot:
    def __init__(self, data):
        self._data = dict(data) if data is not None else None
        self.exists = data is not None

    def to_dict(self):
        return dict(self._data) if self._data is not None else None


class _FakeDraftDocRef:
    def __init__(self, store, path, set_side_effect=None):
        self._store = store
        self.path = path
        self._set_side_effect = set_side_effect

    def get(self, transaction=None):
        return _FakeSnapshot(self._store.get(self.path))

    def set(self, document):
        if self._set_side_effect is not None:
            raise self._set_side_effect
        self._store[self.path] = dict(document)


class _FakeTransaction:
    def set(self, reference, document):
        reference.set(document)


class _FakeDocument:
    def __init__(self, path):
        self.path = path


class _FakeCollection:
    def __init__(self, name, store, set_side_effect=None):
        self.name = name
        self._store = store
        self._set_side_effect = set_side_effect

    def document(self, identifier):
        path = f'{self.name}/{identifier}'
        if self.name == 'loteamentos_drafts':
            return _FakeDraftDocRef(self._store, path, set_side_effect=self._set_side_effect)
        return _FakeDocument(path)


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
    def __init__(self, fail_batch_number=None, set_side_effect=None):
        self.store = {}
        self.collections = {}
        self.commits = []
        self.fail_batch_number = fail_batch_number
        self.set_side_effect = set_side_effect
        self.batch_count = 0

    def collection(self, name):
        return self.collections.setdefault(
            name, _FakeCollection(name, self.store, set_side_effect=self.set_side_effect)
        )

    def transaction(self):
        return _FakeTransaction()

    def batch(self):
        self.batch_count += 1
        return _FakeBatch(self, self.batch_count == self.fail_batch_number)


def _documents(db):
    documents = {}
    for batch in db.commits:
        for path, document in batch:
            documents[path] = document
    return documents


def _sample_pdf_payload(filename='lote_31_q28.pdf', lote_name='Lote 31', quadra='Quadra 28'):
    return {
        'loteamento': {
            'name': 'Loteamento Jardim Botanico',
            'bairro': 'Estivas',
            'cidade': 'Extremoz',
            'uf': 'RN',
            'proprietarioNome': 'CARNEIRO E OLIVEIRA EMPREENDIMENTOS LTDA',
            'proprietarioDocumento': '69.307.863/0001-02',
            'responsavelTecnicoNome': 'JOCSA RAMOS VARELA',
            'responsavelTecnicoRegistro': '2116022975',
        },
        'sourceFormat': 'pdf',
        'sourceFiles': [
            {'filename': filename, 'pageCount': 1, 'status': 'processado'}
        ],
        'items': [
            {
                'quadra': quadra,
                'nome': lote_name,
                'frenteM': 10.0,
                'profundidadeM': 20.0,
                'areaTerrenoM2': 200.0,
                'areaConstruidaM2': 49.96,
                'logradouro': 'Rua Sandoval Wanderley, s/n',
                'taxaOcupacaoPercent': 24.98,
                'coeficienteAproveitamento': 0.24,
                'areaPermeavelM2': 112.46,
                'taxaPermeabilidadePercent': 56.23,
                'areaImpermeavelM2': 37.58,
                'recuoFrontalM': 5.05,
                'recuoFundoM': 5.94,
                'recuoLateralEsquerdoM': 1.43,
                'recuoLateralDireitoM': 1.43,
                'dataProjeto': 'outubro/26',
                'sourceFile': filename,
                'sourcePage': 1,
                'status': 'valido',
            }
        ],
    }


@patch('firestore_utils.firestore.transactional', side_effect=_immediate_transactional)
def test_save_draft_persists_tabular_contract_without_geometry(_):
    db = _FakeDb()
    payload = _sample_pdf_payload()
    metadata = {
        'construtoraId': 'construtora-1',
        'targetLoteamentoId': 'lot-existente-1',
        'status': 'pendente',
        'sourceFormat': 'pdf',
    }

    saved = save_draft_to_firestore('draft-pdf-1', payload, metadata, db=db)

    stored = db.store['loteamentos_drafts/draft-pdf-1']
    assert saved == stored
    assert 'features' not in stored
    assert stored['construtoraId'] == 'construtora-1'
    assert stored['targetLoteamentoId'] == 'lot-existente-1'
    assert stored['loteamento']['name'] == 'Loteamento Jardim Botanico'
    assert stored['sourceFormat'] == 'pdf'
    assert len(stored['sourceFiles']) == 1
    assert len(stored['items']) == 1
    assert 'geometry' not in stored['items'][0]


@patch('firestore_utils.firestore.transactional', side_effect=_immediate_transactional)
def test_save_draft_merges_multiple_pdfs_sharing_same_draft_id_transactionally(_):
    db = _FakeDb()
    meta = {'construtoraId': 'construtora-1', 'status': 'pendente', 'sourceFormat': 'pdf'}

    # Primeiro PDF
    payload1 = _sample_pdf_payload('lote_31_q28.pdf', 'Lote 31', 'Quadra 28')
    save_draft_to_firestore('shared-draft', payload1, meta, db=db)

    # Segundo PDF compartilhando o mesmo draftId
    payload2 = _sample_pdf_payload('lote_32_q28.pdf', 'Lote 32', 'Quadra 28')
    payload2['loteamento'] = {'name': 'Outro Nome Não Sobrescreve', 'bairro': 'Estivas'}
    save_draft_to_firestore('shared-draft', payload2, meta, db=db)

    # Reentrega idempotente do primeiro PDF não duplica itens nem sourceFiles
    save_draft_to_firestore('shared-draft', payload1, meta, db=db)

    stored = db.store['loteamentos_drafts/shared-draft']
    assert stored['status'] == 'pendente'
    assert stored['loteamento']['name'] == 'Loteamento Jardim Botanico'
    assert [f['filename'] for f in stored['sourceFiles']] == [
        'lote_31_q28.pdf', 'lote_32_q28.pdf',
    ]
    assert sorted(i['nome'] for i in stored['items']) == ['Lote 31', 'Lote 32']


@patch('firestore_utils.firestore.transactional', side_effect=_immediate_transactional)
def test_save_draft_keeps_valid_items_when_subsequent_file_fails(_):
    db = _FakeDb()
    meta = {'construtoraId': 'construtora-1', 'status': 'pendente', 'sourceFormat': 'pdf'}
    save_draft_to_firestore('shared-draft', _sample_pdf_payload('ok.pdf', 'Lote 31'), meta, db=db)

    error_payload = {
        'loteamento': {},
        'sourceFormat': 'pdf',
        'sourceFiles': [{'filename': 'corrupt.pdf', 'pageCount': 0, 'status': 'erro', 'error': 'PDF inválido'}],
        'items': [],
    }
    save_draft_to_firestore(
        'shared-draft',
        error_payload,
        {**meta, 'status': 'erro', 'processingError': 'PDF inválido'},
        db=db,
    )

    stored = db.store['loteamentos_drafts/shared-draft']
    assert stored['status'] == 'pendente'
    assert len(stored['items']) == 1
    assert len(stored['sourceFiles']) == 2
    assert stored['sourceFiles'][1]['status'] == 'erro'


@patch('firestore_utils.firestore.transactional', side_effect=_immediate_transactional)
def test_save_draft_transient_error(_):
    db = _FakeDb(set_side_effect=type('ServiceUnavailable', (Exception,), {})('Unavailable'))
    with pytest.raises(Exception) as exc:
        save_draft_to_firestore('test_id', {'items': []}, db=db)
    assert 'ServiceUnavailable' in type(exc.value).__name__


@patch('firestore_utils.firestore.transactional', side_effect=_immediate_transactional)
def test_save_draft_fatal_error(_):
    db = _FakeDb(set_side_effect=ValueError('Invalid data'))
    with pytest.raises(DraftPersistenceError, match='Failed to persist draft to Firestore'):
        save_draft_to_firestore('test_id', {'items': []}, db=db)


def _approved_tabular_draft(
    lote_count=1,
    lote_status='valido',
    quadra='Quadra 28',
    target_loteamento_id=None,
):
    items = []
    for index in range(lote_count):
        items.append({
            'quadra': quadra,
            'nome': f'Lote {index + 1}',
            'frenteM': 10.0,
            'profundidadeM': 20.0,
            'areaTerrenoM2': 200.0,
            'areaConstruidaM2': 49.96,
            'logradouro': 'Rua Sandoval Wanderley, s/n',
            'taxaOcupacaoPercent': 24.98,
            'coeficienteAproveitamento': 0.24,
            'areaPermeavelM2': 112.46,
            'taxaPermeabilidadePercent': 56.23,
            'areaImpermeavelM2': 37.58,
            'recuoFrontalM': 5.05,
            'recuoFundoM': 5.94,
            'recuoLateralEsquerdoM': 1.43,
            'recuoLateralDireitoM': 1.43,
            'dataProjeto': 'outubro/26',
            'status': lote_status,
        })
    return {
        'construtoraId': 'construtora-1',
        'targetLoteamentoId': target_loteamento_id,
        'loteamento': {
            'name': 'Loteamento Jardim Botanico',
            'bairro': 'Estivas',
            'cidade': 'Extremoz',
            'uf': 'RN',
            'proprietarioNome': 'CARNEIRO E OLIVEIRA EMPREENDIMENTOS LTDA',
            'proprietarioDocumento': '69.307.863/0001-02',
            'responsavelTecnicoNome': 'JOCSA RAMOS VARELA',
            'responsavelTecnicoRegistro': '2116022975',
        },
        'items': items,
    }


def test_consolidate_creates_loteamento_quadras_lotes_and_five_default_etapas():
    db = _FakeDb()
    consolidate_approved_draft('draft-1', _approved_tabular_draft(lote_count=2), db=db)

    documents = _documents(db)
    loteamento_id = 'draft-1--loteamento'
    loteamento = documents[f'loteamentos/{loteamento_id}']
    assert loteamento['id'] == loteamento_id
    assert loteamento['construtoraId'] == 'construtora-1'
    assert loteamento['name'] == 'Loteamento Jardim Botanico'
    assert loteamento['bairro'] == 'Estivas'
    assert loteamento['cidade'] == 'Extremoz'
    assert loteamento['uf'] == 'RN'
    assert loteamento['proprietarioDocumento'] == '69.307.863/0001-02'
    assert loteamento['responsavelTecnicoRegistro'] == '2116022975'
    assert 'geometry' not in loteamento

    expected_hash = hashlib.sha256('Quadra 28'.encode('utf-8')).hexdigest()[:16]
    quadra_id = f'draft-1--quadra--ref--{expected_hash}'
    quadra = documents[f'quadras/{quadra_id}']
    assert quadra['loteamentoId'] == loteamento_id
    assert quadra['name'] == 'Quadra 28'
    assert quadra['logradouroPadrao'] == 'Rua Sandoval Wanderley, s/n'
    assert 'geometry' not in quadra

    lote_paths = sorted(p for p in documents if p.startswith('lotes/'))
    assert lote_paths == ['lotes/draft-1--lote--0', 'lotes/draft-1--lote--1']
    for path in lote_paths:
        lote = documents[path]
        assert 'geometry' not in lote
        assert lote['construtoraId'] == 'construtora-1'
        assert lote['loteamentoId'] == loteamento_id
        assert lote['quadraId'] == quadra_id
        assert lote['frenteM'] == 10.0
        assert lote['profundidadeM'] == 20.0
        assert lote['areaTerrenoM2'] == 200.0
        assert lote['areaConstruidaM2'] == 49.96
        assert lote['taxaOcupacaoPercent'] == 24.98
        assert lote['recuoFrontalM'] == 5.05
        assert lote['progressoPercentual'] == 0
        assert lote['etapasConcluidasCount'] == 0
        assert lote['etapasTotalCount'] == 5
        assert lote['statusEtapasMap'] == DEFAULT_STATUS_ETAPAS_MAP
        assert lote['equipesVinculadas'] == []
        assert lote['funcionariosVinculados'] == []

        for tipo, nome, ordem in DEFAULT_ETAPAS:
            etapa_id = f'{lote["id"]}_{tipo}'
            etapa = documents[f'etapas/{etapa_id}']
            assert etapa['id'] == etapa_id
            assert etapa['loteId'] == lote['id']
            assert etapa['quadraId'] == quadra_id
            assert etapa['loteamentoId'] == loteamento_id
            assert etapa['nome'] == nome
            assert etapa['ordem'] == ordem
            assert etapa['status'] == 'pendente'
            assert etapa['percentual'] == 0


def test_consolidate_merges_into_existing_loteamento_when_target_loteamento_id_is_set():
    db = _FakeDb()
    draft = _approved_tabular_draft(lote_count=1, target_loteamento_id='lot-existente-99')
    consolidate_approved_draft('draft-2', draft, db=db)

    documents = _documents(db)
    # Não cria nem sobrescreve documento na coleção loteamentos.
    assert not any(p.startswith('loteamentos/') for p in documents)

    lote = documents['lotes/draft-2--lote--0']
    assert lote['loteamentoId'] == 'lot-existente-99'
    quadra = documents[f'quadras/{lote["quadraId"]}']
    assert quadra['loteamentoId'] == 'lot-existente-99'
    for tipo, _nome, _ordem in DEFAULT_ETAPAS:
        etapa = documents[f'etapas/draft-2--lote--0_{tipo}']
        assert etapa['loteamentoId'] == 'lot-existente-99'


def test_consolidate_splits_writes_into_batches_of_500_including_etapas():
    db = _FakeDb()
    # 100 lotes -> 1 loteamento + 1 quadra + 100 lotes + 500 etapas = 602 operações -> 2 batches (500 + 102)
    consolidate_approved_draft('draft-batch', _approved_tabular_draft(lote_count=100), db=db)

    assert len(db.commits) == 2
    assert len(db.commits[0]) == MAX_BATCH_OPERATIONS
    assert len(db.commits[1]) == 102


def test_consolidate_is_idempotent_for_duplicate_delivery():
    draft = _approved_tabular_draft(lote_count=2)
    first = _FakeDb()
    second = _FakeDb()
    consolidate_approved_draft('draft-1', draft, db=first)
    consolidate_approved_draft('draft-1', draft, db=second)

    assert set(_documents(first)) == set(_documents(second))


def test_consolidate_materializes_ambiguous_lote_with_empty_name_and_default_quadra():
    db = _FakeDb()
    draft = _approved_tabular_draft(lote_count=1, lote_status='ambiguo', quadra='')
    consolidate_approved_draft('draft-amb', draft, db=db)

    documents = _documents(db)
    lote = documents['lotes/draft-amb--lote--0']
    assert lote['name'] == ''
    assert lote['quadraId'] == 'draft-amb--quadra--geral'
    assert documents['quadras/draft-amb--quadra--geral']['name'] == 'Geral'


def test_consolidate_rejects_draft_without_items():
    db = _FakeDb()
    with pytest.raises(ValueError, match='sem lotes'):
        consolidate_approved_draft(
            'draft-1',
            {'construtoraId': 'construtora-1', 'loteamento': {'name': 'X'}, 'items': []},
            db=db,
        )
    assert db.commits == []


def test_consolidate_never_touches_draft_and_propagates_batch_failure():
    db_ok = _FakeDb()
    consolidate_approved_draft('draft-1', _approved_tabular_draft(), db=db_ok)
    assert 'loteamentos_drafts' not in db_ok.collections

    db_fail = _FakeDb(fail_batch_number=1)
    with pytest.raises(RuntimeError, match='batch failed'):
        consolidate_approved_draft('draft-1', _approved_tabular_draft(lote_count=100), db=db_fail)
    assert db_fail.commits == []
