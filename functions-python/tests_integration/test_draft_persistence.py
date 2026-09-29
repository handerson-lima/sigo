"""Teste de integração real contra o emulador do Firestore.

Prova o bug corrigido: ``build_geojson`` devolve ``geometry.coordinates`` como
array aninhado, e o ``doc_ref.set`` original falhava com
``400 Property array contains an invalid nested entity``. A persistência agora
serializa a geometria para String na borda e o documento é gravado e relido.
"""
import json

from firebase_admin import firestore
from shapely.geometry import Polygon

from firestore_utils import consolidate_approved_draft, save_draft_to_firestore
from heuristics import build_geojson

DRAFT_ID = 'integration-draft-dxf'


class _MockDxfText:
    def __init__(self, text, x, y):
        self._text = text
        self._x = x
        self._y = y

    def dxftype(self):
        return 'TEXT'

    @property
    def dxf(self):
        return self

    @property
    def text(self):
        return self._text

    @property
    def insert(self):
        return _Point(self._x, self._y)


class _Point:
    def __init__(self, x, y):
        self.x = x
        self.y = y


def _build_reference_geojson():
    """Reproduz o formato real de saída do extrator (lot./quadra reais)."""
    quadra_entity = object()
    lote_entity = object()
    quadra_poly = Polygon([(-5, -5), (15, -5), (15, 15), (-5, 15), (-5, -5)])
    lote_poly = Polygon([(0, 0), (10, 0), (10, 10), (0, 10), (0, 0)])
    association = {
        'quadras': {quadra_entity: [lote_entity]},
        'lotes_orfaos': [],
        'quadra_polygons': {quadra_entity: quadra_poly},
        'lote_polygons': {lote_entity: lote_poly},
    }
    geojson = build_geojson(
        association,
        [_MockDxfText('12', 5, 5), _MockDxfText('Q 1', 5, 5)],
        association['quadra_polygons'],
        association['lote_polygons'],
    )
    assert geojson['features'], 'build_geojson deve produzir features reais'
    # Confirma que a fonte tem geometria aninhada (a causa do bug original).
    assert isinstance(geojson['features'][0]['geometry']['coordinates'][0][0], list)
    return geojson


def _has_nested_array(value):
    if isinstance(value, list):
        if any(isinstance(item, list) for item in value):
            return True
        return any(_has_nested_array(item) for item in value)
    if isinstance(value, dict):
        return any(_has_nested_array(item) for item in value.values())
    return False


def _read_draft(draft_id):
    snapshot = firestore.client().collection('loteamentos_drafts').document(draft_id).get()
    assert snapshot.exists, f'rascunho {draft_id} não encontrado'
    return snapshot.to_dict()


def test_draft_is_persisted_with_serialized_geometry():
    geojson = _build_reference_geojson()

    save_draft_to_firestore(
        DRAFT_ID,
        geojson,
        {
            'construtoraId': 'construtora-1',
            'loteamentoName': 'arquivo',
            'status': 'pendente',
            'sourceFormat': 'dxf',
        },
    )

    data = _read_draft(DRAFT_ID)
    assert data['status'] == 'pendente'
    assert data['construtoraId'] == 'construtora-1'
    assert data['sourceFormat'] == 'dxf'
    assert data['features'], 'features devem ser persistidas'

    for feature in data['features']:
        assert isinstance(feature['geometry'], str)
        decoded = json.loads(feature['geometry'])
        assert decoded['type'] in ('Polygon', 'MultiPolygon')
        assert decoded['coordinates'], 'geometria real deve ter coordenadas'
        assert feature['properties']['tipo'] in ('lote', 'quadra')

    assert not _has_nested_array(data), 'documento não pode conter arrays aninhados'


def test_correction_round_trip_keeps_geometry_serialized():
    geojson = _build_reference_geojson()
    save_draft_to_firestore(DRAFT_ID, geojson, {'status': 'pendente'})

    data = _read_draft(DRAFT_ID)
    features = list(data['features'])
    feature = dict(features[0])
    properties = dict(feature['properties'])
    properties.update({'nome': 'Lote 1A', 'status': 'resolvido'})
    feature['properties'] = properties
    features[0] = feature

    # Mesmo formato usado por LoteamentosImportRepository.updateDraftFeature.
    firestore.client().collection('loteamentos_drafts').document(DRAFT_ID).update(
        {'features': features}
    )

    corrected = _read_draft(DRAFT_ID)
    corrected_feature = corrected['features'][0]
    assert corrected_feature['geometry'] == data['features'][0]['geometry']
    assert isinstance(corrected_feature['geometry'], str)
    assert corrected_feature['properties']['nome'] == 'Lote 1A'
    assert corrected_feature['properties']['status'] == 'resolvido'
    assert not _has_nested_array(corrected)


def test_consolidation_materializes_top_level_documents_with_string_timestamps():
    geojson = _build_reference_geojson()
    save_draft_to_firestore(
        DRAFT_ID,
        geojson,
        {
            'construtoraId': 'construtora-1',
            'loteamentoName': 'arquivo',
            'status': 'aprovado',
        },
    )

    draft = _read_draft(DRAFT_ID)
    consolidate_approved_draft(DRAFT_ID, draft)

    db = firestore.client()
    loteamento_id = f'{DRAFT_ID}--loteamento'
    loteamento = db.collection('loteamentos').document(loteamento_id).get().to_dict()
    assert loteamento['construtoraId'] == 'construtora-1'
    assert loteamento['name'] == 'arquivo'
    # O app faz DateTime.parse no campo, então a consolidação grava String ISO.
    assert isinstance(loteamento['createdAt'], str)
    assert isinstance(loteamento['updatedAt'], str)

    quadras = list(
        db.collection('quadras').where('loteamentoId', '==', loteamento_id).stream()
    )
    lotes = list(
        db.collection('lotes').where('loteamentoId', '==', loteamento_id).stream()
    )
    assert quadras and lotes

    quadra = quadras[0].to_dict()
    lote = lotes[0].to_dict()
    assert quadra['construtoraId'] == 'construtora-1'
    assert lote['construtoraId'] == 'construtora-1'
    assert lote['quadraId'] == quadra['id']
    assert lote['name']
    json.loads(lote['geometry'])
