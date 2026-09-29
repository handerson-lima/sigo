import json
import logging
from firebase_admin import firestore

logger = logging.getLogger(__name__)

class DraftPersistenceError(Exception):
    pass

def _serialize_feature_geometry(feature):
    """Serializa ``feature['geometry']`` (Map → String JSON) de forma idempotente.

    O Firestore rejeita arrays aninhados, e ``geometry.coordinates`` é um array
    de arrays. Geometrias já serializadas (String) são devolvidas sem alteração.
    """
    if not isinstance(feature, dict):
        return feature
    geometry = feature.get('geometry')
    if not isinstance(geometry, dict):
        return feature
    serialized = dict(feature)
    serialized['geometry'] = json.dumps(geometry, ensure_ascii=False)
    return serialized


def _serialize_geojson_geometries(geojson: dict) -> dict:
    """Copia o FeatureCollection serializando a geometry de cada feature.

    A serialização fica restrita à borda de persistência, preservando o
    contrato Map devolvido por ``heuristics.build_geojson``.
    """
    draft = dict(geojson)
    features = draft.get('features')
    if isinstance(features, list):
        draft['features'] = [
            _serialize_feature_geometry(feature) for feature in features
        ]
    return draft


def save_draft_to_firestore(draft_id: str, geojson: dict, metadata: dict | None = None):
    """
    Salva o rascunho GeoJSON no Firestore na coleção loteamentos_drafts.
    """
    try:
        db = firestore.client()
        doc_ref = db.collection('loteamentos_drafts').document(draft_id)
        draft = _serialize_geojson_geometries(geojson)
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
