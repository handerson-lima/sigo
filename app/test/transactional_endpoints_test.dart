import 'dart:convert';


import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/sync/operation_queue.dart';

void main() {
  group('Story 2.9 — Endpoints Transacionais (OperationQueue)', () {
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
          if (memoryStore.containsKey(key)) return jsonEncode(memoryStore[key]);
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

    test('Endpoint transacional de estoque retorna dados confirmados de saldo',
        () async {
      final expectedResult = {
        'movementId': 'hash-mov-1',
        'quantityUnits': 8000,
        'quantityScale': 1000,
      };

      final queue = OperationQueue(
        sessionUid: () => 'user-test',
        store: fakeStore,
        upload: fakeUpload,
        execute: (action, payload) async {
          executedCalls.add({'action': action, 'payload': payload});
          return expectedResult;
        },
        autoSync: false,
      );

      await queue.enqueue('stockCommand', {
        'operationId': 'op-estoque-1',
        'construtoraId': 'c1',
        'obraId': 'o1',
        'materialId': 'mat-cimento',
        'type': 'saida',
        'quantity': '2.0',
      });

      expect(await queue.pendingCount, 1);
      await queue.sync();

      expect(await queue.syncedCount, 1);
      expect(await queue.pendingCount, 0);
      expect(executedCalls.length, 1);
      expect(executedCalls.first['action'], 'stockCommand');

      final items = await queue.list();
      final row = items.first;
      expect(row['state'], 'synced');
      expect(row['result'], expectedResult);

      final result = await queue.getResult(row['key']);
      expect(result, isNotNull);
      expect(result['movementId'], 'hash-mov-1');
      expect(result['quantityUnits'], 8000);
    });

    test('Endpoint transacional financeiro confirma quitação de despesa',
        () async {
      final expectedResult = {
        'despesaId': 'desp-42',
        'status': 'pago',
      };

      final queue = OperationQueue(
        sessionUid: () => 'user-admin',
        store: fakeStore,
        upload: fakeUpload,
        execute: (action, payload) async {
          executedCalls.add({'action': action, 'payload': payload});
          return expectedResult;
        },
        autoSync: false,
      );

      await queue.enqueue('payExpense', {
        'operationId': 'op-pay-42',
        'construtoraId': 'c1',
        'despesaId': 'desp-42',
      });

      await queue.sync();
      expect(await queue.syncedCount, 1);

      final row = (await queue.list()).first;
      expect(row['result']['status'], 'pago');
    });

    test(
        'Falha de validação transacional (saldo insuficiente / failed-precondition) transiciona para conflict',
        () async {
      final queue = OperationQueue(
        sessionUid: () => 'user-test',
        store: fakeStore,
        upload: fakeUpload,
        execute: (action, payload) async {
          throw FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'Saldo insuficiente ou fora do limite',
          );
        },
        autoSync: false,
      );

      await queue.enqueue('stockCommand', {
        'operationId': 'op-estoque-conflito',
        'construtoraId': 'c1',
        'materialId': 'mat-cimento',
        'type': 'saida',
        'quantity': '9999.0',
      });

      await queue.sync();

      final row = (await queue.list()).first;
      expect(row['state'], 'conflict');
      expect(row['error'], contains('Saldo insuficiente'));
      expect(await queue.failedCount, 1);
    });

    test(
        'Rejeição transacional de autorização transiciona para authorization_rejected',
        () async {
      final queue = OperationQueue(
        sessionUid: () => 'user-sem-acesso',
        store: fakeStore,
        upload: fakeUpload,
        execute: (action, payload) async {
          throw FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'Estoque não autorizado',
          );
        },
        autoSync: false,
      );

      await queue.enqueue('stockCommand', {
        'operationId': 'op-sem-permissao',
        'construtoraId': 'c1',
        'materialId': 'mat-cimento',
        'type': 'saida',
        'quantity': '1.0',
      });

      await queue.sync();

      final row = (await queue.list()).first;
      expect(row['state'], 'authorization_rejected');
      expect(row['error'], contains('Estoque não autorizado'));
      expect(await queue.failedCount, 1);
    });

    test(
        'Falha transitória do serviço transiciona para failed e permite retentativa',
        () async {
      var attempt = 0;
      final queue = OperationQueue(
        sessionUid: () => 'user-test',
        store: fakeStore,
        upload: fakeUpload,
        execute: (action, payload) async {
          attempt++;
          if (attempt == 1) {
            throw FirebaseFunctionsException(
              code: 'unavailable',
              message: 'Serviço temporariamente indisponível',
            );
          }
          return {'ok': true, 'diarioId': 'd1', 'status': 'synced'};
        },
        autoSync: false,
      );

      await queue.enqueue('finalizeDiario', {
        'operationId': 'op-diario-1',
        'construtoraId': 'c1',
        'obraId': 'o1',
      });

      // Primeira tentativa falha temporariamente
      await queue.sync();
      var row = (await queue.list()).first;
      expect(row['state'], 'failed');

      // Segunda tentativa com rede/serviço restabelecido obtém sucesso
      await queue.sync(onlyKey: row['key']);
      row = (await queue.list()).first;
      expect(row['state'], 'synced');
      expect(row['result']['status'], 'synced');
    });

    test(
        'Comandos de obras diferentes são processados e isolados transacionalmente',
        () async {
      final queue = OperationQueue(
        sessionUid: () => 'user-test',
        store: fakeStore,
        upload: fakeUpload,
        execute: (action, payload) async {
          final obraId = payload['obraId'];
          if (obraId == 'o-falha') {
            throw FirebaseFunctionsException(
              code: 'failed-precondition',
              message: 'Obra ausente ou bloqueada',
            );
          }
          return {'status': 'synced', 'obraId': obraId};
        },
        autoSync: false,
      );

      await queue.enqueue('finalizeDiario', {
        'operationId': 'op-obra-1',
        'construtoraId': 'c1',
        'obraId': 'o-sucesso',
      });

      await queue.enqueue('finalizeDiario', {
        'operationId': 'op-obra-2',
        'construtoraId': 'c1',
        'obraId': 'o-falha',
      });

      await queue.sync();

      final items = await queue.list();
      final op1 = items.firstWhere((i) => i['obraId'] == 'o-sucesso');
      final op2 = items.firstWhere((i) => i['obraId'] == 'o-falha');

      expect(op1['state'], 'synced');
      expect(op1['result']['status'], 'synced');
      expect(op2['state'], 'conflict');
    });
  });
}
