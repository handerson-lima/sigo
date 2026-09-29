import hashlib
import json
import logging
from datetime import datetime, timezone
from typing import Any, Iterable

from firebase_admin import firestore
from shapely.errors import ShapelyError
from shapely.geometry import shape as shapely_shape

logger = logging.getLogger(__name__)

MAX_BATCH_OPERATIONS = 500
# Quadra de agrupamento para lotes sem referência de quadra no rascunho (o
# extrator só grava ``quadra`` quando há um texto de quadra reconhecível).
DEFAULT_QUADRA_NAME = 'Geral'


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


def _value(properties: Any, key: str) -> str:
    """Devolve uma propriedade obrigatória e não vazia, com erro útil."""
    value = properties.get(key) if isinstance(properties, dict) else None
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Feature sem propriedade obrigatória '{key}'")
    return value.strip()


def _chunks(items: list, size: int = MAX_BATCH_OPERATIONS) -> Iterable[list]:
    for start in range(0, len(items), size):
        yield items[start:start + size]


def _parse_geometry(feature: dict):
    """Lê ``feature['geometry']`` tanto como Map quanto como String JSON.

    O rascunho persiste a geometria serializada em String (Firestore rejeita
    arrays aninhados); formatos mais antigos trazem o Map direto. Ambos são
    aceitos e normalizados para Map.
    """
    geometry = feature.get('geometry')
    if geometry is None:
        return None
    if isinstance(geometry, dict):
        return geometry
    if isinstance(geometry, str):
        try:
            parsed = json.loads(geometry)
        except (TypeError, ValueError) as error:
            raise ValueError(f'Geometria inválida na feature: {error}') from error
        if not isinstance(parsed, dict):
            raise ValueError('Geometria inválida na feature: esperado objeto')
        return parsed
    raise ValueError('Geometria inválida na feature: tipo não suportado')


def _iso_now() -> str:
    """Instante ISO-8601 compatível com os modelos Flutter (``DateTime.parse``)."""
    return datetime.now(timezone.utc).isoformat()


def _geometry_document(geometry) -> dict:
    if geometry is None:
        return {}
    return {'geometry': json.dumps(geometry, ensure_ascii=False)}


def _polygon_from_geometry(geometry):
    """Converte a geometria do rascunho em polígono Shapely (ou ``None``)."""
    if not isinstance(geometry, dict):
        return None
    if not geometry.get('coordinates'):
        return None
    try:
        polygon = shapely_shape(geometry)
    except (ShapelyError, ValueError, TypeError, KeyError, IndexError):
        return None
    if polygon.is_empty:
        return None
    return polygon


def _quadra_name(properties: dict) -> str:
    name = properties.get('nome')
    return name.strip() if isinstance(name, str) else ''


def _containing_quadra_id(polygon, quadra_features) -> str | None:
    """Quadra de menor área que contém o ponto representativo do lote."""
    if polygon is None or polygon.is_empty:
        return None
    try:
        point = polygon.representative_point()
    except ShapelyError:
        return None
    candidates = []
    for quadra_id, _name, quadra_polygon, _geometry in quadra_features:
        if quadra_polygon is None:
            continue
        try:
            if quadra_polygon.covers(point):
                candidates.append((quadra_polygon.area, quadra_id))
        except ShapelyError:
            continue
    if not candidates:
        return None
    return min(candidates, key=lambda item: item[0])[1]


