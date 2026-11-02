import pytest
from shapely.geometry import Polygon
from heuristics import extract_text, build_geojson

class MockDXFText:
    def __init__(self, text, x, y, is_mtext=False, dxftype_name=None, align_point=None):
        self._text = text
        self.x = x
        self.y = y
        self.is_mtext = is_mtext
        self._dxftype = dxftype_name
        self._align_point = align_point

    def dxftype(self):
        if self._dxftype:
            return self._dxftype
        return 'MTEXT' if self.is_mtext else 'TEXT'

    @property
    def dxf(self):
        return self

    @property
    def text(self):
        return self._text

    @property
    def align_point(self):
        return self._align_point

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

def _single_lote_association(lote_poly):
    lote_entity = MockDXFPoly()
    quadra_entity = MockDXFPoly()
    quadra_poly = Polygon([(-5, -5), (15, -5), (15, 15), (-5, 15), (-5, -5)])
    return {
        'quadras': {quadra_entity: [lote_entity]},
        'lotes_orfaos': [],
        'quadra_polygons': {quadra_entity: quadra_poly},
        'lote_polygons': {lote_entity: lote_poly},
    }


def test_build_geojson_single_inteiro_com_texto_nao_lote_e_valido():
    # SINGLE_INTEIRO: exatamente 1 inteiro + rótulo que não é nome de lote.
    association = _single_lote_association(Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)]))
    textos = [MockDXFText("12", 5, 5), MockDXFText("LOTE 1", 6, 6)]

    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    feature = geojson["features"][0]

    assert feature["properties"]["nome"] == "12"
    assert feature["properties"]["status"] == "valido"


def test_build_geojson_multi_inteiros_escolhe_o_mais_proximo():
    # MULTI_INTEIROS: o inteiro mais próximo do representante do polígono vence.
    association = _single_lote_association(Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)]))
    textos = [MockDXFText("12", 4.9, 5.1), MockDXFText("13", 9, 9), MockDXFText("Q-04", 1, 1)]

    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    feature = geojson["features"][0]

    assert feature["properties"]["nome"] == "12"
    assert feature["properties"]["status"] == "valido"


def test_build_geojson_multi_inteiros_com_empate_mantem_ambiguo():
    # NEAR_TIE: distâncias praticamente iguais não permitem escolher com margem de 5%.
    association = _single_lote_association(Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)]))
    textos = [MockDXFText("12", 4, 5), MockDXFText("13", 6, 5)]

    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    feature = geojson["features"][0]

    assert feature["properties"]["status"] == "ambiguo"
    assert feature["properties"]["nome"] == ""


def test_build_geojson_margem_abaixo_de_5_mantem_ambiguo():
    # ~2,9% de margem relativa: abaixo dos 5% exigidos -> permanece ambíguo.
    association = _single_lote_association(Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)]))
    textos = [MockDXFText("12", 4, 5), MockDXFText("13", 3.970134, 5)]

    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    feature = geojson["features"][0]

    assert feature["properties"]["status"] == "ambiguo"
    assert feature["properties"]["nome"] == ""


def test_build_geojson_margem_acima_de_5_escolhe_o_mais_proximo():
    # ~10% de margem relativa: acima dos 5% exigidos -> valida o mais próximo.
    association = _single_lote_association(Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)]))
    textos = [MockDXFText("12", 4, 5), MockDXFText("13", 3.888889, 5)]

    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    feature = geojson["features"][0]

    assert feature["properties"]["nome"] == "12"
    assert feature["properties"]["status"] == "valido"


def test_build_geojson_inteiro_vence_rotulo_composto():
    # Um único inteiro vence um rótulo composto que contém número (ex.: "LOTE 12").
    association = _single_lote_association(Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)]))
    textos = [MockDXFText("13", 4.9, 5.1), MockDXFText("LOTE 12", 6, 6)]

    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    feature = geojson["features"][0]

    assert feature["properties"]["nome"] == "13"
    assert feature["properties"]["status"] == "valido"


def test_build_geojson_numero_com_pontuacao_e_reconhecido():
    # "12." tem a pontuação de extremidade normalizada e é reconhecido como inteiro.
    association = _single_lote_association(Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)]))
    textos = [MockDXFText("12.", 5, 5)]

    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    feature = geojson["features"][0]

    assert feature["properties"]["nome"] == "12"
    assert feature["properties"]["status"] == "valido"


def test_build_geojson_candidato_unico_nao_inteiro_nao_vira_nome():
    # "nunca inventar": um candidato único sem inteiro permanece ambíguo.
    association = _single_lote_association(Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)]))
    textos = [MockDXFText("GALERIA", 5, 5)]

    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    feature = geojson["features"][0]

    assert feature["properties"]["status"] == "ambiguo"
    assert feature["properties"]["nome"] == ""


def test_build_geojson_orfao_com_numero_mantem_ambiguo_e_sem_nome():
    lote_entity = MockDXFPoly()
    lote_poly = Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)])
    association = {
        'quadras': {},
        'lotes_orfaos': [lote_entity],
        'quadra_polygons': {},
        'lote_polygons': {lote_entity: lote_poly},
    }
    textos = [MockDXFText("15", 5, 5)]

    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    feature = geojson["features"][0]

    assert feature["properties"]["status"] == "ambiguo"
    assert feature["properties"]["nome"] == ""


