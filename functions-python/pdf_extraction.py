"""Extração cadastral e dimensional de pranchas arquitetônicas em PDF (sem geometria).

Suporta 3 cenários no mesmo pipeline:
1. PDF de 1 página;
2. PDF multipágina (agregando itens de todas as páginas em ``items``);
3. Múltiplos arquivos PDF compartilhando o mesmo ``draftId`` (merge transacional
   em ``firestore_utils.save_draft_to_firestore``).

Por página, extrai texto vetorial via PyMuPDF com fallback OCR via ``pytesseract``
quando o texto vetorial for vazio ou insuficiente, e aplica os parsers de:
- Carimbo e localização;
- Quadro Geral de Áreas (conversão de vírgula decimal BR para ``float``);
- Recuos da edificação;
- Cotas lineares (``frenteM * profundidadeM ~= areaTerrenoM2`` com tolerância de 1%).
"""
from __future__ import annotations

import logging
import os
import re
from typing import Any

pymupdf = None
pytesseract = None
cv2 = None
np = None

logger = logging.getLogger(__name__)
_ocr_disabled = False

MIN_VECTOR_TEXT_ALNUM = 20
DIMENSION_AREA_TOLERANCE = 0.01

BRAZILIAN_UFS = frozenset({
    'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS',
    'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC',
    'SP', 'SE', 'TO',
})

_CNPJ_RE = re.compile(r'\b\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}\b')
_CPF_RE = re.compile(r'\b\d{3}\.\d{3}\.\d{3}-\d{2}\b')

_LOTE_QUADRA_RE = re.compile(
    r'\bLote\s*(?:n[º°.]?\s*)?([0-9A-Za-z-]+)\s*(?:da|de|,|\s|-)*\s*(?:Quadra|Qd\.?|Q\.?)\s*[:\-]?\s*([0-9A-Za-z-]+)\b',
    re.IGNORECASE,
)
_QUADRA_LOTE_RE = re.compile(
    r'\b(?:Quadra|Qd\.?|Q\.?)\s*[:\-]?\s*([0-9A-Za-z-]+)\s*(?:,|/|\s|-)*\s*(?:Lote|Lt\.?)\s*(?:n[º°.]?\s*)?([0-9A-Za-z-]+)\b',
    re.IGNORECASE,
)
_QUADRA_ONLY_RE = re.compile(
    r'\b(?:Quadra|Qd\.?)\s*[:\-]?\s*([0-9A-Za-z-]+)\b|\bQ[\s.\-]([0-9]{1,4}[A-Za-z]?)\b',
    re.IGNORECASE,
)
_LOTE_ONLY_RE = re.compile(
    r'\b(?:Lote|Lt\.?)\s*(?:n[º°.]?\s*)?[:\-]?\s*([0-9]{1,4}[A-Za-z]?)\b(?!\s*[.,]\d|\s*m[²2])',
    re.IGNORECASE,
)
_LOTEAMENTO_RE = re.compile(
    r'\bLoteamento\s+([^\n,;]+)',
    re.IGNORECASE,
)
_CITY_UF_RE = re.compile(
    r'([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ\s.\'-]{1,40}?)\s*/\s*([A-Z]{2})\b'
)
_STREET_RE = re.compile(
    r'\b((?:Rua|R\.|Avenida|Av\.?|Travessa|Tv\.?|Alameda|Al\.?|Estrada|Rodovia|Pra[çc]a|Largo)\s+[^\n;]+)',
    re.IGNORECASE,
)
_MONTH_YEAR_RE = re.compile(
    r'\b((?:janeiro|fevereiro|mar[çc]o|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro|'
    r'jan|fev|mar|abr|mai|jun|jul|ago|set|out|nov|dez)\s*/\s*\d{2,4})\b',
    re.IGNORECASE,
)
_EXPLICIT_DIM_PAIR_RE = re.compile(
    r'\b(\d+(?:[.,]\d+)?)\s*m?\s*[xX×]\s*(\d+(?:[.,]\d+)?)\s*m?\b'
)


