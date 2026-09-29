import os
import sys
from types import SimpleNamespace
from unittest.mock import MagicMock

# Adiciona o diretório raiz do projeto ao sys.path para importar main.py
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Mock unbuildable dependencies on this host before anything imports them
sys.modules['google'] = MagicMock()
sys.modules['google.cloud'] = MagicMock()

class MockFirebaseFunctions(MagicMock):
    pass

mock_ff = MockFirebaseFunctions()
mock_ff.recorded = {}


# O decorator só precisa devolver a função original
def mock_decorator(*args, **kwargs):
    def decorator(func):
        return func
    return decorator


def mock_storage_decorator(*args, **kwargs):
    mock_ff.recorded['storage'] = kwargs

    def decorator(func):
        return func
    return decorator


def mock_firestore_decorator(*args, **kwargs):
    def decorator(func):
        func.__firebase_endpoint__ = SimpleNamespace(eventTrigger={'retry': False})
        return func
    return decorator


class MockHttpsError(Exception):
    def __init__(self, code=None, message=None):
        super().__init__(message)
        self.code = code
        self.message = message


class MockFunctionsErrorCode:
    INVALID_ARGUMENT = 'INVALID_ARGUMENT'
    NOT_FOUND = 'NOT_FOUND'
    FAILED_PRECONDITION = 'FAILED_PRECONDITION'
    PERMISSION_DENIED = 'PERMISSION_DENIED'
    INTERNAL = 'INTERNAL'


mock_ff.storage_fn.on_object_finalized = mock_storage_decorator
mock_ff.firestore_fn.on_document_updated = mock_firestore_decorator
mock_ff.https_fn.on_call = mock_decorator
mock_ff.https_fn.HttpsError = MockHttpsError
mock_ff.https_fn.FunctionsErrorCode = MockFunctionsErrorCode
sys.modules['firebase_functions'] = mock_ff
sys.modules['firebase_admin'] = MagicMock()
