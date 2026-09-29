"""Extração nativa de loteamentos a partir de arquivos DXF.

O DXF é o formato de referência do produto. O extrator explodes os blocos
(``INSERT``) herdando o layer, interpreta ``LWPOLYLINE``/``POLYLINE`` como
parcelas, classifica lote × quadra (primeiro por tokens de layer, depois por
geometria) e associa os textos ``TEXT``/``MTEXT`` para montar o mesmo contrato
GeoJSON revisável consumido pelo canvas.
"""
from __future__ import annotations

import logging
import os

import ezdxf

from geometry_utils import associate_lotes_to_quadras, ezdxf_entity_to_polygon
from heuristics import build_geojson

logger = logging.getLogger(__name__)

POLYLINE_TYPES = ('LWPOLYLINE', 'POLYLINE')
TEXT_TYPES = ('TEXT', 'MTEXT')
MAX_INSERT_DEPTH = 12

LOTE_LAYER_TOKEN = 'LOTE'
QUADRA_LAYER_TOKEN = 'QUADRA'

# Parcelas abaixo disso são símbolos gráficos (cotas/marcações), não lotes.
MIN_LOTE_AREA = 10.0
# Um polígono só é quadra quando contém uma parcela substancialmente menor.
QUADRA_AREA_RATIO = 0.5


class DxfExtractionError(ValueError):
    """Falha determinística que deve deixar o rascunho em estado terminal."""


def _effective_layer(entity, inherited_layer: str) -> str:
    """Aplica a herança de layer: entidades em ``0``/``BYBLOCK`` seguem o INSERT."""
    try:
        layer = entity.dxf.layer
    except Exception:  # pragma: no cover - entidades sem DXF attribs
        layer = None
    if not layer or layer == '0' or str(layer).upper() == 'BYBLOCK':
        return inherited_layer
    return layer


def _flatten(container, inherited_layer: str = '0', depth: int = 0):
    """Percorre a entidade explodindo ``INSERT`` recursivamente."""
    for entity in container:
        layer = _effective_layer(entity, inherited_layer)
        if entity.dxftype() == 'INSERT':
            if depth >= MAX_INSERT_DEPTH:
                logger.warning("INSERT aninhado além do limite de profundidade.")
                continue
            try:
                children = list(entity.virtual_entities())
            except Exception as error:  # pragma: no cover - bloco corrompido
                logger.warning("Falha ao explodir bloco %s: %s", entity.dxf.name, error)
                continue
            # Não sobrescrevemos child.dxf.layer: a herança é resolvida por
            # ``_effective_layer``, preservando layers explícitos do bloco.
            yield from _flatten(children, layer, depth + 1)
        else:
            yield entity, layer


def _layer_tag(layer):
    """Devolve ``'lote'``/``'quadra'`` a partir do token do layer, ou ``None``."""
    upper = (layer or '').upper()
    if QUADRA_LAYER_TOKEN in upper:
        return 'quadra'
    if LOTE_LAYER_TOKEN in upper:
        return 'lote'
    return None


def _geometry_classification(poly_entities):
    """Classifica por área e contenção."""
    polygons = {}
    for entity, _ in poly_entities:
        polygon, _ = ezdxf_entity_to_polygon(entity)
        if polygon is None or polygon.is_empty or polygon.area <= 0:
            continue
        polygons[entity] = polygon

    quadras = []
    lotes = []
    for entity, polygon in polygons.items():
        contains_lote = False
        for other, other_polygon in polygons.items():
            if other is entity:
                continue
            if (
                MIN_LOTE_AREA <= other_polygon.area <= polygon.area * QUADRA_AREA_RATIO
                and polygon.covers(other_polygon.representative_point())
            ):
                contains_lote = True
                break
        if contains_lote:
            quadras.append(entity)
        elif polygon.area >= MIN_LOTE_AREA:
            lotes.append(entity)
    return lotes, quadras


def _classify(poly_entities):
    """Combina classificação por token de layer com o resto por geometria."""
    if not any(_layer_tag(layer) for _, layer in poly_entities):
        return _geometry_classification(poly_entities)

    lotes = []
    quadras = []
    untagged = []
    for entity, layer in poly_entities:
        tag = _layer_tag(layer)
        if tag == 'quadra':
            quadras.append(entity)
        elif tag == 'lote':
            lotes.append(entity)
        else:
            untagged.append((entity, layer))

    untagged_lotes, untagged_quadras = _geometry_classification(untagged)
    return lotes + untagged_lotes, quadras + untagged_quadras


def _read_document(filepath):
    filepath = os.fspath(filepath)
    if not filepath or not os.path.exists(filepath):
        raise DxfExtractionError('Arquivo DXF não encontrado.')
    if os.path.getsize(filepath) == 0:
        raise DxfExtractionError('O arquivo DXF está vazio.')
    if not filepath.lower().endswith('.dxf'):
        raise DxfExtractionError('O arquivo enviado não é um DXF.')
    try:
        return ezdxf.readfile(filepath)
    except (OSError, ValueError, ezdxf.DXFError, UnicodeDecodeError) as error:
        raise DxfExtractionError(f'Não foi possível ler o DXF: {error}') from error


def extract_dxf_geojson(filepath: str) -> dict:
    """Lê um DXF e devolve um FeatureCollection revisável (lotes/quadras/textos)."""
    document = _read_document(filepath)

    flat = list(_flatten(document.modelspace()))
    poly_entities = [(entity, layer) for entity, layer in flat
                     if entity.dxftype() in POLYLINE_TYPES]
    text_entities = [entity for entity, _ in flat if entity.dxftype() in TEXT_TYPES]

    if not poly_entities:
        raise DxfExtractionError('O DXF não possui contornos utilizáveis para loteamento.')

    lotes, quadras = _classify(poly_entities)
    if not lotes:
        raise DxfExtractionError('O DXF não possui contornos utilizáveis para loteamento.')

    association = associate_lotes_to_quadras(lotes, quadras)
    geojson = build_geojson(
        association, text_entities,
        association['quadra_polygons'], association['lote_polygons'],
    )

    if not any(
        feature.get('properties', {}).get('tipo') == 'lote'
        for feature in geojson.get('features', [])
    ):
        raise DxfExtractionError('O DXF não possui contornos utilizáveis para loteamento.')
    return geojson
