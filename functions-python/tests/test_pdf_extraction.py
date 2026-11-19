"""Testes unitários da extração cadastral de PDF (3 cenários, OCR e parsers)."""
from __future__ import annotations

from unittest.mock import MagicMock, patch

import pymupdf
import pytest

import pdf_extraction
from pdf_extraction import (
    PdfExtractionError,
    extract_pdf_draft,
    parse_area_table,
    parse_br_number,
    parse_linear_dimensions,
    parse_recuos,
    parse_stamp_metadata,
)

REFERENCE_PAGE_TEXT = """
PROJETO ARQUITETÔNICO RESIDENCIAL UNIFAMILIAR
Lote 31 da Quadra 28 - Loteamento Jardim Botanico
Local: Rua Sandoval Wanderley, s/n, Estivas, Extremoz/RN
Proprietário: CARNEIRO E OLIVEIRA EMPREENDIMENTOS LTDA
CNPJ: 69.307.863/0001-02
Responsável Técnico: JOCSA RAMOS VARELA
CREA/RN: 2116022975
Data: outubro/26

COTAS DO TERRENO
10,00
20,00

QUADRO GERAL DE ÁREAS
LOTE: 200,00 m²
ÁREA CONSTRUÍDA: 49,96 m²
TAXA DE OCUPAÇÃO: 24,98%
COEFICIENTE DE APROVEITAMENTO: 0,24
ÁREA PERMEÁVEL: 112,46 m²
TAXA DE PERMEABILIDADE: 56,23%
ÁREA IMPERMEÁVEL: 37,58 m²

RECUOS
Recuo Frontal: 5,05 m
Recuo de Fundo: 5,94 m
Recuo Lateral Esquerdo: 1,43 m
Recuo Lateral Direito: 1,43 m
"""


def _create_text_pdf(path, pages: list[str]) -> str:
    doc = pymupdf.open()
    for page_text in pages:
        page = doc.new_page(width=595, height=842)
        y = 40
        for line in page_text.strip().splitlines():
            page.insert_text((36, y), line, fontsize=9)
            y += 14
    doc.save(path)
    doc.close()
    return str(path)


def test_parse_br_number_handles_brazilian_and_standard_formats():
    assert parse_br_number('200,00') == 200.0
    assert parse_br_number('49,96 m²') == 49.96
    assert parse_br_number('24,98%') == 24.98
    assert parse_br_number('1.234,56') == 1234.56
    assert parse_br_number('0,24') == 0.24
    assert parse_br_number('10.5') == 10.5
    assert parse_br_number('') is None
    assert parse_br_number('abc') is None


def test_extract_single_page_reference_pdf_matches_full_contract(tmp_path):
    pdf_path = _create_text_pdf(tmp_path / 'lote_31_q28.pdf', [REFERENCE_PAGE_TEXT])

    draft = extract_pdf_draft(pdf_path, filename='lote_31_q28.pdf')

    assert 'features' not in draft
    assert draft['sourceFormat'] == 'pdf'
    assert draft['sourceFiles'] == [
        {'filename': 'lote_31_q28.pdf', 'pageCount': 1, 'status': 'processado'}
    ]

    loteamento = draft['loteamento']
    assert loteamento['name'] == 'Loteamento Jardim Botanico'
    assert loteamento['bairro'] == 'Estivas'
    assert loteamento['cidade'] == 'Extremoz'
    assert loteamento['uf'] == 'RN'
    assert loteamento['proprietarioNome'] == 'CARNEIRO E OLIVEIRA EMPREENDIMENTOS LTDA'
    assert loteamento['proprietarioDocumento'] == '69.307.863/0001-02'
    assert loteamento['responsavelTecnicoNome'] == 'JOCSA RAMOS VARELA'
    assert loteamento['responsavelTecnicoRegistro'] == '2116022975'

    assert len(draft['items']) == 1
    item = draft['items'][0]
    assert 'geometry' not in item
    assert item['quadra'] == 'Quadra 28'
    assert item['nome'] == 'Lote 31'
    assert item['frenteM'] == 10.0
    assert item['profundidadeM'] == 20.0
    assert item['areaTerrenoM2'] == 200.0
    assert item['areaConstruidaM2'] == 49.96
    assert item['logradouro'] == 'Rua Sandoval Wanderley, s/n'
    assert item['taxaOcupacaoPercent'] == 24.98
    assert item['coeficienteAproveitamento'] == 0.24
    assert item['areaPermeavelM2'] == 112.46
    assert item['taxaPermeabilidadePercent'] == 56.23
    assert item['areaImpermeavelM2'] == 37.58
    assert item['recuoFrontalM'] == 5.05
    assert item['recuoFundoM'] == 5.94
    assert item['recuoLateralEsquerdoM'] == 1.43
    assert item['recuoLateralDireitoM'] == 1.43
    assert item['dataProjeto'] == 'outubro/26'
    assert item['sourceFile'] == 'lote_31_q28.pdf'
    assert item['sourcePage'] == 1
    assert item['status'] == 'valido'


