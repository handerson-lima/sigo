import logging
import hashlib
from typing import Any, Iterable
from firebase_admin import firestore

logger = logging.getLogger(__name__)

class DraftPersistenceError(Exception):
    pass

MAX_BATCH_OPERATIONS = 500


def save_draft_to_firestore(draft_id: str, geojson: dict, metadata: dict | None = None):
    """
    Salva o rascunho GeoJSON no Firestore na coleção loteamentos_drafts.
    """
    try:
        db = firestore.client()
        doc_ref = db.collection('loteamentos_drafts').document(draft_id)
        draft = dict(geojson)
        # The client-provided Storage metadata is deliberately copied into the
        # draft: the Firestore approval trigger has no access to the upload UI.
        if metadata:
            draft.update(metadata)
        doc_ref.set(draft)
        logger.info(f"Draft saved successfully to loteamentos_drafts/{draft_id}")
    except Exception as e:
        cls_name = type(e).__name__
        if "ServiceUnavailable" in cls_name or "DeadlineExceeded" in cls_name or "RetryError" in cls_name:
            logger.error(f"Transient error saving draft {draft_id}: {e}")
            raise e
        if "FirebaseError" in cls_name:
            logger.error(f"FirebaseError saving draft {draft_id}: {e}")
            raise e
        logger.error(f"Error saving draft {draft_id} to Firestore: {e}")
        raise DraftPersistenceError(f"Failed to persist draft to Firestore: {e}") from e


def _value(properties: Any, key: str) -> str:
    """Return a required, non-blank feature property with a useful error."""
    value = properties.get(key) if isinstance(properties, dict) else None
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Feature sem propriedade obrigatória '{key}'")
    return value.strip()


def _chunks(items: list[tuple[Any, dict]], size: int = MAX_BATCH_OPERATIONS) -> Iterable[list[tuple[Any, dict]]]:
    for start in range(0, len(items), size):
        yield items[start:start + size]


def consolidate_approved_draft(draft_id: str, draft: dict, db=None) -> None:
    """Materialize an approved GeoJSON draft using deterministic document IDs.

    Every write uses ``set`` so a CloudEvent retry converges on the same final
    documents.  The draft is deleted only after every write batch succeeds.
    """
    construtora_id = _value(draft, 'construtoraId')
    loteamento_name = _value(draft, 'loteamentoName')
    features = draft.get('features')
    if not isinstance(features, list):
        raise ValueError('Rascunho sem lista de features')

    quadras_by_name: dict[str, str] = {}
    lotes: list[tuple[int, dict]] = []
    quadras: list[tuple[int, str]] = []
    for index, feature in enumerate(features):
        if not isinstance(feature, dict):
            raise ValueError(f'Feature inválida no índice {index}')
        properties = feature.get('properties')
        if not isinstance(properties, dict):
            raise ValueError(f'Feature sem propriedades no índice {index}')
        feature_type = properties.get('tipo')
        if feature_type == 'quadra':
            name = _value(properties, 'nome')
            if name in quadras_by_name:
                raise ValueError(f'Nome de quadra duplicado: {name}')
            quadra_id = f'{draft_id}--quadra--{index}'
            quadras_by_name[name] = quadra_id
            quadras.append((index, name))
        elif feature_type == 'lote':
            _value(properties, 'nome')
            _value(properties, 'quadra')
            if properties.get('status') != 'resolvido':
                raise ValueError(f'Lote no índice {index} não está resolvido')
            lotes.append((index, properties))
        else:
            raise ValueError(f"Tipo de feature inválido no índice {index}: {feature_type!r}")

    if not lotes:
        raise ValueError('Rascunho sem lotes para consolidar')

    # Drafts usuais trazem a referência da quadra em cada lote, mas podem não
    # conter uma feature de quadra. Crie essas quadras de forma estável também.
    for _, properties in lotes:
        quadra_name = _value(properties, 'quadra')
        if quadra_name not in quadras_by_name:
            name_hash = hashlib.sha256(quadra_name.encode('utf-8')).hexdigest()[:16]
            quadras_by_name[quadra_name] = f'{draft_id}--quadra--ref--{name_hash}'
            quadras.append((-1, quadra_name))

    db = db or firestore.client()
    loteamento_id = f'{draft_id}--loteamento'
    now = firestore.SERVER_TIMESTAMP
    writes: list[tuple[Any, dict]] = [(
        db.collection('loteamentos').document(loteamento_id),
        {
            'id': loteamento_id,
            'construtoraId': construtora_id,
            'name': loteamento_name,
            'createdAt': now,
            'updatedAt': now,
        },
    )]
    for _, name in quadras:
        quadra_id = quadras_by_name[name]
        writes.append((
            db.collection('quadras').document(quadra_id),
            {
                'id': quadra_id,
                'construtoraId': construtora_id,
                'loteamentoId': loteamento_id,
                'name': name,
                'createdAt': now,
                'updatedAt': now,
            },
        ))

    for index, properties in lotes:
        quadra_name = _value(properties, 'quadra')
        quadra_id = quadras_by_name.get(quadra_name)
        lote_id = f'{draft_id}--lote--{index}'
        writes.append((
            db.collection('lotes').document(lote_id),
            {
                'id': lote_id,
                'construtoraId': construtora_id,
                'loteamentoId': loteamento_id,
                'quadraId': quadra_id,
                'name': _value(properties, 'nome'),
                'createdAt': now,
                'updatedAt': now,
            },
        ))

    for write_chunk in _chunks(writes):
        batch = db.batch()
        for reference, document in write_chunk:
            batch.set(reference, document)
        batch.commit()

    # Deliberately outside the write batches: a failed materialization never
    # removes the retry source.
    db.collection('loteamentos_drafts').document(draft_id).delete()
    logger.info('Draft %s consolidated: %d final documents', draft_id, len(writes))
