"""Extração nativa de loteamentos a partir de pacotes DWF 6.0 (seção W2D).

Valida o container ZIP do DWF, inspeciona o ``manifest.xml`` para localizar os
streams vetoriais ``application/x-w2d`` (``W2D V06.00``), decodifica polilinhas
e textos convertendo coordenadas lógicas W2D para coordenadas do modelo via a
matriz ``(Units ...)`` e reutiliza o pipeline geométrico/heurístico existente.
"""
from __future__ import annotations

import logging
import os
import re
import struct
import xml.etree.ElementTree as ET
import zipfile
import zlib

from dxf_extraction import MIN_LOTE_AREA, _classify
from geometry_utils import associate_lotes_to_quadras
from heuristics import QUADRA_LABEL_MAX_DISTANCE, build_geojson

logger = logging.getLogger(__name__)

MAX_DWF_UNCOMPRESSED_BYTES = 200 * 1024 * 1024

_UNITS_MATRIX_RE = re.compile(
    r"\(\s*Units\b.*?\(\s*"
    r"\(\s*([-+0-9.eE]+)\s+([-+0-9.eE]+)\s+[-+0-9.eE]+\s+[-+0-9.eE]+\s*\)\s*"
    r"\(\s*([-+0-9.eE]+)\s+([-+0-9.eE]+)\s+[-+0-9.eE]+\s+[-+0-9.eE]+\s*\)\s*"
    r"\(\s*[-+0-9.eE]+\s+[-+0-9.eE]+\s+[-+0-9.eE]+\s+[-+0-9.eE]+\s*\)\s*"
    r"\(\s*([-+0-9.eE]+)\s+([-+0-9.eE]+)\s+[-+0-9.eE]+\s+[-+0-9.eE]+\s*\)\s*\)",
    re.DOTALL,
)


class DwfExtractionError(ValueError):
    """Falha determinística na extração DWF que gera rascunho terminal."""


class _W2DPoint:
    __slots__ = ('x', 'y')

    def __init__(self, x: float, y: float):
        self.x = x
        self.y = y


class _W2DPolyline:
    """Adaptador de polilinha W2D compatível com ``geometry_utils`` e ``_classify``."""

    def __init__(self, points: list[tuple[float, float]], color=256):
        self._points = points
        self._effective_color = color

    def dxftype(self) -> str:
        return 'LWPOLYLINE'

    def get_points(self, format: str = 'xy'):  # noqa: A002 - assinatura ezdxf
        return self._points


class _W2DText:
    """Adaptador de texto W2D compatível com ``heuristics.extract_text``."""

    def __init__(self, text: str, x: float, y: float):
        self.text = text
        self.insert = _W2DPoint(x, y)
        self.align_point = None

    def dxftype(self) -> str:
        return 'TEXT'

    @property
    def dxf(self):
        return self


def _i32(value: int) -> int:
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value & 0x80000000 else value


def _normalize_zip_path(path: str) -> str:
    return (path or '').replace('\\', '/').lstrip('/')


def _read_member_bounded(
    zf: zipfile.ZipFile,
    info: zipfile.ZipInfo,
    remaining_budget: int,
) -> bytes:
    if info.file_size < 0 or info.file_size > remaining_budget:
        raise DwfExtractionError('O pacote DWF excede o limite de 200 MB descompactado.')
    chunks = []
    total = 0
    try:
        with zf.open(info, 'r') as stream:
            while True:
                chunk = stream.read(65536)
                if not chunk:
                    break
                total += len(chunk)
                if total > remaining_budget:
                    raise DwfExtractionError(
                        'O pacote DWF excede o limite de 200 MB descompactado.'
                    )
                chunks.append(chunk)
    except DwfExtractionError:
        raise
    except (
        OSError,
        EOFError,
        RuntimeError,
        NotImplementedError,
        zipfile.BadZipFile,
        zlib.error,
    ) as error:
        raise DwfExtractionError(f'Não foi possível ler o DWF: {error}') from error
    return b''.join(chunks)


