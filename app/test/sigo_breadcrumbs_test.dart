import 'package:app/src/common_widgets/sigo_breadcrumbs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _router() => GoRouter(
      initialLocation: '/construtora/c1/loteamentos/l1/quadras/q1/lotes',
      routes: [
        GoRoute(
          path: '/construtora/:cId',
          routes: [
            GoRoute(
              path: 'loteamentos/:loteamentoId',
              routes: [
                GoRoute(
                  path: 'quadras/:quadraId',
                  builder: (context, state) =>
                      const Scaffold(body: Text('quadras destino')),
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
    );

void main() {
  testWidgets('renderiza a trilha derivada do path com separadores', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
    await tester.pumpAndSettle();

    expect(find.text('Loteamento'), findsOneWidget);
    expect(find.text('Quadra'), findsOneWidget);
    expect(find.text('Lotes'), findsOneWidget);
    expect(find.text('/'), findsNWidgets(2));
  });

  testWidgets('tocar num segmento com url navega para a url', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quadra'));
    await tester.pumpAndSettle();

    expect(find.text('quadras destino'), findsOneWidget);
  });

  testWidgets('ultimo segmento nao e clicavel e nao navega', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lotes'));
    await tester.pumpAndSettle();

    expect(find.text('quadras destino'), findsNothing);
    expect(find.text('Loteamento'), findsOneWidget);
  });
}