class PdfExtractionError(ValueError):
    """Falha determinística na extração cadastral de PDF."""


def _load_pymupdf():
    global pymupdf
    if pymupdf is None:
        import pymupdf as pymupdf_module
        pymupdf = pymupdf_module
    return pymupdf


def _load_ocr_modules():
    global pytesseract, cv2, np
    if pytesseract is None:
        try:
            import pytesseract as pytesseract_module
        except ImportError:
            return None, None, None
        pytesseract = pytesseract_module
    if cv2 is None or np is None:
        try:
            import cv2 as cv2_module
            import numpy as numpy_module
            cv2, np = cv2_module, numpy_module
        except ImportError:
            return pytesseract, None, None
    return pytesseract, cv2, np


def parse_br_number(raw: str | None) -> float | None:
    """Converte número em formato brasileiro (vírgula decimal) ou padrão para float."""
    if raw is None:
        return None
    text = str(raw).strip()
    if not text:
        return None
    text = re.sub(r'[%\s]|m[²2]?$', '', text, flags=re.IGNORECASE).strip()
    if not text:
        return None

    if ',' in text and '.' in text:
        if text.rfind(',') > text.rfind('.'):
            text = text.replace('.', '').replace(',', '.')
        else:
            text = text.replace(',', '')
    elif ',' in text:
        text = text.replace(',', '.')

    try:
        value = float(text)
    except ValueError:
        return None
    if value != value:  # NaN
        return None
    return round(value, 4)


def _ocr_page(page) -> str:
    """Executa fallback OCR via pytesseract na página rasterizada."""
    global _ocr_disabled
    if _ocr_disabled:
        return ''
    ocr, cv2_mod, np_mod = _load_ocr_modules()
    if ocr is None:
        return ''
    if command := os.getenv('TESSERACT_CMD'):
        ocr.pytesseract.tesseract_cmd = command

    fitz = _load_pymupdf()
    try:
        pixmap = page.get_pixmap(matrix=fitz.Matrix(2, 2), alpha=False)
        png_bytes = pixmap.tobytes('png')
        if cv2_mod is not None and np_mod is not None:
            image = cv2_mod.imdecode(
                np_mod.frombuffer(png_bytes, dtype=np_mod.uint8),
                cv2_mod.IMREAD_COLOR,
            )
        else:
            from io import BytesIO
            from PIL import Image
            image = Image.open(BytesIO(png_bytes))
        try:
            return ocr.image_to_string(image, lang='por') or ''
        except ocr.TesseractError:
            return ocr.image_to_string(image) or ''
    except (OSError, ocr.TesseractError, ocr.TesseractNotFoundError) as error:
        logger.info('OCR indisponível para PDF: %s', error)
        _ocr_disabled = True
        return ''
    except Exception as error:  # pragma: no cover - fallback defensivo
        logger.warning('Falha inesperada no OCR da página PDF: %s', error)
        return ''


def _extract_page_text(page) -> str:
    """Extrai texto vetorial via PyMuPDF com fallback OCR quando insuficiente."""
    blocks_text = ''
    try:
        blocks = page.get_text('blocks')
        if isinstance(blocks, list) and blocks:
            # Ordena por linha (y0) e coluna (x0) para preservar ordem de leitura.
            sorted_blocks = sorted(blocks, key=lambda b: (round(b[1], 1), round(b[0], 1)))
            blocks_text = '\n'.join(
                str(b[4]).strip() for b in sorted_blocks if len(b) >= 5 and str(b[4]).strip()
            )
    except Exception:
        blocks_text = ''

    plain_text = ''
    try:
        plain_text = page.get_text('text') or ''
    except Exception:
        plain_text = ''

    text = blocks_text if len(blocks_text) >= len(plain_text.strip()) else plain_text
    alnum_count = sum(1 for ch in text if ch.isalnum())
    if alnum_count >= MIN_VECTOR_TEXT_ALNUM:
        return text

    ocr_text = _ocr_page(page)
    if len(ocr_text.strip()) > len(text.strip()):
        return ocr_text
    return text