def _read_w2d_streams(filepath: str) -> list[bytes]:
    filepath = os.fspath(filepath)
    if not filepath or not os.path.exists(filepath):
        raise DwfExtractionError('Arquivo DWF não encontrado.')
    if os.path.getsize(filepath) == 0:
        raise DwfExtractionError('O arquivo DWF está vazio.')
    if not filepath.lower().endswith('.dwf'):
        raise DwfExtractionError('O arquivo enviado não é um DWF.')

    try:
        zf = zipfile.ZipFile(filepath, 'r')
    except (
        OSError,
        EOFError,
        RuntimeError,
        NotImplementedError,
        zipfile.BadZipFile,
        zlib.error,
    ) as error:
        raise DwfExtractionError(f'Não foi possível ler o DWF: {error}') from error

    with zf:
        infos = zf.infolist()
        declared_total = sum(max(0, info.file_size) for info in infos)
        if declared_total > MAX_DWF_UNCOMPRESSED_BYTES:
            raise DwfExtractionError(
                'O pacote DWF excede o limite de 200 MB descompactado.'
            )

        by_norm_name = {_normalize_zip_path(info.filename): info for info in infos}
        by_lower_name = {
            _normalize_zip_path(info.filename).lower(): info for info in infos
        }

        manifest_info = by_lower_name.get('manifest.xml')
        if manifest_info is None:
            raise DwfExtractionError('O pacote DWF não possui manifest.xml.')

        remaining = MAX_DWF_UNCOMPRESSED_BYTES
        manifest_bytes = _read_member_bounded(zf, manifest_info, remaining)
        remaining -= len(manifest_bytes)

        manifest_lower = manifest_bytes.lower()
        if b'<!doctype' in manifest_lower or b'<!entity' in manifest_lower:
            raise DwfExtractionError(
                'O manifest.xml do DWF contém declarações DTD/ENTITY não permitidas.'
            )

        try:
            root = ET.fromstring(manifest_bytes)
        except ET.ParseError as error:
            raise DwfExtractionError(
                f'O manifest.xml do DWF é inválido: {error}'
            ) from error

        w2d_hrefs = []
        for elem in root.iter():
            tag_local = elem.tag.rsplit('}', 1)[-1] if '}' in elem.tag else elem.tag
            if tag_local == 'Resource' and elem.attrib.get('mime') == 'application/x-w2d':
                href = elem.attrib.get('href', '').strip()
                if href:
                    w2d_hrefs.append(href)

        if not w2d_hrefs:
            raise DwfExtractionError(
                'O pacote DWF não possui seção 2D (application/x-w2d).'
            )

        streams = []
        for href in w2d_hrefs:
            norm_href = _normalize_zip_path(href)
            target_info = by_norm_name.get(norm_href) or by_lower_name.get(
                norm_href.lower()
            )
            if target_info is None:
                raise DwfExtractionError(
                    f'Recurso W2D declarado no manifesto não encontrado: {href}'
                )
            w2d_bytes = _read_member_bounded(zf, target_info, remaining)
            remaining -= len(w2d_bytes)
            streams.append(w2d_bytes)

        return streams


def _read_wt_string(data: bytes, pos: int) -> tuple[str, int]:
    n = len(data)
    if pos >= n:
        raise DwfExtractionError('Stream W2D truncado ao ler string.')
    marker = data[pos]
    if marker == ord("'"):
        pos += 1
        out = bytearray()
        while pos < n:
            ch = data[pos]
            if ch == ord('\\'):
                if pos + 1 >= n:
                    raise DwfExtractionError('Stream W2D truncado em escape de string.')
                out.append(data[pos + 1])
                pos += 2
            elif ch == ord("'"):
                pos += 1
                return out.decode('latin1', errors='replace'), pos
            else:
                out.append(ch)
                pos += 1
        raise DwfExtractionError('String ASCII não terminada no stream W2D.')

    if marker == ord('{'):
        if pos + 5 > n:
            raise DwfExtractionError('Stream W2D truncado no cabeçalho de string UTF-16.')
        nchars = struct.unpack_from('<I', data, pos + 1)[0]
        byte_len = nchars * 2
        end_str = pos + 5 + byte_len
        if nchars > MAX_DWF_UNCOMPRESSED_BYTES or end_str >= n or data[end_str] != ord('}'):
            raise DwfExtractionError('String UTF-16 inválida ou truncada no stream W2D.')
        raw = data[pos + 5 : end_str]
        return raw.decode('utf-16le', errors='replace'), end_str + 1

    raise DwfExtractionError(f'Marcador de string W2D desconhecido: 0x{marker:02x}')


