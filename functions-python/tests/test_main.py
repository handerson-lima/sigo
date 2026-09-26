import pytest
import os
import sys
import ezdxf
from unittest.mock import MagicMock, patch

# Mock firebase_functions and google.cloud.storage before importing main
class MockStorageFn:
    CloudEvent = dict
    StorageObjectData = dict
    def on_object_finalized(self, **kwargs):
        def decorator(func):
            return func
        return decorator

class MockFirebaseFunctions:
    storage_fn = MockStorageFn()
    options = MagicMock()

sys.modules['firebase_functions'] = MockFirebaseFunctions()
sys.modules['firebase_admin'] = MagicMock()
sys.modules['google.cloud'] = MagicMock()
sys.modules['google.cloud.storage'] = MagicMock()

from main import processar_dxf, extract_dxf_geometries

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
def mock_storage():
    with patch("main.storage.Client") as mock_client:
        yield mock_client

@pytest.fixture
def synthetic_dxf(tmp_path):
    doc = ezdxf.new()
    msp = doc.modelspace()
    doc.layers.add("LOTE_1")
    doc.layers.add("QUADRA_1")
    doc.layers.add("OUTRO")
    
    # Lote
    msp.add_lwpolyline([(0, 0), (10, 0), (10, 10), (0, 10)], dxfattribs={"layer": "LOTE_1"})
    # Quadra
    msp.add_lwpolyline([(0, 0), (20, 0), (20, 20), (0, 20)], dxfattribs={"layer": "QUADRA_1"})
    # Text
    msp.add_text("Texto Lote", dxfattribs={"layer": "LOTE_1"})
    
    # Block INSERT with Layer 0 inside
    block = doc.blocks.new(name="MeuBlocoLote")
    block.add_lwpolyline([(5, 5), (15, 5), (15, 15), (5, 15)], dxfattribs={"layer": "0"})
    msp.add_blockref("MeuBlocoLote", (0, 0), dxfattribs={"layer": "LOTE_2"})

    # Nested Block
    block_inner = doc.blocks.new(name="InnerBlock")
    block_inner.add_text("NestedText", dxfattribs={"layer": "BYBLOCK"})
    block.add_blockref("InnerBlock", (10, 10))

    filepath = tmp_path / "test.dxf"
    doc.saveas(filepath)
    return str(filepath)

def test_extract_dxf_geometries_happy_path(synthetic_dxf):
    lotes, quadras, textos = extract_dxf_geometries(synthetic_dxf)
    assert len(lotes) == 2  # one from modelspace, one from block insert (inherited layer LOTE_2)
    assert len(quadras) == 1 # one from modelspace
    assert len(textos) == 2 # one from modelspace, one from nested block

def test_extract_dxf_geometries_corrupted(tmp_path):
    filepath = tmp_path / "corrupted.dxf"
    with open(filepath, "w") as f:
        f.write("I am not a dxf file")
    
    lotes, quadras, textos = extract_dxf_geometries(str(filepath))
    assert lotes == []
    assert quadras == []
    assert textos == []

def test_extract_dxf_geometries_no_entities(tmp_path):
    doc = ezdxf.new()
    filepath = tmp_path / "empty.dxf"
    doc.saveas(filepath)
    
    lotes, quadras, textos = extract_dxf_geometries(str(filepath))
    assert lotes == []
    assert quadras == []
    assert textos == []

def test_processar_dxf_filter_route(mock_storage):
    # Outside route
    event = MockCloudEvent(MockStorageObjectData(name="uploads/loteamentos/user/123_file.dxf"))
    processar_dxf(event)
    mock_storage.assert_not_called()

    # Non-dxf
    event = MockCloudEvent(MockStorageObjectData(name="loteamentos_drafts_uploads/user/123_file.png"))
    processar_dxf(event)
    mock_storage.assert_not_called()

    # Empty name or bucket
    event = MockCloudEvent(MockStorageObjectData(name=None))
    processar_dxf(event)
    mock_storage.assert_not_called()

def test_processar_dxf_too_large(mock_storage):
    event = MockCloudEvent(MockStorageObjectData(
        name="loteamentos_drafts_uploads/user/123_file.dxf", 
        size=str(51 * 1024 * 1024)
    ))
    processar_dxf(event)
    mock_storage.assert_not_called()

def test_processar_dxf_valid(mock_storage, synthetic_dxf):
    event = MockCloudEvent(MockStorageObjectData(name="loteamentos_drafts_uploads/user/123_file.dxf"))
    
    mock_bucket = MagicMock()
    mock_blob = MagicMock()
    mock_storage.return_value.bucket.return_value = mock_bucket
    mock_bucket.blob.return_value = mock_blob
    
    # We mock download_to_filename to just leave the generated temp file empty,
    # but since our code actually tries to read it, we should mock the behavior of copying synthetic_dxf
    def fake_download(filename):
        import shutil
        shutil.copy(synthetic_dxf, filename)
    mock_blob.download_to_filename.side_effect = fake_download
    
    processar_dxf(event)
    
    mock_storage.return_value.bucket.assert_called_with("sigo-86dd9.appspot.com")
    mock_blob.download_to_filename.assert_called()
