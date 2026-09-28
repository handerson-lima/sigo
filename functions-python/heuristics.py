import logging
import re
import json
from shapely.geometry import Point

logger = logging.getLogger(__name__)

STOP_WORDS = {"ÁREA", "AREA", "CASA", "LOTES", "LOTE", "QUADRA", "Q", "RUA", "AV", "AVENIDA"}
# Dimensões ex: 15x30, 15.5X30, 15x30.2
DIMENSION_REGEX = re.compile(r'^\d+([.,]\d+)?\s*[xX]\s*\d+([.,]\d+)?\s*(m|cm|M|CM)?$')
# Quadra explícita ex: Q 1, QUADRA 1
QUADRA_REGEX = re.compile(r'^(Q|QUADRA)[\s\.]*[0-9A-Z]+$')

def extract_text(entity):
    """Extrai texto e ponto de inserção de uma entidade ezdxf (TEXT/MTEXT)."""
    text = ""
    try:
        dxftype = entity.dxftype()
        if dxftype == 'TEXT':
            val = entity.dxf.text
            if val is not None:
                text = str(val).upper().strip()
        elif dxftype == 'MTEXT':
            val = entity.text
            if val is not None:
                val_str = str(val)
                # Strip formatting tags like \A1; \fArial; and braces
                val_str = re.sub(r'\\[A-Za-z0-9]+[^;]*;', '', val_str)
                val_str = val_str.replace('{', '').replace('}', '')
                text = val_str.upper().strip()
    except Exception:
        pass

    pt = None
    try:
        if entity.dxftype() == 'TEXT':
            if hasattr(entity.dxf, 'align_point') and entity.dxf.align_point is not None and (entity.dxf.align_point.x != 0 or entity.dxf.align_point.y != 0):
                pt = entity.dxf.align_point
            else:
                pt = entity.dxf.insert
        else:
            pt = entity.dxf.insert
    except AttributeError:
        pass

    return text, pt

def build_geojson(association, textos, quadra_polygons, lote_polygons):
    parsed_texts = []
    for txt in textos:
        val, pt = extract_text(txt)
        if val and pt is not None:
            parsed_texts.append((val, Point(pt.x, pt.y)))

    features = []

    def serialize_geometry(geom):
        if geom.geom_type == 'Polygon':
            coords = [[[pt[0], pt[1]] for pt in geom.exterior.coords]]
            for interior in geom.interiors:
                coords.append([[pt[0], pt[1]] for pt in interior.coords])
            return {"type": "Polygon", "coordinates": coords}
        elif geom.geom_type == 'MultiPolygon':
            mp_coords = []
            for p in geom.geoms:
                coords = [[[pt[0], pt[1]] for pt in p.exterior.coords]]
                for interior in p.interiors:
                    coords.append([[pt[0], pt[1]] for pt in interior.coords])
                mp_coords.append(coords)
            return {"type": "MultiPolygon", "coordinates": mp_coords}
        return {"type": "Polygon", "coordinates": []}

    def process_lote(lote_entity, q_entity=None):
        poly = lote_polygons.get(lote_entity)
        if poly is None or poly.is_empty:
            # Emit as ambiguous orphan with empty Polygon
            feature = {
                "type": "Feature",
                "geometry": {
                    "type": "Polygon",
                    "coordinates": []
                },
                "properties": {
                    "tipo": "lote",
                    "nome": "",
                    "status": "ambiguo",
                    "quadra": ""
                }
            }
            return feature
        
        candidates = []
        for val, pt in parsed_texts:
            if poly.covers(pt):
                # Filtra regex de dimensão
                if DIMENSION_REGEX.match(val):
                    continue
                
                # Check entire word (optionally stripping trailing punctuation)
                if val.strip('.,') in STOP_WORDS:
                    continue

                candidates.append(val)
        
        # Deduplicate
        candidates = list(dict.fromkeys(candidates))
        
        status = "ambiguo"
        nome = ""
        if len(candidates) == 1:
            status = "valido"
            nome = candidates[0]
        
        if q_entity is None:
            status = "ambiguo"
        
        quadra_nome = ""
        if q_entity is not None:
            quadra_poly = quadra_polygons.get(q_entity)
            if quadra_poly:
                q_candidates = []
                for val, pt in parsed_texts:
                    if quadra_poly.covers(pt):
                        if QUADRA_REGEX.match(val) or val == "Q":
                            q_candidates.append(val)
                if q_candidates:
                    if len(q_candidates) == 1:
                        quadra_nome = q_candidates[0]

        feature = {
            "type": "Feature",
            "geometry": json.dumps(serialize_geometry(poly)),
            "properties": {
                "tipo": "lote",
                "nome": nome,
                "status": status,
                "quadra": quadra_nome
            }
        }
        return feature

    for q_entity, lote_list in association['quadras'].items():
        for lote in lote_list:
            f = process_lote(lote, q_entity)
            if f:
                features.append(f)
                
    for lote in association['lotes_orfaos']:
        f = process_lote(lote, None)
        if f:
            features.append(f)
            
    quadras_reparadas = association.get('quadras_reparadas', set())
    for q_entity in quadras_reparadas:
        poly = quadra_polygons.get(q_entity)
        if poly is None or poly.is_empty:
            continue
        quadra_nome = ""
        q_candidates = []
        for val, pt in parsed_texts:
            if poly.covers(pt):
                if QUADRA_REGEX.match(val) or val == "Q":
                    q_candidates.append(val)
        if q_candidates:
            if len(q_candidates) == 1:
                quadra_nome = q_candidates[0]
        
        feature = {
            "type": "Feature",
            "geometry": serialize_geometry(poly),
            "properties": {
                "tipo": "quadra",
                "nome": quadra_nome,
                "status": "ambiguo",
                "geometria_reparada": True
            }
        }
        features.append(feature)

    geojson = {
        "type": "FeatureCollection",
        "features": features
    }
    return geojson

