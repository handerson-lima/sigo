"""Extração experimental de plantas de loteamento presentes em PDFs rasterizados."""

from __future__ import annotations

import logging
import os
import re
import json
from typing import Any

cv2 = None
np = None
pymupdf = None
pytesseract = None

logger = logging.getLogger(__name__)
_ocr_disabled = False


def _load_vision_modules():
    """Adia imports pesados para não estourar o timeout de discovery do Firebase."""
    global cv2, np, pymupdf
    if cv2 is None:
        import cv2 as cv2_module
        import numpy as numpy_module
        import pymupdf as pymupdf_module
        cv2, np, pymupdf = cv2_module, numpy_module, pymupdf_module
    return cv2, np, pymupdf


def _load_ocr_module():
    global pytesseract
    if pytesseract is None:
        try:
            import pytesseract as pytesseract_module
        except ImportError:
            return None
        pytesseract = pytesseract_module
    return pytesseract


class PdfExtractionError(ValueError):
    """O PDF não contém uma planta rasterizada utilizável."""


def _render_page_image(page: pymupdf.Page) -> np.ndarray:
    """Rasteriza a página inteira, inclusive paths sem imagem embutida."""
    cv2_module, np_module, _ = _load_vision_modules()
    pixmap = page.get_pixmap(matrix=pymupdf.Matrix(2, 2), alpha=False)
    decoded = cv2_module.imdecode(np_module.frombuffer(pixmap.tobytes('png'), dtype=np_module.uint8), cv2_module.IMREAD_COLOR)
    if decoded is None:
        raise PdfExtractionError('Não foi possível decodificar a imagem da planta.')
    return decoded


def _vector_polygons(page: pymupdf.Page) -> list[list[list[float]]]:
    """Converte retângulos vetoriais fechados em lotes revisáveis."""
    polygons: list[list[list[float]]] = []
    for drawing in page.get_drawings():
        for item in drawing['items']:
            if item[0] != 're':
                continue
            rect = item[1]
            if rect.width < 2 or rect.height < 2:
                continue
            polygons.append([
                [float(rect.x0), float(rect.y0)],
                [float(rect.x1), float(rect.y0)],
                [float(rect.x1), float(rect.y1)],
                [float(rect.x0), float(rect.y1)],
                [float(rect.x0), float(rect.y0)],
            ])
    return polygons


def _line_mask(image: np.ndarray) -> np.ndarray:
    cv2_module, np_module, _ = _load_vision_modules()
    hsv = cv2_module.cvtColor(image, cv2_module.COLOR_BGR2HSV)
    gray = cv2_module.cvtColor(image, cv2_module.COLOR_BGR2GRAY)
    black = cv2_module.inRange(gray, 0, 100)
    green = cv2_module.inRange(hsv, np_module.array((35, 20, 80)), np_module.array((95, 255, 255)))
    return cv2_module.bitwise_or(black, green)


def _enclosed_lot_polygons(image: np.ndarray) -> list[list[list[float]]]:
    cv2_module, np_module, _ = _load_vision_modules()
    closed_lines = cv2_module.dilate(_line_mask(image), np_module.ones((2, 2), np_module.uint8))
    count, labels, stats, _ = cv2_module.connectedComponentsWithStats(cv2_module.bitwise_not(closed_lines))
    height, width = image.shape[:2]
    polygons: list[list[list[float]]] = []
    for label in range(1, count):
        x, y, cell_width, cell_height, area = stats[label]
        page_area = width * height
        if not (page_area * 0.00005 <= area <= page_area * 0.02
                and width * 0.003 <= cell_width <= width * 0.25
                and height * 0.003 <= cell_height <= height * 0.25
                and x > width * 0.02 and y > height * 0.02
                and x + cell_width < width * 0.98 and y + cell_height < height * 0.98):
            continue
        component = np_module.uint8(labels == label) * 255
        contours, _ = cv2_module.findContours(component, cv2_module.RETR_EXTERNAL, cv2_module.CHAIN_APPROX_SIMPLE)
        if not contours:
            continue
        contour = max(contours, key=cv2_module.contourArea)
        simplified = cv2_module.approxPolyDP(contour, max(1.0, 0.01 * cv2_module.arcLength(contour, True)), True)
        if len(simplified) < 3:
            continue
        points = [[float(point[0][0]), float(point[0][1])] for point in simplified]
        polygons.append(points + [points[0]])
    return polygons


def _ocr_lot_name(image: np.ndarray | None, polygon: list[list[float]]) -> str:
    global _ocr_disabled
    ocr = _load_ocr_module()
    if image is None or ocr is None or _ocr_disabled:
        return ''
    if command := os.getenv('TESSERACT_CMD'):
        ocr.pytesseract.tesseract_cmd = command
    xs, ys = [p[0] for p in polygon[:-1]], [p[1] for p in polygon[:-1]]
    crop = image[int(min(ys)):int(max(ys)) + 1, int(min(xs)):int(max(xs)) + 1]
    try:
        text = ocr.image_to_string(crop, config='--psm 7 -c tessedit_char_whitelist=0123456789')
    except (
        OSError,
        ocr.TesseractError,
        ocr.TesseractNotFoundError,
    ) as error:
        logger.info('OCR indisponível para PDF experimental: %s', error)
        _ocr_disabled = True
        return ''
    candidate = re.sub(r'\s+', '', text)
    return candidate if candidate.isdigit() else ''


def extract_pdf_geojson(filepath: str) -> dict[str, Any]:
    """Gera lotes revisáveis de um PDF rasterizado, sem inventar identificações."""
    _, _, fitz = _load_vision_modules()
    try:
        document = fitz.open(filepath)
    except (OSError, RuntimeError) as error:
        raise PdfExtractionError('PDF inválido ou corrompido.') from error
    try:
        if document.page_count != 1:
            raise PdfExtractionError('O PDF experimental deve conter exatamente uma página.')
        page = document[0]
        image = _render_page_image(page)
        polygons = _enclosed_lot_polygons(image) or _vector_polygons(page)
    finally:
        document.close()
    if not polygons:
        raise PdfExtractionError('Nenhum contorno de lote confiável foi encontrado no PDF.')
    return {
        'type': 'FeatureCollection',
        'features': [{
            'type': 'Feature',
            # Firestore não permite arrays diretamente aninhados. O canvas já
            # aceita o contrato GeoJSON serializado usado pelo importador DXF.
            'geometry': json.dumps({'type': 'Polygon', 'coordinates': [polygon]}),
            'properties': {
                'tipo': 'lote', 'nome': _ocr_lot_name(image, polygon),
                'status': 'ambiguo', 'quadra': '', 'origem': 'pdf_experimental',
            },
        } for polygon in polygons],
    }
