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

    # INVALID_FILE (non-DXF) is signalled as None, not as an empty extraction
    assert extract_dxf_geometries(str(filepath)) is None

def test_extract_dxf_geometries_invalid_structure(tmp_path):
    filepath = tmp_path / "invalid_structure.dxf"
    with open(filepath, "w") as f:
        # Valid DXF header but no EOF -> ezdxf raises DXFStructureError (ezdxf.DXFError)
        f.write("0\nSECTION\n2\nHEADER\n0\nENDSEC\n")

    assert extract_dxf_geometries(str(filepath)) is None

def test_extract_dxf_geometries_ioerror(tmp_path):
    filepath = tmp_path / "nonexistent.dxf"
    # Deterministic IO failure is treated as an invalid file (None), not retried
    assert extract_dxf_geometries(str(filepath)) is None

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
@patch("main.save_draft_to_firestore")
def test_processar_dxf_valid(mock_save_draft, mock_storage_client, synthetic_dxf):
    event = MockCloudEvent(MockStorageObjectData(name="loteamentos_drafts_uploads/user/123_file.dxf"))

    mock_bucket = MagicMock()
    mock_blob = MagicMock()
    mock_storage_client.return_value.bucket.return_value = mock_bucket
    mock_bucket.blob.return_value = mock_blob

    def mock_download(filename, **kwargs):
        import shutil
        shutil.copy(synthetic_dxf, filename)

    mock_blob.download_to_filename.side_effect = mock_download

    processar_dxf(event)

    mock_storage_client.return_value.bucket.assert_called_with("sigo-86dd9.appspot.com")
    mock_bucket.blob.assert_called_once_with(
        "loteamentos_drafts_uploads/user/123_file.dxf", generation="12345"
    )
    mock_blob.download_to_filename.assert_called_once()
    
    mock_save_draft.assert_called_once()
    args, _ = mock_save_draft.call_args
    assert args[0] == "user/123_file.dxf"  # draft_id
    
    geojson = args[1]
    assert geojson["type"] == "FeatureCollection"
    # synthetic_dxf tem 2 lotes e 1 texto "Texto Lote" e 1 quadra
    assert len(geojson["features"]) == 2

    # Assert cleanup
    downloaded_path = mock_blob.download_to_filename.call_args[0][0]
    assert not os.path.exists(downloaded_path)

@patch("main.save_draft_to_firestore")
@patch("main.storage.Client")
def test_processar_dxf_swallows_persistence_error(mock_storage_client, mock_save_draft, synthetic_dxf):
    from firestore_utils import DraftPersistenceError
    event = MockCloudEvent(MockStorageObjectData(name="loteamentos_drafts_uploads/user/123_file.dxf"))

    mock_bucket = MagicMock()
    mock_blob = MagicMock()
    mock_storage_client.return_value.bucket.return_value = mock_bucket
    mock_bucket.blob.return_value = mock_blob

    def mock_download(filename, **kwargs):
        import shutil
        shutil.copy(synthetic_dxf, filename)

    mock_blob.download_to_filename.side_effect = mock_download
    mock_save_draft.side_effect = DraftPersistenceError("Poison message")

    # Should NOT raise, the error is swallowed
    processar_dxf(event)
    mock_save_draft.assert_called_once()

@patch("main.storage.Client")
@patch("main.extract_dxf_geometries")
def test_processar_dxf_download_failure_cleans_temp(mock_extract, mock_storage_client):
    event = MockCloudEvent(MockStorageObjectData(name="loteamentos_drafts_uploads/user/123_file.dxf"))

    mock_bucket = MagicMock()
    mock_blob = MagicMock()
    mock_blob.download_to_filename.side_effect = OSError("network down")
    mock_storage_client.return_value.bucket.return_value = mock_bucket
    mock_bucket.blob.return_value = mock_blob

    with pytest.raises(OSError):
        processar_dxf(event)

    downloaded_path = mock_blob.download_to_filename.call_args[0][0]
    assert not os.path.exists(downloaded_path)
    mock_extract.assert_not_called()

