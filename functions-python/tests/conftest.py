import os
import sys
from unittest.mock import MagicMock

# Adiciona o diretório raiz do projeto ao sys.path para importar main.py
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Mock unbuildable dependencies on this host before anything imports them
sys.modules['google'] = MagicMock()
sys.modules['google.cloud'] = MagicMock()

class MockFirebaseFunctions(MagicMock):
    pass

mock_ff = MockFirebaseFunctions()
# The decorator should just return the function
def mock_decorator(*args, **kwargs):
    def decorator(func):
        return func
    return decorator

mock_ff.storage_fn.on_object_finalized = mock_decorator
sys.modules['firebase_functions'] = mock_ff
sys.modules['firebase_admin'] = MagicMock()
