import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/loteamentos/data/loteamentos_import_repository.dart';

class FakeFirebaseStorage extends Fake implements FirebaseStorage {}

void main() {
  group('LoteamentosImportRepository', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeFirebaseStorage fakeStorage;
    late LoteamentosImportRepository repository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeStorage = FakeFirebaseStorage();
      repository = LoteamentosImportRepository(fakeFirestore, fakeStorage);
    });

    test('updateDraftFeature safely merges properties inside a transaction', () async {
      // Configurar dados de teste
      final draftId = 'draft123';
      final draftRef = fakeFirestore.collection('loteamentos_drafts').doc(draftId);
      await draftRef.set({
        'features': [
          {'type': 'Feature', 'properties': {'nome': 'Lote 1', 'status': 'ambiguo'}},
          {'type': 'Feature', 'properties': {'nome': 'Lote 2', 'status': 'resolvido'}},
        ],
      });

      // Executar a transação
      await repository.updateDraftFeature(draftId, 0, {'nome': 'Lote 1A', 'status': 'resolvido'});

      // Validar os resultados
      final snapshot = await draftRef.get();
      final data = snapshot.data();
      expect(data, isNotNull);
      final features = data!['features'] as List<dynamic>;
      expect(features.length, 2);
      expect((features[0] as Map)['properties']['nome'], 'Lote 1A');
      expect((features[0] as Map)['properties']['status'], 'resolvido');
      // Garante que o outro elemento não foi modificado
      expect((features[1] as Map)['properties']['nome'], 'Lote 2');
    });

    test('updateDraftFeature throws on invalid index', () async {
      final draftId = 'draft123';
      final draftRef = fakeFirestore.collection('loteamentos_drafts').doc(draftId);
      await draftRef.set({
        'features': [],
      });

      expect(
        () => repository.updateDraftFeature(draftId, 0, {'nome': 'Lote'}),
        throwsA(isA<Exception>()),
      );
    });
  });
}