@patch("main.storage.Client")
@patch("main.extract_dxf_geometries")
def test_processar_dxf_unexpected_error_propagates_and_cleans_temp(mock_extract, mock_storage_client):
    event = MockCloudEvent(MockStorageObjectData(name="loteamentos_drafts_uploads/user/123_file.dxf"))

    mock_bucket = MagicMock()
    mock_blob = MagicMock()
    mock_extract.side_effect = RuntimeError("boom")
    mock_storage_client.return_value.bucket.return_value = mock_bucket
    mock_bucket.blob.return_value = mock_blob

    with pytest.raises(RuntimeError):
        processar_dxf(event)

    downloaded_path = mock_blob.download_to_filename.call_args[0][0]
    assert not os.path.exists(downloaded_path)

@patch("main.storage.Client")
@patch("main.extract_dxf_geometries")
def test_processar_dxf_size_at_limit_is_accepted(mock_extract, mock_storage_client):
    event = MockCloudEvent(MockStorageObjectData(
        name="loteamentos_drafts_uploads/user/123_file.dxf",
        size=str(50 * 1024 * 1024),
    ))
    mock_storage_client.return_value.bucket.return_value = MagicMock()
    mock_storage_client.return_value.bucket.return_value.blob.return_value = MagicMock()
    mock_extract.return_value = ([], [], [])

    processar_dxf(event)
    mock_storage_client.assert_called_once()

@patch("main.storage.Client")
@patch("main.extract_dxf_geometries")
def test_processar_dxf_uppercase_extension_is_accepted(mock_extract, mock_storage_client):
    event = MockCloudEvent(MockStorageObjectData(
        name="loteamentos_drafts_uploads/user/123_file.DXF"))
    mock_storage_client.return_value.bucket.return_value = MagicMock()
    mock_storage_client.return_value.bucket.return_value.blob.return_value = MagicMock()
    mock_extract.return_value = ([], [], [])

    processar_dxf(event)
    mock_storage_client.assert_called_once()

@patch("main.storage.Client")
@patch("main.extract_dxf_geometries")
def test_processar_dxf_invalid_file_does_not_raise(mock_extract, mock_storage_client, caplog):
    event = MockCloudEvent(MockStorageObjectData(name="loteamentos_drafts_uploads/user/123_file.dxf"))
    mock_storage_client.return_value.bucket.return_value = MagicMock()
    mock_storage_client.return_value.bucket.return_value.blob.return_value = MagicMock()
    mock_extract.return_value = None

    with caplog.at_level("ERROR"):
        processar_dxf(event)

    assert "INVALID_FILE" in caplog.text

@patch("main.storage.Client")
@patch("main.extract_dxf_geometries")
def test_processar_dxf_no_entities_logs_warning(mock_extract, mock_storage_client, caplog):
    event = MockCloudEvent(MockStorageObjectData(name="loteamentos_drafts_uploads/user/123_file.dxf"))
    mock_storage_client.return_value.bucket.return_value = MagicMock()
    mock_storage_client.return_value.bucket.return_value.blob.return_value = MagicMock()
    mock_extract.return_value = ([], [], [])

    with caplog.at_level("WARNING"):
        processar_dxf(event)

    assert "NO_ENTITIES" in caplog.text

@patch("main.storage.Client")
def test_processar_dxf_missing_name(mock_storage_client):
    event = MockCloudEvent(MockStorageObjectData(name=None))
    processar_dxf(event)
    mock_storage_client.assert_not_called()

@patch("main.storage.Client")
def test_processar_dxf_missing_bucket(mock_storage_client):
    event = MockCloudEvent(MockStorageObjectData(
        name="loteamentos_drafts_uploads/user/123_file.dxf", bucket=None))
    processar_dxf(event)
    mock_storage_client.assert_not_called()

@patch("main.storage.Client")
def test_processar_dxf_missing_size(mock_storage_client):
    event = MockCloudEvent(MockStorageObjectData(
        name="loteamentos_drafts_uploads/user/123_file.dxf", size=None))
    processar_dxf(event)
    mock_storage_client.assert_not_called()