def _clean_field(value: str | None) -> str | None:
    if not value:
        return None
    cleaned = re.sub(r'\s+', ' ', value).strip(' \t\r\n:;-–|,')
    return cleaned or None


def _format_lote_name(code: str | None) -> str:
    if not code:
        return ''
    cleaned = code.strip()
    if not cleaned:
        return ''
    if cleaned.lower().startswith('lote '):
        return cleaned
    return f'Lote {cleaned}'


def _format_quadra_name(code: str | None) -> str:
    if not code:
        return ''
    cleaned = code.strip()
    if not cleaned:
        return ''
    if cleaned.lower().startswith('quadra '):
        return cleaned
    return f'Quadra {cleaned}'


def _extract_location(text: str) -> dict[str, str | None]:
    """Extrai logradouro, bairro, cidade e UF do texto do carimbo."""
    logradouro: str | None = None
    bairro: str | None = None
    cidade: str | None = None
    uf: str | None = None

    # Prioriza trecho próximo a "Local:" / "Endereço:"
    local_match = re.search(
        r'(?:Local|Endere[çc]o)\s*[:\-]\s*(.+?)(?:\n\s*(?:Propriet[aá]rio|Respons[aá]vel|Autor|Projeto|Assunto|Escala|Data|Folha|Prancha|Quadro)\b|\Z)',
        text,
        re.IGNORECASE | re.DOTALL,
    )
    search_scope = local_match.group(1) if local_match else text

    # Cidade/UF (validando UF brasileira)
    for scope in (search_scope, text):
        for match in _CITY_UF_RE.finditer(scope):
            candidate_uf = match.group(2).upper()
            if candidate_uf in BRAZILIAN_UFS:
                raw_city = match.group(1).strip()
                # Se veio precedido por vírgula/hífen na mesma linha, pega o último segmento
                city_parts = re.split(r'[,\-–|]', raw_city)
                cidade = _clean_field(city_parts[-1])
                uf = candidate_uf
                # Tenta extrair bairro imediatamente antes de Cidade/UF
                if len(city_parts) >= 2 and not bairro:
                    candidate_bairro = _clean_field(city_parts[-2])
                    if candidate_bairro and not re.search(
                        r'^(?:Loteamento|Lote|Quadra|Rua|Av\.?|Avenida|s/n|sn)\b',
                        candidate_bairro,
                        re.IGNORECASE,
                    ):
                        bairro = candidate_bairro
                break
        if cidade and uf:
            break

    # Bairro explícito
    bairro_explicit = re.search(
        r'\bBairro\s*[:\-]\s*([^\n,;/\-–]+)',
        text,
        re.IGNORECASE,
    )
    if bairro_explicit:
        bairro = _clean_field(bairro_explicit.group(1))

    # Se bairro ainda não foi achado, procura segmento entre Loteamento/Logradouro e Cidade/UF
    if not bairro and cidade and uf:
        before_city = re.search(
            rf'([^\n]+?)\s*[,–\-]\s*{re.escape(cidade)}\s*/\s*{re.escape(uf)}\b',
            search_scope,
            re.IGNORECASE,
        )
        if before_city:
            parts = [p.strip() for p in re.split(r'[,–\-|]', before_city.group(1)) if p.strip()]
            for part in reversed(parts):
                if re.search(
                    r'^(?:Loteamento|Lote|Quadra|Rua|R\.|Av\.?|Avenida|Travessa|Alameda|Estrada|Rodovia|s/n|sn|n[º°]?)\b',
                    part,
                    re.IGNORECASE,
                ):
                    continue
                if len(part) >= 2:
                    bairro = _clean_field(part)
                    break

    # Logradouro
    for scope in (search_scope, text):
        street_match = _STREET_RE.search(scope)
        if street_match:
            raw_street = street_match.group(1).strip()
            # Corta antes de Bairro, Loteamento, Cidade/UF ou separadores de outro campo
            raw_street = re.split(
                r'\s*(?:-\s*(?:Bairro|Loteamento)|;\s*|\bBairro\s*[:\-]|\bLoteamento\b|\bQuadra\b|\bLote\b)',
                raw_street,
                maxsplit=1,
                flags=re.IGNORECASE,
            )[0]
            if bairro:
                raw_street = re.split(
                    rf',\s*{re.escape(bairro)}\b|\s*[-–]\s*{re.escape(bairro)}\b',
                    raw_street,
                    maxsplit=1,
                    flags=re.IGNORECASE,
                )[0]
            if cidade and uf:
                raw_street = re.split(
                    rf',\s*{re.escape(cidade)}\s*/\s*{re.escape(uf)}\b|\s*[-–]\s*{re.escape(cidade)}\s*/\s*{re.escape(uf)}\b',
                    raw_street,
                    maxsplit=1,
                    flags=re.IGNORECASE,
                )[0]
            logradouro = _clean_field(raw_street)
            if logradouro:
                break

    return {
        'logradouro': logradouro,
        'bairro': bairro,
        'cidade': cidade,
        'uf': uf,
    }


