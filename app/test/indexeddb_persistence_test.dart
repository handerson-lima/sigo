import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/sync/queue_store_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('sigo_test_idb_');
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

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Story 2.3 — Persistência Local IndexedDB (sigo-operations)', () {
    test('queue.js estrutura stores snapshots e operations com reconexão resiliente', () {
      final queueJs = File('web/queue.js');
      expect(
        queueJs.existsSync(),
        isTrue,
        reason: 'Arquivo web/queue.js deve existir',
      );
      final js = queueJs.readAsStringSync();

      // Verifica abertura da base versionada sigo-operations com versão gerenciada
      expect(
        js.contains("indexedDB.open('sigo-operations', SIGO_DB_VERSION)") ||
            js.contains("indexedDB.open('sigo-operations', 2)") ||
            js.contains("indexedDB.open('sigo-operations', 3)"),
        isTrue,
        reason: 'Deve abrir sigo-operations com versão gerenciada',
      );

      // Verifica criação atômica das stores no upgradeneeded
      expect(
        js.contains("db.createObjectStore('snapshots', {keyPath:'key'})"),
        isTrue,
        reason: 'Deve criar store snapshots com keyPath key',
      );
      expect(
        js.contains("db.createObjectStore('operations', {keyPath:'key'})"),
        isTrue,
        reason: 'Deve criar store operations com keyPath key',
      );

      // Verifica reconexão resiliente com getDb e versionchange
      expect(
        js.contains('function getDb()'),
        isTrue,
        reason:
            'Deve utilizar função getDb sob demanda para permitir reconexão',
      );
      expect(
        js.contains(
          'db.onversionchange = () => { db.close(); currentDbPromise = null; };',
        ),
        isTrue,
        reason:
            'Deve fechar conexão em onversionchange e liberar reconexão limpa',
      );
      expect(
        js.contains('request.onblocked'),
        isTrue,
        reason: 'Deve tratar evento onblocked informando bloqueio de abas',
      );
    });

    test('queue.js garante isolamento estrito por UID nas operações de cache e fila', () {
      final queueJs = File('web/queue.js');
      final js = queueJs.readAsStringSync();

      // cacheGet deve validar que o uid do snapshot confere com o uid requisitante
      expect(
        js.contains('req.result?.uid===input.uid?req.result.value:null'),
        isTrue,
        reason: 'cacheGet só deve expor dados caso uid confira com o registro',
      );

      // cacheClear deve deletar apenas registros pertencentes ao uid informado
      expect(
        js.contains(
          'if(cursor.value.uid===input.uid && (!input.prefix || (cursor.value.key && cursor.value.key.includes(input.prefix))))cursor.delete()',
        ),
        isTrue,
        reason: 'cacheClear deve purgar apenas snapshots do UID solicitante e respeitar prefixo opcional',
      );

      // list de operações deve filtrar rigorosamente pelo UID
      expect(
        js.contains('result=req.result.filter(r=>r.uid===input.uid'),
        isTrue,
        reason: 'Listagem de operações deve restringir registros pelo UID',
      );

      // Inserção na fila deve ser idempotente
      expect(
        js.contains(
          'if(action===\'insert\') { if(old) {result=old;return;} store.add(input); result=input; }',
        ),
        isTrue,
        reason: 'Inserção de operação deve ser idempotente',
      );
    });

    test('Contrato de persistência nativa: isolamento de UID e persistência de snapshots', () async {
      final docPath = 'construtoras/demo/obras/ob-1';
      final keyAlice = jsonEncode(['alice', docPath]);
      final keyBob = jsonEncode(['bob', docPath]);

      // 1. Alice grava snapshot
      await queueStore(
        'cachePut',
        jsonEncode({
          'uid': 'alice',
          'key': keyAlice,
          'value': {'name': 'Obra Alice', 'budget': 1000},
        }),
      );

      // 2. Alice lê snapshot com sucesso
      final readAlice = await queueStore(
        'cacheGet',
        jsonEncode({'uid': 'alice', 'key': keyAlice}),
      );
      expect(jsonDecode(readAlice), {'name': 'Obra Alice', 'budget': 1000});

      // 3. Bob tenta ler o mesmo arquivo com a key de Alice -> deve retornar null
      final readBobWithAliceKey = await queueStore(
        'cacheGet',
        jsonEncode({'uid': 'bob', 'key': keyAlice}),
      );
      expect(
        readBobWithAliceKey,
        'null',
        reason: 'Bob não pode acessar snapshot gravado por Alice mesmo usando a chave de Alice',
      );

      // 4. Bob grava seu próprio snapshot
      await queueStore(
        'cachePut',
        jsonEncode({
          'uid': 'bob',
          'key': keyBob,
          'value': {'name': 'Obra Bob', 'budget': 2000},
        }),
      );

      // 5. Limpeza de cache de Alice
      await queueStore('cacheClear', jsonEncode({'uid': 'alice'}));

      // Snapshot de Alice foi purgado
      final readAliceAfterClear = await queueStore(
        'cacheGet',
        jsonEncode({'uid': 'alice', 'key': keyAlice}),
      );
      expect(readAliceAfterClear, 'null');

      // Snapshot de Bob permanece intacto
      final readBobAfterAliceClear = await queueStore(
        'cacheGet',
        jsonEncode({'uid': 'bob', 'key': keyBob}),
      );
      expect(jsonDecode(readBobAfterAliceClear), {
        'name': 'Obra Bob',
        'budget': 2000,
      });
    });

    test('Contrato de persistência nativa: fila de operações idempotente e isolada de cacheClear', () async {
      final opKey = 'op-101';
      final opData = {
        'key': opKey,
        'uid': 'alice',
        'state': 'pending',
        'payload': {'action': 'registrarItem', 'quantidade': 5},
      };

      // Inserção da operação
      final insertResult1 = await queueStore('insert', jsonEncode(opData));
      expect(jsonDecode(insertResult1)['key'], opKey);

      // Inserção idempotente com payload divergente para a mesma chave deve retornar a original
      final insertResult2 = await queueStore(
        'insert',
        jsonEncode({
          ...opData,
          'payload': {'action': 'tentativaAlterar', 'quantidade': 999},
        }),
      );
      expect(
        jsonDecode(insertResult2)['payload']['quantidade'],
        5,
        reason: 'Segunda inserção com mesma chave deve retornar registro existente sem sobrescrever',
      );

      // cacheClear de Alice NÃO pode deletar operações da fila
      await queueStore('cacheClear', jsonEncode({'uid': 'alice'}));

      final listResult = await queueStore('list', jsonEncode({'uid': 'alice'}));
      final ops = (jsonDecode(listResult) as List).cast<Map<String, dynamic>>();
      expect(
        ops.any((op) => op['key'] == opKey),
        isTrue,
        reason: 'cacheClear não deve remover registros da store de operações',
      );
    });
  });
}
