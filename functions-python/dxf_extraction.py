"""Extração nativa de loteamentos a partir de arquivos DXF.

O DXF é o formato de referência do produto. O extrator explodes os blocos
(``INSERT``) herdando o layer, interpreta ``LWPOLYLINE``/``POLYLINE`` como
parcelas, classifica lote × quadra (primeiro por tokens de layer, depois por
geometria) e associa os textos ``TEXT``/``MTEXT`` para montar o mesmo contrato
GeoJSON revisável consumido pelo canvas.
"""
from __future__ import annotations

from collections import Counter
import logging
import os

import ezdxf
from shapely.geometry import Point

from geometry_utils import associate_lotes_to_quadras, ezdxf_entity_to_polygon
from heuristics import (
    QUADRA_LABEL_MAX_DISTANCE,
    QUADRA_REGEX,
    _is_lote_name_candidate,
    build_geojson,
    extract_text,
)

logger = logging.getLogger(__name__)

POLYLINE_TYPES = ('LWPOLYLINE', 'POLYLINE')
TEXT_TYPES = ('TEXT', 'MTEXT', 'ATTRIB')
MAX_INSERT_DEPTH = 12

LOTE_LAYER_TOKEN = 'LOTE'
QUADRA_LAYER_TOKEN = 'QUADRA'

# Parcelas abaixo disso são símbolos gráficos (cotas/marcações), não lotes.
MIN_LOTE_AREA = 10.0
# Um polígono só é quadra quando contém uma parcela substancialmente menor.
QUADRA_AREA_RATIO = 0.5
# Proporção mínima para considerar uma cor ACI como predominante nos lotes.
DOMINANT_COLOR_RATIO = 0.5


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


def _effective_color(entity, inherited_color: int, doc=None, effective_layer: str | None = None) -> int:
    """Resolve a cor ACI efetiva (0/BYBLOCK -> INSERT, 256/BYLAYER -> layer)."""
    try:
        color = entity.dxf.color
    except Exception:  # pragma: no cover - entidades sem DXF attribs
        color = 256
    if color is None:
        color = 256
    if color == 0:
        color = inherited_color if inherited_color is not None else 256
    if color == 256 and doc is not None:
        layer_name = effective_layer
        if not layer_name:
            try:
                layer_name = entity.dxf.layer
            except Exception:  # pragma: no cover
                layer_name = '0'
        try:
            layer_entry = doc.layers.get(layer_name or '0')
            if layer_entry is not None:
                return abs(int(layer_entry.dxf.color))
        except Exception:  # pragma: no cover - layer inexistente
            pass
    return int(color)


def _unit_linear_scale(doc) -> float:
    """Retorna quantas unidades do desenho equivalem a 1 metro (fallback 1.0)."""
    if doc is None:
        return 1.0
    try:
        code = int(doc.header.get('$INSUNITS', 0) or 0)
    except Exception:  # pragma: no cover
        return 1.0
    if code in (0, 6):
        return 1.0
    try:
        factor = ezdxf.units.conversion_factor(code, ezdxf.units.M)
        if factor and factor > 0:
            return 1.0 / factor
    except Exception:
        pass
    return 1.0


def _unit_area_scale(doc) -> float:
    """Retorna quantas unidades² do desenho equivalem a 1 m² (fallback 1.0)."""
    linear = _unit_linear_scale(doc)
    return linear ** 2


def _flatten(container, inherited_layer: str = '0', depth: int = 0, inherited_color: int = 256, doc=None):
    """Percorre a entidade explodindo ``INSERT`` recursivamente."""
    for entity in container:
        layer = _effective_layer(entity, inherited_layer)
        color = _effective_color(entity, inherited_color, doc, layer)
        if entity.dxftype() == 'INSERT':
            for attrib in getattr(entity, 'attribs', ()):
                attrib_layer = _effective_layer(attrib, layer)
                attrib_color = _effective_color(attrib, color, doc, attrib_layer)
                try:
                    attrib._effective_color = attrib_color
                except Exception:  # pragma: no cover
                    pass
                yield attrib, attrib_layer
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
            yield from _flatten(children, layer, depth + 1, color, doc)
        else:
            try:
                entity._effective_color = color
            except Exception:  # pragma: no cover
                pass
            yield entity, layer


def _layer_tag(layer):
    """Devolve ``'lote'``/``'quadra'`` a partir do token do layer, ou ``None``."""
    upper = (layer or '').upper()
    if QUADRA_LAYER_TOKEN in upper:
        return 'quadra'
    if LOTE_LAYER_TOKEN in upper:
        return 'lote'
    return None


