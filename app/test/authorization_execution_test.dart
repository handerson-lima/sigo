import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/sync/operation_queue.dart';

void main() {
  group(
    'Story 2.11 — Execução de Autorização (OperationQueue & Permissões)',
    () {
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
            var items = memoryStore.values.toList();
            if (data['construtoraId'] != null) {
              items = items.where((i) {
                final payload = i['payload'] as Map<String, dynamic>?;
                return i['construtoraId'] == data['construtoraId'] ||
                    payload?['construtoraId'] == data['construtoraId'];
              }).toList();
            }
            if (data['obraId'] != null) {
              items = items.where((i) {
                final payload = i['payload'] as Map<String, dynamic>?;
                return i['obraId'] == data['obraId'] ||
                    payload?['obraId'] == data['obraId'];
              }).toList();
            }
            return jsonEncode(items);
          }
          if (action == 'claim') {
            final key = data['key'] as String;
            final item = memoryStore[key];
            if (item == null) return 'null';
            // Se já estiver em authorization_rejected, synced ou conflict, não permite claim a menos que force seja true
            if ([
                  'synced',
                  'conflict',
                  'authorization_rejected',
                ].contains(item['state']) &&
                data['force'] != true) {
              return 'null';
            }
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

      test('Erro permission-denied transiciona operação para authorization_rejected e suspende retries', () async {
        int executionAttempts = 0;

        final queue = OperationQueue(
          sessionUid: () => 'user-sem-acesso',
          store: fakeStore,
          upload: fakeUpload,
          execute: (action, payload) async {
            executionAttempts++;
            executedCalls.add({'action': action, 'payload': payload});
            throw FirebaseFunctionsException(
              code: 'permission-denied',
              message: 'Estoque não autorizado',
            );
          },
          autoSync: false,
        );

        await queue.enqueue('stockCommand', {
          'operationId': 'op-auth-001',
          'construtoraId': 'c-bloqueada',
          'obraId': 'o-bloqueada',
          'materialId': 'mat-001',
          'type': 'saida',
          'quantity': 1000,
        });

        // 1. Dispara o primeiro ciclo de sync
        await queue.sync();

        expect(executionAttempts, equals(1));
        final itemsAfterFirstSync = await queue.list();
        expect(itemsAfterFirstSync.length, equals(1));
        expect(
          itemsAfterFirstSync.first['state'],
          equals('authorization_rejected'),
        );
        expect(
          itemsAfterFirstSync.first['error'],
          contains('permission-denied'),
        );

        // 2. Dispara novos ciclos de sync automáticos
        await queue.sync();
        await queue.sync();

        // Nenhuma nova tentativa deve ser feita pelo motor de sync automático
        expect(executionAttempts, equals(1));
        final itemsAfterSubsequentSync = await queue.list();
        expect(
          itemsAfterSubsequentSync.first['state'],
          equals('authorization_rejected'),
        );
      });

      test('Erro unauthenticated transiciona operação para failed (recuperável após renovação da sessão)', () async {
        int executionAttempts = 0;

        final queue = OperationQueue(
          sessionUid: () => 'user-sessao-expirada',
          store: fakeStore,
          upload: fakeUpload,
          execute: (action, payload) async {
            executionAttempts++;
            throw FirebaseFunctionsException(
              code: 'unauthenticated',
              message: 'A conta mudou. Entre novamente.',
            );
          },
          autoSync: false,
        );

        await queue.enqueue('payExpense', {
          'operationId': 'op-pay-auth-002',
          'construtoraId': 'c-1',
          'despesaId': 'desp-001',
        });

        await queue.sync();

        expect(executionAttempts, equals(1));
        final items = await queue.list();
        expect(items.first['state'], equals('failed'));
        expect(items.first['error'], contains('unauthenticated'));
      });

      test('Erro genérico contendo "não autorizado" ou "permission-denied" classifica como authorization_rejected', () async {
        final queue = OperationQueue(
          sessionUid: () => 'user-operador',
          store: fakeStore,
          upload: fakeUpload,
          execute: (action, payload) async {
            throw StateError('Acesso não autorizado ao módulo financeiro');
          },
          autoSync: false,
        );

        await queue.enqueue('payExpense', {
          'operationId': 'op-pay-auth-003',
          'construtoraId': 'c-1',
          'despesaId': 'desp-002',
        });

        await queue.sync();

        final items = await queue.list();
        expect(items.first['state'], equals('authorization_rejected'));
        expect(items.first['error'], contains('não autorizado'));
      });

      test('Operação autorizada com sucesso comita sem falhas e atualiza estado para synced', () async {
        int executionAttempts = 0;

        final queue = OperationQueue(
          sessionUid: () => 'user-dev-global',
          store: fakeStore,
          upload: fakeUpload,
          execute: (action, payload) async {
            executionAttempts++;
            return {'movementId': 'hash-dev-001', 'quantityUnits': 5000};
          },
          autoSync: false,
        );

        await queue.enqueue('stockCommand', {
          'operationId': 'op-dev-auth-004',
          'construtoraId': 'c-qualquer',
          'obraId': 'o-qualquer',
          'materialId': 'mat-dev-1',
          'type': 'entrada',
          'quantity': 5000,
        });

        await queue.sync();

        expect(executionAttempts, equals(1));
        final items = await queue.list();
        expect(items.first['state'], equals('synced'));
        expect(items.first['result'], isNotNull);
        expect(items.first['result']['movementId'], equals('hash-dev-001'));
        expect(await queue.scopedSyncedCount(), equals(1));
      });

      test('scopedFailedCount contabiliza operações em authorization_rejected para visualização na UI', () async {
        final queue = OperationQueue(
          sessionUid: () => 'user-operario',
          store: fakeStore,
          upload: fakeUpload,
          execute: (action, payload) async {
            throw FirebaseFunctionsException(
              code: 'permission-denied',
              message: 'Diário não autorizado',
            );
          },
          autoSync: false,
        );

        await queue.enqueue('finalizeDiario', {
          'operationId': 'op-diario-auth-005',
          'construtoraId': 'c-1',
          'obraId': 'o-1',
          'diario': {'id': 'd-1'},
        });

        await queue.sync();

        // Verifica contagem com e sem escopo de obra
        expect(
          await queue.scopedFailedCount(construtoraId: 'c-1', obraId: 'o-1'),
          equals(1),
        );
        expect(
          await queue.scopedFailedCount(
            construtoraId: 'c-1',
            obraId: 'o-outra',
          ),
          equals(0),
        );
      });
    },
  );
}
