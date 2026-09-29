import json
import os
import sys

# Importa os módulos do projeto (firestore_utils/heuristics) sem o conftest de
# tests/, que mocka google/firebase_admin globalmente.
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# O firebase emulators:exec já injeta estas variáveis; os defaults mantêm o
# teste executável quando apontado manualmente para o emulador.
os.environ.setdefault('FIRESTORE_EMULATOR_HOST', '127.0.0.1:8080')
os.environ.setdefault('GCLOUD_PROJECT', 'demo-sigo')
os.environ.setdefault(
    'FIREBASE_CONFIG',
    json.dumps({'projectId': 'demo-sigo', 'storageBucket': 'demo-sigo.appspot.com'}),
)

import pytest  # noqa: E402
import firebase_admin  # noqa: E402
from firebase_admin import credentials  # noqa: E402
from google.auth.credentials import AnonymousCredentials  # noqa: E402


class _EmulatorCredential(credentials.Base):
    """Credencial anônima: o Admin SDK não deve buscar ADC contra o emulador."""

    def get_credential(self):
        return AnonymousCredentials()


@pytest.fixture(scope='session', autouse=True)
def _initialize_firebase_app():
    if not firebase_admin._apps:
        firebase_admin.initialize_app(
            _EmulatorCredential(), options={'projectId': 'demo-sigo'}
        )
    yield
