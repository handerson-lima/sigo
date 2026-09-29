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
import time
from google.cloud import storage
from firebase_functions import firestore_fn, https_fn, options, storage_fn
from firebase_admin import initialize_app, firestore

initialize_app()
logger = logging.getLogger(__name__)

from dxf_extraction import DxfExtractionError, extract_dxf_geojson
from firestore_utils import (
    DraftPersistenceError,
    consolidate_approved_draft,
    save_draft_to_firestore,
)

# Max file size: 50MB
MAX_FILE_SIZE_BYTES = 50 * 1024 * 1024
CONSOLIDATION_CLAIM_TTL_SECONDS = 120


def _claim_consolidation_request(draft_id: str, request_id: str) -> bool:
    """Reserva atomicamente uma solicitação para não processá-la duas vezes."""
    db = firestore.client()
    draft_ref = db.collection('loteamentos_drafts').document(draft_id)
    transaction = db.transaction()

    @firestore.transactional
    def claim(transaction):
        snapshot = draft_ref.get(transaction=transaction)
        draft = snapshot.to_dict() if snapshot.exists else None
        if not draft or draft.get('consolidationRequestId') != request_id:
            return False
        if draft.get('consolidationCompletedRequestId') == request_id:
            return False
        if draft.get('consolidationProcessingRequestId') == request_id:
            started_at = draft.get('consolidationProcessingStartedAt')
            if isinstance(started_at, (int, float)) and (
                time.time() - started_at < CONSOLIDATION_CLAIM_TTL_SECONDS
            ):
                return False
        transaction.update(draft_ref, {
            'consolidationProcessingRequestId': request_id,
            'consolidationProcessingStartedAt': time.time(),
        })
        return True

    return claim(transaction)


def _release_consolidation_request(draft_id: str, request_id: str) -> None:
    """Libera uma reserva falha sem limpar a de uma solicitação mais nova."""
    db = firestore.client()
    draft_ref = db.collection('loteamentos_drafts').document(draft_id)
    transaction = db.transaction()

    @firestore.transactional
    def release(transaction):
        snapshot = draft_ref.get(transaction=transaction)
        draft = snapshot.to_dict() if snapshot.exists else None
        if draft and draft.get('consolidationProcessingRequestId') == request_id:
            transaction.update(draft_ref, {
                'consolidationProcessingRequestId': firestore.DELETE_FIELD,
                'consolidationProcessingStartedAt': firestore.DELETE_FIELD,
            })

    release(transaction)


def _complete_consolidation_request(draft_id: str, request_id: str) -> bool:
    """Marca a conclusão somente enquanto a solicitação ainda possui a reserva."""
    db = firestore.client()
    draft_ref = db.collection('loteamentos_drafts').document(draft_id)
    transaction = db.transaction()

    @firestore.transactional
    def complete(transaction):
        snapshot = draft_ref.get(transaction=transaction)
        draft = snapshot.to_dict() if snapshot.exists else None
        if not draft or draft.get('consolidationProcessingRequestId') != request_id:
            return False
        transaction.update(draft_ref, {
            'consolidationCompletedRequestId': request_id,
            'consolidationProcessingRequestId': firestore.DELETE_FIELD,
            'consolidationProcessingStartedAt': firestore.DELETE_FIELD,
        })
        return True

    return complete(transaction)


def _is_active_member(uid: str, construtora_id: str) -> bool:
    """Reproduz a função ``member(c)`` das regras para o Admin SDK."""
    if not uid or not construtora_id:
        return False
    db = firestore.client()
    construtora_ref = db.collection('construtoras').document(construtora_id)
    construtora = construtora_ref.get()
    if not construtora.exists:
        return False
    if (construtora.to_dict() or {}).get('isActive', True) is False:
        return False
    member = construtora_ref.collection('construtora_members').document(uid).get()
    if not member.exists:
        return False
    return (member.to_dict() or {}).get('isActive') is True


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


