import os

import ezdxf
import pytest

from dxf_extraction import DxfExtractionError, extract_dxf_draft

FIXTURE = os.path.join(
    os.path.dirname(__file__),
    '..',
    '..',
    'dwg_dxf',
    '00a-LOTEAMENTO_HR_R13A-Model_SEM_COTAS.dxf',
)


def _save(doc, path):
    doc.saveas(path)
    return str(path)


def _add_quadra_lote_layer_dxf(path):
    doc = ezdxf.new()
    doc.layers.add('QUADRA')
    doc.layers.add('LOTE')
    msp = doc.modelspace()
    msp.add_lwpolyline([(0, 0), (100, 0), (100, 100), (0, 100)], dxfattribs={'layer': 'QUADRA'})
    msp.add_lwpolyline([(10, 10), (20, 10), (20, 30), (10, 30)], dxfattribs={'layer': 'LOTE'})
    msp.add_mtext('12', dxfattribs={'layer': 'LOTE'}).set_location((15, 20))
    return _save(doc, path)


def _add_geometry_dxf(path):
    doc = ezdxf.new()
    msp = doc.modelspace()
    msp.add_lwpolyline([(0, 0), (100, 0), (100, 100), (0, 100)])
    msp.add_lwpolyline([(10, 10), (20, 10), (20, 20), (10, 20)])
    msp.add_mtext('15', dxfattribs={}).set_location((15, 15))
    return _save(doc, path)


def test_extract_reference_dxf_gera_itens_tabulares_sem_geometria():
    draft = extract_dxf_draft(FIXTURE)

    assert draft['sourceFormat'] == 'dxf'
    assert 'features' not in draft
    assert len(draft['sourceFiles']) == 1
    assert draft['sourceFiles'][0]['status'] == 'processado'

    items = draft['items']
    assert len(items) >= 1
    for item in items:
        assert 'geometry' not in item
        assert set(item).issuperset({
            'nome', 'quadra', 'status', 'frenteM', 'profundidadeM', 'areaTerrenoM2',
        })
        assert item['areaTerrenoM2'] is not None and item['areaTerrenoM2'] > 0
        assert item['frenteM'] is not None and item['frenteM'] > 0
        assert item['profundidadeM'] is not None and item['profundidadeM'] >= item['frenteM']


def test_extract_reference_dxf_associa_textos_aos_lotes():
    draft = extract_dxf_draft(FIXTURE)

    # O fixture sem cotas associa o número do lote como nome confiável em 245
    # parcelas; após descartar molduras Q-xx e áreas de cor divergente restam 18 ambíguos.
    items = draft['items']
    validos = [i['nome'] for i in items if i['status'] == 'valido']
    ambiguos = [i for i in items if i['status'] == 'ambiguo']
    assert len(validos) == 245
    assert len(ambiguos) == 18
    assert '101' in validos


def test_extract_reference_dxf_reconhece_rotulos_de_quadra_com_hifen():
    draft = extract_dxf_draft(FIXTURE)

    quadras = {
        i['quadra']
        for i in draft['items']
        if (i.get('quadra') or '').strip()
    }
    assert 'Q-04' in quadras
    assert 'Q-19' in quadras
    assert len(quadras) == 23


def test_extract_classifica_por_tokens_de_layer_e_calcula_dimensoes(tmp_path):
    path = _add_quadra_lote_layer_dxf(tmp_path / 'layer.dxf')

    draft = extract_dxf_draft(path)

    assert len(draft['items']) == 1
    item = draft['items'][0]
    assert item['nome'] == '12'
    assert item['status'] == 'valido'
    assert item['frenteM'] == 10.0
    assert item['profundidadeM'] == 20.0
    assert item['areaTerrenoM2'] == 200.0
    assert 'geometry' not in item


def test_extract_classifica_por_geometria_quando_layer_zero(tmp_path):
    path = _add_geometry_dxf(tmp_path / 'geometry.dxf')

    draft = extract_dxf_draft(path)

    assert len(draft['items']) == 1
    assert draft['items'][0]['nome'] == '15'
    assert draft['items'][0]['status'] == 'valido'
    assert draft['items'][0]['areaTerrenoM2'] == 100.0


def test_extract_marca_lote_sem_texto_confiavel_como_ambiguo(tmp_path):
    doc = ezdxf.new()
    msp = doc.modelspace()
    msp.add_lwpolyline([(0, 0), (100, 0), (100, 100), (0, 100)])
    msp.add_lwpolyline([(10, 10), (20, 10), (20, 20), (10, 20)])
    path = _save(doc, tmp_path / 'ambiguous.dxf')

    draft = extract_dxf_draft(path)

    item = draft['items'][0]
    assert item['status'] == 'ambiguo'
    assert item['nome'] == ''


