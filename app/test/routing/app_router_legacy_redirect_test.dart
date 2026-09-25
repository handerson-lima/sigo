import 'package:flutter_test/flutter_test.dart';

// Extrai a lógica exata de app_router.dart
String? checkLegacyRedirect(Uri uri) {
  if (uri.path == '/construtora' || uri.path.startsWith('/construtora/')) {
    final newUri = uri.replace(path: uri.path.replaceFirst(RegExp(r'^/construtora'), '/construtoras'));
    return newUri.toString();
  }
  return null;
}

void main() {
  group('Router Legacy Redirects', () {
    test('Redirects /construtora exact match', () {
      final uri = Uri.parse('/construtora');
      expect(checkLegacyRedirect(uri), '/construtoras');
    });

    test('Redirects /construtora/ exato', () {
      final uri = Uri.parse('/construtora/');
      expect(checkLegacyRedirect(uri), '/construtoras/');
    });

    test('Preserves query parameters and fragments', () {
      final uri = Uri.parse('/construtora/c1/obra/o1?tab=info#section');
      expect(checkLegacyRedirect(uri), '/construtoras/c1/obra/o1?tab=info#section');
    });

    test('Does not redirect if not /construtora', () {
      final uri = Uri.parse('/construtoras/c1');
      expect(checkLegacyRedirect(uri), isNull);
    });
  });
}
