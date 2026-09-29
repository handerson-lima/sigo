import logging
from firebase_admin import firestore

logger = logging.getLogger(__name__)

class DraftPersistenceError(Exception):
    pass

def save_draft_to_firestore(draft_id: str, geojson: dict, metadata: dict | None = None):
    """
    Salva o rascunho GeoJSON no Firestore na coleção loteamentos_drafts.
    """
    try:
        db = firestore.client()
        doc_ref = db.collection('loteamentos_drafts').document(draft_id)
        draft = dict(geojson)
        # O metadado vindo do Storage é copiado para o rascunho: a tela de
        # revisão depende de construtora/nome que só o upload conhece.
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