def test_build_geojson_dois_lotes_na_mesma_quadra():
    lote_entity1 = MockDXFPoly()
    lote_poly1 = Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)])
    lote_entity2 = MockDXFPoly()
    lote_poly2 = Polygon([(20, 0), (30, 0), (30, 10), (20, 10), (20, 0)])
    quadra_entity = MockDXFPoly()
    quadra_poly = Polygon([(-5, -5), (35, -5), (35, 15), (-5, 15), (-5, -5)])
    association = {
        'quadras': {quadra_entity: [lote_entity1, lote_entity2]},
        'lotes_orfaos': [],
        'quadra_polygons': {quadra_entity: quadra_poly},
        'lote_polygons': {lote_entity1: lote_poly1, lote_entity2: lote_poly2},
    }
    textos = [MockDXFText("12", 5, 5), MockDXFText("20", 25, 5)]

    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    f1 = next(f for f in geojson["features"] if f["geometry"]["coordinates"][0][0][0] == 0)
    f2 = next(f for f in geojson["features"] if f["geometry"]["coordinates"][0][0][0] == 20)

    assert f1["properties"]["nome"] == "12"
    assert f1["properties"]["status"] == "valido"
    assert f2["properties"]["nome"] == "20"
    assert f2["properties"]["status"] == "valido"


def test_build_geojson_descarta_tokens_que_nao_sao_nome_de_lote():
    # NONLOT_TOKEN: quadra, área, decimal e rua/área não viram nome de lote.
    association = _single_lote_association(Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)]))
    textos = [
        MockDXFText("Q-04", 2, 2),
        MockDXFText("152,00M²", 3, 3),
        MockDXFText("16.00", 4, 4),
        MockDXFText("RUA DAS FLORES", 6, 6),
        MockDXFText("ÁREA VERDE", 7, 7),
    ]

    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    feature = geojson["features"][0]

    assert feature["properties"]["status"] == "ambiguo"
    assert feature["properties"]["nome"] == ""


def test_build_geojson_e_deterministico():
    association = _single_lote_association(Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)]))
    textos = [MockDXFText("12", 4.9, 5.1), MockDXFText("13", 9, 9)]

    first = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    second = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])

    assert first == second


def test_build_geojson_zero_texto_mantem_ambiguo():
    # ZERO_TEXTO: lote sem texto coberto permanece ambíguo e sem nome.
    association = _single_lote_association(Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)]))

    geojson = build_geojson(association, [], association['quadra_polygons'], association['lote_polygons'])
    feature = geojson["features"][0]

    assert feature["properties"]["status"] == "ambiguo"
    assert feature["properties"]["nome"] == ""


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
    # "AV." deve ser descartado; resta apenas o inteiro "12".
    association = _single_lote_association(Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)]))
    textos = [MockDXFText("12", 5, 5), MockDXFText("AV.", 6, 6)]

    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    feature = geojson["features"][0]

    assert feature["properties"]["nome"] == "12"
    assert feature["properties"]["status"] == "valido"

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



def test_build_geojson_reconhece_quadra_com_hifen():
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

    # O rótulo Q-04 (hífen) fica fora do lote, mas dentro da quadra.
    textos = [MockDXFText("12", 5, 5), MockDXFText("Q-04", -2, -2)]
    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    feature = geojson["features"][0]

    assert feature["properties"]["quadra"] == "Q-04"
    assert feature["properties"]["nome"] == "12"
    assert feature["properties"]["status"] == "valido"


def test_repaired_quadra_and_multipart_lote_preserve_holes_and_parts():
    from shapely.geometry import MultiPolygon, shape
    q, lote = MockDXFPoly(), MockDXFPoly()
    geometry = MultiPolygon([
        Polygon([(0,0),(4,0),(4,4),(0,4)], [[(1,1),(2,1),(2,2),(1,2)]]),
        Polygon([(6,0),(7,0),(7,1),(6,1)]),
    ])
    association = {'quadras': {q: [lote]}, 'lotes_orfaos': [], 'quadras_reparadas': {q}}
    result = build_geojson(association, [MockDXFText('Q 1', 3, 3)], {q: geometry}, {lote: geometry})
    assert len(result['features']) == 2
    for feature in result['features']:
        assert shape(feature['geometry']).equals(geometry)
    quadra = next(f for f in result['features'] if f['properties']['tipo'] == 'quadra')
    assert quadra['properties'] == {'tipo': 'quadra', 'nome': 'Q 1', 'status': 'ambiguo', 'geometria_reparada': True}


def test_extract_text_attrib():
    class Pt:
        def __init__(self, x, y):
            self.x = x
            self.y = y

    attrib = MockDXFText('lote 12', 10, 20, dxftype_name='ATTRIB')
    text, pt = extract_text(attrib)
    assert text == 'LOTE 12'
    assert pt.x == 10 and pt.y == 20

    attrib_aligned = MockDXFText('07', 0, 0, dxftype_name='ATTRIB', align_point=Pt(15, 25))
    text_aligned, pt_aligned = extract_text(attrib_aligned)
    assert text_aligned == '07'
    assert pt_aligned.x == 15 and pt_aligned.y == 25


