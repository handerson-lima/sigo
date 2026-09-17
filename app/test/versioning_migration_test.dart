import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/sync/operation_queue.dart';
import 'package:app/src/sync/queue_store_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('sigo_migration_test_');
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

  group('Story 2.14 — Estrutura de Versionamento e Migração em queue.js', () {
    late String js;

    setUpAll(() {
      final queueJs = File('web/queue.js');
      expect(queueJs.existsSync(), isTrue, reason: 'Arquivo web/queue.js deve existir');
      js = queueJs.readAsStringSync();
    });

    test('define constante de versão de schema e abertura versionada', () {
      expect(js.contains('const SIGO_DB_VERSION = 3'), isTrue,
          reason: 'Deve declarar constante SIGO_DB_VERSION = 3');
      expect(js.contains("indexedDB.open('sigo-operations', SIGO_DB_VERSION)"), isTrue,
          reason: 'Deve abrir banco utilizando a constante de versão de schema');
    });

    test('implementa runner ordenado e sequencial de migrações por oldVersion', () {
      expect(js.contains('request.onupgradeneeded = (event) => {'), isTrue,
          reason: 'Deve receber o evento de upgrade no handler');
      expect(js.contains('const oldVersion = event.oldVersion'), isTrue,
          reason: 'Deve capturar oldVersion do evento');

      // Passo v1: criação da store operations
      expect(js.contains('if (oldVersion < 1)'), isTrue,
          reason: 'Deve verificar migração v1 para criação de operations');
      expect(js.contains("db.createObjectStore('operations', {keyPath:'key'})"), isTrue);

      // Passo v2: criação da store snapshots
      expect(js.contains('if (oldVersion < 2)'), isTrue,
          reason: 'Deve verificar migração v2 para criação de snapshots');
      expect(js.contains("db.createObjectStore('snapshots', {keyPath:'key'})"), isTrue);

      // Passo v3: criação da store meta
      expect(js.contains('if (oldVersion < 3)'), isTrue,
          reason: 'Deve verificar migração v3 para criação de meta');
      expect(js.contains("db.createObjectStore('meta', {keyPath:'key'})"), isTrue);
    });

    test('registra metadados na store meta durante o upgrade sem tocar nas stores de dados', () {
      expect(js.contains("metaStore.put({"), isTrue);
      expect(js.contains("key: 'schema_version'"), isTrue);
      expect(js.contains("version: SIGO_DB_VERSION"), isTrue);
      expect(js.contains("previousVersion: oldVersion"), isTrue);
      expect(js.contains("migratedAt: Date.now()"), isTrue);

      // Garante que não existem métodos destrutivos no queue.js
      expect(js.contains('deleteDatabase'), isFalse,
          reason: 'Nunca deve chamar deleteDatabase');
      expect(js.contains('clear()'), isFalse,
          reason: 'Nunca deve limpar a fila operations automaticamente');
    });

    test('fornece tratamento de concorrência com onblocked e versionchange', () {
      expect(js.contains('request.onblocked'), isTrue);
      expect(js.contains('Feche as outras abas para atualizar a fila'), isTrue,
          reason: 'Deve alertar o usuário para fechar outras abas concorrentes');
      expect(js.contains('db.onversionchange = () => { db.close(); currentDbPromise = null; };'), isTrue,
          reason: 'Deve fechar conexão em onversionchange permitindo que a outra aba complete a migração');
    });

    test('expõe ação getSchemaVersion na API global sigoQueue', () {
      expect(js.contains("action === 'getSchemaVersion'"), isTrue,
          reason: 'sigoQueue deve responder à ação getSchemaVersion');
      expect(js.contains("store.get('schema_version')"), isTrue,
          reason: 'Deve ler metadados da store meta');
    });
  });

  group('Story 2.14 — Preservação de Comandos e Anexos através de Migrações (Nativo / Contrato)', () {
    test('getSchemaVersion retorna metadados válidos de schema v3', () async {
      final res = await queueStore('getSchemaVersion', '{}');
      final map = jsonDecode(res) as Map<String, dynamic>;

      expect(map['version'], 3);
      expect(map['schema'], 'sigo-operations');
      expect(map['migratedAt'], isNotNull);
    });

    test('upgrade de versão preserva comandos pendentes e anexos de fotos íntegros', () async {
      final opKey = 'op-migration-101';
      final photoBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

      // 1. Simula estado gravado na versão anterior (v1/v2) com anexo de foto
      final legacyPayload = {
        'key': opKey,
        'uid': 'user-worker-1',
        'state': 'pending',
        'action': 'salvarDiario',
        'construtoraId': 'const-10',
        'obraId': 'obra-20',
        'attachments': [
          {
            'path': 'obras/obra-20/fotos/foto1.png',
            'size': 1024,
            'sha256': 'dummy-sha-256',
            'bytes': photoBase64,
          }
        ],
        'payload': {
          'descricao': 'Concretagem da laje nível 2',
          'data': '2026-09-16',
        },
      };

      final insertRes = await queueStore('insert', jsonEncode(legacyPayload));
      expect(jsonDecode(insertRes)['key'], opKey);

      // Também grava snapshot de leitura pré-migração
      final cacheKey = jsonEncode(['user-worker-1', 'obras/obra-20/detalhes']);
      await queueStore('cachePut', jsonEncode({
        'uid': 'user-worker-1',
        'key': cacheKey,
        'value': {'nome': 'Residencial Horizonte', 'fase': 'Estrutura'},
      }));

      // 2. Executa migração simulada de schema definindo nova versão
      await queueStore('setSchemaVersion', jsonEncode({
        'version': 3,
        'schema': 'sigo-operations',
        'previousVersion': 2,
        'migratedAt': DateTime.now().millisecondsSinceEpoch,
      }));

      // 3. Verifica se a versão foi atualizada
      final versionRes = await queueStore('getSchemaVersion', '{}');
      final versionMap = jsonDecode(versionRes) as Map<String, dynamic>;
      expect(versionMap['version'], 3);
      expect(versionMap['previousVersion'], 2);

      // 4. Invariante crítica: comando na fila deve permanecer intacto
      final listRes = await queueStore('list', jsonEncode({'uid': 'user-worker-1'}));
      final ops = (jsonDecode(listRes) as List).cast<Map<String, dynamic>>();

      final migratedOp = ops.firstWhere((o) => o['key'] == opKey);
      expect(migratedOp['state'], 'pending');
      expect(migratedOp['action'], 'salvarDiario');

      // 5. Invariante crítica: bytes do anexo da foto permanecem 100% íntegros
      final attachments = (migratedOp['attachments'] as List).cast<Map<String, dynamic>>();
      expect(attachments.length, 1);
      expect(attachments.first['bytes'], photoBase64);
      expect(attachments.first['path'], 'obras/obra-20/fotos/foto1.png');

      // 6. Snapshot de leitura também permanece acessível
      final cacheRes = await queueStore('cacheGet', jsonEncode({
        'uid': 'user-worker-1',
        'key': cacheKey,
      }));
      expect(jsonDecode(cacheRes)['nome'], 'Residencial Horizonte');
    });

    test('preserva comandos em diferentes estados operacionais (syncing, failed, conflict, rejected)', () async {
      final states = ['pending', 'syncing', 'failed', 'conflict', 'authorization_rejected'];

      for (int i = 0; i < states.length; i++) {
        final state = states[i];
        final key = 'op-state-$state';
        await queueStore('insert', jsonEncode({
          'key': key,
          'uid': 'user-multi-state',
          'state': state,
          'action': 'operacaoTeste',
          'payload': {'index': i},
        }));
      }

      // Executa migração
      await queueStore('setSchemaVersion', jsonEncode({
        'version': 3,
        'migratedAt': DateTime.now().millisecondsSinceEpoch,
      }));

      // Verifica todos os estados preservados
      final listRes = await queueStore('list', jsonEncode({'uid': 'user-multi-state'}));
      final ops = (jsonDecode(listRes) as List).cast<Map<String, dynamic>>();

      for (final state in states) {
        final key = 'op-state-$state';
        final op = ops.firstWhere((o) => o['key'] == key, orElse: () => {});
        expect(op['state'], state, reason: 'Estado $state deve ser preservado após migração');
      }
    });

    test('OperationQueue.getSchemaVersion integra com o motor de persistência', () async {
      final queue = OperationQueue(
        sessionUid: () => 'test-uid',
        store: queueStore,
        upload: (a, b, uid) async {},
        execute: (a, p) async => {'ok': true},
        autoSync: false,
      );

      final versionInfo = await queue.getSchemaVersion();
      expect(versionInfo['version'], 3);
      expect(versionInfo['schema'], 'sigo-operations');
    });
  });
}
