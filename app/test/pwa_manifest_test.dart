import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PWA Manifest & Service Worker Tests', () {
    test('manifest.json possui campos essenciais de instalação e integridade de ícones', () {
      final manifestFile = File('web/manifest.json');
      expect(
        manifestFile.existsSync(),
        isTrue,
        reason: 'web/manifest.json deve existir',
      );

      final content = manifestFile.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;

      expect(json['name'], equals('SIGO'));
      expect(json['short_name'], equals('SIGO'));
      expect(json['start_url'], equals('.'));
      expect(json['scope'], equals('.'));
      expect(json['display'], equals('standalone'));
      expect(json['background_color'], equals('#0175C2'));
      expect(json['theme_color'], equals('#0175C2'));
      expect(json['lang'], equals('pt-BR'));
      expect(json['id'], equals('sigo-pwa'));

      final icons = json['icons'] as List<dynamic>;
      expect(icons, isNotEmpty);

      for (final icon in icons) {
        final iconMap = icon as Map<String, dynamic>;
        final src = iconMap['src'] as String;
        final iconFile = File('web/$src');
        expect(
          iconFile.existsSync(),
          isTrue,
          reason: 'Ícone $src declarado no manifest deve existir em web/',
        );
      }

      final maskables = icons.where(
        (i) => (i as Map<String, dynamic>)['purpose'] == 'maskable',
      );
      expect(
        maskables,
        isNotEmpty,
        reason: 'Deve haver pelo menos um ícone maskable no manifest',
      );
    });

    test(
      'index.html contém metadados PWA, registro do ServiceWorker e manifest',
      () {
        final indexFile = File('web/index.html');
        expect(
          indexFile.existsSync(),
          isTrue,
          reason: 'web/index.html deve existir',
        );

        final html = indexFile.readAsStringSync();
        expect(html.contains('rel="manifest" href="manifest.json"'), isTrue);
        expect(
          html.contains('navigator.serviceWorker.register("sigo-sw.js")'),
          isTrue,
        );
        expect(
          html.contains('name="mobile-web-app-capable" content="yes"'),
          isTrue,
        );
        expect(html.contains('rel="apple-touch-icon"'), isTrue);
      },
    );

    test('sigo-sw.js de desenvolvimento não lança exceções e possui ciclo de vida seguro', () {
      final swFile = File('web/sigo-sw.js');
      expect(
        swFile.existsSync(),
        isTrue,
        reason: 'web/sigo-sw.js deve existir',
      );

      final js = swFile.readAsStringSync();
      expect(
        js.contains('throw new Error'),
        isFalse,
        reason: 'Worker de dev não deve lançar exceções não tratadas',
      );
      expect(js.contains("addEventListener('install'"), isTrue);
      expect(js.contains("addEventListener('activate'"), isTrue);
      expect(js.contains("addEventListener('fetch'"), isTrue);
    });

    test('prepare_pwa.py e build_pwa.sh existem e configuram worker atômico offline', () {
      final preparePy = File('tool/prepare_pwa.py');
      expect(
        preparePy.existsSync(),
        isTrue,
        reason: 'tool/prepare_pwa.py deve existir',
      );
      final prepareContent = preparePy.readAsStringSync();
      expect(prepareContent.contains("CACHE='sigo-shell-"), isTrue);
      expect(prepareContent.contains("mode==='navigate'"), isTrue);

      final buildSh = File('tool/build_pwa.sh');
      expect(
        buildSh.existsSync(),
        isTrue,
        reason: 'tool/build_pwa.sh deve existir',
      );
      final buildContent = buildSh.readAsStringSync();
      expect(buildContent.contains('--no-web-resources-cdn'), isTrue);
      expect(buildContent.contains('--pwa-strategy=none'), isTrue);
    });
  });
}
