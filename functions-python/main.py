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
from google.cloud import storage
from firebase_functions import storage_fn
from firebase_admin import initialize_app

initialize_app()
logger = logging.getLogger(__name__)

from dwf_extraction import DwfExtractionError, extract_dwf_geojson
from firestore_utils import (
    DraftPersistenceError,
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


@storage_fn.on_object_finalized(region="us-east1")
def processar_dwf(event: storage_fn.CloudEvent[storage_fn.StorageObjectData]):
    """
    Background Cloud Function to be triggered by Cloud Storage.
    Path expected: loteamentos_drafts_uploads/{userId}/{timestamp}_{filename}.dwf
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

    file_name_lower = file_data.name.lower()
    if not file_name_lower.endswith('.dwf'):
        logger.info(f"Ignoring unsupported file: {file_data.name}")
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

    fd, temp_local_filename = tempfile.mkstemp(suffix='.dwf')
    try:
        blob.download_to_filename(temp_local_filename)
        logger.info(f"Downloaded {file_data.name} to {temp_local_filename}")
        geojson = extract_dwf_geojson(temp_local_filename)
        draft_id = file_data.name.split('/')[-1]
        save_draft_to_firestore(
            draft_id, geojson, {**_upload_metadata(file_data), 'sourceFormat': 'dwf'},
        )
        logger.info(f"Processamento DWF concluído. Rascunho {draft_id} salvo com sucesso.")
            
    except (IOError, OSError) as e:
        logger.error(f"Transient error processing {file_data.name}: {e}")
        raise
    except DraftPersistenceError:
        logger.exception(f"Fatal error persisting {file_data.name}")
        # Sem raise para evitar loop infinito de poison messages do DXF para o Firestore
    except DwfExtractionError as error:
        logger.error('DWF_INVALID: %s', error)
        draft_id = file_data.name.split('/')[-1]
        save_draft_to_firestore(
            draft_id,
            {'type': 'FeatureCollection', 'features': []},
            {**_upload_metadata(file_data), 'status': 'erro',
             'sourceFormat': 'dwf', 'processingError': str(error)},
        )
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
