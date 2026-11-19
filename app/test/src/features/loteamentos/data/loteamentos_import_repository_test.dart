import 'dart:async';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/loteamentos/data/loteamentos_import_repository.dart';

class FakeFirebaseStorage extends Fake implements FirebaseStorage {}

class _RecordingUploadTask extends Fake implements UploadTask {
  @override
  Future<T> then<T>(
    FutureOr<T> Function(TaskSnapshot) onValue, {
    Function? onError,
  }) => Future<T>.value(onValue(FakeTaskSnapshot()));
}

class FakeTaskSnapshot extends Fake implements TaskSnapshot {}

class _RecordedUpload {
  final String path;
  final Uint8List bytes;
  final SettableMetadata? metadata;

  _RecordedUpload({
    required this.path,
    required this.bytes,
    required this.metadata,
  });
}

class _RecordingReference extends Fake implements Reference {
  final String _path;
  final List<_RecordedUpload> _uploads;

  _RecordingReference(this._path, this._uploads);

  @override
  UploadTask putData(Uint8List data, [SettableMetadata? metadata]) {
    _uploads.add(_RecordedUpload(path: _path, bytes: data, metadata: metadata));
    return _RecordingUploadTask();
  }
}

class _RecordingFirebaseStorage extends Fake implements FirebaseStorage {
  final List<_RecordedUpload> uploads = [];
  String? lastPath;

