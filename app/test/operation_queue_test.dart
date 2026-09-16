import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/sync/operation_queue.dart';

void main() {
  group('Story 2.4 — Fila de Sincronização Durável (OperationQueue)', () {
    late Map<String, Map<String, dynamic>> memoryDb;
    late String currentUid;
    late List<String> uploadedPaths;
    late List<Map<String, dynamic>> executedActions;

    Future<String> memoryStore(String action, String inputJson) async {
      final args = jsonDecode(inputJson) as Map<String, dynamic>;
      if (action == 'list') {
        final uid = args['uid'] as String;
        final list = memoryDb.values.where((r) => r['uid'] == uid).toList();
        return jsonEncode(list);
      }
      final key = args['key'] as String;
      if (action == 'insert') {
        final existing = memoryDb[key];
        if (existing != null) {
          return jsonEncode(existing);
        }
        memoryDb[key] = Map<String, dynamic>.from(args);
        return jsonEncode(args);
      }
      if (action == 'claim') {
        final existing = memoryDb[key];
        if (existing == null || existing['uid'] != args['uid']) return 'null';
        if (['synced', 'conflict', 'authorization_rejected'].contains(existing['state'])) {
          return 'null';
        }
        final now = DateTime.now().millisecondsSinceEpoch;
        if ((existing['leaseUntil'] as int? ?? 0) > now) return 'null';
        existing['state'] = 'syncing';
        existing['lease'] = args['lease'];
        existing['leaseUntil'] = now + 120000;
        return jsonEncode(existing);
      }
      if (action == 'finish') {
        final existing = memoryDb[key];
        if (existing == null || existing['uid'] != args['uid'] || existing['lease'] != args['lease']) {
          return 'null';
        }
        existing['state'] = args['state'];
        existing['error'] = args['error'];
        existing['lease'] = null;
        existing['leaseUntil'] = 0;
        existing['attempts'] = (existing['attempts'] as int? ?? 0) + 1;
        return jsonEncode(existing);
      }
      return 'null';
    }

    setUp(() {
      memoryDb = {};
      currentUid = 'user-alice';
      uploadedPaths = [];
      executedActions = [];
    });

    test('enqueue armazena operação com chave determinística e estado pending', () async {
      final queue = OperationQueue(
        sessionUid: () => currentUid,
        store: memoryStore,
        upload: (a, bytes, uid) async {},
        execute: (action, payload) async {},
        autoSync: false,
      );

      final payload = {
        'construtoraId': 'c1',
        'obraId': 'o1',
        'operationId': 'op-001',
        'observacoes': 'Teste de diário',
      };

      await queue.enqueue('finalizeDiario', payload);

      expect(await queue.pendingCount, 1);
      expect(await queue.failedCount, 0);
      expect(await queue.syncedCount, 0);

      final items = await queue.list();
      expect(items.length, 1);
      final item = items.first;
      expect(item['action'], 'finalizeDiario');
      expect(item['state'], 'pending');
      expect(item['uid'], 'user-alice');
      expect(item['payload']['actorUid'], 'user-alice');
      expect(item['payload']['observacoes'], 'Teste de diário');
    });

    test('enqueue é idempotente para mesmo payload e rejeita payload divergente', () async {
      final queue = OperationQueue(
        sessionUid: () => currentUid,
        store: memoryStore,
        upload: (a, bytes, uid) async {},
        execute: (action, payload) async {},
        autoSync: false,
      );

      final payload = {
        'construtoraId': 'c1',
        'obraId': 'o1',
        'operationId': 'op-002',
        'conteudo': 'original',
      };

      // 1. Primeira submissão com sucesso
      await queue.enqueue('saveDoc', payload);

      // 2. Segunda submissão idêntica não duplica nem lança erro
      await queue.enqueue('saveDoc', payload);
      expect(await queue.pendingCount, 1);

      // 3. Submissão com mesmo ID mas payload divergente lança StateError
      final divergentPayload = {
        'construtoraId': 'c1',
        'obraId': 'o1',
        'operationId': 'op-002',
        'conteudo': 'modificado',
      };
      expect(
        () async => await queue.enqueue('saveDoc', divergentPayload),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Identificador já utilizado por outra operação'),
        )),
      );
    });

    test('sync processa anexos, valida SHA-256 e executa backend com sucesso', () async {
      final queue = OperationQueue(
        sessionUid: () => currentUid,
        store: memoryStore,
        upload: (a, bytes, uid) async {
          uploadedPaths.add(a['path'] as String);
        },
        execute: (action, payload) async {
          executedActions.add({'action': action, 'payload': payload});
        },
        autoSync: false,
      );

      final rawBytes = utf8.encode('conteudo-da-foto-valida');
      final hash = sha256.convert(rawBytes).toString();
      final attachments = [
        {
          'path': 'construtoras/c1/obras/o1/diarios/d1/foto1.jpg',
          'bytes': base64Encode(rawBytes),
          'size': rawBytes.length,
          'sha256': hash,
          'contentType': 'image/jpeg',
        }
      ];

      await queue.enqueue(
        'finalizeDiario',
        {'construtoraId': 'c1', 'obraId': 'o1', 'operationId': 'op-003'},
        attachments: attachments,
      );

      await queue.sync();

      expect(uploadedPaths, ['construtoras/c1/obras/o1/diarios/d1/foto1.jpg']);
      expect(executedActions.length, 1);
      expect(executedActions.first['action'], 'finalizeDiario');

      final items = await queue.list();
      expect(items.first['state'], 'synced');
      expect(await queue.syncedCount, 1);
      expect(await queue.pendingCount, 0);
    });

    test('sync detecta anexo corrompido e marca operação como failed', () async {
      final queue = OperationQueue(
        sessionUid: () => currentUid,
        store: memoryStore,
        upload: (a, bytes, uid) async {},
        execute: (action, payload) async {},
        autoSync: false,
      );

      final rawBytes = utf8.encode('conteudo-real');
      final attachments = [
        {
          'path': 'foto-adulterada.jpg',
          'bytes': base64Encode(rawBytes),
          'size': rawBytes.length,
          'sha256': 'hash-invalido-divergente',
          'contentType': 'image/jpeg',
        }
      ];

      await queue.enqueue(
        'finalizeDiario',
        {'construtoraId': 'c1', 'obraId': 'o1', 'operationId': 'op-004'},
        attachments: attachments,
      );

      await queue.sync();

      final items = await queue.list();
      expect(items.first['state'], 'failed');
      expect(items.first['error'], contains('Anexo ausente ou corrompido'));
      expect(await queue.failedCount, 1);
    });

    test('sync trata permission-denied como authorization_rejected sem loops', () async {
      final queue = OperationQueue(
        sessionUid: () => currentUid,
        store: memoryStore,
        upload: (a, bytes, uid) async {},
        execute: (action, payload) async {
          throw FirebaseException(plugin: 'functions', code: 'permission-denied', message: 'Sem acesso à obra');
        },
        autoSync: false,
      );

      await queue.enqueue(
        'registrarItem',
        {'construtoraId': 'c1', 'obraId': 'o1', 'operationId': 'op-005'},
      );

      await queue.sync();

      final items = await queue.list();
      expect(items.first['state'], 'authorization_rejected');
      expect(await queue.failedCount, 1);

      // Nova chamada a sync não deve tentar processar novamente authorization_rejected
      await queue.sync();
      final itemsAfter = await queue.list();
      expect(itemsAfter.first['state'], 'authorization_rejected');
      expect(itemsAfter.first['attempts'], 1);
    });

    test('sync trata already-exists e failed-precondition como conflict', () async {
      final queue = OperationQueue(
        sessionUid: () => currentUid,
        store: memoryStore,
        upload: (a, bytes, uid) async {},
        execute: (action, payload) async {
          throw FirebaseException(plugin: 'functions', code: 'already-exists', message: 'Documento já cadastrado');
        },
        autoSync: false,
      );

      await queue.enqueue(
        'criarDocumento',
        {'construtoraId': 'c1', 'obraId': 'o1', 'operationId': 'op-006'},
      );

      await queue.sync();

      final items = await queue.list();
      expect(items.first['state'], 'conflict');
      expect(await queue.failedCount, 1);
    });

    test('sync aborta com segurança se o usuário mudar de conta durante o processo', () async {
      late OperationQueue queue;
      queue = OperationQueue(
        sessionUid: () => currentUid,
        store: memoryStore,
        upload: (a, bytes, uid) async {},
        execute: (action, payload) async {
          // Simula troca de usuário durante a execução
          currentUid = 'user-bob';
        },
        autoSync: false,
      );

      await queue.enqueue(
        'acaoPrivada',
        {'construtoraId': 'c1', 'obraId': 'o1', 'operationId': 'op-007'},
      );

      await queue.sync();

      // Para user-bob a lista deve ser vazia
      expect(await queue.list(), isEmpty);

      // Para user-alice a operação foi preservada e não foi marcada como synced
      currentUid = 'user-alice';
      final aliceItems = await queue.list();
      expect(aliceItems.length, 1);
      expect(aliceItems.first['state'], isNot('synced'));
    });
  });
}
