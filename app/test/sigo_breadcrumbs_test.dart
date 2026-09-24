import 'package:app/src/common_widgets/sigo_breadcrumbs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('renderiza todos os segmentos e separadores', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SigoBreadcrumbs(
            segments: [
              BreadcrumbSegment(label: 'Loteamento', url: '/a'),
              BreadcrumbSegment(label: 'Quadra', url: '/b'),
              BreadcrumbSegment(label: 'Lotes'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Loteamento'), findsOneWidget);
    expect(find.text('Quadra'), findsOneWidget);
    expect(find.text('Lotes'), findsOneWidget);
    expect(find.text('/'), findsNWidgets(2));
  });

  testWidgets('tocar num segmento com url navega para a url', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: SigoBreadcrumbs(
              segments: [
                BreadcrumbSegment(label: 'Loteamento', url: '/destino'),
                BreadcrumbSegment(label: 'Lotes'),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/destino',
          builder: (context, state) => const Scaffold(body: Text('chegou')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Loteamento'));
    await tester.pumpAndSettle();

    expect(find.text('chegou'), findsOneWidget);
  });

  testWidgets('ultimo segmento nao e clicavel e nao navega', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: SigoBreadcrumbs(
              segments: [
                BreadcrumbSegment(label: 'Loteamento', url: '/destino'),
                BreadcrumbSegment(label: 'Lotes'),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/destino',
          builder: (context, state) => const Scaffold(body: Text('chegou')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Lotes'));
    await tester.pumpAndSettle();

    expect(find.text('chegou'), findsNothing);
    expect(find.text('Loteamento'), findsOneWidget);
  });
}