def consolidate_approved_draft(draft_id: str, draft: dict, db=None) -> None:
    """Materializa um rascunho aprovado em documentos top-level determinísticos.

    Cada gravação usa ``set`` com ID derivado do rascunho, então reentregas e
    retentativas convergem nos mesmos documentos sem duplicar entidades. O
    rascunho é preservado (nunca apagado) para permitir nova tentativa.

    A quadra de cada lote vem primeiro da propriedade ``quadra``; quando o
    extrator não reconhece um rótulo de quadra (caso do DXF de referência),
    usa a contenção espacial nos polígonos de quadra e, por fim, uma quadra
    ``Geral`` estável para que todo lote tenha FK preenchida.
    """
    construtora_id = _value(draft, 'construtoraId')
    loteamento_name = _value(draft, 'loteamentoName')
    features = draft.get('features')
    if not isinstance(features, list):
        raise ValueError('Rascunho sem lista de features')

    quadras_by_name: dict[str, str] = {}
    quadra_features: list[tuple[str, str, object, dict | None]] = []
    lotes: list[tuple[int, dict, dict | None, object]] = []
    for index, feature in enumerate(features):
        if not isinstance(feature, dict):
            raise ValueError(f'Feature inválida no índice {index}')
        properties = feature.get('properties')
        if not isinstance(properties, dict):
            raise ValueError(f'Feature sem propriedades no índice {index}')
        geometry = _parse_geometry(feature)
        feature_type = properties.get('tipo')
        if feature_type == 'quadra':
            name = _quadra_name(properties)
            if name and name in quadras_by_name:
                raise ValueError(f'Nome de quadra duplicado: {name}')
            quadra_id = f'{draft_id}--quadra--{index}'
            if name:
                quadras_by_name[name] = quadra_id
            quadra_features.append((quadra_id, name, _polygon_from_geometry(geometry), geometry))
        elif feature_type == 'lote':
            _value(properties, 'nome')
            # O canvas só bloqueia a aprovação enquanto há pendência ('ambiguo').
            if properties.get('status') == 'ambiguo':
                raise ValueError(f'Lote no índice {index} está ambíguo')
            lotes.append((index, properties, geometry, _polygon_from_geometry(geometry)))
        else:
            raise ValueError(f"Tipo de feature inválido no índice {index}: {feature_type!r}")

    if not lotes:
        raise ValueError('Rascunho sem lotes para consolidar')

    db = db or firestore.client()
    loteamento_id = f'{draft_id}--loteamento'
    now = _iso_now()
    quadra_documents: dict[str, dict] = {}
    quadra_order: list[str] = []

    def ensure_quadra(quadra_id: str, name: str, geometry) -> str:
        if quadra_id not in quadra_documents:
            quadra_documents[quadra_id] = {
                'id': quadra_id,
                'construtoraId': construtora_id,
                'loteamentoId': loteamento_id,
                'name': name,
                'createdAt': now,
                'updatedAt': now,
                **_geometry_document(geometry),
            }
            quadra_order.append(quadra_id)
        return quadra_id

    for quadra_id, name, _polygon, geometry in quadra_features:
        ensure_quadra(quadra_id, name, geometry)

    lote_documents: list[tuple[str, dict]] = []
    for index, properties, geometry, polygon in lotes:
        raw_quadra = properties.get('quadra')
        quadra_name = raw_quadra.strip() if isinstance(raw_quadra, str) else ''
        quadra_id = quadras_by_name.get(quadra_name) if quadra_name else None
        if quadra_name and not quadra_id:
            name_hash = hashlib.sha256(quadra_name.encode('utf-8')).hexdigest()[:16]
            quadra_id = ensure_quadra(
                f'{draft_id}--quadra--ref--{name_hash}', quadra_name, None,
            )
            quadras_by_name[quadra_name] = quadra_id
        if not quadra_id:
            quadra_id = _containing_quadra_id(polygon, quadra_features)
        if not quadra_id:
            quadra_id = ensure_quadra(
                f'{draft_id}--quadra--geral', DEFAULT_QUADRA_NAME, None,
            )
        lote_id = f'{draft_id}--lote--{index}'
        lote_documents.append((
            lote_id,
            {
                'id': lote_id,
                'construtoraId': construtora_id,
                'loteamentoId': loteamento_id,
                'quadraId': quadra_id,
                'name': _value(properties, 'nome'),
                'createdAt': now,
                'updatedAt': now,
                **_geometry_document(geometry),
            },
        ))

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
    for quadra_id in quadra_order:
        writes.append((
            db.collection('quadras').document(quadra_id), quadra_documents[quadra_id],
        ))
    for lote_id, document in lote_documents:
        writes.append((db.collection('lotes').document(lote_id), document))

    for write_chunk in _chunks(writes):
        batch = db.batch()
        for reference, document in write_chunk:
            batch.set(reference, document)
        batch.commit()

    logger.info('Draft %s materialized: %d final documents', draft_id, len(writes))
