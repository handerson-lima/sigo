import cv2
import numpy as np
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
