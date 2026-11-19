import os
import struct
import zipfile

import pytest

from dwf_extraction import (
    MAX_DWF_UNCOMPRESSED_BYTES,
    DwfExtractionError,
    extract_dwf_draft,
)

FIXTURE = os.path.join(
    os.path.dirname(__file__),
    '..',
    '..',
    'dwg_dxf',
    'LOTEAMENTO_HR_R13A-Model.dwf',
)

_MANIFEST_WITH_W2D = """<?xml version="1.0" encoding="UTF-8"?>
<dwf:Manifest xmlns:dwf="DWF-Manifest:6.0" version="6.0">
  <dwf:Sections>
    <dwf:Section type="com.autodesk.dwf.ePlot" name="section1" title="Model">
      <dwf:Toc>
        <dwf:Resource role="2d streaming graphics" mime="application/x-w2d" href="section1\\drawing.w2d"/>
      </dwf:Toc>
    </dwf:Section>
  </dwf:Sections>
</dwf:Manifest>
"""


def _write_dwf_zip(path, entries: dict[str, bytes]):
    with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_DEFLATED) as zf:
        for name, content in entries.items():
            zf.writestr(name, content)
    return str(path)


def _rect_16r(dx0: int, dy0: int, w: int, h: int) -> bytes:
    pts = [(dx0, dy0), (w, 0), (0, h), (-w, 0), (0, -h)]
    buf = bytearray([0x10, len(pts)])
    for dx, dy in pts:
        buf.extend(struct.pack('<hh', dx, dy))
    return bytes(buf)


def _text_ascii(dx: int, dy: int, text: str) -> bytes:
    return b'x' + struct.pack('<ii', dx, dy) + b"'" + text.encode('latin1') + b"'"


def _text_utf16(dx: int, dy: int, text: str) -> bytes:
    encoded = text.encode('utf-16le')
    nchars = len(text)
    return b'x' + struct.pack('<ii', dx, dy) + b'{' + struct.pack('<I', nchars) + encoded + b'}'


def test_extract_reference_dwf_gera_23_quadras_245_validos_e_18_ambiguos_tabular():
    draft = extract_dwf_draft(FIXTURE)

    assert draft['sourceFormat'] == 'dwf'
    assert 'features' not in draft
    items = draft['items']
    validos = [i for i in items if i['status'] == 'valido']
    ambiguos = [i for i in items if i['status'] == 'ambiguo']
    quadras = {
        i['quadra']
        for i in items
        if (i.get('quadra') or '').strip()
    }

    assert len(validos) == 245
    assert len(ambiguos) == 18
    assert len(quadras) == 23
    for idx in range(1, 24):
        assert f'Q-{idx:02d}' in quadras
    for item in items:
        assert 'geometry' not in item
        assert set(item).issuperset({
            'nome', 'quadra', 'status', 'frenteM', 'profundidadeM', 'areaTerrenoM2',
        })
        assert item['areaTerrenoM2'] is not None and item['areaTerrenoM2'] > 0


def test_extract_synthetic_dwf_com_units_utf16_e_dimensoes(tmp_path):
    stream = bytearray()
    stream.extend(
        b"(W2D V06.00)(Units '' ((10 0 0 0)(0 10 0 0)(0 0 1 0)(1000 2000 0 1)))V"
    )
    stream.extend(b'O' + struct.pack('<ii', 1000, 2000))
    stream.extend(b'c\x01')
    stream.extend(_rect_16r(0, 0, 1000, 1000))
    # Lote 10m x 20m -> área 200m²
    stream.extend(b'c\x28')
    stream.extend(_rect_16r(100, 100, 100, 200))
    stream.extend(b'\x06' + struct.pack('<H', 0x0021) + b"'Arial'" + struct.pack('<I', 20))
    stream.extend(_text_ascii(50, 100, '12'))
    stream.extend(_text_utf16(0, 0, '200,00m²'))
    stream.extend(_text_ascii(350, 300, 'Q-01'))

    dwf_path = _write_dwf_zip(
        tmp_path / 'synthetic.dwf',
        {
            'manifest.xml': _MANIFEST_WITH_W2D.encode('utf-8'),
            'section1\\drawing.w2d': bytes(stream),
        },
    )

    draft = extract_dwf_draft(dwf_path)
    assert len(draft['items']) == 1
    item = draft['items'][0]
    assert item['nome'] == '12'
    assert item['quadra'] == 'Q-01'
    assert item['status'] == 'valido'
    assert item['frenteM'] == 10.0
    assert item['profundidadeM'] == 20.0
    assert item['areaTerrenoM2'] == 200.0
    assert 'geometry' not in item


def test_extract_rejeita_arquivo_inexistente(tmp_path):
    with pytest.raises(DwfExtractionError, match='não encontrado'):
        extract_dwf_draft(str(tmp_path / 'ausente.dwf'))


def test_extract_rejeita_dwf_vazio(tmp_path):
    empty = tmp_path / 'vazio.dwf'
    empty.write_bytes(b'')
    with pytest.raises(DwfExtractionError, match='vazio'):
        extract_dwf_draft(str(empty))


def test_extract_rejeita_extensao_diferente(tmp_path):
    other = tmp_path / 'arquivo.dxf'
    other.write_text('qualquer')
    with pytest.raises(DwfExtractionError, match='não é um DWF'):
        extract_dwf_draft(str(other))


def test_extract_rejeita_dwf_nao_zip(tmp_path):
    bad = tmp_path / 'corrompido.dwf'
    bad.write_bytes(b'isto nao e um zip')
    with pytest.raises(DwfExtractionError, match='Não foi possível ler o DWF'):
        extract_dwf_draft(str(bad))


