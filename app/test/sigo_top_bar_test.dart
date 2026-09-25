import 'package:app/src/common_widgets/sigo_top_bar.dart';
import 'package:app/src/features/authentication/data/auth_repository.dart';
import 'package:app/src/features/loteamentos/domain/loteamento.dart';
import 'package:app/src/features/loteamentos/data/loteamento_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('SigoTopBar usa activeRoute explicito sem router', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final List<Loteamento> loteamentosList = [
      Loteamento(
        id: 'o9',
        construtoraId: 'c9',
        name: 'Obra Nove',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      ),
    ];

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            appBar: SigoTopBar(
              title: 'Painel',
              activeRoute: '/construtoras/c9/loteamentos/o9',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
          watchLoteamentosProvider((construtoraId: 'c9'))
              .overrideWith((ref) => Stream.value(loteamentosList)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('loteamento-switcher-dropdown')),
      findsOneWidget,
    );
  });
}
