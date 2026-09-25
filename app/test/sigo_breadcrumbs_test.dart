import 'package:app/src/common_widgets/sigo_breadcrumbs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _router() => GoRouter(
  initialLocation: '/construtoras/c1/loteamentos/l1/quadras/q1/lotes',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(body: Text('root destino')),
    ),
    GoRoute(
      path: '/construtoras/:cId',
      builder: (context, state) => const SizedBox(),
      routes: [
        GoRoute(
          path: 'loteamentos',
          builder: (context, state) =>
              const Scaffold(body: Text('loteamentos destino')),
          routes: [
            GoRoute(
              path: ':loteamentoId',
              builder: (context, state) => const SizedBox(),
              routes: [
                GoRoute(
                  path: 'quadras',
                  builder: (context, state) =>
                      const Scaffold(body: Text('quadras destino')),
                  routes: [
                    GoRoute(
                      path: ':quadraId',
                      builder: (context, state) => const SizedBox(),
                      routes: [
                        GoRoute(
                          path: 'lotes',
                          builder: (context, state) =>
                              const Scaffold(body: SigoBreadcrumbs()),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets('renderiza a trilha derivada do path com separadores', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
    await tester.pumpAndSettle();

    expect(find.text('Minhas Construtoras'), findsOneWidget);
    expect(find.text('Construtora'), findsOneWidget);
    expect(find.text('Loteamento'), findsOneWidget);
    expect(find.text('Quadra'), findsOneWidget);
    expect(find.text('Lotes'), findsOneWidget);
    expect(find.text('/'), findsNWidgets(4));
  });

  testWidgets('tocar num segmento com url navega para a lista do nivel', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quadra'));
    await tester.pumpAndSettle();

    expect(find.text('quadras destino'), findsOneWidget);
  });

  testWidgets('tocar em Minhas Construtoras navega para raiz', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Minhas Construtoras'));
    await tester.pumpAndSettle();

    expect(find.text('root destino'), findsOneWidget);
  });

  testWidgets(
    'tocar no segmento Loteamento navega para a lista de loteamentos',
    (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Loteamento'));
      await tester.pumpAndSettle();

      expect(find.text('loteamentos destino'), findsOneWidget);
    },
  );

  testWidgets('ultimo segmento nao e clicavel e nao navega', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lotes'));
    await tester.pumpAndSettle();

    expect(find.text('quadras destino'), findsNothing);
    expect(find.text('Loteamento'), findsOneWidget);
  });
}