@storage_fn.on_object_finalized(
    region="us-east1",
    memory=options.MemoryOption.GB_1,
    cpu=1,
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

    file_name_lower = file_data.name.lower()
    if not file_name_lower.endswith('.dxf'):
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

    fd, temp_local_filename = tempfile.mkstemp(suffix='.dxf')
    try:
        blob.download_to_filename(temp_local_filename)
        logger.info(f"Downloaded {file_data.name} to {temp_local_filename}")
        geojson = extract_dxf_geojson(temp_local_filename)
        draft_id = file_data.name.split('/')[-1]
        save_draft_to_firestore(
            draft_id, geojson, {**_upload_metadata(file_data), 'sourceFormat': 'dxf'},
        )
        logger.info(f"Processamento DXF concluído. Rascunho {draft_id} salvo com sucesso.")
            
    except (IOError, OSError) as e:
        logger.error(f"Transient error processing {file_data.name}: {e}")
        raise
    except DraftPersistenceError:
        logger.exception(f"Fatal error persisting {file_data.name}")
        # Sem raise para evitar loop infinito de poison messages do DXF para o Firestore
    except DxfExtractionError as error:
        logger.error('DXF_INVALID: %s', error)
        draft_id = file_data.name.split('/')[-1]
        save_draft_to_firestore(
            draft_id,
            {'type': 'FeatureCollection', 'features': []},
            {**_upload_metadata(file_data), 'status': 'erro',
             'sourceFormat': 'dxf', 'processingError': str(error)},
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
    completed_request_id = after.get('consolidationCompletedRequestId')
    if not request_id:
        logger.info('Ignoring consolidation event: approved draft has no request id')
        return
    if request_id == (before or {}).get('consolidationRequestId'):
        logger.info('Ignoring consolidation event: request id unchanged')
        return
    if request_id == completed_request_id:
        logger.info('Ignoring completed consolidation request %s', request_id)
        return

    draft_id = event.params['draft_id']
    if not _claim_consolidation_request(draft_id, request_id):
        logger.info('Ignoring already claimed consolidation request %s', request_id)
        return

    logger.info('Starting consolidation request %s for draft %s', request_id, draft_id)
    try:
        consolidate_approved_draft(draft_id, after)
        if _complete_consolidation_request(draft_id, request_id):
            logger.info('Consolidation request %s completed for draft %s', request_id, draft_id)
        else:
            logger.info('Consolidation request %s completion ignored for draft %s', request_id, draft_id)
    except ValueError:
        # Erro permanente de validação do rascunho: uma nova entrega nunca vai
        # passar, então libera a reserva e dá ack para não virar poison message.
        logger.exception(
            'Consolidation request %s rejected for draft %s; invalid draft',
            request_id,
            draft_id,
        )
        _release_consolidation_request(draft_id, request_id)
    except Exception:
        logger.exception(
            'Consolidation request %s failed for draft %s; draft retained for retry',
            request_id,
            draft_id,
        )
        _release_consolidation_request(draft_id, request_id)
        raise


@https_fn.on_call(region='us-east1')
def consolidar_loteamento_manual(request: https_fn.CallableRequest):
    """Consolida explicitamente o rascunho aprovado sem depender do Eventarc."""
    data = request.data if isinstance(request.data, dict) else {}
    draft_id = data.get('draftId')
    if not isinstance(draft_id, str) or not draft_id:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            'draftId é obrigatório.',
        )

    auth = getattr(request, 'auth', None)
    uid = getattr(auth, 'uid', None)
    if not uid:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.PERMISSION_DENIED,
            'Autenticação obrigatória.',
        )

    draft_ref = firestore.client().collection('loteamentos_drafts').document(draft_id)
    snapshot = draft_ref.get()
    draft = snapshot.to_dict() if snapshot.exists else None
    if not draft:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.NOT_FOUND, 'Rascunho não encontrado.')
    if not _is_active_member(uid, draft.get('construtoraId')):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.PERMISSION_DENIED,
            'Usuário não é membro ativo da construtora do rascunho.',
        )
    if draft.get('status') != 'aprovado':
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            'O rascunho precisa estar aprovado.',
        )

    request_id = draft.get('consolidationRequestId')
    if not request_id:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            'Solicitação de consolidação ausente.',
        )
    if draft.get('consolidationCompletedRequestId') == request_id:
        return {'status': 'already_completed'}
    if not _claim_consolidation_request(draft_id, request_id):
        return {'status': 'already_processing'}

    try:
        consolidate_approved_draft(draft_id, draft)
        if not _complete_consolidation_request(draft_id, request_id):
            raise RuntimeError('A solicitação de consolidação perdeu sua reserva.')
        logger.info('Manual consolidation request %s completed for draft %s', request_id, draft_id)
        return {'status': 'completed'}
    except Exception as error:
        _release_consolidation_request(draft_id, request_id)
        logger.exception('Manual consolidation failed for draft %s', draft_id)
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INTERNAL,
            'Não foi possível consolidar o loteamento.',
        ) from error


# firebase-functions-python 0.6 still publishes Firestore triggers with retry
# disabled and exposes no public retry option. The deployment manifest is the
# supported discovery contract, so opt this event trigger into redelivery.
consolidar_loteamento_aprovado.__firebase_endpoint__.eventTrigger['retry'] = True