@patch("main.storage.Client")
def test_processar_dxf_invalid_size(mock_storage_client):
    event = MockCloudEvent(MockStorageObjectData(
        name="loteamentos_drafts_uploads/user/123_file.dxf", size="not-a-number"))
    processar_dxf(event)
    mock_storage_client.assert_not_called()

@patch("main.storage.Client")
def test_processar_dxf_missing_generation(mock_storage_client):
    event = MockCloudEvent(MockStorageObjectData(
        name="loteamentos_drafts_uploads/user/123_file.dxf", generation=None))
    processar_dxf(event)
    mock_storage_client.assert_not_called()

def test_extract_dxf_geometries_no_entities(tmp_path):
    doc = ezdxf.new()
    msp = doc.modelspace()
    doc.layers.add("RUAS")
    msp.add_lwpolyline([(0, 0), (5, 0), (5, 5), (0, 5)], dxfattribs={"layer": "RUAS"})

    filepath = tmp_path / "no_entities.dxf"
    doc.saveas(filepath)

    lotes, quadras, textos = extract_dxf_geometries(str(filepath))
    assert lotes == []
    assert quadras == []
    assert textos == []

def test_extract_dxf_geometries_combined_layer(tmp_path):
    doc = ezdxf.new()
    msp = doc.modelspace()
    doc.layers.add("LOTE_E_QUADRA")
    msp.add_lwpolyline([(0, 0), (10, 0), (10, 10), (0, 10)], dxfattribs={"layer": "LOTE_E_QUADRA"})

    filepath = tmp_path / "combined.dxf"
    doc.saveas(filepath)

    lotes, quadras, textos = extract_dxf_geometries(str(filepath))
    assert len(lotes) == 1
    assert len(quadras) == 1

def test_extract_dxf_geometries_nested_insert_layer0(tmp_path):
    doc = ezdxf.new()
    msp = doc.modelspace()
    doc.layers.add("LOTES")

    inner = doc.blocks.new(name="InnerBlock")
    inner.add_lwpolyline([(0, 0), (1, 0), (1, 1), (0, 1)], dxfattribs={"layer": "0"})

    outer = doc.blocks.new(name="OuterBlock")
    outer.add_blockref("InnerBlock", (0, 0), dxfattribs={"layer": "0"})

    msp.add_blockref("OuterBlock", (0, 0), dxfattribs={"layer": "LOTES"})

    filepath = tmp_path / "nested.dxf"
    doc.saveas(filepath)

    lotes, quadras, textos = extract_dxf_geometries(str(filepath))
    assert len(lotes) == 1
    assert quadras == []
    assert textos == []

def test_extract_dxf_geometries_nested_insert_byblock(tmp_path):
    doc = ezdxf.new()
    msp = doc.modelspace()
    doc.layers.add("LOTES")

    inner = doc.blocks.new(name="InnerBlock")
    inner.add_lwpolyline([(0, 0), (1, 0), (1, 1), (0, 1)], dxfattribs={"layer": "0"})

    outer = doc.blocks.new(name="OuterBlock")
    outer.add_blockref("InnerBlock", (0, 0), dxfattribs={"layer": "BYBLOCK"})

    msp.add_blockref("OuterBlock", (0, 0), dxfattribs={"layer": "LOTES"})

    filepath = tmp_path / "byblock.dxf"
    doc.saveas(filepath)

    lotes, quadras, textos = extract_dxf_geometries(str(filepath))
    assert len(lotes) == 1

def test_extract_dxf_geometries_nested_insert_without_parent_layer(tmp_path):
    doc = ezdxf.new()
    msp = doc.modelspace()

    inner = doc.blocks.new(name="InnerBlock")
    inner.add_lwpolyline([(0, 0), (1, 0), (1, 1), (0, 1)], dxfattribs={"layer": "0"})

    outer = doc.blocks.new(name="OuterBlock")
    outer.add_blockref("InnerBlock", (0, 0), dxfattribs={"layer": "0"})

    msp.add_blockref("OuterBlock", (0, 0), dxfattribs={"layer": "0"})

    filepath = tmp_path / "no_parent.dxf"
    doc.saveas(filepath)

    lotes, quadras, textos = extract_dxf_geometries(str(filepath))
    assert lotes == []
    assert quadras == []
