import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/sync/queue_store_native.dart';
import 'package:app/src/sync/read_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('sigo_test_partition_');
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

  group('Story 2.6 — Particionamento de Cache', () {
    test('queue.js possui suporte a filtro por prefix na ação cacheClear', () {
      final queueJs = File('web/queue.js');
      expect(queueJs.existsSync(), isTrue);
      final js = queueJs.readAsStringSync();

      expect(js.contains('input.prefix'), isTrue,
          reason: 'queue.js deve suportar input.prefix para purga particionada');
      expect(js.contains('cursor.value.key.includes(input.prefix)'), isTrue,
          reason: 'cursor deve deletar apenas chaves que contêm o prefixo');
    });

    test('Snapshots de obras diferentes são estritamente particionados para o mesmo usuário', () async {
      const uid = 'user-alice';
      final pathObraA = 'construtoras/c1/obras/obra-A/diarios';
      final pathObraB = 'construtoras/c1/obras/obra-B/diarios';

      final keyA = jsonEncode([uid, pathObraA]);
      final keyB = jsonEncode([uid, pathObraB]);

      // Grava em Obra A e Obra B
      await queueStore('cachePut', jsonEncode({
        'uid': uid,
        'key': keyA,
        'value': {'obra': 'A', 'registros': 10},
      }));

      await queueStore('cachePut', jsonEncode({
        'uid': uid,
        'key': keyB,
        'value': {'obra': 'B', 'registros': 25},
      }));

      // Lê Obra A e Obra B independentemente
      final readA = await queueStore('cacheGet', jsonEncode({'uid': uid, 'key': keyA}));
      final readB = await queueStore('cacheGet', jsonEncode({'uid': uid, 'key': keyB}));

      expect(jsonDecode(readA)['obra'], 'A');
      expect(jsonDecode(readB)['obra'], 'B');
    });

    test('clearReadCacheScope purga seletivamente apenas a partição alvo (ex: obra revogada)', () async {
      const uid = 'user-alice';
      final pathObraA = 'construtoras/c1/obras/obra-A/dados';
      final pathObraB = 'construtoras/c1/obras/obra-B/dados';
      final pathConstrutora2 = 'construtoras/c2/obras/obra-X/dados';

      final keyA = jsonEncode([uid, pathObraA]);
      final keyB = jsonEncode([uid, pathObraB]);
      final keyC2 = jsonEncode([uid, pathConstrutora2]);

      await queueStore('cachePut', jsonEncode({'uid': uid, 'key': keyA, 'value': {'status': 'ativo-A'}}));
      await queueStore('cachePut', jsonEncode({'uid': uid, 'key': keyB, 'value': {'status': 'ativo-B'}}));
      await queueStore('cachePut', jsonEncode({'uid': uid, 'key': keyC2, 'value': {'status': 'ativo-C2'}}));

      // Purga apenas o escopo da Obra A
      await clearReadCacheScope(uid, 'obras/obra-A');

      // Obra A foi purgada
      final readA = await queueStore('cacheGet', jsonEncode({'uid': uid, 'key': keyA}));
      expect(readA, 'null', reason: 'Snapshot da Obra A deve ter sido removido');

      // Obra B e Construtora C2 permanecem intactos
      final readB = await queueStore('cacheGet', jsonEncode({'uid': uid, 'key': keyB}));
      expect(jsonDecode(readB)['status'], 'ativo-B', reason: 'Snapshot da Obra B deve ser preservado');

      final readC2 = await queueStore('cacheGet', jsonEncode({'uid': uid, 'key': keyC2}));
      expect(jsonDecode(readC2)['status'], 'ativo-C2', reason: 'Snapshot de outra construtora deve ser preservado');
    });

    test('clearReadCache global elimina todas as partições do usuário sem afetar outros usuários', () async {
      const alice = 'alice-1';
      const bob = 'bob-2';
      final keyAlice = jsonEncode([alice, 'construtoras/c1/obras/o1/dados']);
      final keyBob = jsonEncode([bob, 'construtoras/c1/obras/o1/dados']);

      await queueStore('cachePut', jsonEncode({'uid': alice, 'key': keyAlice, 'value': {'user': 'alice'}}));
      await queueStore('cachePut', jsonEncode({'uid': bob, 'key': keyBob, 'value': {'user': 'bob'}}));

      // Alice desloga ou tem acesso revogado globalmente
      await clearReadCache(alice);

      final readAlice = await queueStore('cacheGet', jsonEncode({'uid': alice, 'key': keyAlice}));
      expect(readAlice, 'null');

      final readBob = await queueStore('cacheGet', jsonEncode({'uid': bob, 'key': keyBob}));
      expect(jsonDecode(readBob)['user'], 'bob');
    });
  });
}
