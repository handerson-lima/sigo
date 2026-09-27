import logging
import re
from shapely.geometry import Point

logger = logging.getLogger(__name__)

STOP_WORDS = {"ÁREA", "AREA", "CASA", "LOTES", "QUADRA", "Q", "RUA", "AV", "AVENIDA"}
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
            if hasattr(entity.dxf, 'align_point') and (entity.dxf.align_point.x != 0 or entity.dxf.align_point.y != 0):
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

        # Fix GeoJSON array of arrays
        coords = [[[pt[0], pt[1]] for pt in poly.exterior.coords]]
        for interior in poly.interiors:
            coords.append([[pt[0], pt[1]] for pt in interior.coords])

        feature = {
            "type": "Feature",
            "geometry": {
                "type": "Polygon",
                "coordinates": coords
            },
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

    geojson = {
        "type": "FeatureCollection",
        "features": features
    }
    return geojson

