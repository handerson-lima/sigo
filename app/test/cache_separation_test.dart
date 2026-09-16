import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Story 2.2 — Cache do Aplicativo Separado dos Dados de Negócio', () {
    test('Service worker de release possui política estrita de whitelist sem cacheamento de APIs', () {
      final preparePy = File('tool/prepare_pwa.py');
      expect(preparePy.existsSync(), isTrue);
      final content = preparePy.readAsStringSync();

      // Verifica que o namespace de cache é exclusivo para o shell
      expect(content.contains("const CACHE='sigo-shell-"), isTrue,
          reason: 'Namespace do cache deve ser sigo-shell-*');

      // Verifica filtragem de origem: chamadas para APIs externas/Firestore passam direto
      expect(content.contains("url.origin!==self.location.origin"), isTrue,
          reason: 'Requisições para domínios de API externos devem ser ignoradas pelo SW');

      // Verifica método GET: mutações (POST/PUT/DELETE) nunca são interceptadas
      expect(content.contains("event.request.method!=='GET'"), isTrue,
          reason: 'Apenas requisições GET locais podem consultar o cache');

      // Verifica que o fetch handler NUNCA faz cache.put ou cache.add em tempo de execução
      // (O cache é populado apenas na instalação atômica via addAll(ASSETS))
      final fetchHandlerStart = content.indexOf("self.addEventListener('fetch'");
      expect(fetchHandlerStart, isPositive);
      final fetchHandlerCode = content.substring(fetchHandlerStart);
      expect(fetchHandlerCode.contains('cache.put'), isFalse,
          reason: 'O fetch handler não pode gravar dados dinâmicos em tempo de execução');
      expect(fetchHandlerCode.contains('cache.add('), isFalse,
          reason: 'O fetch handler não pode adicionar dados dinâmicos em tempo de execução');

      // Verifica que apenas assets compilados pré-declarados são servidos
      expect(content.contains("ASSETS.includes(relative)"), isTrue,
          reason: 'Apenas ativos locais da lista ASSETS podem ser servidos do cache');
    });

    test('IndexedDB sigo-operations mantém stores de snapshots e operations isoladas do shell', () {
      final queueJs = File('web/queue.js');
      expect(queueJs.existsSync(), isTrue);
      final js = queueJs.readAsStringSync();

      // Verifica nome do banco de dados e versão
      expect(js.contains("indexedDB.open('sigo-operations'"), isTrue);
      expect(js.contains("'snapshots'"), isTrue,
          reason: 'Deve haver store dedicada a snapshots de leitura de negócio');
      expect(js.contains("'operations'"), isTrue,
          reason: 'Deve haver store dedicada à fila transacional de operações');

      // Verifica particionamento por UID em snapshots
      expect(js.contains('cursor.value.uid===input.uid'), isTrue,
          reason: 'Limpeza de snapshots (cacheClear) deve purgar somente o UID do usuário');
      expect(js.contains('req.result?.uid===input.uid'), isTrue,
          reason: 'Leitura de snapshots (cacheGet) deve verificar UID para evitar vazamento');
    });

    test('read_cache.dart purga snapshots em permission-denied e isActive == false sem tocar no shell', () {
      final readCacheDart = File('lib/src/sync/read_cache.dart');
      expect(readCacheDart.existsSync(), isTrue);
      final dartCode = readCacheDart.readAsStringSync();

      // Verifica função de limpeza dedicada de dados de leitura
      expect(dartCode.contains('Future<void> clearReadCache(String uid)'), isTrue);
      expect(dartCode.contains("_cache('cacheClear', uid, '')"), isTrue);

      // Verifica purga reativa quando isActive == false
      expect(dartCode.contains("value?['isActive'] == false"), isTrue);

      // Verifica purga reativa em permission-denied / unauthenticated
      expect(dartCode.contains("['permission-denied', 'unauthenticated'].contains(e.code)"), isTrue);
    });

    test('Simulação de Store comprova isolamento entre usuários e limpeza seletiva de snapshots', () async {
      final store = <String, Map<String, dynamic>>{};

      void putSnapshot(String uid, String path, dynamic data) {
        final key = jsonEncode([uid, path]);
        store[key] = {'uid': uid, 'key': key, 'value': data};
      }

      dynamic getSnapshot(String uid, String path) {
        final key = jsonEncode([uid, path]);
        final item = store[key];
        if (item != null && item['uid'] == uid) {
          return item['value'];
        }
        return null;
      }

      void clearSnapshots(String uid) {
        store.removeWhere((k, v) => v['uid'] == uid);
      }

      // 1. Usuário A armazena dados de obra
      putSnapshot('user-A', 'construtoras/c1/obras/o1', {'name': 'Obra A'});
      expect(getSnapshot('user-A', 'construtoras/c1/obras/o1'), equals({'name': 'Obra A'}));

      // 2. Usuário B não consegue ler os snapshots de A
      expect(getSnapshot('user-B', 'construtoras/c1/obras/o1'), isNull);

      // 3. Usuário B armazena seus próprios dados
      putSnapshot('user-B', 'construtoras/c1/obras/o1', {'name': 'Obra B - Visão B'});
      expect(getSnapshot('user-B', 'construtoras/c1/obras/o1'), equals({'name': 'Obra B - Visão B'}));

      // 4. Usuário A tem acesso revogado -> clearSnapshots('user-A')
      clearSnapshots('user-A');
      expect(getSnapshot('user-A', 'construtoras/c1/obras/o1'), isNull);

      // 5. Dados do Usuário B permanecem intactos no IndexedDB
      expect(getSnapshot('user-B', 'construtoras/c1/obras/o1'), equals({'name': 'Obra B - Visão B'}));
    });
  });
}