def _extract_labeled_value(text: str, labels: tuple[str, ...]) -> str | None:
    """Extrai o valor associado a um rótulo de carimbo (mesma linha ou linha seguinte)."""
    label_pattern = '|'.join(labels)
    pattern = re.compile(
        rf'(?:^|\n)\s*(?:{label_pattern})\s*[:\-]?\s*([^\n]*)',
        re.IGNORECASE,
    )
    match = pattern.search(text)
    if not match:
        return None
    same_line = match.group(1).strip()
    if same_line:
        return same_line
    # Tenta próxima linha não vazia
    rest = text[match.end():]
    for line in rest.splitlines():
        stripped = line.strip()
        if stripped:
            return stripped
    return None


def parse_stamp_metadata(text: str) -> dict[str, Any]:
    """Extrai campos do carimbo e localização da prancha."""
    quadra_code: str | None = None
    lote_code: str | None = None

    m = _LOTE_QUADRA_RE.search(text)
    if m:
        lote_code, quadra_code = m.group(1), m.group(2)
    else:
        m = _QUADRA_LOTE_RE.search(text)
        if m:
            quadra_code, lote_code = m.group(1), m.group(2)
        else:
            q_match = _QUADRA_ONLY_RE.search(text)
            if q_match:
                quadra_code = q_match.group(1) or q_match.group(2)
            l_match = _LOTE_ONLY_RE.search(text)
            if l_match:
                lote_code = l_match.group(1)

    loteamento_name: str | None = None
    lot_match = _LOTEAMENTO_RE.search(text)
    if lot_match:
        raw_lot = lot_match.group(1).strip()
        # Corta em separador de bairro/cidade se vier na mesma frase com ' - '
        raw_lot = re.split(r'\s+[-–]\s+', raw_lot, maxsplit=1)[0]
        loteamento_name = _clean_field(f'Loteamento {raw_lot}')

    location = _extract_location(text)

    # Proprietário e CPF/CNPJ
    prop_raw = _extract_labeled_value(
        text,
        (r'Propriet[aá]rio(?:a)?(?:\s*/\s*Empreendedor)?', r'Empreendedor', r'Contratante'),
    )
    proprietario_doc: str | None = None
    cnpj_match = _CNPJ_RE.search(text)
    cpf_match = _CPF_RE.search(text)
    if cnpj_match:
        proprietario_doc = cnpj_match.group(0)
    elif cpf_match:
        proprietario_doc = cpf_match.group(0)

    proprietario_nome: str | None = None
    if prop_raw:
        cleaned_prop = _CNPJ_RE.sub('', prop_raw)
        cleaned_prop = _CPF_RE.sub('', cleaned_prop)
        cleaned_prop = re.sub(r'\b(?:CNPJ|CPF)\s*[:\-]?\s*$', '', cleaned_prop, flags=re.IGNORECASE)
        proprietario_nome = _clean_field(cleaned_prop)

    # Responsável Técnico e CREA/CAU
    rt_raw = _extract_labeled_value(
        text,
        (
            r'Respons[aá]vel\s+T[eé]cnico',
            r'Autor\s+do\s+Projeto',
            r'Resp\.?\s*T[eé]c\.?',
        ),
    )
    rt_registro: str | None = None
    reg_match = re.search(
        r'\b(?:CREA|CAU)(?:\s*[-/]\s*[A-Z]{2})?\s*[:\-]?\s*([A-Za-z0-9.\-/]{4,})',
        text,
        re.IGNORECASE,
    )
    if reg_match:
        rt_registro = _clean_field(reg_match.group(1))

    rt_nome: str | None = None
    if rt_raw:
        cleaned_rt = re.sub(
            r'\b(?:CREA|CAU)(?:\s*[-/]\s*[A-Z]{2})?\s*[:\-]?\s*[A-Za-z0-9.\-/]+',
            '',
            rt_raw,
            flags=re.IGNORECASE,
        )
        rt_nome = _clean_field(cleaned_rt)

    # Data do projeto
    data_projeto: str | None = None
    date_labeled = _extract_labeled_value(text, (r'Data(?:\s+do\s+Projeto)?',))
    if date_labeled:
        m_month = _MONTH_YEAR_RE.search(date_labeled)
        if m_month:
            data_projeto = m_month.group(1).strip()
        else:
            m_num = re.search(r'\b\d{1,2}/\d{2,4}(?:/\d{2,4})?\b', date_labeled)
            if m_num:
                data_projeto = m_num.group(0)
            else:
                data_projeto = _clean_field(date_labeled)
    else:
        m_month = _MONTH_YEAR_RE.search(text)
        if m_month:
            data_projeto = m_month.group(1).strip()

    return {
        'loteamentoName': loteamento_name,
        'quadra': _format_quadra_name(quadra_code),
        'nome': _format_lote_name(lote_code),
        'logradouro': location['logradouro'],
        'bairro': location['bairro'],
        'cidade': location['cidade'],
        'uf': location['uf'],
        'proprietarioNome': proprietario_nome,
        'proprietarioDocumento': proprietario_doc,
        'responsavelTecnicoNome': rt_nome,
        'responsavelTecnicoRegistro': rt_registro,
        'dataProjeto': data_projeto,
    }


