import os

import ezdxf
import pytest

from dxf_extraction import DxfExtractionError, extract_dxf_geojson

FIXTURE = os.path.join(os.path.dirname(__file__), '..', '..', 'dwg_dxf', '00a-LOTEAMENTO_HR_R13A-Model.dxf')


def _save(doc, path):
    doc.saveas(path)
    return str(path)


def _add_quadra_lote_layer_dxf(path):
    doc = ezdxf.new()
    doc.layers.add('QUADRA')
    doc.layers.add('LOTE')
    msp = doc.modelspace()
    msp.add_lwpolyline([(0, 0), (100, 0), (100, 100), (0, 100)], dxfattribs={'layer': 'QUADRA'})
    msp.add_lwpolyline([(10, 10), (20, 10), (20, 20), (10, 20)], dxfattribs={'layer': 'LOTE'})
    msp.add_mtext('12', dxfattribs={'layer': 'LOTE'}).set_location((15, 15))
    return _save(doc, path)


def _add_geometry_dxf(path):
    doc = ezdxf.new()
    msp = doc.modelspace()
    msp.add_lwpolyline([(0, 0), (100, 0), (100, 100), (0, 100)])
    msp.add_lwpolyline([(10, 10), (20, 10), (20, 20), (10, 20)])
    msp.add_mtext('15', dxfattribs={}).set_location((15, 15))
    return _save(doc, path)


def test_extract_reference_dxf_gera_lotes_revisaveis():
    geojson = extract_dxf_geojson(FIXTURE)

    assert geojson['type'] == 'FeatureCollection'
    lotes = [f for f in geojson['features'] if f['properties']['tipo'] == 'lote']
    assert len(lotes) >= 1
    for feature in lotes:
        assert set(feature['properties']).issuperset({'tipo', 'nome', 'quadra', 'status'})
        assert feature['geometry']['type'] in {'Polygon', 'MultiPolygon'}


def test_extract_reference_dxf_associa_textos_aos_lotes():
    geojson = extract_dxf_geojson(FIXTURE)

    # O MTEXT '16.00' é o único que as heurísticas (congeladas) associam como
    # nome confiável de um lote dentro de quadra; uma regressão aqui o derruba.
    validos = [
        f['properties']['nome']
        for f in geojson['features']
        if f['properties']['tipo'] == 'lote' and f['properties']['status'] == 'valido'
    ]
    assert validos == ['16.00']


def test_extract_classifica_por_tokens_de_layer(tmp_path):
    path = _add_quadra_lote_layer_dxf(tmp_path / 'layer.dxf')

    geojson = extract_dxf_geojson(path)

    lotes = [f for f in geojson['features'] if f['properties']['tipo'] == 'lote']
    assert len(lotes) == 1
    assert lotes[0]['properties']['nome'] == '12'
    assert lotes[0]['properties']['status'] == 'valido'


def test_extract_classifica_por_geometria_quando_layer_zero(tmp_path):
    path = _add_geometry_dxf(tmp_path / 'geometry.dxf')

    geojson = extract_dxf_geojson(path)

    lotes = [f for f in geojson['features'] if f['properties']['tipo'] == 'lote']
    assert len(lotes) == 1
    assert lotes[0]['properties']['nome'] == '15'
    assert lotes[0]['properties']['status'] == 'valido'


def test_extract_marca_lote_sem_texto_confiavel_como_ambiguo(tmp_path):
    doc = ezdxf.new()
    msp = doc.modelspace()
    msp.add_lwpolyline([(0, 0), (100, 0), (100, 100), (0, 100)])
    msp.add_lwpolyline([(10, 10), (20, 10), (20, 20), (10, 20)])
    path = _save(doc, tmp_path / 'ambiguous.dxf')

    geojson = extract_dxf_geojson(path)

    lote = next(f for f in geojson['features'] if f['properties']['tipo'] == 'lote')
    assert lote['properties']['status'] == 'ambiguo'
    assert lote['properties']['nome'] == ''


def test_extract_herda_layer_do_insert(tmp_path):
    doc = ezdxf.new()
    doc.layers.add('QUADRA')
    doc.layers.add('LOTE')
    # Parcela definida no próprio layer LOTE: o INSERT em QUADRA não pode
    # sobrescrevê-lo; se sobrescrever, deixa de existir lote e a extração falha.
    block = doc.blocks.new('parcela')
    block.add_lwpolyline([(10, 10), (20, 10), (20, 20), (10, 20)], dxfattribs={'layer': 'LOTE'})
    msp = doc.modelspace()
    msp.add_lwpolyline([(0, 0), (100, 0), (100, 100), (0, 100)], dxfattribs={'layer': 'QUADRA'})
    msp.add_blockref('parcela', (0, 0), dxfattribs={'layer': 'QUADRA'})
    msp.add_mtext('Q 1', dxfattribs={'layer': 'QUADRA'}).set_location((50, 50))
    path = _save(doc, tmp_path / 'insert.dxf')

    geojson = extract_dxf_geojson(path)

    lotes = [f for f in geojson['features'] if f['properties']['tipo'] == 'lote']
    assert len(lotes) == 1
    assert lotes[0]['properties']['quadra'] == 'Q 1'


def test_extract_mescla_layer_e_geometria(tmp_path):
    doc = ezdxf.new()
    doc.layers.add('LOTE')
    msp = doc.modelspace()
    # Quadra nomeada + lote nomeado, e uma parcela sem layer (0) que só a
    # geometria consegue classificar; todas devem sobreviver.
    msp.add_lwpolyline([(0, 0), (100, 0), (100, 100), (0, 100)], dxfattribs={'layer': 'QUADRA'})
    msp.add_lwpolyline([(10, 10), (20, 10), (20, 20), (10, 20)], dxfattribs={'layer': 'LOTE'})
    msp.add_lwpolyline([(30, 10), (40, 10), (40, 20), (30, 20)])
    path = _save(doc, tmp_path / 'mixed.dxf')

    geojson = extract_dxf_geojson(path)

    lotes = [f for f in geojson['features'] if f['properties']['tipo'] == 'lote']
    assert len(lotes) == 2


def test_extract_rejeita_dxf_corrompido(tmp_path):
    invalid = tmp_path / 'invalid.dxf'
    invalid.write_text('isto não é um DXF')

    with pytest.raises(DxfExtractionError, match='Não foi possível ler o DXF'):
        extract_dxf_geojson(str(invalid))


def test_extract_rejeita_dxf_vazio(tmp_path):
    empty = tmp_path / 'empty.dxf'
    empty.write_bytes(b'')

    with pytest.raises(DxfExtractionError, match='vazio'):
        extract_dxf_geojson(str(empty))


def test_extract_rejeita_extensao_diferente(tmp_path):
    other = tmp_path / 'arquivo.dwg'
    other.write_text('conteúdo qualquer')

    with pytest.raises(DxfExtractionError, match='não é um DXF'):
        extract_dxf_geojson(str(other))


def test_extract_rejeita_dxf_sem_lotes(tmp_path):
    doc = ezdxf.new()
    doc.modelspace().add_line((0, 0), (10, 10))
    path = _save(doc, tmp_path / 'sem-lotes.dxf')

    with pytest.raises(DxfExtractionError, match='contornos utilizáveis'):
        extract_dxf_geojson(path)


def test_extract_rejeita_arquivo_inexistente(tmp_path):
    with pytest.raises(DxfExtractionError, match='não encontrado'):
        extract_dxf_geojson(str(tmp_path / 'ausente.dxf'))
