import os
import tempfile
import logging
import ezdxf
from google.cloud import storage
from firebase_functions import storage_fn, options
from firebase_admin import initialize_app

initialize_app()
logger = logging.getLogger(__name__)

from geometry_utils import associate_lotes_to_quadras
from heuristics import build_geojson
from firestore_utils import save_draft_to_firestore, DraftPersistenceError

# Max file size: 50MB
MAX_FILE_SIZE_BYTES = 50 * 1024 * 1024


def _inherit_layer(layer_name: str, parent_layer):
    """Entidades/INSERTs em layer '0' ou 'BYBLOCK' assumem o layer da referência pai."""
    if (not layer_name or layer_name == "0" or layer_name == "BYBLOCK") and parent_layer:
        return parent_layer
    return layer_name


def extract_dxf_geometries(filepath: str):
    """
    Reads DXF and extracts Lotes, Quadras, and Texts from modelspace and blocks (INSERTs).

    Returns ``(lotes, quadras, textos)`` for a readable DXF (lists may be empty when the
    file has no matching entities), or ``None`` when the file is not a valid/readable DXF.
    The ``None`` signal lets the caller distinguish INVALID_FILE from NO_ENTITIES.
    """
    try:
        doc = ezdxf.readfile(filepath)
    except (OSError, ezdxf.DXFError) as e:
        # Invalid/corrupt input (deterministic): log and stop gracefully without
        # crashing the handler. Returning None distinguishes INVALID_FILE from
        # NO_ENTITIES (valid DXF, no matching entities) and avoids retrying a
        # deterministic failure. Unexpected errors are not caught here so they
        # propagate instead of being silently swallowed.
        logger.error(f"INVALID_FILE: cannot read DXF {filepath}: {e}")
        return None

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

        # Entidades de bloco no layer '0'/'BYBLOCK' assumem o layer da referência (INSERT)
        layer_name = _inherit_layer(layer_name, parent_layer)

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
            # INSERT em layer 0/BYBLOCK herda do layer do ancestral
            try:
                layer_to_pass = str(entity.dxf.layer).upper()
            except AttributeError:
                layer_to_pass = ""

            layer_to_pass = _inherit_layer(layer_to_pass, parent_layer)

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
    logger.debug(f"Processing {getattr(file_data, 'name', 'NO_NAME')}")

    if not file_data.name:
        return

    if not file_data.bucket:
        logger.debug("No bucket specified")
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
        logger.debug("No size specified")
        logger.error(f"File {file_data.name} has no size specified.")
        return

    if not file_data.generation:
        logger.error(f"File {file_data.name} has no generation specified.")
        return

    logger.debug("Passed all checks, calling storage.Client")

    storage_client = storage.Client()
    bucket = storage_client.bucket(file_data.bucket)
    blob = bucket.blob(file_data.name, generation=file_data.generation)

    fd, temp_local_filename = tempfile.mkstemp(suffix=".dxf")
    try:
        blob.download_to_filename(temp_local_filename)
        logger.info(f"Downloaded {file_data.name} to {temp_local_filename}")

        result = extract_dxf_geometries(temp_local_filename)

        if result is None:
            logger.error(f"File {file_data.name} is not a valid DXF (INVALID_FILE); skipping.")
        else:
            lotes, quadras, textos = result
            if not lotes and not quadras:
                logger.warning(f"File {file_data.name} contained no Lote or Quadra entities (NO_ENTITIES).")
            else:
                association = associate_lotes_to_quadras(lotes, quadras)
                
                # Log association results
                associated_count = sum(len(l) for l in association['quadras'].values())
                orphans_count = len(association['lotes_orfaos'])
                logger.info(f"Extracted {len(lotes)} lotes, {len(quadras)} quadras and {len(textos)} textos.")
                logger.info(f"Associated {associated_count} lotes to quadras. {orphans_count} lotes are orphans.")
                
                geojson = build_geojson(
                    association, 
                    textos, 
                    association['quadra_polygons'], 
                    association['lote_polygons']
                )

                draft_id = file_data.name.replace('loteamentos_drafts_uploads/', '')
                save_draft_to_firestore(draft_id, geojson)
                logger.info(f"Processamento concluído. Rascunho {draft_id} salvo com sucesso.")
            
    except (IOError, OSError) as e:
        logger.error(f"Transient error processing {file_data.name}: {e}")
        raise
    except DraftPersistenceError as e:
        logger.error(f"Fatal error persisting {file_data.name}: {e}")
        # Sem raise para evitar loop infinito de poison messages do DXF para o Firestore
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