def parse_area_table(text: str) -> dict[str, float | None]:
    """Extrai valores do Quadro Geral de Áreas (convertendo vírgula decimal BR)."""
    patterns: dict[str, tuple[str, ...]] = {
        'areaTerrenoM2': (
            r'[ÁA]REA\s+DO\s+TERRENO\s*[:\-=]?\s*([0-9]+(?:[.,][0-9]+)?)\s*m[²2]',
            r'[ÁA]REA\s+DO\s+LOTE\s*[:\-=]?\s*([0-9]+(?:[.,][0-9]+)?)\s*m[²2]',
            r'\bTERRENO\s*[:\-=]?\s*([0-9]+(?:[.,][0-9]+)?)\s*m[²2]',
            r'\bLOTE\s*[:\-=]?\s*([0-9]+(?:[.,][0-9]+)?)\s*m[²2]',
        ),
        'areaConstruidaM2': (
            r'[ÁA]REA\s+(?:TOTAL\s+)?CONSTRU[ÍI]DA\s*[:\-=]?\s*([0-9]+(?:[.,][0-9]+)?)\s*m[²2]',
            r'[ÁA]REA\s+A\s+CONSTRUIR\s*[:\-=]?\s*([0-9]+(?:[.,][0-9]+)?)\s*m[²2]',
            r'\bCONSTRU[ÍI]DA\s*[:\-=]?\s*([0-9]+(?:[.,][0-9]+)?)\s*m[²2]',
        ),
        'taxaOcupacaoPercent': (
            r'TAXA\s+DE\s+OCUPA[ÇC][ÃA]O\s*[:\-=]?\s*([0-9]+(?:[.,][0-9]+)?)\s*%?',
        ),
        'coeficienteAproveitamento': (
            r'COEFICIENTE\s+DE\s+APROVEITAMENTO\s*[:\-=]?\s*([0-9]+(?:[.,][0-9]+)?)',
        ),
        'areaPermeavelM2': (
            r'[ÁA]REA\s+PERME[ÁA]VEL\s*[:\-=]?\s*([0-9]+(?:[.,][0-9]+)?)\s*m[²2]',
        ),
        'taxaPermeabilidadePercent': (
            r'TAXA\s+DE\s+PERMEABILIDADE\s*[:\-=]?\s*([0-9]+(?:[.,][0-9]+)?)\s*%?',
        ),
        'areaImpermeavelM2': (
            r'[ÁA]REA\s+IMPERME[ÁA]VEL\s*[:\-=]?\s*([0-9]+(?:[.,][0-9]+)?)\s*m[²2]',
        ),
    }

    result: dict[str, float | None] = {}
    for field, field_patterns in patterns.items():
        value: float | None = None
        for pattern in field_patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                value = parse_br_number(match.group(1))
                if value is not None:
                    break
        result[field] = value
    return result


