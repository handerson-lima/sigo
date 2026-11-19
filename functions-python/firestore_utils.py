"""Persistência de rascunhos tabulares e consolidação sem geometria no Firestore."""
from __future__ import annotations

import hashlib
import logging
import math
from datetime import datetime, timezone
from typing import Any, Iterable

from firebase_admin import firestore

logger = logging.getLogger(__name__)

MAX_BATCH_OPERATIONS = 500
# Quadra de agrupamento para lotes sem referência de quadra no rascunho.
DEFAULT_QUADRA_NAME = 'Geral'

DEFAULT_ETAPAS: tuple[tuple[str, str, int], ...] = (
    ('muro', 'Muro', 1),
    ('cinza1', 'Cinza/1ª', 2),
    ('cinza2', 'Cinza/2ª', 3),
    ('cinza3', 'Cinza/3ª', 4),
    ('branca', 'Branca/Acabamento', 5),
)

DEFAULT_STATUS_ETAPAS_MAP: dict[str, str] = {
    'muro': 'pendente',
    'cinza1': 'pendente',
    'cinza2': 'pendente',
    'cinza3': 'pendente',
    'branca': 'pendente',
}

_LOTEAMENTO_OPTIONAL_FIELDS = (
    'bairro',
    'cidade',
    'uf',
    'proprietarioNome',
    'proprietarioDocumento',
    'responsavelTecnicoNome',
    'responsavelTecnicoRegistro',
)

_LOTE_NUMERIC_FIELDS = (
    'frenteM',
    'profundidadeM',
    'areaTerrenoM2',
    'areaConstruidaM2',
    'taxaOcupacaoPercent',
    'coeficienteAproveitamento',
    'areaPermeavelM2',
    'taxaPermeabilidadePercent',
    'areaImpermeavelM2',
    'recuoFrontalM',
    'recuoFundoM',
    'recuoLateralEsquerdoM',
    'recuoLateralDireitoM',
)

_LOTE_STRING_FIELDS = (
    'logradouro',
    'proprietarioNome',
    'proprietarioDocumento',
    'responsavelTecnicoNome',
    'responsavelTecnicoRegistro',
    'dataProjeto',
)


class DraftPersistenceError(Exception):
    pass


def _iso_now() -> str:
    """Instante ISO-8601 compatível com os modelos Flutter (``DateTime.parse``)."""
    return datetime.now(timezone.utc).isoformat()


def _optional_str(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    stripped = value.strip()
    return stripped or None


def _optional_float(value: Any) -> float | None:
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, (int, float)):
        fval = float(value)
        if math.isfinite(fval):
            return fval
    return None


def _value(mapping: Any, key: str) -> str:
    """Devolve uma propriedade obrigatória e não vazia, com erro útil."""
    value = mapping.get(key) if isinstance(mapping, dict) else None
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Rascunho sem propriedade obrigatória '{key}'")
    return value.strip()


def _chunks(items: list, size: int = MAX_BATCH_OPERATIONS) -> Iterable[list]:
    for start in range(0, len(items), size):
        yield items[start:start + size]


def _merge_loteamento_dict(
    existing: dict[str, Any] | None,
    incoming: dict[str, Any] | None,
    fallback_name: str | None = None,
) -> dict[str, Any]:
    merged: dict[str, Any] = {}
    for source in (existing or {}, incoming or {}):
        if not isinstance(source, dict):
            continue
        for key, value in source.items():
            if value is not None and value != '' and not merged.get(key):
                merged[key] = value
    if not merged.get('name') and fallback_name:
        merged['name'] = fallback_name
    return merged