  @override
  Reference ref([String? path]) {
    lastPath = path;
    return _RecordingReference(path ?? '', uploads);
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

    test('preserva o nome base de PDF, DXF e DWF para o rascunho', () {
      expect(
        LoteamentosImportRepository.loteamentoNameFromFilename(
          'Lote_31_Q28.pdf',
        ),
        'Lote_31_Q28',
      );
      expect(
        LoteamentosImportRepository.loteamentoNameFromFilename(
          'Lote_31_Q28.PDF',
        ),
        'Lote_31_Q28',
      );
      expect(
        LoteamentosImportRepository.loteamentoNameFromFilename(
          'LOTEAMENTO_HR_R13A-Model.dxf',
        ),
        'LOTEAMENTO_HR_R13A-Model',
      );
      expect(
        LoteamentosImportRepository.loteamentoNameFromFilename(
          'LOTEAMENTO_HR_R13A-Model.dwf',
        ),
        'LOTEAMENTO_HR_R13A-Model',
      );
      expect(
        LoteamentosImportRepository.loteamentoNameFromFilename(
          'LOTEAMENTO_HR_R13A-Model.DWF',
        ),
        'LOTEAMENTO_HR_R13A-Model',
      );
    });

    test('resolve o contentType correto para PDF, DXF e DWF', () {
      expect(
        LoteamentosImportRepository.contentTypeFromFilename('arquivo.pdf'),
        'application/pdf',
      );
      expect(
        LoteamentosImportRepository.contentTypeFromFilename('arquivo.PDF'),
        'application/pdf',
      );
      expect(
        LoteamentosImportRepository.contentTypeFromFilename('arquivo.dxf'),
        'application/dxf',
      );
      expect(
        LoteamentosImportRepository.contentTypeFromFilename('arquivo.DXF'),
        'application/dxf',
      );
      expect(
        LoteamentosImportRepository.contentTypeFromFilename('arquivo.dwf'),
        'application/x-dwf',
      );
      expect(
        LoteamentosImportRepository.contentTypeFromFilename('arquivo.DWF'),
        'application/x-dwf',
      );
      expect(
        LoteamentosImportRepository.contentTypeFromFilename('arquivo.dwg'),
        isNull,
      );
    });

    test('rejeita formatos não suportados (DWG e TXT) e nomes sem base', () {
      expect(
        LoteamentosImportRepository.loteamentoNameFromFilename('arquivo.dwg'),
        isNull,
      );
      expect(
        LoteamentosImportRepository.loteamentoNameFromFilename('arquivo.txt'),
        isNull,
      );
      expect(
        LoteamentosImportRepository.loteamentoNameFromFilename('.pdf'),
        isNull,
      );
      expect(
        LoteamentosImportRepository.loteamentoNameFromFilename('.dxf'),
        isNull,
      );
      expect(
        LoteamentosImportRepository.loteamentoNameFromFilename('.dwf'),
        isNull,
      );
    });

    test('envia caminho e metadados necessários ao rascunho DXF', () async {
      final storage = _RecordingFirebaseStorage();
      final repo = LoteamentosImportRepository(fakeFirestore, storage);

      final draftId = await repo.uploadDxf(
        userId: 'user-1',
        construtoraId: 'construtora-1',
        fileBytes: Uint8List.fromList([1, 2]),
        filename: 'Loteamento A.dxf',
      );

      expect(storage.uploads, hasLength(1));
      final upload = storage.uploads.first;
      expect(upload.path, 'loteamentos_drafts_uploads/user-1/$draftId');
      expect(upload.bytes, Uint8List.fromList([1, 2]));
      expect(upload.metadata?.contentType, 'application/dxf');
      expect(upload.metadata?.customMetadata, {
        'construtoraId': 'construtora-1',
        'loteamentoName': 'Loteamento A',
        'originalFilename': 'Loteamento A.dxf',
      });
    });

    test('envia caminho e metadados necessários ao rascunho DWF', () async {
      final storage = _RecordingFirebaseStorage();
      final repo = LoteamentosImportRepository(fakeFirestore, storage);

      final draftId = await repo.uploadFile(
        userId: 'user-1',
        construtoraId: 'construtora-1',
        fileBytes: Uint8List.fromList([3, 4]),
        filename: 'Loteamento B.dwf',
      );

      expect(storage.uploads, hasLength(1));
      final upload = storage.uploads.first;
      expect(upload.path, 'loteamentos_drafts_uploads/user-1/$draftId');
      expect(upload.bytes, Uint8List.fromList([3, 4]));
      expect(upload.metadata?.contentType, 'application/x-dwf');
      expect(upload.metadata?.customMetadata, {
        'construtoraId': 'construtora-1',
        'loteamentoName': 'Loteamento B',
        'originalFilename': 'Loteamento B.dwf',
      });
    });

    test('envia PDF único com contentType application/pdf e targetLoteamentoId', () async {
      final storage = _RecordingFirebaseStorage();
      final repo = LoteamentosImportRepository(fakeFirestore, storage);

      final draftId = await repo.uploadFiles(
        userId: 'user-1',
        construtoraId: 'construtora-1',
        targetLoteamentoId: 'lot-existente-1',
        loteamentoNameOverride: 'Jardim Botanico',
        files: [
          ImportUploadFile(
            bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
            filename: 'lote_31_q28.pdf',
          ),
        ],
      );

      expect(storage.uploads, hasLength(1));
      final upload = storage.uploads.first;
      expect(upload.path, 'loteamentos_drafts_uploads/user-1/$draftId');
      expect(upload.metadata?.contentType, 'application/pdf');
      expect(upload.metadata?.customMetadata, {
        'construtoraId': 'construtora-1',
        'loteamentoName': 'Jardim Botanico',
        'originalFilename': 'lote_31_q28.pdf',
        'targetLoteamentoId': 'lot-existente-1',
      });
    });

    test(
      'envia múltiplos PDFs compartilhando o mesmo draftId nos metadados do Storage',
      () async {
        final storage = _RecordingFirebaseStorage();
        final repo = LoteamentosImportRepository(fakeFirestore, storage);

        final draftId = await repo.uploadFiles(
          userId: 'user-1',
          construtoraId: 'construtora-1',
          targetLoteamentoId: 'lot-existente-2',
          files: [
            ImportUploadFile(
              bytes: Uint8List.fromList([1, 2, 3]),
              filename: 'lote_01.pdf',
            ),
            ImportUploadFile(
              bytes: Uint8List.fromList([4, 5, 6]),
              filename: 'lote_02.pdf',
            ),
          ],
        );

        expect(draftId, startsWith('draft_'));
        expect(storage.uploads, hasLength(2));
        expect(storage.uploads[0].path, isNot(storage.uploads[1].path));
        for (final upload in storage.uploads) {
          expect(upload.metadata?.contentType, 'application/pdf');
          expect(upload.metadata?.customMetadata?['draftId'], draftId);
          expect(
            upload.metadata?.customMetadata?['construtoraId'],
            'construtora-1',
          );
          expect(
            upload.metadata?.customMetadata?['targetLoteamentoId'],
            'lot-existente-2',
          );
        }
      },
    );

    test('uploadFiles rejeita lista vazia ou formato inválido antes de acessar o Storage', () async {
      final storage = _RecordingFirebaseStorage();
      final repo = LoteamentosImportRepository(fakeFirestore, storage);

      expect(
        () => repo.uploadFiles(
          userId: 'user-1',
          construtoraId: 'construtora-1',
          files: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.uploadFiles(
          userId: 'user-1',
          construtoraId: 'construtora-1',
          files: [
            ImportUploadFile(
              bytes: Uint8List.fromList([1]),
              filename: 'ok.pdf',
            ),
            ImportUploadFile(
              bytes: Uint8List.fromList([2]),
              filename: 'invalido.dwg',
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(storage.uploads, isEmpty);
    });

    test('saveDraftReview grava loteamento, targetLoteamentoId, items e updatedAt', () async {
      final draftRef = fakeFirestore
          .collection('loteamentos_drafts')
          .doc('draft-tabular');
      await draftRef.set({'status': 'pendente'});

      await repository.saveDraftReview(
        draftId: 'draft-tabular',
        loteamento: {'name': 'Jardim Botanico', 'cidade': 'Extremoz', 'uf': 'RN'},
        targetLoteamentoId: 'lot-123',
        items: [
          {
            'quadra': 'Quadra 28',
            'nome': 'Lote 31',
            'frenteM': 10.0,
            'profundidadeM': 20.0,
            'areaTerrenoM2': 200.0,
            'status': 'valido',
          },
        ],
      );

      final data = (await draftRef.get()).data()!;
      expect(data['loteamento'], {
        'name': 'Jardim Botanico',
        'cidade': 'Extremoz',
        'uf': 'RN',
      });
      expect(data['targetLoteamentoId'], 'lot-123');
      expect((data['items'] as List).length, 1);
      expect(data['updatedAt'], isA<String>());
    });

    test('aprovação grava loteamento, targetLoteamentoId, items, status aprovado, requestId e updatedAt', () async {
      final draft = fakeFirestore
          .collection('loteamentos_drafts')
          .doc('draft-1');
      await draft.set({'status': 'pendente'});

      await repository.approveTabularDraft(
        draftId: 'draft-1',
        loteamento: {'name': 'Jardim Botanico'},
        targetLoteamentoId: null,
        items: [
          {'quadra': 'Quadra 28', 'nome': 'Lote 31', 'status': 'valido'},
        ],
      );

      final data = (await draft.get()).data()!;
      expect(data['status'], 'aprovado');
      expect(data['loteamento'], {'name': 'Jardim Botanico'});
      expect(data['targetLoteamentoId'], isNull);
      expect((data['items'] as List).length, 1);
      expect(data['updatedAt'], isA<String>());
      expect(data['consolidationRequestId'], isA<String>());
      final requestId = data['consolidationRequestId'] as String;
      final parts = requestId.split('-');
      expect(parts.length, 2);
      final randomPart = int.tryParse(parts[1]);
      expect(randomPart, isNotNull);
      expect(randomPart, greaterThanOrEqualTo(0));
      expect(randomPart, lessThan(0x7fffffff));
    });

    test('cada aprovação gera uma solicitação de consolidação nova', () async {
      final draft = fakeFirestore
          .collection('loteamentos_drafts')
          .doc('draft-1');
      await draft.set({'status': 'aprovado'});

      await repository.approveDraft('draft-1');
      final first = (await draft.get()).data()?['consolidationRequestId'];
      await repository.approveDraft('draft-1');
      final second = (await draft.get()).data()?['consolidationRequestId'];

      expect(first, isA<String>());
      expect(second, isA<String>());
      expect(second, isNot(first));
    });

    test('aprovação dispara o retry manual da consolidação', () async {
      final draft = fakeFirestore
          .collection('loteamentos_drafts')
          .doc('draft-1');
      await draft.set({'status': 'pendente'});
      final requested = <String>[];
      final repo = LoteamentosImportRepository(
        fakeFirestore,
        fakeStorage,
        requestConsolidation: (draftId) async => requested.add(draftId),
      );

      await repo.approveDraft('draft-1');

      expect(requested, ['draft-1']);
    });

    test('falha no retry manual não bloqueia a aprovação', () async {
      final draft = fakeFirestore
          .collection('loteamentos_drafts')
          .doc('draft-1');
      await draft.set({'status': 'pendente'});
      final repo = LoteamentosImportRepository(
        fakeFirestore,
        fakeStorage,
        requestConsolidation: (_) async => throw Exception('callable offline'),
      );

      await repo.approveDraft('draft-1');

      expect((await draft.get()).data()?['status'], 'aprovado');
    });
  });
}
