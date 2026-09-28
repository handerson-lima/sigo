import cv2
import json
import numpy as np
import pymupdf
import pytest

from pdf_extraction import PdfExtractionError, _enclosed_lot_polygons, extract_pdf_geojson


def test_extracts_enclosed_cells_as_ambiguous_pdf_lotes():
    image = np.full((800, 800, 3), 255, dtype=np.uint8)
    cv2.rectangle(image, (180, 300), (240, 360), (0, 0, 0), 2)
    cv2.rectangle(image, (250, 300), (310, 360), (0, 0, 0), 2)

    polygons = _enclosed_lot_polygons(image)

    assert len(polygons) == 2
    assert all(polygon[0] == polygon[-1] for polygon in polygons)


def test_rejects_corrupted_pdf(tmp_path):
    invalid_pdf = tmp_path / 'invalid.pdf'
    invalid_pdf.write_text('not a PDF')

    with pytest.raises(PdfExtractionError, match='PDF inválido'):
        extract_pdf_geojson(str(invalid_pdf))


def test_extracts_vector_rectangles_as_ambiguous_lotes(tmp_path):
    pdf_path = tmp_path / 'vector.pdf'
    document = pymupdf.open()
    page = document.new_page()
    page.draw_rect(pymupdf.Rect(20, 20, 50, 50))
    page.draw_rect(pymupdf.Rect(60, 20, 90, 50))
    document.save(pdf_path)
    document.close()

    geojson = extract_pdf_geojson(str(pdf_path))

    assert len(geojson['features']) == 2
    assert all(feature['properties']['status'] == 'ambiguo' for feature in geojson['features'])
    assert json.loads(geojson['features'][0]['geometry'])['type'] == 'Polygon'


def test_rejects_pdf_image_without_enclosed_lots(tmp_path):
    pdf_path = tmp_path / 'blank-image.pdf'
    image = np.full((800, 800, 3), 255, dtype=np.uint8)
    _, encoded = cv2.imencode('.png', image)
    document = pymupdf.open()
    page = document.new_page()
    page.insert_image(page.rect, stream=encoded.tobytes())
    document.save(pdf_path)
    document.close()

    with pytest.raises(PdfExtractionError, match='Nenhum contorno'):
        extract_pdf_geojson(str(pdf_path))