def _merge_source_files(
    existing_files: list[dict[str, Any]],
    incoming_files: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    result = [dict(f) for f in existing_files if isinstance(f, dict)]
    index_by_name = {
        f.get('filename'): idx
        for idx, f in enumerate(result)
        if f.get('filename')
    }
    for entry in incoming_files:
        if not isinstance(entry, dict):
            continue
        fname = entry.get('filename')
        if fname and fname in index_by_name:
            result[index_by_name[fname]] = dict(entry)
        else:
            if fname:
                index_by_name[fname] = len(result)
            result.append(dict(entry))
    return result


def _merge_items(
    existing_items: list[dict[str, Any]],
    incoming_items: list[dict[str, Any]],
    incoming_filenames: set[str],
) -> list[dict[str, Any]]:
    """Faz merge idempotente de itens: substitui os do mesmo arquivo e apensa novos."""
    kept = [
        dict(item)
        for item in existing_items
        if isinstance(item, dict)
        and (not incoming_filenames or item.get('sourceFile') not in incoming_filenames)
    ]
    for item in incoming_items:
        if isinstance(item, dict):
            cleaned = {k: v for k, v in item.items() if k != 'geometry'}
            kept.append(cleaned)
    return kept


def _build_draft_document(
    existing: dict[str, Any] | None,
    draft_payload: dict[str, Any],
    metadata: dict[str, Any] | None,
    now: str,
) -> dict[str, Any]:
    meta = dict(metadata or {})
    incoming_loteamento = draft_payload.get('loteamento')
    if not isinstance(incoming_loteamento, dict):
        incoming_loteamento = {}

    fallback_name = _optional_str(meta.get('loteamentoName'))
    existing_loteamento = (existing or {}).get('loteamento')
    merged_loteamento = _merge_loteamento_dict(
        existing_loteamento if isinstance(existing_loteamento, dict) else None,
        incoming_loteamento,
        fallback_name=fallback_name,
    )

    incoming_files = draft_payload.get('sourceFiles')
    if not isinstance(incoming_files, list):
        incoming_files = []
    existing_files = (existing or {}).get('sourceFiles')
    if not isinstance(existing_files, list):
        existing_files = []
    merged_files = _merge_source_files(existing_files, incoming_files)

    incoming_filenames = {
        f.get('filename')
        for f in incoming_files
        if isinstance(f, dict) and f.get('filename')
    }
    incoming_items = draft_payload.get('items')
    if not isinstance(incoming_items, list):
        incoming_items = []
    existing_items = (existing or {}).get('items')
    if not isinstance(existing_items, list):
        existing_items = []
    merged_items = _merge_items(existing_items, incoming_items, incoming_filenames)

    incoming_status = meta.get('status') or draft_payload.get('status') or 'pendente'
    if merged_items:
        status = (existing or {}).get('status')
        if status not in ('pendente', 'aprovado'):
            status = 'pendente'
    else:
        status = incoming_status

    construtora_id = (
        _optional_str(meta.get('construtoraId'))
        or _optional_str((existing or {}).get('construtoraId'))
        or _optional_str(draft_payload.get('construtoraId'))
    )
    target_loteamento_id = (
        _optional_str(meta.get('targetLoteamentoId'))
        or _optional_str((existing or {}).get('targetLoteamentoId'))
        or _optional_str(draft_payload.get('targetLoteamentoId'))
    )
    source_format = (
        _optional_str(meta.get('sourceFormat'))
        or _optional_str(draft_payload.get('sourceFormat'))
        or _optional_str((existing or {}).get('sourceFormat'))
        or 'pdf'
    )

    doc: dict[str, Any] = {
        'construtoraId': construtora_id,
        'targetLoteamentoId': target_loteamento_id,
        'loteamento': merged_loteamento,
        'status': status,
        'sourceFormat': source_format,
        'sourceFiles': merged_files,
        'items': merged_items,
        'consolidationRequestId': (existing or {}).get('consolidationRequestId'),
        'consolidationCompletedRequestId': (existing or {}).get(
            'consolidationCompletedRequestId'
        ),
        'createdAt': (existing or {}).get('createdAt') or now,
        'updatedAt': now,
    }
    if merged_loteamento.get('name'):
        doc['loteamentoName'] = merged_loteamento['name']
    if status == 'erro' and meta.get('processingError'):
        doc['processingError'] = meta['processingError']
    return doc


def save_draft_to_firestore(
    draft_id: str,
    draft_payload: dict[str, Any],
    metadata: dict[str, Any] | None = None,
    *,
    db=None,
) -> dict[str, Any]:
    """Salva ou faz merge transacional de um rascunho tabular em ``loteamentos_drafts/{draft_id}``.

    Suporta uploads simultâneos de múltiplos PDFs compartilhando o mesmo ``draftId``
    via transação atômica do Firestore, sem gravar ``geometry`` nem ``features``.
    """
    try:
        client = db or firestore.client()
        doc_ref = client.collection('loteamentos_drafts').document(draft_id)
        now = _iso_now()

        transaction = client.transaction()

        @firestore.transactional
        def _upsert_in_transaction(txn):
            snapshot = doc_ref.get(transaction=txn)
            existing = snapshot.to_dict() if getattr(snapshot, 'exists', False) else None
            document = _build_draft_document(existing, draft_payload, metadata, now)
            txn.set(doc_ref, document)
            return document

        saved = _upsert_in_transaction(transaction)
        logger.info('Draft saved successfully to loteamentos_drafts/%s', draft_id)
        return saved
    except Exception as e:
        cls_name = type(e).__name__
        if (
            'ServiceUnavailable' in cls_name
            or 'DeadlineExceeded' in cls_name
            or 'RetryError' in cls_name
        ):
            logger.error('Transient error saving draft %s: %s', draft_id, e)
            raise e
        if 'FirebaseError' in cls_name:
            logger.error('FirebaseError saving draft %s: %s', draft_id, e)
            raise e
        logger.error('Error saving draft %s to Firestore: %s', draft_id, e)
        raise DraftPersistenceError(f'Failed to persist draft to Firestore: {e}') from e


def _build_lote_document(
    *,
    lote_id: str,
    construtora_id: str,
    loteamento_id: str,
    quadra_id: str,
    item: dict[str, Any],
    now: str,
) -> dict[str, Any]:
    name = (
        ''
        if item.get('status') == 'ambiguo'
        else (_optional_str(item.get('nome')) or '')
    )
    doc: dict[str, Any] = {
        'id': lote_id,
        'construtoraId': construtora_id,
        'loteamentoId': loteamento_id,
        'quadraId': quadra_id,
        'name': name,
        'progressoPercentual': 0,
        'etapasConcluidasCount': 0,
        'etapasTotalCount': len(DEFAULT_ETAPAS),
        'statusEtapasMap': dict(DEFAULT_STATUS_ETAPAS_MAP),
        'equipesVinculadas': [],
        'funcionariosVinculados': [],
        'createdAt': now,
        'updatedAt': now,
    }

    for field in _LOTE_NUMERIC_FIELDS:
        val = _optional_float(item.get(field))
        if val is not None:
            doc[field] = val

    if (
        'areaTerrenoM2' not in doc
        and 'frenteM' in doc
        and 'profundidadeM' in doc
        and doc['frenteM'] > 0
        and doc['profundidadeM'] > 0
    ):
        doc['areaTerrenoM2'] = round(doc['frenteM'] * doc['profundidadeM'], 6)

    for field in _LOTE_STRING_FIELDS:
        val = _optional_str(item.get(field))
        if val is not None:
            doc[field] = val

    return doc


def _build_default_etapas(
    *,
    construtora_id: str,
    loteamento_id: str,
    quadra_id: str,
    lote_id: str,
    now: str,
) -> list[tuple[str, dict[str, Any]]]:
    etapas: list[tuple[str, dict[str, Any]]] = []
    for tipo, nome, ordem in DEFAULT_ETAPAS:
        etapa_id = f'{lote_id}_{tipo}'
        etapas.append((
            etapa_id,
            {
                'id': etapa_id,
                'construtoraId': construtora_id,
                'loteamentoId': loteamento_id,
                'quadraId': quadra_id,
                'loteId': lote_id,
                'nome': nome,
                'ordem': ordem,
                'responsavelId': None,
                'status': 'pendente',
                'percentual': 0,
                'equipeId': None,
                'equipeNome': None,
                'funcionarioId': None,
                'funcionarioNome': None,
                'createdAt': now,
                'updatedAt': now,
            },
        ))
    return etapas


def consolidate_approved_draft(draft_id: str, draft: dict, db=None) -> None:
    """Materializa um rascunho tabular aprovado em documentos top-level determinísticos.

    - Suporta criar novo loteamento (``targetLoteamentoId`` ausente/nulo) ou mesclar
      quadras e lotes em um loteamento existente (``targetLoteamentoId`` preenchido).
    - Não persiste ``geometry`` em nenhum documento.
    - Cria atomicamente as **5 etapas padrão** (``muro``, ``cinza1``, ``cinza2``,
      ``cinza3``, ``branca``) para cada lote, respeitando o limite de 500 operações
      por ``WriteBatch`` do Firestore.
    - Preserva o documento de rascunho em ``loteamentos_drafts`` para retentativas.
    """
    construtora_id = _value(draft, 'construtoraId')
    target_loteamento_id = _optional_str(draft.get('targetLoteamentoId'))
    loteamento_raw = draft.get('loteamento')
    if not isinstance(loteamento_raw, dict):
        loteamento_raw = {}
    loteamento_name = (
        _optional_str(loteamento_raw.get('name'))
        or _optional_str(draft.get('loteamentoName'))
    )
    if not target_loteamento_id and not loteamento_name:
        raise ValueError("Rascunho sem propriedade obrigatória 'loteamento.name'")

    items = draft.get('items')
    if not isinstance(items, list) or not items:
        raise ValueError('Rascunho sem lotes para consolidar')

    db = db or firestore.client()
    loteamento_id = target_loteamento_id or f'{draft_id}--loteamento'
    now = _iso_now()

    quadras_by_name: dict[str, str] = {}
    quadra_documents: dict[str, dict[str, Any]] = {}
    quadra_order: list[str] = []

    def ensure_quadra(quadra_id: str, name: str, logradouro_padrao: str | None) -> str:
        if quadra_id not in quadra_documents:
            q_doc: dict[str, Any] = {
                'id': quadra_id,
                'construtoraId': construtora_id,
                'loteamentoId': loteamento_id,
                'name': name,
                'createdAt': now,
                'updatedAt': now,
            }
            if logradouro_padrao:
                q_doc['logradouroPadrao'] = logradouro_padrao
            quadra_documents[quadra_id] = q_doc
            quadra_order.append(quadra_id)
        elif logradouro_padrao and 'logradouroPadrao' not in quadra_documents[quadra_id]:
            quadra_documents[quadra_id]['logradouroPadrao'] = logradouro_padrao
        return quadra_id

    lote_documents: list[tuple[str, dict[str, Any]]] = []
    etapa_documents: list[tuple[str, dict[str, Any]]] = []

    for index, item in enumerate(items):
        if not isinstance(item, dict):
            raise ValueError(f'Item inválido no índice {index}')

        quadra_name = _optional_str(item.get('quadra')) or ''
        logradouro_item = _optional_str(item.get('logradouro'))
        if quadra_name:
            quadra_id = quadras_by_name.get(quadra_name)
            if not quadra_id:
                name_hash = hashlib.sha256(quadra_name.encode('utf-8')).hexdigest()[:16]
                quadra_id = ensure_quadra(
                    f'{draft_id}--quadra--ref--{name_hash}',
                    quadra_name,
                    logradouro_item,
                )
                quadras_by_name[quadra_name] = quadra_id
            else:
                ensure_quadra(quadra_id, quadra_name, logradouro_item)
        else:
            quadra_id = ensure_quadra(
                f'{draft_id}--quadra--geral',
                DEFAULT_QUADRA_NAME,
                logradouro_item,
            )

        lote_id = f'{draft_id}--lote--{index}'
        lote_doc = _build_lote_document(
            lote_id=lote_id,
            construtora_id=construtora_id,
            loteamento_id=loteamento_id,
            quadra_id=quadra_id,
            item=item,
            now=now,
        )
        lote_documents.append((lote_id, lote_doc))
        etapa_documents.extend(
            _build_default_etapas(
                construtora_id=construtora_id,
                loteamento_id=loteamento_id,
                quadra_id=quadra_id,
                lote_id=lote_id,
                now=now,
            )
        )

    writes: list[tuple[Any, dict[str, Any]]] = []
    if not target_loteamento_id:
        loteamento_doc: dict[str, Any] = {
            'id': loteamento_id,
            'construtoraId': construtora_id,
            'name': loteamento_name,
            'createdAt': now,
            'updatedAt': now,
        }
        for field in _LOTEAMENTO_OPTIONAL_FIELDS:
            val = _optional_str(loteamento_raw.get(field))
            if val is not None:
                loteamento_doc[field] = val
        writes.append((
            db.collection('loteamentos').document(loteamento_id),
            loteamento_doc,
        ))

    for quadra_id in quadra_order:
        writes.append((
            db.collection('quadras').document(quadra_id),
            quadra_documents[quadra_id],
        ))
    for lote_id, document in lote_documents:
        writes.append((db.collection('lotes').document(lote_id), document))
    for etapa_id, document in etapa_documents:
        writes.append((db.collection('etapas').document(etapa_id), document))

    for write_chunk in _chunks(writes, MAX_BATCH_OPERATIONS):
        batch = db.batch()
        for reference, document in write_chunk:
            batch.set(reference, document)
        batch.commit()

    logger.info('Draft %s materialized: %d final documents', draft_id, len(writes))
