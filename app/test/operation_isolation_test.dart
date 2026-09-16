import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/sync/operation_queue.dart';
import 'package:app/src/sync/queue_store_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sigo_isolation_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Story 2.7 — Isolamento de Operações (OperationQueue)', () {
    test('queue.js suporta filtros de escopo opcionais (construtoraId, obraId, action)', () {
      final queueJs = File('web/queue.js');
      final js = queueJs.readAsStringSync();

      expect(
        js.contains('!input.construtoraId || r.construtoraId===input.construtoraId || r.payload?.construtoraId===input.construtoraId'),
        isTrue,
        reason: 'queue.js deve suportar filtro por construtoraId',
      );
      expect(
        js.contains('!input.obraId || r.obraId===input.obraId || r.payload?.obraId===input.obraId'),
        isTrue,
        reason: 'queue.js deve suportar filtro por obraId',
      );
      expect(
        js.contains('!input.action || r.action===input.action'),
        isTrue,
        reason: 'queue.js deve suportar filtro por action',
      );
    });

    test('Operações são estritamente isoladas e filtráveis por obra e construtora', () async {
      String? currentUser = 'alice';
      final queue = OperationQueue(
        sessionUid: () => currentUser,
        store: queueStore,
        upload: (a, b, u) async {},
        execute: (action, payload) async {},
        autoSync: false,
      );

      // Enfileira operação na Obra A
      await queue.enqueue('createDailyEntry', {
        'operationId': 'op-obra-a-1',
        'construtoraId': 'const-x',
        'obraId': 'obra-alpha',
        'content': 'Diário Alpha',
      });

      // Enfileira operação na Obra B
      await queue.enqueue('createDailyEntry', {
        'operationId': 'op-obra-b-1',
        'construtoraId': 'const-x',
        'obraId': 'obra-beta',
        'content': 'Diário Beta',
      });

      // Enfileira operação em módulo central (sem obraId)
      await queue.enqueue('createSupplier', {
        'operationId': 'op-central-1',
        'construtoraId': 'const-x',
        'name': 'Fornecedor Central',
      });

      // Listagem geral deve trazer todas as 3 operações
      final all = await queue.list();
      expect(all.length, 3);

      // Listagem da Obra Alpha deve trazer apenas a operação de Alpha
      final alphaList = await queue.list(obraId: 'obra-alpha');
      expect(alphaList.length, 1);
      expect(alphaList.first['payload']['obraId'], 'obra-alpha');
      expect(alphaList.first['payload']['operationId'], 'op-obra-a-1');

      // Listagem da Obra Beta deve trazer apenas a operação de Beta
      final betaList = await queue.list(obraId: 'obra-beta');
      expect(betaList.length, 1);
      expect(betaList.first['payload']['obraId'], 'obra-beta');
      expect(betaList.first['payload']['operationId'], 'op-obra-b-1');

      // Listagem por ação específica
      final supplierList = await queue.list(action: 'createSupplier');
      expect(supplierList.length, 1);
      expect(supplierList.first['payload']['name'], 'Fornecedor Central');

      // Contadores escopados por obra
      expect(await queue.scopedPendingCount(obraId: 'obra-alpha'), 1);
      expect(await queue.scopedPendingCount(obraId: 'obra-beta'), 1);
      expect(await queue.scopedPendingCount(obraId: 'obra-gamma'), 0);
    });

    test('Sincronização seletiva por obra processa apenas a partição alvo', () async {
      String? currentUser = 'alice';
      final executedActions = <Map<String, dynamic>>[];

      final queue = OperationQueue(
        sessionUid: () => currentUser,
        store: queueStore,
        upload: (a, b, u) async {},
        execute: (action, payload) async {
          executedActions.add({'action': action, 'payload': payload});
        },
        autoSync: false,
      );

      // Enfileira operação na Obra A
      await queue.enqueue('createDailyEntry', {
        'operationId': 'op-sync-a-1',
        'construtoraId': 'const-x',
        'obraId': 'obra-alpha',
      });

      // Enfileira operação na Obra B
      await queue.enqueue('createDailyEntry', {
        'operationId': 'op-sync-b-1',
        'construtoraId': 'const-x',
        'obraId': 'obra-beta',
      });

      // Executa sincronização apenas para Obra Alpha
      await queue.sync(obraId: 'obra-alpha');

      // Apenas Obra Alpha deve ter sido despachada para o backend
      expect(executedActions.length, 1);
      expect(executedActions.first['payload']['obraId'], 'obra-alpha');

      // Contadores pós-sync seletivo
      expect(await queue.scopedSyncedCount(obraId: 'obra-alpha'), 1);
      expect(await queue.scopedPendingCount(obraId: 'obra-alpha'), 0);
      expect(await queue.scopedPendingCount(obraId: 'obra-beta'), 1); // Permanece pendente
    });

    test('Isolamento de falhas: rejeição de autorização em uma obra não bloqueia as demais', () async {
      String? currentUser = 'alice';
      final executedOperations = <String>[];

      final queue = OperationQueue(
        sessionUid: () => currentUser,
        store: queueStore,
        upload: (a, b, u) async {},
        execute: (action, payload) async {
          final opId = payload['operationId'] as String;
          executedOperations.add(opId);
          if (payload['obraId'] == 'obra-revogada') {
            throw FirebaseException(
              plugin: 'functions',
              code: 'permission-denied',
              message: 'Acesso negado à obra',
            );
          }
        },
        autoSync: false,
      );

      // Enfileira na obra revogada
      await queue.enqueue('saveChecklist', {
        'operationId': 'op-revogada-1',
        'construtoraId': 'const-x',
        'obraId': 'obra-revogada',
      });

      // Enfileira na obra legítima
      await queue.enqueue('saveChecklist', {
        'operationId': 'op-legitima-1',
        'construtoraId': 'const-x',
        'obraId': 'obra-legitima',
      });

      // Sincronização geral de todas as pendências
      await queue.sync();

      // Ambas foram tentadas
      expect(executedOperations.contains('op-revogada-1'), isTrue);
      expect(executedOperations.contains('op-legitima-1'), isTrue);

      // Obra revogada foi isolada em authorization_rejected
      final revogadas = await queue.list(obraId: 'obra-revogada');
      expect(revogadas.first['state'], 'authorization_rejected');
      expect(await queue.scopedFailedCount(obraId: 'obra-revogada'), 1);

      // Obra legítima concluiu com synced
      final legitimas = await queue.list(obraId: 'obra-legitima');
      expect(legitimas.first['state'], 'synced');
      expect(await queue.scopedSyncedCount(obraId: 'obra-legitima'), 1);
      expect(await queue.scopedPendingCount(obraId: 'obra-legitima'), 0);
    });
  });
}