@pytest.mark.parametrize(
    ('raw_text', 'expected_nome'),
    [
        ('LOTE 12', '12'),
        ('LT 12', '12'),
        ('LT. 12', '12'),
        ('L-12', '12'),
        ('LOTE 07', '07'),
    ],
)
def test_build_geojson_prefixo_lote_normaliza_para_inteiro(raw_text, expected_nome):
    association = _single_lote_association(Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)]))
    textos = [MockDXFText(raw_text, 5, 5)]

    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    feature = geojson['features'][0]

    assert feature['properties']['status'] == 'valido'
    assert feature['properties']['nome'] == expected_nome


def test_build_geojson_multi_prefixados_escolhe_o_mais_proximo():
    association = _single_lote_association(Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)]))
    textos = [MockDXFText('LOTE 12', 4.9, 5.1), MockDXFText('LT 13', 9, 9)]

    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    feature = geojson['features'][0]

    assert feature['properties']['status'] == 'valido'
    assert feature['properties']['nome'] == '12'


def test_build_geojson_fallback_distancia_quadra_adjacente():
    lote_entity = MockDXFPoly()
    lote_poly = Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)])
    quadra_entity = MockDXFPoly()
    quadra_poly = Polygon([(0, 0), (20, 0), (20, 20), (0, 20), (0, 0)])
    association = {
        'quadras': {quadra_entity: [lote_entity]},
        'lotes_orfaos': [],
        'quadra_polygons': {quadra_entity: quadra_poly},
        'lote_polygons': {lote_entity: lote_poly},
    }
    # Q-19 fora da quadra, mas a 5 m da borda (<= 8 m).
    textos = [MockDXFText('1', 5, 5), MockDXFText('Q-19', 25, 10)]

    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    feature = geojson['features'][0]

    assert feature['properties']['quadra'] == 'Q-19'


def test_build_geojson_fallback_distancia_quadra_ignora_multiplos_ou_distantes():
    lote_entity = MockDXFPoly()
    lote_poly = Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)])
    quadra_entity = MockDXFPoly()
    quadra_poly = Polygon([(0, 0), (20, 0), (20, 20), (0, 20), (0, 0)])
    association = {
        'quadras': {quadra_entity: [lote_entity]},
        'lotes_orfaos': [],
        'quadra_polygons': {quadra_entity: quadra_poly},
        'lote_polygons': {lote_entity: lote_poly},
    }
    # Dois rótulos no raio de 8 m -> mantém vazio.
    textos_duplos = [MockDXFText('1', 5, 5), MockDXFText('Q-19', 25, 10), MockDXFText('Q-20', 24, 12)]
    geojson_duplos = build_geojson(
        association, textos_duplos, association['quadra_polygons'], association['lote_polygons']
    )
    assert geojson_duplos['features'][0]['properties']['quadra'] == ''

    # Um rótulo além de 8 m -> mantém vazio.
    textos_longe = [MockDXFText('1', 5, 5), MockDXFText('Q-19', 30, 10)]
    geojson_longe = build_geojson(
        association, textos_longe, association['quadra_polygons'], association['lote_polygons']
    )
    assert geojson_longe['features'][0]['properties']['quadra'] == ''


def test_build_geojson_fallback_nao_sobrescreve_quadra_coberta_nem_quadra_sem_lotes():
    lote_entity = MockDXFPoly()
    lote_poly = Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)])
    quadra_com_lote = MockDXFPoly()
    quadra_vazia = MockDXFPoly()
    quadra_poly1 = Polygon([(0, 0), (20, 0), (20, 20), (0, 20), (0, 0)])
    quadra_poly2 = Polygon([(100, 0), (120, 0), (120, 20), (100, 20), (100, 0)])
    association = {
        'quadras': {quadra_com_lote: [lote_entity], quadra_vazia: []},
        'lotes_orfaos': [],
        'quadra_polygons': {quadra_com_lote: quadra_poly1, quadra_vazia: quadra_poly2},
        'lote_polygons': {lote_entity: lote_poly},
        'quadras_reparadas': {quadra_vazia},
    }
    textos = [
        MockDXFText('1', 5, 5),
        MockDXFText('Q-01', 15, 15),   # coberto por quadra_poly1
        MockDXFText('Q-02', 23, 10),   # adjacente a quadra_poly1 (<= 8m)
        MockDXFText('Q-99', 124, 10),  # adjacente a quadra_vazia sem lotes (<= 8m)
    ]

    geojson = build_geojson(association, textos, association['quadra_polygons'], association['lote_polygons'])
    lote_feat = next(f for f in geojson['features'] if f['properties']['tipo'] == 'lote')
    quadra_feat = next(f for f in geojson['features'] if f['properties']['tipo'] == 'quadra')

    assert lote_feat['properties']['quadra'] == 'Q-01'
    assert quadra_feat['properties']['nome'] == ''