def _read_ascii_opcode(data: bytes, pos: int) -> tuple[str, int]:
    n = len(data)
    start = pos
    depth = 0
    in_str = False
    while pos < n:
        ch = data[pos]
        if in_str:
            if ch == ord('\\'):
                if pos + 1 >= n:
                    raise DwfExtractionError('Opcode ASCII truncado no stream W2D.')
                pos += 2
                continue
            if ch == ord("'"):
                in_str = False
        else:
            if ch == ord("'"):
                in_str = True
            elif ch == ord('{'):
                _, pos = _read_wt_string(data, pos)
                continue
            elif ch == ord('('):
                depth += 1
            elif ch == ord(')'):
                depth -= 1
                if depth == 0:
                    pos += 1
                    return data[start:pos].decode('latin1', errors='replace'), pos
        pos += 1
    raise DwfExtractionError('Opcode ASCII não balanceado no stream W2D.')


def _parse_w2d_stream(
    data: bytes,
) -> tuple[list[tuple[_W2DPolyline, str]], list[_W2DText]]:
    stripped = data.lstrip(b' \t\r\n')
    if not stripped.startswith(b'(W2D'):
        raise DwfExtractionError('Stream W2D inválido: cabeçalho (W2D ...) ausente.')

    pos = 0
    n = len(data)
    ox = 0
    oy = 0
    m00 = 1.0
    m01 = 0.0
    m10 = 0.0
    m11 = 1.0
    det = 1.0
    tx = 0.0
    ty = 0.0
    current_color = 256
    poly_entities: list[tuple[_W2DPolyline, str]] = []
    text_entities: list[_W2DText] = []

    def _to_world(lx: int, ly: int) -> tuple[float, float]:
        dx_t = lx - tx
        dy_t = ly - ty
        return (
            (dx_t * m11 - dy_t * m10) / det,
            (-dx_t * m01 + dy_t * m00) / det,
        )

    try:
        while pos < n:
            b = data[pos]
            if b in (0x20, 0x09, 0x0A, 0x0D):
                pos += 1
                continue

            if b == ord('('):
                token, pos = _read_ascii_opcode(data, pos)
                match = _UNITS_MATRIX_RE.search(token)
                if match:
                    new_m00 = float(match.group(1))
                    new_m01 = float(match.group(2))
                    new_m10 = float(match.group(3))
                    new_m11 = float(match.group(4))
                    new_tx = float(match.group(5))
                    new_ty = float(match.group(6))
                    new_det = new_m00 * new_m11 - new_m01 * new_m10
                    if abs(new_det) > 1e-12:
                        m00, m01, m10, m11 = new_m00, new_m01, new_m10, new_m11
                        det = new_det
                        tx, ty = new_tx, new_ty
                continue

            if b == ord('V'):
                pos += 1
            elif b == ord('c'):
                if pos + 2 > n:
                    raise DwfExtractionError('Opcode de cor truncado no stream W2D.')
                current_color = data[pos + 1]
                pos += 2
            elif b == 0x03:
                if pos + 5 > n:
                    raise DwfExtractionError('Opcode RGBA truncado no stream W2D.')
                current_color = struct.unpack_from('<BBBB', data, pos + 1)
                pos += 5
            elif b == 0x17:
                if pos + 5 > n:
                    raise DwfExtractionError('Opcode LineWeight truncado no stream W2D.')
                pos += 5
            elif b == ord('O'):
                if pos + 9 > n:
                    raise DwfExtractionError('Opcode Origin truncado no stream W2D.')
                ox, oy = struct.unpack_from('<ii', data, pos + 1)
                pos += 9
            elif b in (0x10, 0x14):
                if pos + 2 > n:
                    raise DwfExtractionError('Opcode de polilinha truncado no stream W2D.')
                count = data[pos + 1]
                if count == 0:
                    if pos + 4 > n:
                        raise DwfExtractionError(
                            'Contagem estendida de polilinha truncada no stream W2D.'
                        )
                    count = 256 + struct.unpack_from('<H', data, pos + 2)[0]
                    offset = pos + 4
                else:
                    offset = pos + 2
                end_pts = offset + count * 4
                if end_pts > n:
                    raise DwfExtractionError(
                        'Pontos de polilinha truncados no stream W2D.'
                    )
                pts: list[tuple[float, float]] = []
                for idx in range(count):
                    dx, dy = struct.unpack_from('<hh', data, offset + idx * 4)
                    ox = _i32(ox + dx)
                    oy = _i32(oy + dy)
                    if b == 0x10:
                        pts.append(_to_world(ox, oy))
                pos = end_pts
                if b == 0x10 and len(pts) >= 3:
                    poly_entities.append((_W2DPolyline(pts, current_color), '0'))
            elif b == 0x0C:
                if pos + 9 > n:
                    raise DwfExtractionError('Opcode Line16R truncado no stream W2D.')
                for idx in range(2):
                    dx, dy = struct.unpack_from('<hh', data, pos + 1 + idx * 4)
                    ox = _i32(ox + dx)
                    oy = _i32(oy + dy)
                pos += 9
            elif b == 0x92:
                if pos + 17 > n:
                    raise DwfExtractionError('Opcode Arc truncado no stream W2D.')
                dx, dy = struct.unpack_from('<ii', data, pos + 1)
                ox = _i32(ox + dx)
                oy = _i32(oy + dy)
                pos += 17
            elif b == 0x06:
                if pos + 3 > n:
                    raise DwfExtractionError('Opcode Font truncado no stream W2D.')
                mask = struct.unpack_from('<H', data, pos + 1)[0]
                pos += 3
                if mask & 0x0001:
                    _, pos = _read_wt_string(data, pos)
                if mask & 0x0002:
                    pos += 1
                if mask & 0x0004:
                    pos += 1
                if mask & 0x0008:
                    pos += 1
                if mask & 0x0010:
                    pos += 1
                if mask & 0x0020:
                    pos += 4
                if mask & 0x0040:
                    pos += 2
                if mask & 0x0080:
                    pos += 2
                if mask & 0x0100:
                    pos += 2
                if mask & 0x0200:
                    pos += 2
                if mask & 0x0400:
                    pos += 4
                if pos > n:
                    raise DwfExtractionError('Campos de Font truncados no stream W2D.')
            elif b == ord('x'):
                if pos + 9 > n:
                    raise DwfExtractionError('Opcode Text truncado no stream W2D.')
                dx, dy = struct.unpack_from('<ii', data, pos + 1)
                ox = _i32(ox + dx)
                oy = _i32(oy + dy)
                pos += 9
                txt_val, pos = _read_wt_string(data, pos)
                if txt_val and txt_val.strip():
                    wx, wy = _to_world(ox, oy)
                    text_entities.append(_W2DText(txt_val, wx, wy))
            else:
                raise DwfExtractionError(
                    f'Opcode binário W2D não suportado: 0x{b:02x} na posição {pos}'
                )
    except struct.error as error:
        raise DwfExtractionError(f'Stream W2D corrompido: {error}') from error

    return poly_entities, text_entities


