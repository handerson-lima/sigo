import os
import re
import tempfile
import logging
import ezdxf
from google.cloud import storage
from firebase_functions import storage_fn, options
from firebase_admin import initialize_app
from geometry_utils import associate_lotes_to_quadras

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
    except IOError as e:
        logger.error(f"IOError reading DXF file: {e}")
        return [], [], []
    except ezdxf.DXFError as e:
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

        # Herdando layer 0 ou faltante do bloco pai
        if (not layer_name or layer_name == "0" or layer_name == "BYBLOCK") and parent_layer:
            layer_name = parent_layer

        layer_clean = layer_name.replace('_', ' ').replace('-', ' ')
        tokens = layer_clean.split()
        is_lote = "LOTE" in tokens
        is_quadra = "QUADRA" in tokens
        
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
            # Herda layer do INSERT para as sub-entidades
            layer_to_pass = str(entity.dxf.layer).upper() if entity.has_dxf_attrib('layer') else parent_layer
            try:
                for v_entity in entity.virtual_entities():
                    explode_and_process(v_entity, parent_layer=layer_to_pass)
            except Exception as e:
                logger.warning(f"Failed to explode INSERT: {e}")
        else:
            process_entity(entity, parent_layer)

    # Process all entities in modelspace
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

    if not file_data.name:
        return
        
    if not file_data.bucket:
        return

    # Filter route
    if not file_data.name.startswith("loteamentos_drafts_uploads/"):
        logger.info(f"Ignoring file outside loteamentos_drafts_uploads: {file_data.name}")
        return

    if not file_data.name.lower().endswith('.dxf'):
        logger.info(f"Ignoring non-dxf file: {file_data.name}")
        return

    # Size check
    if file_data.size and int(file_data.size) > MAX_FILE_SIZE_BYTES:
        logger.error(f"File {file_data.name} is too large: {file_data.size} bytes.")
        return

    # Extract userId and loteamento_id
    parts = file_data.name.split("/")
    if len(parts) == 3:
        user_id = parts[1]
        filename = parts[2]
        # Assume format {timestamp}_{loteamentoId}_{originalName} ou similar
        file_parts = filename.split("_")
        loteamento_id = file_parts[1] if len(file_parts) > 1 else filename.replace('.dxf', '')
    else:
        logger.error(f"Invalid path structure: {file_data.name}")
        return

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
            
            # Story 2.2: Point-in-Polygon association
            association_result = associate_lotes_to_quadras(lotes, quadras)
            
            quadras_associadas = association_result.get("quadras", [])
            lotes_orfaos = association_result.get("lotes_orfaos", [])
            
            logger.info(f"Associação concluída: {len(quadras_associadas)} quadras processadas, {len(lotes_orfaos)} lotes sem quadra associada.")
            
        # Future step: do firestore insertions (Story 2.3b).
            
    except Exception as e:
        logger.error(f"Unhandled error processing {file_data.name}: {e}")
        # Do not swallow exceptions so retries can happen if it's transient (e.g. download fail)
        raise
    finally:
        os.close(fd)
        if os.path.exists(temp_local_filename):
            os.remove(temp_local_filename)