def test_extract_herda_layer_do_insert(tmp_path):
    doc = ezdxf.new()
    doc.layers.add('QUADRA')
    doc.layers.add('LOTE')
    block = doc.blocks.new('parcela')
    block.add_lwpolyline([(10, 10), (20, 10), (20, 20), (10, 20)], dxfattribs={'layer': 'LOTE'})
    msp = doc.modelspace()
    msp.add_lwpolyline([(0, 0), (100, 0), (100, 100), (0, 100)], dxfattribs={'layer': 'QUADRA'})
    msp.add_blockref('parcela', (0, 0), dxfattribs={'layer': 'QUADRA'})
    msp.add_mtext('Q 1', dxfattribs={'layer': 'QUADRA'}).set_location((50, 50))
    path = _save(doc, tmp_path / 'insert.dxf')

    draft = extract_dxf_draft(path)

    assert len(draft['items']) == 1
    assert draft['items'][0]['quadra'] == 'Q 1'


def test_extract_mescla_layer_e_geometria(tmp_path):
    doc = ezdxf.new()
    doc.layers.add('LOTE')
    msp = doc.modelspace()
    msp.add_lwpolyline([(0, 0), (100, 0), (100, 100), (0, 100)], dxfattribs={'layer': 'QUADRA'})
    msp.add_lwpolyline([(10, 10), (20, 10), (20, 20), (10, 20)], dxfattribs={'layer': 'LOTE'})
    msp.add_lwpolyline([(30, 10), (40, 10), (40, 20), (30, 20)])
    path = _save(doc, tmp_path / 'mixed.dxf')

    draft = extract_dxf_draft(path)

    assert len(draft['items']) == 2


def test_extract_rejeita_dxf_corrompido(tmp_path):
    invalid = tmp_path / 'invalid.dxf'
    invalid.write_text('isto não é um DXF')

    with pytest.raises(DxfExtractionError, match='Não foi possível ler o DXF'):
        extract_dxf_draft(str(invalid))


def test_extract_rejeita_dxf_vazio(tmp_path):
    empty = tmp_path / 'empty.dxf'
    empty.write_bytes(b'')

    with pytest.raises(DxfExtractionError, match='vazio'):
        extract_dxf_draft(str(empty))


def test_extract_rejeita_extensao_diferente(tmp_path):
    other = tmp_path / 'arquivo.dwg'
    other.write_text('conteúdo qualquer')

    with pytest.raises(DxfExtractionError, match='não é um DXF'):
        extract_dxf_draft(str(other))


def test_extract_rejeita_dxf_sem_lotes(tmp_path):
    doc = ezdxf.new()
    doc.modelspace().add_line((0, 0), (10, 10))
    path = _save(doc, tmp_path / 'sem-lotes.dxf')

    with pytest.raises(DxfExtractionError, match='contornos utilizáveis'):
        extract_dxf_draft(path)


def test_extract_rejeita_arquivo_inexistente(tmp_path):
    with pytest.raises(DxfExtractionError, match='não encontrado'):
        extract_dxf_draft(str(tmp_path / 'ausente.dxf'))


def test_extract_descarta_moldura_qxx_e_associa_quadra_por_proximidade(tmp_path):
    doc = ezdxf.new()
    msp = doc.modelspace()
    msp.add_lwpolyline([(0, 0), (100, 0), (100, 100), (0, 100)])
    msp.add_lwpolyline([(10, 10), (20, 10), (20, 20), (10, 20)])
    msp.add_mtext('12').set_location((15, 15))
    msp.add_lwpolyline([(102, 40), (106, 40), (106, 44), (102, 44)])
    msp.add_mtext('Q-19').set_location((104, 42))
    path = _save(doc, tmp_path / 'moldura_q19.dxf')

    draft = extract_dxf_draft(path)

    assert len(draft['items']) == 1
    assert draft['items'][0]['nome'] == '12'
    assert draft['items'][0]['quadra'] == 'Q-19'


