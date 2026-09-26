import os
import tempfile
import logging
import ezdxf
from google.cloud import storage
from firebase_functions import storage_fn, options
from firebase_admin import initialize_app

initialize_app()
logger = logging.getLogger(__name__)

# Max file size: 50MB
MAX_FILE_SIZE_BYTES = 50 * 1024 * 1024

def extract_dxf_geometries(filepath: str):
    """
    Reads DXF and extracts Lotes, Quadras, and Texts from modelspace and blocks (INSERTs).
    """
    try:
        doc = ezdxf.readfile(filepath)
    except Exception as e:
        # ezdxf exceptions are broad, catch Exception and check if it's DXFStructureError etc
        # But we log and raise to not swallow silently if it's transient, actually if it's a corrupted file we should return empty
        # If it's IOError we might raise it
        if isinstance(e, (IOError, OSError)):
            # If it's not a DXF file (e.g. text file), ezdxf raises IOError/OSError
            logger.error(f"Corrupted or invalid DXF file (IOError): {e}")
            return [], [], []
        logger.error(f"Corrupted or invalid DXF file: {e}")
        return [], [], []

    msp = doc.modelspace()
    lotes = []
    quadras = []
    textos = []

    def process_entity(entity, parent_layer=None):
        layer_name = ""
        try:
            layer_name = str(entity.dxf.layer).upper()
        except AttributeError:
            pass

        # Se a entidade for layer 0 ou faltante, e estiver dentro de um bloco, ELA HERDA a cor/layer do bloco pai (se não explicitamente forçado no BYBLOCK)
        # Na verdade, em ezdxf, entidades no bloco com layer '0' devem assumir o layer da referência (INSERT)
        if (not layer_name or layer_name == "0" or layer_name == "BYBLOCK") and parent_layer:
            layer_name = parent_layer

        layer_clean = layer_name.replace('_', ' ').replace('-', ' ')
        tokens = layer_clean.split()
        
        # Match flexível para incluir plurais
        is_lote = any(tok in ("LOTE", "LOTES") for tok in tokens)
        is_quadra = any(tok in ("QUADRA", "QUADRAS") for tok in tokens)
        
        etype = entity.dxftype()
        if etype in ('TEXT', 'MTEXT', 'ATTRIB', 'ATTDEF'):
            textos.append(entity)
        else:
            if not (is_lote or is_quadra):
                return
            if is_lote:
                lotes.append(entity)
            if is_quadra:
                quadras.append(entity)

    def explode_and_process(entity, parent_layer=None):
        if entity.dxftype() == 'INSERT':
            # Herda layer do INSERT
            try:
                layer_to_pass = str(entity.dxf.layer).upper()
            except AttributeError:
                layer_to_pass = parent_layer
                
            try:
                for v_entity in entity.virtual_entities():
                    explode_and_process(v_entity, parent_layer=layer_to_pass)
            except Exception as e:
                logger.warning(f"Failed to explode INSERT: {e}")
        else:
            process_entity(entity, parent_layer)

    for entity in msp:
        explode_and_process(entity)

    return lotes, quadras, textos


@storage_fn.on_object_finalized(
    region="us-central1",
    memory=options.MemoryOption.MB_512
)
def processar_dxf(event: storage_fn.CloudEvent[storage_fn.StorageObjectData]):
    """
    Background Cloud Function to be triggered by Cloud Storage.
    Path expected: loteamentos_drafts_uploads/{userId}/{timestamp}_{filename}.dxf
    """
    file_data = event.data
    print(f"DEBUG: Processing {getattr(file_data, 'name', 'NO_NAME')}")

    if not file_data.name:
        return
        
    if not file_data.bucket:
        print("DEBUG: no bucket")
        return

    # Filter route
    if not file_data.name.startswith("loteamentos_drafts_uploads/"):
        logger.info(f"Ignoring file outside loteamentos_drafts_uploads: {file_data.name}")
        return

    if not file_data.name.lower().endswith('.dxf'):
        logger.info(f"Ignoring non-dxf file: {file_data.name}")
        return

    # Size check
    if file_data.size:
        try:
            size_int = int(file_data.size)
            if size_int > MAX_FILE_SIZE_BYTES:
                logger.error(f"File {file_data.name} is too large: {size_int} bytes.")
                return
        except ValueError:
            logger.error(f"Invalid file size format: {file_data.size}")
            return
    else:
        print("DEBUG: no size")
        logger.error(f"File {file_data.name} has no size specified.")
        return

    print("DEBUG: passed all checks, calling storage.Client")

    storage_client = storage.Client()
    bucket = storage_client.bucket(file_data.bucket)
    blob = bucket.blob(file_data.name, generation=file_data.generation)

    fd, temp_local_filename = tempfile.mkstemp(suffix=".dxf")
    try:
        blob.download_to_filename(temp_local_filename)
        logger.info(f"Downloaded {file_data.name} to {temp_local_filename}")

        lotes, quadras, textos = extract_dxf_geometries(temp_local_filename)
        
        if not lotes and not quadras:
            logger.warning(f"File {file_data.name} contained no Lote or Quadra entities.")
        else:
            logger.info(f"Extracted {len(lotes)} lotes, {len(quadras)} quadras and {len(textos)} textos.")
            
    except (IOError, OSError) as e:
        logger.error(f"Transient error processing {file_data.name}: {e}")
        raise
    except Exception as e:
        logger.error(f"Unhandled error processing {file_data.name}: {e}")
        raise
    finally:
        os.close(fd)
        if os.path.exists(temp_local_filename):
            try:
                os.remove(temp_local_filename)
            except OSError as e:
                logger.warning(f"Failed to remove temp file {temp_local_filename}: {e}")
