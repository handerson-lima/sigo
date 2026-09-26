import pytest
import ezdxf
import os
from unittest.mock import patch, MagicMock

# The conftest.py already sets up the sys.path, so we can import directly
from main import extract_dxf_geometries, processar_dxf

class MockCloudEvent:
    def __init__(self, data):
        self.data = data

class MockStorageObjectData:
    def __init__(self, name, bucket="sigo-86dd9.appspot.com", size="1024", generation="12345"):
        self.name = name
        self.bucket = bucket
        self.size = size
        self.generation = generation

@pytest.fixture
def synthetic_dxf(tmp_path):
    doc = ezdxf.new()
    msp = doc.modelspace()
    doc.layers.add("LOTES")
    doc.layers.add("QUADRAS")
    doc.layers.add("OUTRO")
    
    # Lote no plural (testando token flexível)
    msp.add_lwpolyline([(0, 0), (10, 0), (10, 10), (0, 10)], dxfattribs={"layer": "LOTES"})
    # Quadra
    msp.add_lwpolyline([(0, 0), (20, 0), (20, 20), (0, 20)], dxfattribs={"layer": "QUADRA"})
    # Text
    msp.add_text("Texto Lote", dxfattribs={"layer": "LOTES"})
    
    # Block INSERT with Layer 0 inside
    block = doc.blocks.new(name="MeuBlocoLote")
    block.add_lwpolyline([(5, 5), (15, 5), (15, 15), (5, 15)], dxfattribs={"layer": "0"})
    msp.add_blockref("MeuBlocoLote", (0, 0), dxfattribs={"layer": "LOTE 2"})

    filepath = tmp_path / "test.dxf"
    doc.saveas(filepath)
    return str(filepath)

def test_extract_dxf_geometries_happy_path(synthetic_dxf):
    lotes, quadras, textos = extract_dxf_geometries(synthetic_dxf)
    assert len(lotes) == 2  # modelspace (LOTES) + block (inherited LOTE 2)
    assert len(quadras) == 1 # modelspace (QUADRA)
    assert len(textos) == 1

def test_extract_dxf_geometries_corrupted(tmp_path):
    filepath = tmp_path / "corrupted.dxf"
    with open(filepath, "w") as f:
        f.write("I am not a dxf file")
    
    lotes, quadras, textos = extract_dxf_geometries(str(filepath))
    assert lotes == []
    assert quadras == []
    assert textos == []

def test_extract_dxf_geometries_ioerror(tmp_path):
    filepath = tmp_path / "nonexistent.dxf"
    # Should swallow and return empty for OS errors inside extract
    lotes, quadras, textos = extract_dxf_geometries(str(filepath))
    assert lotes == []

@patch("main.storage.Client")
def test_processar_dxf_filter_route(mock_storage_client):
    # Outside route
    event = MockCloudEvent(MockStorageObjectData(name="uploads/loteamentos/user/123_file.dxf"))
    processar_dxf(event)
    mock_storage_client.assert_not_called()

    # Non-dxf
    event = MockCloudEvent(MockStorageObjectData(name="loteamentos_drafts_uploads/user/123_file.png"))
    processar_dxf(event)
    mock_storage_client.assert_not_called()

@patch("main.storage.Client")
def test_processar_dxf_too_large(mock_storage_client):
    event = MockCloudEvent(MockStorageObjectData(
        name="loteamentos_drafts_uploads/user/123_file.dxf", 
        size=str(51 * 1024 * 1024)
    ))
    processar_dxf(event)
    mock_storage_client.assert_not_called()

@patch("main.storage.Client")
@patch("main.extract_dxf_geometries")
def test_processar_dxf_valid(mock_extract, mock_storage_client, synthetic_dxf):
    event = MockCloudEvent(MockStorageObjectData(name="loteamentos_drafts_uploads/user/123_file.dxf"))
    
    mock_bucket = MagicMock()
    mock_blob = MagicMock()
    mock_storage_client.return_value.bucket.return_value = mock_bucket
    mock_bucket.blob.return_value = mock_blob
    
    mock_extract.return_value = (["l1"], ["q1"], ["t1"])
    
    processar_dxf(event)
    
    mock_storage_client.return_value.bucket.assert_called_with("sigo-86dd9.appspot.com")
    mock_blob.download_to_filename.assert_called()
    mock_extract.assert_called_once()