def parse_recuos(text: str) -> dict[str, float | None]:
    """Extrai recuos opcionais da edificação (em metros)."""
    patterns: dict[str, str] = {
        'recuoFrontalM': r'(?:RECUO\s+FRONTAL|AFASTAMENTO\s+FRONTAL|RECUO\s+DE\s+FRENTE)\s*[:\-=]?\s*([0-9]+(?:[.,][0-9]+)?)\s*m?\b',
        'recuoFundoM': r'(?:RECUO\s+(?:DE\s+)?FUNDOS?|AFASTAMENTO\s+(?:DE\s+)?FUNDOS?)\s*[:\-=]?\s*([0-9]+(?:[.,][0-9]+)?)\s*m?\b',
        'recuoLateralEsquerdoM': r'(?:RECUO\s+LATERAL\s+ESQUERD[OA]|AFASTAMENTO\s+LATERAL\s+ESQUERD[OA]|LATERAL\s+ESQUERD[OA])\s*[:\-=]?\s*([0-9]+(?:[.,][0-9]+)?)\s*m?\b',
        'recuoLateralDireitoM': r'(?:RECUO\s+LATERAL\s+DIREIT[OA]|AFASTAMENTO\s+LATERAL\s+DIREIT[OA]|LATERAL\s+DIREIT[OA])\s*[:\-=]?\s*([0-9]+(?:[.,][0-9]+)?)\s*m?\b',
    }
    result: dict[str, float | None] = {}
    for field, pattern in patterns.items():
        match = re.search(pattern, text, re.IGNORECASE)
        result[field] = parse_br_number(match.group(1)) if match else None

    if result['recuoLateralEsquerdoM'] is None and result['recuoLateralDireitoM'] is None:
        both = re.search(
            r'RECUOS?\s+LATERAIS?\s*[:\-=]?\s*([0-9]+(?:[.,][0-9]+)?)\s*m?\b',
            text,
            re.IGNORECASE,
        )
        if both:
            val = parse_br_number(both.group(1))
            result['recuoLateralEsquerdoM'] = val
            result['recuoLateralDireitoM'] = val
    return result


def _pair_matches_area(a: float, b: float, area_terreno_m2: float) -> bool:
    if a <= 0 or b <= 0 or area_terreno_m2 <= 0:
        return False
    return abs((a * b) - area_terreno_m2) / area_terreno_m2 <= DIMENSION_AREA_TOLERANCE