def test_extract_multipage_pdf_aggregates_all_pages_into_items(tmp_path):
    page1 = REFERENCE_PAGE_TEXT
    page2 = REFERENCE_PAGE_TEXT.replace('Lote 31', 'Lote 32').replace('49,96 m²', '55,10 m²')
    page3 = REFERENCE_PAGE_TEXT.replace('Lote 31', 'Lote 33').replace('Quadra 28', 'Quadra 29')
    pdf_path = _create_text_pdf(tmp_path / 'pranchas_loteamento.pdf', [page1, page2, page3])

    draft = extract_pdf_draft(pdf_path, filename='pranchas_loteamento.pdf')

    assert draft['sourceFiles'] == [
        {'filename': 'pranchas_loteamento.pdf', 'pageCount': 3, 'status': 'processado'}
    ]
    assert len(draft['items']) == 3
    assert [i['nome'] for i in draft['items']] == ['Lote 31', 'Lote 32', 'Lote 33']
    assert [i['quadra'] for i in draft['items']] == ['Quadra 28', 'Quadra 28', 'Quadra 29']
    assert [i['sourcePage'] for i in draft['items']] == [1, 2, 3]
    assert draft['items'][1]['areaConstruidaM2'] == 55.10
    assert draft['loteamento']['name'] == 'Loteamento Jardim Botanico'


def test_ocr_fallback_runs_when_vector_text_is_empty(tmp_path, monkeypatch):
    pdf_path = tmp_path / 'scanned.pdf'
    doc = pymupdf.open()
    page = doc.new_page(width=400, height=400)
    page.draw_rect(pymupdf.Rect(10, 10, 100, 100))
    doc.save(pdf_path)
    doc.close()

    monkeypatch.setattr(pdf_extraction, '_ocr_disabled', False)
    fake_ocr = MagicMock()
    fake_ocr.TesseractError = RuntimeError
    fake_ocr.TesseractNotFoundError = FileNotFoundError
    fake_ocr.image_to_string.return_value = REFERENCE_PAGE_TEXT

    with patch('pdf_extraction._load_ocr_modules', return_value=(fake_ocr, None, None)):
        draft = extract_pdf_draft(str(pdf_path), filename='scanned.pdf')

    fake_ocr.image_to_string.assert_called_once()
    assert len(draft['items']) == 1
    assert draft['items'][0]['nome'] == 'Lote 31'
    assert draft['items'][0]['areaTerrenoM2'] == 200.0


def test_parse_linear_dimensions_tolerance_and_null_fallback():
    # Dentro de 1% de tolerância: 10.05 * 20.0 = 201.0 (erro 0.5% <= 1%)
    frente, prof = parse_linear_dimensions('Cotas: 10,05 e 20,00', 200.0)
    assert (frente, prof) == (10.05, 20.0)

    # Fora de 1% de tolerância: 11 * 20 = 220 (erro 10% > 1%) -> mantém nulos
    frente, prof = parse_linear_dimensions('Cotas: 11,00 e 20,00', 200.0)
    assert (frente, prof) == (None, None)

    # Sem cotas, apenas areaTerrenoM2 -> mantém nulos para revisão opcional
    frente, prof = parse_linear_dimensions('LOTE: 200,00 m²', 200.0)
    assert (frente, prof) == (None, None)


def test_parse_stamp_metadata_handles_inverted_and_abbreviated_patterns():
    meta = parse_stamp_metadata('Q-14, Lt 07 - Loteamento Parque Verde, Natal/RN\nCPF: 123.456.789-00')
    assert meta['quadra'] == 'Quadra 14'
    assert meta['nome'] == 'Lote 07'
    assert meta['loteamentoName'] == 'Loteamento Parque Verde'
    assert meta['cidade'] == 'Natal'
    assert meta['uf'] == 'RN'
    assert meta['proprietarioDocumento'] == '123.456.789-00'


def test_parse_area_table_and_recuos_multiline():
    text = """
    ÁREA DO TERRENO
    250,50 m²
    ÁREA CONSTRUÍDA
    82,40 m²
    Recuos Laterais: 1,50 m
    """
    areas = parse_area_table(text)
    recuos = parse_recuos(text)
    assert areas['areaTerrenoM2'] == 250.5
    assert areas['areaConstruidaM2'] == 82.4
    assert recuos['recuoLateralEsquerdoM'] == 1.5
    assert recuos['recuoLateralDireitoM'] == 1.5


def test_rejects_corrupted_empty_and_blank_pdfs(tmp_path, monkeypatch):
    invalid_pdf = tmp_path / 'invalid.pdf'
    invalid_pdf.write_text('not a PDF')
    with pytest.raises(PdfExtractionError, match='PDF inválido'):
        extract_pdf_draft(str(invalid_pdf))

    empty_pdf = tmp_path / 'empty.pdf'
    empty_pdf.write_bytes(b'')
    with pytest.raises(PdfExtractionError, match='vazio'):
        extract_pdf_draft(str(empty_pdf))

    blank_pdf = tmp_path / 'blank.pdf'
    doc = pymupdf.open()
    doc.new_page()
    doc.save(blank_pdf)
    doc.close()
    monkeypatch.setattr(pdf_extraction, '_ocr_disabled', True)
    with pytest.raises(PdfExtractionError, match='Nenhum dado cadastral'):
        extract_pdf_draft(str(blank_pdf))
