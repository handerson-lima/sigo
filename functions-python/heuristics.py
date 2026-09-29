import logging
import re
from shapely.geometry import Point

logger = logging.getLogger(__name__)

STOP_WORDS = {"ÁREA", "AREA", "CASA", "LOTES", "LOTE", "QUADRA", "Q", "RUA", "AV", "AVENIDA"}
# Dimensões ex: 15x30, 15.5X30, 15x30.2
DIMENSION_REGEX = re.compile(r'^\d+([.,]\d+)?\s*[xX]\s*\d+([.,]\d+)?\s*(m|cm|M|CM)?$')
# Quadra explícita ex: Q 1, QUADRA 1, Q-04, Q.04
QUADRA_REGEX = re.compile(r'^(Q|QUADRA)[\s.\-]*[0-9A-Z]+$')
# Área em metros quadrados ex: M², 152,00M², M2 (ancorado, não casa M20/M2A)
AREA_REGEX = re.compile(r'^\d*[,.]?\d*\s*M\s*[²2]$')
# Decimais isolados ex: 16.00, 1.488,00, 152,00
DECIMAL_REGEX = re.compile(r'^\d+([.,]\d+)+$')
# Nome de lote puro (inteiro) ex: 12, 101
INTEGER_REGEX = re.compile(r'^\d+$')
# Termos que nunca nomeiam lote (rua/área/institucional)
NON_LOTE_TERMS = {
    "ÁREA", "AREA", "RUA", "AV", "AVENIDA", "ESTRADA", "TRAVESSA", "ALAMEDA",
    "RODOVIA", "CALÇADA", "PRAÇA", "VILA", "INSTITUCIONAL", "LAGOA",
    "INFILTRAÇÃO", "INFILTRACAO", "VERDE", "RESERVA", "FAIXA", "APP", "JARDIM",
}
# Margem relativa mínima (5%) para escolher o inteiro mais próximo do polígono.
MARGEM_PROXIMIDADE = 0.05


def _contains_word(value, term):
    """Casa o termo como palavra inteira, evitando acertos por substring."""
    return term in re.split(r'[^0-9A-ZÀ-Ü]+', value)


def _is_lote_name_candidate(value):
    """Indica se um texto coberto pelo polígono pode nomear o lote."""
    if not value:
        return False
    if DIMENSION_REGEX.match(value):
        return False
    if DECIMAL_REGEX.match(value):
        return False
    if AREA_REGEX.match(value):
        return False
    if QUADRA_REGEX.match(value) or value.strip('.,') == "Q":
        return False
    if value.strip('.,') in STOP_WORDS:
        return False
    if not re.search(r'[0-9A-ZÀ-Ü]', value):
        return False
    if any(_contains_word(value, term) for term in NON_LOTE_TERMS):
        return False
    return True


def _select_nome(candidates, poly):
    """Escolhe ``(nome, valido)`` para um lote a partir dos textos cobertos.

    Apenas inteiros nomeiam lotes (com pontuação de extremidade normalizada). Com
    dois ou mais inteiros, escolhe o mais próximo do ``representative_point`` do
    polígono se estiver estritamente mais perto que o segundo colocado por ao
    menos ``MARGEM_PROXIMIDADE``; caso contrário mantém o lote sem nome (ambíguo).
    Um candidato único que não seja inteiro nunca vira nome.
    """
    inteiros = {}
    for value, point in candidates:
        normalizado = value.strip('.,;:')
        if INTEGER_REGEX.match(normalizado):
            inteiros.setdefault(normalizado, point)

    if len(inteiros) >= 2:
        representative = poly.representative_point()
        ordenados = sorted(inteiros.items(), key=lambda item: representative.distance(item[1]))
        distancia_1 = representative.distance(ordenados[0][1])
        distancia_2 = representative.distance(ordenados[1][1])
        if distancia_2 <= 0:
            return "", False
        if (distancia_2 - distancia_1) / distancia_2 >= MARGEM_PROXIMIDADE:
            return ordenados[0][0], True
        return "", False

    if len(inteiros) == 1:
        return next(iter(inteiros)), True

    return "", False

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
            if poly.covers(pt) and _is_lote_name_candidate(val):
                candidates.append((val, pt))

        nome, escolhido = _select_nome(candidates, poly)
        status = "valido" if escolhido else "ambiguo"

        if q_entity is None:
            status = "ambiguo"
            nome = ""

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
            "geometry": serialize_geometry(poly),
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

