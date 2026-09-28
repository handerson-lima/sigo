import os
import json

# Ensure FIREBASE_CONFIG is set during local deploy discovery to avoid metadata timeouts
if "FIREBASE_CONFIG" not in os.environ:
    os.environ["FIREBASE_CONFIG"] = json.dumps({
        "projectId": "sigo-c2eb2",
        "storageBucket": "sigo-c2eb2.firebasestorage.app"
    })

import tempfile
import logging
import ezdxf
from google.cloud import storage
from firebase_functions import firestore_fn, storage_fn, options
from firebase_admin import initialize_app, firestore

initialize_app()
logger = logging.getLogger(__name__)

from geometry_utils import associate_lotes_to_quadras
from heuristics import build_geojson
from firestore_utils import (
    DraftPersistenceError,
    consolidate_approved_draft,
    save_draft_to_firestore,
)

# Max file size: 50MB
MAX_FILE_SIZE_BYTES = 50 * 1024 * 1024


def _upload_metadata(file_data):
    """Extract the information needed after the Storage event has finished."""
    metadata = getattr(file_data, 'metadata', None) or {}
    construtora_id = metadata.get('construtoraId') if isinstance(metadata, dict) else None
    loteamento_name = metadata.get('loteamentoName') if isinstance(metadata, dict) else None
    if not construtora_id or not loteamento_name:
        raise DraftPersistenceError('Upload sem construtoraId ou loteamentoName')
    return {
        'construtoraId': construtora_id,
        'loteamentoName': loteamento_name,
        'status': 'pendente',
    }


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
        
        # Match flexível usando substring
        is_lote = "LOTE" in layer_name
        is_quadra = "QUADRA" in layer_name
        
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
    region="us-east1",
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

                draft_id = file_data.name.split('/')[-1]
                save_draft_to_firestore(draft_id, geojson, _upload_metadata(file_data))
                logger.info(f"Processamento concluído. Rascunho {draft_id} salvo com sucesso.")
            
    except (IOError, OSError) as e:
        logger.error(f"Transient error processing {file_data.name}: {e}")
        raise
    except DraftPersistenceError:
        logger.exception(f"Fatal error persisting {file_data.name}")
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


@firestore_fn.on_document_updated(
    document='loteamentos_drafts/{draft_id}',
    region='us-east1',
)
def consolidar_loteamento_aprovado(event: firestore_fn.Event[firestore_fn.Change]):
    """Consolida apenas uma solicitação nova de um rascunho aprovado."""
    before = event.data.before.to_dict() if event.data.before else None
    after = event.data.after.to_dict() if event.data.after else None
    if not after or after.get('status') != 'aprovado':
        logger.info('Ignoring consolidation event: draft is not approved')
        return

    request_id = after.get('consolidationRequestId')
    previous_request_id = before.get('consolidationRequestId') if before else None
    completed_request_id = after.get('consolidationCompletedRequestId')
    if not request_id:
        logger.info('Ignoring consolidation event: approved draft has no request id')
        return
    if request_id == previous_request_id:
        logger.info('Ignoring duplicate consolidation request %s', request_id)
        return
    if request_id == completed_request_id:
        logger.info('Ignoring completed consolidation request %s', request_id)
        return

    draft_id = event.params['draft_id']
    logger.info('Starting consolidation request %s for draft %s', request_id, draft_id)
    try:
        consolidate_approved_draft(draft_id, after)
        firestore.client().collection('loteamentos_drafts').document(draft_id).update({
            'consolidationCompletedRequestId': request_id,
        })
        logger.info('Consolidation request %s completed for draft %s', request_id, draft_id)
    except Exception:
        logger.exception(
            'Consolidation request %s failed for draft %s; draft retained for retry',
            request_id,
            draft_id,
        )
        raise


# firebase-functions-python 0.6 still publishes Firestore triggers with retry
# disabled and exposes no public retry option. The deployment manifest is the
# supported discovery contract, so opt this event trigger into redelivery.
consolidar_loteamento_aprovado.__firebase_endpoint__.eventTrigger['retry'] = True