def test_extract_lote_com_insert_attrib(tmp_path):
    doc = ezdxf.new()
    block = doc.blocks.new('CARIMBO_LOTE')
    block.add_lwpolyline([(0, 0), (10, 0), (10, 10), (0, 10)])
    block.add_attdef('NUM_LOTE', (5, 5))
    msp = doc.modelspace()
    msp.add_lwpolyline([(0, 0), (100, 0), (100, 100), (0, 100)])
    msp.add_mtext('Q-01').set_location((50, 50))
    insert = msp.add_blockref('CARIMBO_LOTE', (10, 10))
    insert.add_auto_attribs({'NUM_LOTE': 'LOTE 12'})
    path = _save(doc, tmp_path / 'attrib.dxf')

    draft = extract_dxf_draft(path)

    assert len(draft['items']) == 1
    assert draft['items'][0]['nome'] == '12'
    assert draft['items'][0]['status'] == 'valido'
    assert draft['items'][0]['quadra'] == 'Q-01'


def test_extract_escala_insunits_milimetros_descarta_simbolos_pequenos_e_converte_metros(tmp_path):
    doc = ezdxf.new()
    doc.header['$INSUNITS'] = 4  # milímetros
    msp = doc.modelspace()
    msp.add_lwpolyline([(0, 0), (100000, 0), (100000, 100000), (0, 100000)])
    # Lote real 10m x 20m em mm (10000 x 20000 = 200 m²)
    msp.add_lwpolyline([(10000, 10000), (20000, 10000), (20000, 30000), (10000, 30000)])
    msp.add_mtext('7').set_location((15000, 20000))
    # Símbolo gráfico 500mm x 500mm -> descartado
    msp.add_lwpolyline([(100, 100), (600, 100), (600, 600), (100, 600)])
    path = _save(doc, tmp_path / 'mm.dxf')

    draft = extract_dxf_draft(path)

    assert len(draft['items']) == 1
    item = draft['items'][0]
    assert item['nome'] == '7'
    assert item['frenteM'] == 10.0
    assert item['profundidadeM'] == 20.0
    assert item['areaTerrenoM2'] == 200.0


def test_extract_filtra_poligonos_sem_candidato_fora_da_cor_aci_predominante(tmp_path):
    doc = ezdxf.new()
    msp = doc.modelspace()
    msp.add_lwpolyline([(0, 0), (100, 0), (100, 100), (0, 100)], dxfattribs={'color': 1})
    msp.add_lwpolyline([(10, 10), (20, 10), (20, 20), (10, 20)], dxfattribs={'color': 3})
    msp.add_mtext('1').set_location((15, 15))
    msp.add_lwpolyline([(25, 10), (35, 10), (35, 20), (25, 20)], dxfattribs={'color': 3})
    msp.add_mtext('2').set_location((30, 15))
    msp.add_lwpolyline([(40, 10), (50, 10), (50, 20), (40, 20)], dxfattribs={'color': 3})
    msp.add_lwpolyline([(60, 10), (75, 10), (75, 25), (60, 25)], dxfattribs={'color': 18})
    msp.add_mtext('ÁREA INSTITUCIONAL').set_location((65, 15))
    path = _save(doc, tmp_path / 'aci_color.dxf')

    draft = extract_dxf_draft(path)

    items = draft['items']
    assert len(items) == 3
    assert len([i for i in items if i['status'] == 'valido']) == 2
    assert len([i for i in items if i['status'] == 'ambiguo']) == 1


def test_extract_herda_cor_aci_byblock_e_bylayer(tmp_path):
    doc = ezdxf.new()
    doc.layers.add('PARCELAS', color=3)
    block = doc.blocks.new('LOTE_BLK')
    block.add_lwpolyline([(0, 0), (10, 0), (10, 10), (0, 10)], dxfattribs={'color': 0})
    msp = doc.modelspace()
    msp.add_lwpolyline([(0, 0), (100, 0), (100, 100), (0, 100)], dxfattribs={'color': 1})
    msp.add_lwpolyline([(10, 10), (20, 10), (20, 20), (10, 20)], dxfattribs={'layer': 'PARCELAS'})
    msp.add_mtext('1').set_location((15, 15))
    msp.add_lwpolyline([(25, 10), (35, 10), (35, 20), (25, 20)], dxfattribs={'layer': 'PARCELAS'})
    msp.add_mtext('2').set_location((30, 15))
    msp.add_blockref('LOTE_BLK', (40, 10), dxfattribs={'color': 3})
    msp.add_blockref('LOTE_BLK', (60, 10), dxfattribs={'color': 6})
    path = _save(doc, tmp_path / 'aci_inheritance.dxf')

    draft = extract_dxf_draft(path)

    assert len(draft['items']) == 3
