import pytest
from shapely.geometry import Polygon
from heuristics import extract_text, build_geojson

class MockDXFText:
    def __init__(self, text, x, y, is_mtext=False):
        self._text = text
        self.x = x
        self.y = y
        self.is_mtext = is_mtext

    def dxftype(self):
        return 'MTEXT' if self.is_mtext else 'TEXT'

    @property
    def dxf(self):
        return self

    @property
    def text(self):
        return self._text

    @property
    def insert(self):
        class Pt:
            def __init__(self, x, y):
                self.x = x
                self.y = y
        return Pt(self.x, self.y)

class MockDXFPoly:
    pass

def test_extract_text():
    t1 = MockDXFText("Lote 1", 10, 10)
    text, pt = extract_text(t1)
    assert text == "LOTE 1"
    assert pt.x == 10 and pt.y == 10

def test_extract_text_mtext():
    t_mtext = MockDXFText(r"{\fArial|b0|i0|c0|p34;\A1;LOTE 1}", 10, 10, is_mtext=True)
    text, pt = extract_text(t_mtext)
    assert text == "LOTE 1"

def test_extract_text_none():
    t_none = MockDXFText(None, 10, 10)
    text, pt = extract_text(t_none)
    assert text == ""

def test_build_geojson_happy_path():
    lote_entity = MockDXFPoly()
    quadra_entity = MockDXFPoly()
    
    lote_poly = Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)])
    quadra_poly = Polygon([(-5, -5), (15, -5), (15, 15), (-5, 15), (-5, -5)])

    association = {
        'quadras': {quadra_entity: [lote_entity]},
        'lotes_orfaos': [],
        'quadra_polygons': {quadra_entity: quadra_poly},
        'lote_polygons': {lote_entity: lote_poly}
    }
    
    # Texto dentro do lote
    textos = [MockDXFText("12", 5, 5)]

    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    
    assert geojson["type"] == "FeatureCollection"
    assert len(geojson["features"]) == 1
    
    feature = geojson["features"][0]
    assert feature["properties"]["tipo"] == "lote"
    assert feature["properties"]["nome"] == "12"
    assert feature["properties"]["status"] == "valido"

def test_build_geojson_ambiguous_multiple_texts():
    lote_entity = MockDXFPoly()
    lote_poly = Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)])

    quadra_entity = MockDXFPoly()
    quadra_poly = Polygon([(-5, -5), (15, -5), (15, 15), (-5, 15), (-5, -5)])

    association = {
        'quadras': {quadra_entity: [lote_entity]},
        'lotes_orfaos': [],
        'quadra_polygons': {quadra_entity: quadra_poly},
        'lote_polygons': {lote_entity: lote_poly}
    }
    
    # "CASA" deve ser filtrado. "15x30" deve ser filtrado. Resta "12", então é válido.
    textos = [MockDXFText("12", 5, 5), MockDXFText("CASA", 6, 6), MockDXFText("15x30", 7, 7)]

    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    feature = geojson["features"][0]
    assert feature["properties"]["nome"] == "12"
    assert feature["properties"]["status"] == "valido"

def test_build_geojson_ambiguous_zero_or_multiple_valid_texts():
    lote_entity1 = MockDXFPoly()
    lote_poly1 = Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)])

    lote_entity2 = MockDXFPoly()
    lote_poly2 = Polygon([(20, 0), (30, 0), (30, 10), (20, 10), (20, 0)])

    quadra_entity = MockDXFPoly()
    quadra_poly = Polygon([(-5, -5), (40, -5), (40, 40), (-5, 40), (-5, -5)])

    association = {
        'quadras': {quadra_entity: [lote_entity1, lote_entity2]},
        'lotes_orfaos': [],
        'quadra_polygons': {quadra_entity: quadra_poly},
        'lote_polygons': {lote_entity1: lote_poly1, lote_entity2: lote_poly2}
    }
    
    # Lote 1 tem dois candidatos válidos
    textos = [MockDXFText("12", 5, 5), MockDXFText("LOTE 1", 6, 6)]
    # Lote 2 tem zero candidatos válidos
    
    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    f1 = next(f for f in geojson["features"] if f["geometry"]["coordinates"][0][0][0] == 0)
    f2 = next(f for f in geojson["features"] if f["geometry"]["coordinates"][0][0][0] == 20)

    assert f1["properties"]["status"] == "ambiguo"
    assert f1["properties"]["nome"] == ""
    assert f2["properties"]["status"] == "ambiguo"
    assert f2["properties"]["nome"] == ""


