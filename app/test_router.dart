import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('Test router exception', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        try {
          print('Redirecting: ${state.uri.path}, matched: ${state.matchedLocation}');
          if (state.matchedLocation == '/login') {
            return null;
          }
        } catch (e) {
          print('Error in redirect: $e');
        }
        if (state.uri.path.startsWith('/foo/')) {
          return state.uri.path.replaceFirst('/foo', '/bar');
        }
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (_, __) => Container()),
        GoRoute(path: '/bar/:id', builder: (_, __) => Container()),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/foo/123');
    await tester.pumpAndSettle();
  });
}
