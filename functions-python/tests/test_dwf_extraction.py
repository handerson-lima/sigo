import json
import zipfile
from types import SimpleNamespace

import pytest

from dwf_extraction import DwfExtractionError, extract_dwf_geojson, validate_dwf_package


def _dwf_with_w2d(tmp_path):
    dwf = tmp_path / 'valid.dwf'
    with zipfile.ZipFile(dwf, 'w') as archive:
        archive.writestr('manifest.xml', '<Manifest mime="application/x-w2d"/>')
    return dwf


def test_validate_dwf_package_requires_manifest_and_w2d(tmp_path):
    invalid = tmp_path / 'invalid.dwf'
    invalid.write_bytes(b'not-a-zip')
    with pytest.raises(DwfExtractionError, match='pacote DWF'):
        validate_dwf_package(invalid)

    without_w2d = tmp_path / 'without-w2d.dwf'
    with zipfile.ZipFile(without_w2d, 'w') as archive:
        archive.writestr('manifest.xml', '<Manifest/>')
    with pytest.raises(DwfExtractionError, match='W2D'):
        validate_dwf_package(without_w2d)


def test_validate_dwf_package_accepts_manifest_with_w2d(tmp_path):
    validate_dwf_package(_dwf_with_w2d(tmp_path))


def test_extract_dwf_geojson_requires_classified_polygon_lotes(tmp_path, monkeypatch):
    def converter(command, **_):
        output_path = command[command.index('--output') + 1]
        with open(output_path, 'w', encoding='utf-8') as output:
            json.dump({
                'type': 'FeatureCollection',
                'features': [{
                    'type': 'Feature',
                    'properties': {'tipo': 'lote', 'nome': '01'},
                    'geometry': {'type': 'Polygon', 'coordinates': []},
                }],
            }, output)
        return SimpleNamespace(returncode=0, stderr='')

    monkeypatch.setenv('DWF_CONVERTER_COMMAND', 'converter --input {input} --output {output}')
    monkeypatch.setattr('dwf_extraction.subprocess.run', converter)
    assert extract_dwf_geojson(_dwf_with_w2d(tmp_path))['features'][0]['properties']['tipo'] == 'lote'


def test_extract_dwf_geojson_rejects_unclassified_features(tmp_path, monkeypatch):
    def converter(command, **_):
        output_path = command[command.index('--output') + 1]
        with open(output_path, 'w', encoding='utf-8') as output:
            json.dump({'type': 'FeatureCollection', 'features': [{'type': 'Feature'}]}, output)
        return SimpleNamespace(returncode=0, stderr='')

    monkeypatch.setenv('DWF_CONVERTER_COMMAND', 'converter --input {input} --output {output}')
    monkeypatch.setattr('dwf_extraction.subprocess.run', converter)
    with pytest.raises(DwfExtractionError, match='contornos utilizáveis'):
        extract_dwf_geojson(_dwf_with_w2d(tmp_path))


def test_extract_dwf_geojson_rejects_non_object_converter_output(tmp_path, monkeypatch):
    def converter(command, **_):
        output_path = command[command.index('--output') + 1]
        with open(output_path, 'w', encoding='utf-8') as output:
            json.dump([], output)
        return SimpleNamespace(returncode=0, stderr='')

    monkeypatch.setenv('DWF_CONVERTER_COMMAND', 'converter --input {input} --output {output}')
    monkeypatch.setattr('dwf_extraction.subprocess.run', converter)
    with pytest.raises(DwfExtractionError, match='contornos utilizáveis'):
        extract_dwf_geojson(_dwf_with_w2d(tmp_path))
