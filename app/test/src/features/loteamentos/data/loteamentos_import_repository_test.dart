import 'dart:async';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/loteamentos/data/loteamentos_import_repository.dart';

class FakeFirebaseStorage extends Fake implements FirebaseStorage {}

class _RecordingUploadTask extends Fake implements UploadTask {
  @override
  Future<T> then<T>(FutureOr<T> Function(TaskSnapshot) onValue, {
    Function? onError,
  }) => Future<T>.value(onValue(FakeTaskSnapshot()));
}

class FakeTaskSnapshot extends Fake implements TaskSnapshot {}

class _RecordingReference extends Fake implements Reference {
  Uint8List? bytes;
  SettableMetadata? metadata;

  @override
  UploadTask putData(Uint8List data, [SettableMetadata? metadata]) {
    bytes = data;
    this.metadata = metadata;
    return _RecordingUploadTask();
  }
}

class _RecordingFirebaseStorage extends Fake implements FirebaseStorage {
  final reference = _RecordingReference();
  String? path;

  @override
  Reference ref([String? path]) {
    this.path = path;
    return reference;
  }
}

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

    test(
      'updateDraftFeature safely merges properties inside a transaction',
      () async {
        // Configurar dados de teste
        final draftId = 'draft123';
        final draftRef = fakeFirestore
            .collection('loteamentos_drafts')
            .doc(draftId);
        await draftRef.set({
          'features': [
            {
              'type': 'Feature',
              'properties': {'nome': 'Lote 1', 'status': 'ambiguo'},
            },
            {
              'type': 'Feature',
              'properties': {'nome': 'Lote 2', 'status': 'resolvido'},
            },
          ],
        });

        // Executar a transação
        await repository.updateDraftFeature(draftId, 0, {
          'nome': 'Lote 1A',
          'status': 'resolvido',
        });

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
      },
    );

    test('updateDraftFeature throws on invalid index', () async {
      final draftId = 'draft123';
      final draftRef = fakeFirestore
          .collection('loteamentos_drafts')
          .doc(draftId);
      await draftRef.set({'features': []});

      expect(
        () => repository.updateDraftFeature(draftId, 0, {'nome': 'Lote'}),
        throwsA(isA<Exception>()),
      );
    });

    test('preserva o nome base do DXF para a consolidação', () {
      expect(
        LoteamentosImportRepository.loteamentoNameFromFilename(
          '00-LOTEAMENTO_HR_R13A_CLUSTER_A_QUADRAS_E_LOTES_R2013.dxf',
        ),
        '00-LOTEAMENTO_HR_R13A_CLUSTER_A_QUADRAS_E_LOTES_R2013',
      );
    });

    test('rejeita nome DXF sem base utilizável antes do upload', () {
      expect(
        LoteamentosImportRepository.loteamentoNameFromFilename('.dxf'),
        isNull,
      );
      expect(
        LoteamentosImportRepository.loteamentoNameFromFilename('arquivo.txt'),
        isNull,
      );
    });

    test('envia caminho e metadados necessários à consolidação', () async {
      final storage = _RecordingFirebaseStorage();
      final repo = LoteamentosImportRepository(fakeFirestore, storage);

      final draftId = await repo.uploadDxf(
        userId: 'user-1',
        construtoraId: 'construtora-1',
        fileBytes: Uint8List.fromList([1, 2]),
        filename: 'Loteamento A.dxf',
      );

      expect(storage.path, 'loteamentos_drafts_uploads/user-1/$draftId');
      expect(storage.reference.bytes, Uint8List.fromList([1, 2]));
      expect(storage.reference.metadata?.contentType, 'application/dxf');
      expect(storage.reference.metadata?.customMetadata, {
        'construtoraId': 'construtora-1',
        'loteamentoName': 'Loteamento A',
      });
    });

    test('aprovação sempre registra uma nova solicitação de consolidação', () async {
      final draft = fakeFirestore.collection('loteamentos_drafts').doc('draft-1');
      await draft.set({'status': 'pendente'});

      await repository.approveDraft('draft-1');
      final firstRequest = (await draft.get()).data()?['consolidationRequestId'];
      await repository.approveDraft('draft-1');
      final data = (await draft.get()).data();

      expect(data?['status'], 'aprovado');
      expect(firstRequest, isA<String>());
      expect(data?['consolidationRequestId'], isA<String>());
      expect(data?['consolidationRequestId'], isNot(firstRequest));
    });
  });
}
