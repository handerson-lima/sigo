"""Validação de pacotes DWF e adaptação da saída do conversor W2D para GeoJSON.

O formato W2D é proprietário. A conversão é delegada a uma ferramenta compatível
com Autodesk configurada por ``DWF_CONVERTER_COMMAND``. O comando recebe os
placeholders ``{input}`` e ``{output}`` e deve gravar um FeatureCollection GeoJSON.
"""
import json
import math
import os
import shlex
import subprocess
import tempfile
import zipfile
from xml.etree import ElementTree


MAX_DWF_UNCOMPRESSED_BYTES = 200 * 1024 * 1024
MAX_GEOJSON_OUTPUT_BYTES = 50 * 1024 * 1024


class DwfExtractionError(ValueError):
    """Falha determinística que deve deixar o rascunho em estado terminal."""


def _archive_member_exists(archive: zipfile.ZipFile, href: str) -> bool:
    """DWF manifests use Windows separators even when stored elsewhere."""
    wanted = href.replace('\\', '/').lstrip('./')
    return any(
        info.filename.replace('\\', '/').lstrip('./') == wanted and not info.is_dir()
        and info.file_size > 0
        for info in archive.infolist()
    )


def _has_w2d_section(archive: zipfile.ZipFile) -> bool:
    manifests = [name for name in archive.namelist() if name.lower().endswith('manifest.xml')]
    if not manifests:
        return False
    for manifest in manifests:
        try:
            root = ElementTree.fromstring(archive.read(manifest))
        except ElementTree.ParseError as error:
            raise DwfExtractionError('Manifesto DWF inválido.') from error
        for element in root.iter():
            attributes = {key.rsplit('}', 1)[-1].lower(): value for key, value in element.attrib.items()}
            if attributes.get('mime', '').lower() == 'application/x-w2d':
                href = attributes.get('href')
                if href and _archive_member_exists(archive, href):
                    return True
    return False


def validate_dwf_package(filepath: str) -> None:
    """Garante que o upload é um pacote DWF ZIP com uma seção vetorial W2D."""
    if not zipfile.is_zipfile(filepath):
        raise DwfExtractionError('O arquivo não é um pacote DWF válido.')
    try:
        with zipfile.ZipFile(filepath) as archive:
            if sum(info.file_size for info in archive.infolist()) > MAX_DWF_UNCOMPRESSED_BYTES:
                raise DwfExtractionError('O pacote DWF excede o limite descompactado permitido.')
            if not _has_w2d_section(archive):
                raise DwfExtractionError('O DWF não contém manifesto ou seção vetorial W2D.')
    except zipfile.BadZipFile as error:
        raise DwfExtractionError('O arquivo não é um pacote DWF válido.') from error


def extract_dwf_geojson(filepath: str) -> dict:
    """Converte um DWF validado em FeatureCollection via conversor configurado."""
    validate_dwf_package(filepath)
    command_template = os.environ.get('DWF_CONVERTER_COMMAND')
    if not command_template:
        raise DwfExtractionError('Conversor DWF/W2D compatível com Autodesk não configurado.')

    fd, output_path = tempfile.mkstemp(suffix='.geojson')
    os.close(fd)
    try:
        command = [part.format(input=filepath, output=output_path)
                   for part in shlex.split(command_template)]
        if not command:
            raise ValueError('comando vazio')
        completed = subprocess.run(
            command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120,
        )
        if completed.returncode != 0:
            raise DwfExtractionError('Conversor DWF/W2D falhou.')
        if os.path.getsize(output_path) > MAX_GEOJSON_OUTPUT_BYTES:
            raise DwfExtractionError('A saída do conversor DWF excede o limite permitido.')
        with open(output_path, encoding='utf-8') as output:
            geojson = json.load(output)
    except DwfExtractionError:
        raise
    except (KeyError, ValueError, OSError, subprocess.TimeoutExpired, json.JSONDecodeError) as error:
        raise DwfExtractionError(f'Não foi possível extrair a geometria DWF: {error}') from error
    finally:
        if os.path.exists(output_path):
            os.remove(output_path)

    features = geojson.get('features') if isinstance(geojson, dict) else None
    if not isinstance(geojson, dict) or geojson.get('type') != 'FeatureCollection' or not isinstance(features, list):
        raise DwfExtractionError('O DWF não possui contornos utilizáveis para loteamento.')
    polygon_types = {'Polygon', 'MultiPolygon'}
    classified_features = [
        feature for feature in features
        if isinstance(feature, dict)
        and isinstance(feature.get('properties'), dict)
        and feature['properties'].get('tipo') in {'lote', 'quadra'}
        and isinstance(feature.get('geometry'), dict)
        and feature['geometry'].get('type') in polygon_types
        and _valid_polygon_geometry(feature['geometry'])
    ]
    if not any(feature['properties']['tipo'] == 'lote' for feature in classified_features):
        raise DwfExtractionError('O DWF não possui contornos utilizáveis para loteamento.')
    if len(classified_features) != len(features):
        raise DwfExtractionError('O conversor DWF devolveu geometrias não classificáveis.')
    return geojson


def _valid_position(position) -> bool:
    return (
        isinstance(position, (list, tuple))
        and len(position) >= 2
        and all(isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)
                for value in position[:2])
    )


def _valid_ring(ring) -> bool:
    return (
        isinstance(ring, list)
        and len(ring) >= 4
        and all(_valid_position(position) for position in ring)
        and ring[0][:2] == ring[-1][:2]
    )


def _valid_polygon_geometry(geometry: dict) -> bool:
    coordinates = geometry.get('coordinates')
    if geometry.get('type') == 'Polygon':
        return isinstance(coordinates, list) and bool(coordinates) and all(_valid_ring(ring) for ring in coordinates)
    return (
        isinstance(coordinates, list)
        and bool(coordinates)
        and all(isinstance(polygon, list) and polygon and all(_valid_ring(ring) for ring in polygon)
                for polygon in coordinates)
    )