def test_extract_rejeita_dwf_sem_manifest(tmp_path):
    path = _write_dwf_zip(tmp_path / 'sem_manifest.dwf', {'foo.txt': b'abc'})
    with pytest.raises(DwfExtractionError, match='manifest.xml'):
        extract_dwf_draft(path)


def test_extract_rejeita_dwf_com_manifest_invalido(tmp_path):
    path = _write_dwf_zip(tmp_path / 'bad_manifest.dwf', {'manifest.xml': b'<broken'})
    with pytest.raises(DwfExtractionError, match='manifest.xml do DWF é inválido'):
        extract_dwf_draft(path)


def test_extract_rejeita_dwf_sem_secao_w2d(tmp_path):
    manifest = b'<dwf:Manifest xmlns:dwf="DWF-Manifest:6.0"></dwf:Manifest>'
    path = _write_dwf_zip(tmp_path / 'sem_w2d.dwf', {'manifest.xml': manifest})
    with pytest.raises(DwfExtractionError, match='application/x-w2d'):
        extract_dwf_draft(path)


def test_extract_rejeita_dwf_acima_do_limite_descompactado(tmp_path, monkeypatch):
    monkeypatch.setattr('dwf_extraction.MAX_DWF_UNCOMPRESSED_BYTES', 64)
    path = _write_dwf_zip(
        tmp_path / 'grande.dwf',
        {
            'manifest.xml': _MANIFEST_WITH_W2D.encode('utf-8'),
            'section1\\drawing.w2d': b'(W2D V06.00)' + b' ' * 200,
        },
    )
    with pytest.raises(DwfExtractionError, match='200 MB'):
        extract_dwf_draft(path)


def test_extract_rejeita_dwf_sem_lotes(tmp_path):
    path = _write_dwf_zip(
        tmp_path / 'sem_lotes.dwf',
        {
            'manifest.xml': _MANIFEST_WITH_W2D.encode('utf-8'),
            'section1\\drawing.w2d': b'(W2D V06.00)V',
        },
    )
    with pytest.raises(DwfExtractionError, match='contornos utilizáveis'):
        extract_dwf_draft(path)


def test_extract_rejeita_w2d_truncado(tmp_path):
    path = _write_dwf_zip(
        tmp_path / 'truncado.dwf',
        {
            'manifest.xml': _MANIFEST_WITH_W2D.encode('utf-8'),
            'section1\\drawing.w2d': b'(W2D V06.00)O\x01\x02',
        },
    )
    with pytest.raises(DwfExtractionError, match='truncado'):
        extract_dwf_draft(path)


def test_extract_suporta_units_rotacionada_90_graus_e_contagem_estendida_256(tmp_path):
    def to_logical(xw: int, yw: int) -> tuple[int, int]:
        return 100 - 10 * yw, 200 + 10 * xw

    stream = bytearray()
    utf16_author = 'Autor(1)'.encode('utf-16le')
    stream.extend(b'(W2D V06.00)(Author {' + struct.pack('<I', len('Autor(1)')) + utf16_author + b'})')
    stream.extend(
        b"(Units 'Meters (m)' ((0 10 0 0)(-10 0 0 0)(0 0 1 0)(100 200 0 1)))V"
    )

    ox, oy = to_logical(0, 0)
    stream.extend(b'O' + struct.pack('<ii', ox, oy))
    stream.extend(b'c\x01')

    quadra_world = [(0, 0), (100, 0), (100, 100), (0, 100), (0, 0)]
    stream.extend(bytes([0x10, len(quadra_world)]))
    for xw, yw in quadra_world:
        lx, ly = to_logical(xw, yw)
        stream.extend(struct.pack('<hh', lx - ox, ly - oy))
        ox, oy = lx, ly

    stream.extend(b'c\x28')
    lote_world = [(10, 10), (20, 10), (20, 30), (10, 30)]
    while len(lote_world) < 260:
        lote_world.append((10, 10))
    stream.extend(b'\x10\x00' + struct.pack('<H', len(lote_world) - 256))
    for xw, yw in lote_world:
        lx, ly = to_logical(xw, yw)
        stream.extend(struct.pack('<hh', lx - ox, ly - oy))
        ox, oy = lx, ly

    for label, (xw, yw) in [('99', (15, 20)), ('Q-07', (50, 50))]:
        lx, ly = to_logical(xw, yw)
        stream.extend(_text_ascii(lx - ox, ly - oy, label))
        ox, oy = lx, ly

    dwf_path = _write_dwf_zip(
        tmp_path / 'rotated_256.dwf',
        {
            'manifest.xml': _MANIFEST_WITH_W2D.encode('utf-8'),
            'section1\\drawing.w2d': bytes(stream),
        },
    )

    draft = extract_dwf_draft(dwf_path)
    assert len(draft['items']) == 1
    item = draft['items'][0]
    assert item['nome'] == '99'
    assert item['quadra'] == 'Q-07'
    assert item['status'] == 'valido'
    assert item['frenteM'] == 10.0
    assert item['profundidadeM'] == 20.0
    assert item['areaTerrenoM2'] == 200.0


def test_extract_rejeita_manifest_com_entity_ou_doctype(tmp_path):
    xxe_manifest = b"""<?xml version="1.0"?>
<!DOCTYPE lolz [
  <!ENTITY lol "lol">
]>
<dwf:Manifest xmlns:dwf="DWF-Manifest:6.0"></dwf:Manifest>
"""
    path = _write_dwf_zip(
        tmp_path / 'entity_manifest.dwf',
        {'manifest.xml': xxe_manifest},
    )
    with pytest.raises(DwfExtractionError, match='DTD/ENTITY'):
        extract_dwf_draft(path)