def _geometry_classification(
    poly_entities,
    min_lote_area: float = MIN_LOTE_AREA,
    text_entities=None,
    doc=None,
):
    """Classifica por área e contenção, descartando molduras Q-xx e cores fora do padrão."""
    polygons = {}
    layers_by_entity = {}
    for entity, layer in poly_entities:
        polygon, _ = ezdxf_entity_to_polygon(entity)
        if polygon is None or polygon.is_empty or polygon.area <= 0:
            continue
        polygons[entity] = polygon
        layers_by_entity[entity] = layer

    quadras = []
    candidate_lotes = []
    for entity, polygon in polygons.items():
        contains_lote = False
        for other, other_polygon in polygons.items():
            if other is entity:
                continue
            if (
                min_lote_area <= other_polygon.area <= polygon.area * QUADRA_AREA_RATIO
                and polygon.covers(other_polygon.representative_point())
            ):
                contains_lote = True
                break
        if contains_lote:
            quadras.append(entity)
        elif polygon.area >= min_lote_area:
            candidate_lotes.append(entity)

    if not text_entities:
        return candidate_lotes, quadras

    parsed_texts = []
    for txt in text_entities:
        val, pt = extract_text(txt)
        if val and pt is not None:
            parsed_texts.append((val, pt.x, pt.y, Point(pt.x, pt.y)))

    has_lote_candidate = {}
    filtered_lotes = []
    for entity in candidate_lotes:
        polygon = polygons[entity]
        minx, miny, maxx, maxy = polygon.bounds
        covered_vals = [
            val
            for val, x, y, pt in parsed_texts
            if minx <= x <= maxx and miny <= y <= maxy and polygon.covers(pt)
        ]
        has_name_cand = any(_is_lote_name_candidate(val) for val in covered_vals)
        has_quadra_label = any(QUADRA_REGEX.match(val) or val == 'Q' for val in covered_vals)
        if has_quadra_label and not has_name_cand:
            continue
        has_lote_candidate[entity] = has_name_cand
        filtered_lotes.append(entity)

    def _entity_color(ent):
        cached = getattr(ent, '_effective_color', None)
        if cached is not None:
            return cached
        return _effective_color(ent, 256, doc, layers_by_entity.get(ent))

    named_colors = [
        _entity_color(ent)
        for ent in filtered_lotes
        if has_lote_candidate.get(ent)
    ]
    dominant_color = None
    if named_colors:
        most_common_color, count = Counter(named_colors).most_common(1)[0]
        if count / len(named_colors) >= DOMINANT_COLOR_RATIO:
            dominant_color = most_common_color

    if dominant_color is None:
        return filtered_lotes, quadras

    lotes = [
        ent
        for ent in filtered_lotes
        if has_lote_candidate.get(ent) or _entity_color(ent) == dominant_color
    ]
    return lotes, quadras


def _classify(
    poly_entities,
    min_lote_area: float = MIN_LOTE_AREA,
    text_entities=None,
    doc=None,
):
    """Combina classificação por token de layer com o resto por geometria."""
    if not any(_layer_tag(layer) for _, layer in poly_entities):
        return _geometry_classification(
            poly_entities,
            min_lote_area=min_lote_area,
            text_entities=text_entities,
            doc=doc,
        )

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

    untagged_lotes, untagged_quadras = _geometry_classification(
        untagged,
        min_lote_area=min_lote_area,
        text_entities=text_entities,
        doc=doc,
    )
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

    flat = list(_flatten(document.modelspace(), doc=document))
    poly_entities = [(entity, layer) for entity, layer in flat
                     if entity.dxftype() in POLYLINE_TYPES]
    text_entities = [entity for entity, _ in flat if entity.dxftype() in TEXT_TYPES]

    if not poly_entities:
        raise DxfExtractionError('O DXF não possui contornos utilizáveis para loteamento.')

    area_scale = _unit_area_scale(document)
    linear_scale = _unit_linear_scale(document)
    min_lote_area = MIN_LOTE_AREA * area_scale

    lotes, quadras = _classify(
        poly_entities,
        min_lote_area=min_lote_area,
        text_entities=text_entities,
        doc=document,
    )
    if not lotes:
        raise DxfExtractionError('O DXF não possui contornos utilizáveis para loteamento.')

    association = associate_lotes_to_quadras(lotes, quadras)
    geojson = build_geojson(
        association,
        text_entities,
        association['quadra_polygons'],
        association['lote_polygons'],
        max_quadra_label_distance=QUADRA_LABEL_MAX_DISTANCE * linear_scale,
    )

    if not any(
        feature.get('properties', {}).get('tipo') == 'lote'
        for feature in geojson.get('features', [])
    ):
        raise DxfExtractionError('O DXF não possui contornos utilizáveis para loteamento.')
    return geojson
