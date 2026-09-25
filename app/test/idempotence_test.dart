import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/financeiro/data/financeiro_repository.dart';
import 'package:app/src/sync/operation_queue.dart';

void main() {
  group('Story 2.10 — Idempotência de Comandos (OperationQueue & Repositories)', () {
    late Map<String, dynamic> memoryStore;
    late List<Map<String, dynamic>> executedCalls;
    late QueueStore fakeStore;
    late QueueUpload fakeUpload;

    setUp(() {
      memoryStore = {};
      executedCalls = [];

      fakeStore = (String action, String input) async {
        final data = jsonDecode(input);
        if (action == 'insert') {
          final key = data['key'] as String;
          if (memoryStore.containsKey(key)) {
            final existing = memoryStore[key];
            // Se o payload ou anexos forem diferentes, simula erro de integridade do storage
            if (jsonEncode(existing['payload']) !=
                    jsonEncode(data['payload']) ||
                jsonEncode(existing['attachments']) !=
                    jsonEncode(data['attachments'])) {
              throw StateError(
                'Identificador já utilizado por outra operação.',
              );
            }
            return jsonEncode(existing);
          }
          memoryStore[key] = data;
          return jsonEncode(data);
        }
        if (action == 'list') {
          return jsonEncode(memoryStore.values.toList());
        }
        if (action == 'claim') {
          final key = data['key'] as String;
          final item = memoryStore[key];
          if (item == null) return 'null';
          item['state'] = 'syncing';
          item['lease'] = data['lease'];
          return jsonEncode(item);
        }
        if (action == 'finish') {
          final key = data['key'] as String;
          final item = memoryStore[key];
          if (item == null) return 'null';
          item['state'] = data['state'];
          item['error'] = data['error'];
          if (data.containsKey('result')) {
            item['result'] = data['result'];
          }
          item['lease'] = null;
          return jsonEncode(item);
        }
        return 'null';
      };

      fakeUpload = (attachment, bytes, uid) async {};
    });

    test('Reenvio de comando após perda de ACK de rede recebe resultado estável e conclui como synced', () async {
      int serverExecutionCount = 0;
      final stableResult = {
        'movementId': 'hash-mov-001',
        'quantityUnits': 10000,
        'quantityScale': 1000,
      };

      final queue = OperationQueue(
        sessionUid: () => 'user-operador',
        store: fakeStore,
        upload: fakeUpload,
        execute: (action, payload) async {
          executedCalls.add({'action': action, 'payload': payload});
          serverExecutionCount++;
          if (serverExecutionCount == 1) {
            // Simula que a Cloud Function comitou no Firestore, mas a rede caiu antes do ACK
            throw FirebaseFunctionsException(
              code: 'unavailable',
              message: 'Conexão interrompida antes do retorno',
            );
          }
          // Na segunda chamada (retry do SyncEngine), o backend consulta commands/ e retorna o resultado original
          return stableResult;
        },
        autoSync: false,
      );

      await queue.enqueue('stockCommand', {
        'operationId': 'op-mov-001',
        'construtoraId': 'c1',
        'obraId': 'o1',
        'materialId': 'mat-1',
        'type': 'entrada',
        'quantity': '10.0',
      });

      // 1ª tentativa falha por queda de rede
      await queue.sync();
      var items = await queue.list();
      expect(items.first['state'], 'failed');
      expect(await queue.syncedCount, 0);

      // 2ª tentativa (retry com mesmo operationId) obtém o resultado idempotente do servidor
      await queue.sync(onlyKey: items.first['key']);
      items = await queue.list();
      final row = items.first;
      expect(row['state'], 'synced');
      expect(row['result'], stableResult);
      expect(await queue.syncedCount, 1);
      expect(executedCalls.length, 2);
      expect(executedCalls[0]['payload']['operationId'], 'op-mov-001');
      expect(executedCalls[1]['payload']['operationId'], 'op-mov-001');
    });

    test('Divergência de payload para o mesmo operationId é rejeitada como already-exists e transiciona para conflict', () async {
      final queue = OperationQueue(
        sessionUid: () => 'user-operador',
        store: fakeStore,
        upload: fakeUpload,
        execute: (action, payload) async {
          // Servidor detecta prior.payloadHash !== currentHash e lança already-exists
          throw FirebaseFunctionsException(
            code: 'already-exists',
            message: 'operationId com conteúdo diferente',
          );
        },
        autoSync: false,
      );

      await queue.enqueue('stockCommand', {
        'operationId': 'op-divergente',
        'construtoraId': 'c1',
        'obraId': 'o1',
        'materialId': 'mat-1',
        'type': 'saida',
        'quantity': '5.0',
      });

      await queue.sync();

      final items = await queue.list();
      final row = items.first;
      expect(row['state'], 'conflict');
      expect(row['error'], contains('operationId com conteúdo diferente'));
      expect(await queue.failedCount, 1);
    });

    test('Enfileiramento duplicado com mesmo payload e operationId preserva a operação única sem corromper a fila', () async {
      final queue = OperationQueue(
        sessionUid: () => 'user-1',
        store: fakeStore,
        upload: fakeUpload,
        execute: (action, payload) async => {'ok': true},
        autoSync: false,
      );

      final payload = {
        'operationId': 'op-duplo-clique',
        'construtoraId': 'c1',
        'obraId': 'o1',
        'materialId': 'mat-1',
        'type': 'entrada',
        'quantity': '2.0',
      };

      // Primeiro enfileiramento
      await queue.enqueue('stockCommand', payload);
      expect(await queue.pendingCount, 1);

      // Segundo enfileiramento idêntico (duplo clique)
      await queue.enqueue('stockCommand', payload);
      // A fila permanece com 1 item íntegro
      expect(await queue.pendingCount, 1);
      final list = await queue.list();
      expect(list.length, 1);
    });

    test('Enfileiramento com mesmo operationId mas payload divergente lança StateError de conflito local', () async {
      final queue = OperationQueue(
        sessionUid: () => 'user-1',
        store: fakeStore,
        upload: fakeUpload,
        execute: (action, payload) async => {'ok': true},
        autoSync: false,
      );

      await queue.enqueue('stockCommand', {
        'operationId': 'op-reuso-indevido',
        'construtoraId': 'c1',
        'obraId': 'o1',
        'materialId': 'mat-1',
        'type': 'entrada',
        'quantity': '2.0',
      });

      // Tentativa de enfileirar outro comando com mesmo id mas dados diferentes
      expect(
        () => queue.enqueue('stockCommand', {
          'operationId': 'op-reuso-indevido',
          'construtoraId': 'c1',
          'obraId': 'o1',
          'materialId': 'mat-1',
          'type': 'entrada',
          'quantity': '999.0', // diverge!
        }),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Identificador já utilizado por outra operação'),
          ),
        ),
      );
    });

    test('FinanceiroRepository.marcarComoPago gera operationId determinístico pay-despesaId prevenindo duplicidades', () async {
      final fakeFirestore = FakeFirebaseFirestore();

      // Configura OperationQueue isolado com fakeStore
      final customQueue = OperationQueue(
        sessionUid: () => 'user-financeiro',
        store: fakeStore,
        upload: fakeUpload,
        execute: (action, payload) async {
          return {'despesaId': payload['despesaId'], 'status': 'pago'};
        },
        autoSync: false,
      );

      final repo = FinanceiroRepository(fakeFirestore, queue: customQueue);

      // Chamada 1 sem operationId explícito
      await repo.marcarComoPago('c1', 'despesa-xyz');
      // Chamada 2 sem operationId explícito para a mesma despesa (duplo clique / repetição)
      await repo.marcarComoPago('c1', 'despesa-xyz');

      // Verifica itens na fila do customQueue
      final items = await customQueue.list();
      expect(items.length, 1);
      final row = items.first;
      expect(row['action'], 'payExpense');
      expect(row['payload']['despesaId'], 'despesa-xyz');
      expect(row['payload']['operationId'], 'pay-despesa-xyz');

      // Executa a sincronização idempotente
      await customQueue.sync();
      final syncedItems = await customQueue.list();
      expect(syncedItems.first['state'], 'synced');
    });

    test('Reenvio de finalização de diário já confirmado retorna status synced original sem duplicar', () async {
      final expectedResult = {'diarioId': 'diario-100', 'status': 'synced'};
      final queue = OperationQueue(
        sessionUid: () => 'user-resp',
        store: fakeStore,
        upload: fakeUpload,
        execute: (action, payload) async => expectedResult,
        autoSync: false,
      );

      await queue.enqueue('finalizeDiario', {
        'operationId': 'diario-100',
        'construtoraId': 'c1',
        'obraId': 'o1',
        'diario': {'id': 'diario-100'},
      });

      await queue.sync();
      final row = (await queue.list()).first;
      expect(row['state'], 'synced');
      expect(row['result'], expectedResult);

      final cachedResult = await queue.getResult(row['key']);
      expect(cachedResult, expectedResult);
    });
  });
}

class FakeFirebaseFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
