import 'dart:convert';

import 'package:app/src/sync/operation_queue.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

class Store {
  final rows = <String, Map<String, dynamic>>{};
  bool fail = false;
  Future<String> call(String action, String input) async {
    if (fail) throw StateError('QuotaExceededError');
    final a = jsonDecode(input) as Map<String, dynamic>;
    if (action == 'list') {
      return jsonEncode(
        rows.values.where((r) => r['uid'] == a['uid']).toList(),
      );
    }
    final old = rows[a['key']];
    if (action == 'insert') {
      rows.putIfAbsent(a['key'], () => a);
      return jsonEncode(rows[a['key']]);
    }
    if (old == null || old['uid'] != a['uid']) return 'null';
    if (action == 'claim') {
      if ([
        'synced',
        'conflict',
        'authorization_rejected',
      ].contains(old['state'])) {
        return 'null';
      }
      old['lease'] = a['lease'];
      old['state'] = 'syncing';
    }
    if (action == 'finish') {
      if (old['lease'] != a['lease']) return 'null';
      old['state'] = a['state'];
      old['error'] = a['error'];
    }
    return jsonEncode(old);
  }
}

Map<String, dynamic> photo(String id) => {
  'id': id,
  'bytes': base64Encode([1, 2, 3]),
  'size': 3,
  'sha256': sha256.convert([1, 2, 3]).toString(),
};
const payload = {'operationId': 'op', 'construtoraId': 'c'};
void main() {
  test(
    'falha no segundo anexo não confirma; retomada completa confirma uma vez',
    () async {
      final store = Store();
      var failSecond = true, calls = 0;
      final uploaded = <String>{};
      final queue = OperationQueue(
        sessionUid: () => 'u',
        store: store.call,
        autoSync: false,
        upload: (a, b, u) async {
          if (a['id'] == 'second' && failSecond) {
            throw StateError('Storage indisponível');
          }
          uploaded.add(a['id']);
        },
        execute: (a, p) async {
          calls++;
        },
      );
      await queue.enqueue(
        'finalizeDiario',
        payload,
        attachments: [photo('first'), photo('second')],
      );
      await queue.sync();
      expect(calls, 0);
      expect(store.rows.values.single['state'], 'failed');
      expect(uploaded, {'first'});
      failSecond = false;
      await queue.sync();
      await queue.sync();
      expect(calls, 1);
      expect(store.rows.values.single['state'], 'synced');
    },
  );
  test(
    'arquivo ausente bloqueia confirmação e quota não gera sucesso local',
    () async {
      final store = Store();
      var calls = 0;
      final q = OperationQueue(
        sessionUid: () => 'u',
        store: store.call,
        autoSync: false,
        upload: (a, b, u) async {},
        execute: (a, p) async {
          calls++;
        },
      );
      await q.enqueue(
        'finalizeDiario',
        payload,
        attachments: [
          {...photo('missing'), 'bytes': ''},
        ],
      );
      await q.sync();
      expect(calls, 0);
      expect(store.rows.values.single['state'], 'failed');
      store.fail = true;
      await expectLater(
        q.enqueue('stockCommand', {
          'operationId': 'other',
          'construtoraId': 'c',
        }),
        throwsStateError,
      );
      await q.sync();
      expect(q.lastError, isNotNull);
    },
  );
  test('troca de conta durante upload preserva fila do autor e não executa comando', () async {
    final store = Store();
    String? uid = 'u';
    var calls = 0;
    final q = OperationQueue(
      sessionUid: () => uid,
      store: store.call,
      autoSync: false,
      upload: (a, b, u) async {
        uid = 'other';
      },
      execute: (a, p) async {
        calls++;
      },
    );
    await q.enqueue('finalizeDiario', payload, attachments: [photo('first')]);
    await q.sync();
    expect(calls, 0);
    expect(await q.list(), isEmpty);
    uid = 'u';
    expect((await q.list()).single['state'], 'failed');
  });
  test(
    'sessão expirada é recuperável; revogação não faz retry automático',
    () async {
      final store = Store();
      var code = 'unauthenticated', calls = 0;
      final q = OperationQueue(
        sessionUid: () => 'u',
        store: store.call,
        autoSync: false,
        upload: (a, b, u) async {},
        execute: (a, p) async {
          calls++;
          throw FirebaseFunctionsException(code: code, message: 'negado');
        },
      );
      await q.enqueue('payExpense', payload);
      await q.sync();
      expect(store.rows.values.single['state'], 'failed');
      code = 'permission-denied';
      await q.sync();
      expect(store.rows.values.single['state'], 'authorization_rejected');
      await q.sync();
      expect(calls, 2);
    },
  );
  test(
    'resposta perdida mantém mesmo identificador e payload para o retry',
    () async {
      final store = Store();
      final ids = <String>{};
      var attempts = 0;
      final q = OperationQueue(
        sessionUid: () => 'u',
        store: store.call,
        autoSync: false,
        upload: (a, b, u) async {},
        execute: (a, p) async {
          ids.add(p['operationId']);
          attempts++;
          if (attempts == 1) throw StateError('Resposta perdida');
          expect(p['actorUid'], 'u');
        },
      );
      await q.enqueue('stockCommand', payload);
      await q.sync();
      await q.sync();
      expect(ids, {'op'});
      expect(store.rows.values.single['state'], 'synced');
    },
  );
}
