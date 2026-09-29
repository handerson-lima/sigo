"""Validação de pacotes DWF e adaptação da saída do conversor W2D para GeoJSON.

O formato W2D é proprietário. A conversão é delegada a uma ferramenta compatível
com Autodesk configurada por ``DWF_CONVERTER_COMMAND``. O comando recebe os
placeholders ``{input}`` e ``{output}`` e deve gravar um FeatureCollection GeoJSON.
"""
import json
import os
import shlex
import subprocess
import tempfile
import zipfile
from xml.etree import ElementTree


class DwfExtractionError(ValueError):
    """Falha determinística que deve deixar o rascunho em estado terminal."""


def _has_w2d_section(archive: zipfile.ZipFile) -> bool:
    manifests = [name for name in archive.namelist() if name.lower().endswith('manifest.xml')]
    if not manifests:
        return False
    for manifest in manifests:
        try:
            root = ElementTree.fromstring(archive.read(manifest))
        except ElementTree.ParseError as error:
            raise DwfExtractionError('Manifesto DWF inválido.') from error
        if any('application/x-w2d' in (element.text or '').lower() or
               'application/x-w2d' in ' '.join(element.attrib.values()).lower()
               for element in root.iter()):
            return True
    return False


def validate_dwf_package(filepath: str) -> None:
    """Garante que o upload é um pacote DWF ZIP com uma seção vetorial W2D."""
    if not zipfile.is_zipfile(filepath):
        raise DwfExtractionError('O arquivo não é um pacote DWF válido.')
    try:
        with zipfile.ZipFile(filepath) as archive:
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
        completed = subprocess.run(command, capture_output=True, text=True, timeout=120)
        if completed.returncode != 0:
            raise DwfExtractionError('Conversor DWF/W2D falhou: ' +
                                     (completed.stderr.strip() or 'erro desconhecido.'))
        with open(output_path, encoding='utf-8') as output:
            geojson = json.load(output)
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError) as error:
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
    ]
    if not any(feature['properties']['tipo'] == 'lote' for feature in classified_features):
        raise DwfExtractionError('O DWF não possui contornos utilizáveis para loteamento.')
    if len(classified_features) != len(features):
        raise DwfExtractionError('O conversor DWF devolveu geometrias não classificáveis.')
    return geojson