def parse_linear_dimensions(
    text: str,
    area_terreno_m2: float | None,
) -> tuple[float | None, float | None]:
    """Identifica ``(frenteM, profundidadeM)`` a partir de cotas lineares.

    Quando ``area_terreno_m2`` está presente, exige compatibilidade
    ``frente * profundidade ~= areaTerrenoM2`` com tolerância de 1%.
    """
    # 1. Rótulos explícitos de frente e profundidade
    frente_match = re.search(
        r'\b(?:Frente|Testada)\s*[:\-=]?\s*([0-9]+(?:[.,][0-9]+)?)\s*m?\b',
        text,
        re.IGNORECASE,
    )
    prof_match = re.search(
        r'\b(?:Profundidade|Comprimento|Lateral)\s*[:\-=]?\s*([0-9]+(?:[.,][0-9]+)?)\s*m?\b',
        text,
        re.IGNORECASE,
    )
    if frente_match and prof_match:
        frente = parse_br_number(frente_match.group(1))
        prof = parse_br_number(prof_match.group(1))
        if frente and prof and frente > 0 and prof > 0:
            if area_terreno_m2 is None or _pair_matches_area(frente, prof, area_terreno_m2):
                return frente, prof

    # 2. Pares explícitos no formato AxB (ex.: 10,00 x 20,00 m ou 10x20m)
    for match in _EXPLICIT_DIM_PAIR_RE.finditer(text):
        a = parse_br_number(match.group(1))
        b = parse_br_number(match.group(2))
        if a and b and 2.0 <= a <= 500.0 and 2.0 <= b <= 500.0:
            if area_terreno_m2 is None or _pair_matches_area(a, b, area_terreno_m2):
                return min(a, b), max(a, b)

    # 3. Cotas lineares avulsas confrontadas com areaTerrenoM2 (tolerância 1%)
    if area_terreno_m2 is None or area_terreno_m2 <= 0:
        return None, None

    # Remove documentos/datas/áreas/porcentagens para reduzir ruído de números
    cleaned = _CNPJ_RE.sub(' ', text)
    cleaned = _CPF_RE.sub(' ', cleaned)
    cleaned = re.sub(r'\b\d+(?:[.,]\d+)?\s*(?:m[²2]|%)\b', ' ', cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r'\b(?:CREA|CAU)\s*[:\-]?\s*[A-Za-z0-9.\-/]+', ' ', cleaned, flags=re.IGNORECASE)

    candidates: list[float] = []
    for match in re.finditer(r'(?<![/\d.])(\d+(?:[.,]\d+)?)\s*m?(?![/\d.,%²2])', cleaned):
        val = parse_br_number(match.group(1))
        if val is not None and 2.0 <= val <= 500.0:
            candidates.append(val)

    best_pair: tuple[float, float] | None = None
    best_error = float('inf')
    n = len(candidates)
    for i in range(n):
        for j in range(i + 1, n):
            a, b = candidates[i], candidates[j]
            if not _pair_matches_area(a, b, area_terreno_m2):
                continue
            rel_err = abs((a * b) - area_terreno_m2) / area_terreno_m2
            pair = (min(a, b), max(a, b))
            if rel_err < best_error:
                best_error = rel_err
                best_pair = pair

    if best_pair is not None:
        return best_pair
    return None, None


