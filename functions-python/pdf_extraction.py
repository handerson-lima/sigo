"""Extração experimental de plantas de loteamento presentes em PDFs rasterizados."""

from __future__ import annotations

import logging
import os
import re
from typing import Any

import cv2
import numpy as np
import pymupdf

try:
    import pytesseract
except ImportError:  # pragma: no cover
    pytesseract = None

logger = logging.getLogger(__name__)


class PdfExtractionError(ValueError):
    """O PDF não contém uma planta rasterizada utilizável."""


def _decode_largest_page_image(page: pymupdf.Page) -> np.ndarray:
    images = page.get_images(full=True)
    if not images:
        raise PdfExtractionError('PDF sem imagem de planta para vetorização.')
    largest = max(images, key=lambda image: image[2] * image[3])
    image_data = page.parent.extract_image(largest[0])
    decoded = cv2.imdecode(np.frombuffer(image_data['image'], dtype=np.uint8), cv2.IMREAD_COLOR)
    if decoded is None:
        raise PdfExtractionError('Não foi possível decodificar a imagem da planta.')
    return decoded


def _line_mask(image: np.ndarray) -> np.ndarray:
    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    black = cv2.inRange(gray, 0, 100)
    green = cv2.inRange(hsv, np.array((35, 20, 80)), np.array((95, 255, 255)))
    return cv2.bitwise_or(black, green)


def _enclosed_lot_polygons(image: np.ndarray) -> list[list[list[float]]]:
    closed_lines = cv2.dilate(_line_mask(image), np.ones((2, 2), np.uint8))
    count, labels, stats, _ = cv2.connectedComponentsWithStats(cv2.bitwise_not(closed_lines))
    height, width = image.shape[:2]
    polygons: list[list[list[float]]] = []
    for label in range(1, count):
        x, y, cell_width, cell_height, area = stats[label]
        if not (1000 <= area <= 30000 and 8 <= cell_width <= 220 and 8 <= cell_height <= 220
                and x > 100 and y > 250 and x + cell_width < width - 100
                and y + cell_height < height - 300):
            continue
        component = np.uint8(labels == label) * 255
        contours, _ = cv2.findContours(component, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if not contours:
            continue
        contour = max(contours, key=cv2.contourArea)
        simplified = cv2.approxPolyDP(contour, max(1.0, 0.01 * cv2.arcLength(contour, True)), True)
        if len(simplified) < 3:
            continue
        points = [[float(point[0][0]), float(point[0][1])] for point in simplified]
        polygons.append(points + [points[0]])
    return polygons


def _ocr_lot_name(image: np.ndarray, polygon: list[list[float]]) -> str:
    if pytesseract is None:
        return ''
    if command := os.getenv('TESSERACT_CMD'):
        pytesseract.pytesseract.tesseract_cmd = command
    xs, ys = [p[0] for p in polygon[:-1]], [p[1] for p in polygon[:-1]]
    crop = image[int(min(ys)):int(max(ys)) + 1, int(min(xs)):int(max(xs)) + 1]
    try:
        text = pytesseract.image_to_string(crop, config='--psm 7 -c tessedit_char_whitelist=0123456789')
    except (OSError, pytesseract.TesseractNotFoundError) as error:
        logger.info('OCR indisponível para PDF experimental: %s', error)
        return ''
    candidate = re.sub(r'\s+', '', text)
    return candidate if candidate.isdigit() else ''


def extract_pdf_geojson(filepath: str) -> dict[str, Any]:
    """Gera lotes revisáveis de um PDF rasterizado, sem inventar identificações."""
    try:
        document = pymupdf.open(filepath)
    except (OSError, RuntimeError, pymupdf.FileDataError) as error:
        raise PdfExtractionError('PDF inválido ou corrompido.') from error
    try:
        if document.page_count != 1:
            raise PdfExtractionError('O PDF experimental deve conter exatamente uma página.')
        image = _decode_largest_page_image(document[0])
        polygons = _enclosed_lot_polygons(image)
    finally:
        document.close()
    if not polygons:
        raise PdfExtractionError('Nenhum contorno de lote confiável foi encontrado no PDF.')
    return {
        'type': 'FeatureCollection',
        'features': [{
            'type': 'Feature',
            'geometry': {'type': 'Polygon', 'coordinates': [polygon]},
            'properties': {
                'tipo': 'lote', 'nome': _ocr_lot_name(image, polygon),
                'status': 'ambiguo', 'quadra': '', 'origem': 'pdf_experimental',
            },
        } for polygon in polygons],
    }