def extract_dwf_geojson(filepath: str) -> dict:
    """Lê um arquivo DWF e devolve um FeatureCollection revisável (lotes/quadras/textos)."""
    streams = _read_w2d_streams(filepath)

    poly_entities: list[tuple[_W2DPolyline, str]] = []
    text_entities: list[_W2DText] = []
    for stream in streams:
        polys, texts = _parse_w2d_stream(stream)
        poly_entities.extend(polys)
        text_entities.extend(texts)

    if not poly_entities:
        raise DwfExtractionError(
            'O DWF não possui contornos utilizáveis para loteamento.'
        )

    lotes, quadras = _classify(
        poly_entities,
        min_lote_area=MIN_LOTE_AREA,
        text_entities=text_entities,
        doc=None,
    )
    if not lotes:
        raise DwfExtractionError(
            'O DWF não possui contornos utilizáveis para loteamento.'
        )

    association = associate_lotes_to_quadras(lotes, quadras)
    geojson = build_geojson(
        association,
        text_entities,
        association['quadra_polygons'],
        association['lote_polygons'],
        max_quadra_label_distance=QUADRA_LABEL_MAX_DISTANCE,
    )

    if not any(
        feature.get('properties', {}).get('tipo') == 'lote'
        for feature in geojson.get('features', [])
    ):
        raise DwfExtractionError(
            'O DWF não possui contornos utilizáveis para loteamento.'
        )
    return geojson