def extract_page_record(
    text: str,
    *,
    source_file: str,
    source_page: int,
) -> tuple[dict[str, Any], dict[str, Any] | None]:
    """Processa o texto de uma página e retorna ``(loteamento_meta, item | None)``."""
    stamp = parse_stamp_metadata(text)
    areas = parse_area_table(text)
    recuos = parse_recuos(text)

    area_terreno = areas['areaTerrenoM2']
    frente_m, profundidade_m = parse_linear_dimensions(text, area_terreno)
    if area_terreno is None and frente_m is not None and profundidade_m is not None:
        area_terreno = round(frente_m * profundidade_m, 2)

    loteamento_meta = {
        k: v
        for k, v in {
            'name': stamp['loteamentoName'],
            'bairro': stamp['bairro'],
            'cidade': stamp['cidade'],
            'uf': stamp['uf'],
            'proprietarioNome': stamp['proprietarioNome'],
            'proprietarioDocumento': stamp['proprietarioDocumento'],
            'responsavelTecnicoNome': stamp['responsavelTecnicoNome'],
            'responsavelTecnicoRegistro': stamp['responsavelTecnicoRegistro'],
        }.items()
        if v is not None
    }

    has_item_signal = any([
        stamp['nome'],
        stamp['quadra'],
        area_terreno is not None,
        areas['areaConstruidaM2'] is not None,
        frente_m is not None,
        profundidade_m is not None,
        stamp['logradouro'] is not None,
    ])
    if not has_item_signal:
        return loteamento_meta, None

    status = 'valido' if (stamp['nome'] or area_terreno is not None) else 'ambiguo'
    item: dict[str, Any] = {
        'quadra': stamp['quadra'],
        'nome': stamp['nome'],
        'frenteM': frente_m,
        'profundidadeM': profundidade_m,
        'areaTerrenoM2': area_terreno,
        'areaConstruidaM2': areas['areaConstruidaM2'],
        'logradouro': stamp['logradouro'],
        'taxaOcupacaoPercent': areas['taxaOcupacaoPercent'],
        'coeficienteAproveitamento': areas['coeficienteAproveitamento'],
        'areaPermeavelM2': areas['areaPermeavelM2'],
        'taxaPermeabilidadePercent': areas['taxaPermeabilidadePercent'],
        'areaImpermeavelM2': areas['areaImpermeavelM2'],
        'recuoFrontalM': recuos['recuoFrontalM'],
        'recuoFundoM': recuos['recuoFundoM'],
        'recuoLateralEsquerdoM': recuos['recuoLateralEsquerdoM'],
        'recuoLateralDireitoM': recuos['recuoLateralDireitoM'],
        'proprietarioNome': stamp['proprietarioNome'],
        'proprietarioDocumento': stamp['proprietarioDocumento'],
        'responsavelTecnicoNome': stamp['responsavelTecnicoNome'],
        'responsavelTecnicoRegistro': stamp['responsavelTecnicoRegistro'],
        'dataProjeto': stamp['dataProjeto'],
        'sourceFile': source_file,
        'sourcePage': source_page,
        'status': status,
    }
    return loteamento_meta, item


def _merge_loteamento_meta(target: dict[str, Any], incoming: dict[str, Any]) -> None:
    for key, value in incoming.items():
        if value is not None and not target.get(key):
            target[key] = value


def extract_pdf_draft(filepath: str, filename: str | None = None) -> dict[str, Any]:
    """Extrai rascunho tabular sem geometria de um PDF de 1 ou múltiplas páginas."""
    fitz = _load_pymupdf()
    filepath = os.fspath(filepath)
    if not filepath or not os.path.exists(filepath):
        raise PdfExtractionError('Arquivo PDF não encontrado.')
    if os.path.getsize(filepath) == 0:
        raise PdfExtractionError('O arquivo PDF está vazio.')

    try:
        document = fitz.open(filepath)
    except (OSError, RuntimeError, ValueError) as error:
        raise PdfExtractionError('PDF inválido ou corrompido.') from error

    display_filename = filename or os.path.basename(filepath)
    loteamento: dict[str, Any] = {}
    items: list[dict[str, Any]] = []

    try:
        page_count = document.page_count
        if page_count == 0:
            raise PdfExtractionError('O PDF não contém páginas.')

        for page_index, page in enumerate(document, start=1):
            text = _extract_page_text(page)
            if not text or not text.strip():
                continue
            page_loteamento, item = extract_page_record(
                text,
                source_file=display_filename,
                source_page=page_index,
            )
            _merge_loteamento_meta(loteamento, page_loteamento)
            if item is not None:
                items.append(item)
    finally:
        document.close()

    if not items:
        raise PdfExtractionError(
            'Nenhum dado cadastral ou dimensional confiável foi encontrado no PDF.'
        )

    return {
        'loteamento': loteamento,
        'sourceFormat': 'pdf',
        'sourceFiles': [
            {
                'filename': display_filename,
                'pageCount': page_count,
                'status': 'processado',
            }
        ],
        'items': items,
    }