def test_build_geojson_orphan():
    lote_entity = MockDXFPoly()
    lote_poly = Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)])

    association = {
        'quadras': {},
        'lotes_orfaos': [lote_entity],
        'quadra_polygons': {},
        'lote_polygons': {lote_entity: lote_poly}
    }
    
    textos = [MockDXFText("15", 5, 5)]
    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    feature = geojson["features"][0]
    assert feature["properties"]["status"] == "ambiguo"

def test_build_geojson_orphan_without_polygon():
    lote_entity = MockDXFPoly()
    association = {
        'quadras': {},
        'lotes_orfaos': [lote_entity],
        'quadra_polygons': {},
        'lote_polygons': {}
    }
    
    geojson = build_geojson(association, [], association['quadra_polygons'], association['lote_polygons'])
    feature = geojson["features"][0]
    assert feature["properties"]["status"] == "ambiguo"
    assert feature["geometry"]["type"] == "Polygon"
    assert feature["geometry"]["coordinates"] == []

def test_build_geojson_punctuation_cleaning():
    lote_entity = MockDXFPoly()
    lote_poly = Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)])

    association = {
        'quadras': {},
        'lotes_orfaos': [lote_entity],
        'quadra_polygons': {},
        'lote_polygons': {lote_entity: lote_poly}
    }
    
    # "AV." deve ser limpado e reconhecido como stopword
    textos = [MockDXFText("12", 5, 5), MockDXFText("AV.", 6, 6)]
    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    feature = geojson["features"][0]
    
    # É um lote órfão então o status final é ambiguo (regra de quadra)
    # Mas se formos verificar apenas candidatos, se "AV." virasse candidato, teríamos dois
    # Vamos verificar se "AV." foi descartado fazendo-o ter nome vazio (ambiguo por 2 cand)
    # ou nome = "12" (valido por 1 cand antes da checagem de orfao)
    # Wait, lote órfão sempre tem status "ambiguo".
    # Em orfãos, a regra len(candidates) == 1 ainda preenche o "nome".
    assert feature["properties"]["nome"] == "12"

def test_build_geojson_deduplication():
    lote_entity = MockDXFPoly()
    lote_poly = Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)])

    quadra_entity = MockDXFPoly()
    quadra_poly = Polygon([(-5, -5), (15, -5), (15, 15), (-5, 15), (-5, -5)])

    association = {
        'quadras': {quadra_entity: [lote_entity]},
        'lotes_orfaos': [],
        'quadra_polygons': {quadra_entity: quadra_poly},
        'lote_polygons': {lote_entity: lote_poly}
    }
    
    # Dois textos idênticos "12" devem ser deduplicados para 1 candidato válido
    textos = [MockDXFText("12", 5, 5), MockDXFText("12", 6, 6)]
    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    feature = geojson["features"][0]
    
    assert feature["properties"]["nome"] == "12"
    assert feature["properties"]["status"] == "valido"

def test_build_geojson_zero_origin():
    lote_entity = MockDXFPoly()
    lote_poly = Polygon([(-5, -5), (10, -5), (10, 10), (-5, 10), (-5, -5)])
    quadra_entity = MockDXFPoly()
    quadra_poly = Polygon([(-10, -10), (15, -10), (15, 15), (-10, 15), (-10, -10)])
    association = {
        'quadras': {quadra_entity: [lote_entity]},
        'lotes_orfaos': [],
        'quadra_polygons': {quadra_entity: quadra_poly},
        'lote_polygons': {lote_entity: lote_poly}
    }
    
    # Pt (0,0) é falsy, se pt is not None não for usado, será filtrado.
    textos = [MockDXFText("12", 0, 0)]
    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    feature = geojson["features"][0]
    
    assert feature["properties"]["nome"] == "12"
    assert feature["properties"]["status"] == "valido"

