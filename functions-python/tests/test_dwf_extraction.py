import json
import zipfile
from types import SimpleNamespace

import pytest

from dwf_extraction import DwfExtractionError, extract_dwf_geojson, validate_dwf_package


def _dwf_with_w2d(tmp_path):
    dwf = tmp_path / 'valid.dwf'
    with zipfile.ZipFile(dwf, 'w') as archive:
        archive.writestr(
            'manifest.xml',
            '<Manifest><Resource mime="application/x-w2d" href="graphics/model.w2d"/></Manifest>',
        )
        archive.writestr('graphics/model.w2d', b'w2d')
    return dwf


def _valid_lote_feature():
    return {
        'type': 'Feature',
        'properties': {'tipo': 'lote', 'nome': '01'},
        'geometry': {
            'type': 'Polygon',
            'coordinates': [[[0, 0], [1, 0], [1, 1], [0, 0]]],
        },
    }


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


def test_validate_dwf_package_accepts_reference_dwf():
    validate_dwf_package('dwg_dxf/LOTEAMENTO_HR_R13A-Model.dwf')


def test_validate_dwf_package_rejects_manifest_without_w2d_resource(tmp_path):
    dwf = tmp_path / 'missing-resource.dwf'
    with zipfile.ZipFile(dwf, 'w') as archive:
        archive.writestr(
            'manifest.xml',
            '<Manifest><Resource mime="application/x-w2d" href="missing.w2d"/></Manifest>',
        )
    with pytest.raises(DwfExtractionError, match='W2D'):
        validate_dwf_package(dwf)


def test_validate_dwf_package_rejects_expansible_zip(tmp_path, monkeypatch):
    monkeypatch.setattr('dwf_extraction.MAX_DWF_UNCOMPRESSED_BYTES', 3)
    with pytest.raises(DwfExtractionError, match='descompactado'):
        validate_dwf_package(_dwf_with_w2d(tmp_path))


def test_extract_dwf_geojson_requires_classified_polygon_lotes(tmp_path, monkeypatch):
    def converter(command, **_):
        output_path = command[command.index('--output') + 1]
        with open(output_path, 'w', encoding='utf-8') as output:
            json.dump({
                'type': 'FeatureCollection',
                'features': [_valid_lote_feature()],
            }, output)
        return SimpleNamespace(returncode=0, stderr='')

    monkeypatch.setenv('DWF_CONVERTER_COMMAND', 'converter --input {input} --output {output}')
    monkeypatch.setattr('dwf_extraction.subprocess.run', converter)
    assert extract_dwf_geojson(_dwf_with_w2d(tmp_path))['features'][0]['properties']['tipo'] == 'lote'


def test_extract_dwf_geojson_rejects_invalid_polygon_geometry(tmp_path, monkeypatch):
    def converter(command, **_):
        output_path = command[command.index('--output') + 1]
        with open(output_path, 'w', encoding='utf-8') as output:
            json.dump({'type': 'FeatureCollection', 'features': [{
                **_valid_lote_feature(),
                'geometry': {'type': 'Polygon', 'coordinates': []},
            }]}, output)
        return SimpleNamespace(returncode=0)

    monkeypatch.setenv('DWF_CONVERTER_COMMAND', 'converter --input {input} --output {output}')
    monkeypatch.setattr('dwf_extraction.subprocess.run', converter)
    with pytest.raises(DwfExtractionError, match='contornos utilizáveis'):
        extract_dwf_geojson(_dwf_with_w2d(tmp_path))


def test_extract_dwf_geojson_rejects_invalid_converter_configuration(tmp_path, monkeypatch):
    monkeypatch.setenv('DWF_CONVERTER_COMMAND', 'converter --input {missing}')
    with pytest.raises(DwfExtractionError, match='Não foi possível extrair'):
        extract_dwf_geojson(_dwf_with_w2d(tmp_path))


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
