import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/obras/domain/obra_member.dart';
import 'package:app/src/features/obras/presentation/current_permissions_provider.dart';
import 'package:app/src/features/obras/presentation/obra_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('SigoSidebar nav items hidden for inactive obra', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final router = GoRouter(
      initialLocation: '/construtoras/c1/obra/obraA',
      routes: [
        GoRoute(
          path: '/construtoras/:cId/obra/:oId',
          builder: (context, state) {
            final cId = state.pathParameters['cId']!;
            final oId = state.pathParameters['oId']!;
            return ObraDashboardScreen(construtoraId: cId, obraId: oId);
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedDevProvider.overrideWith((ref) => Stream.value(false)),
          currentPermissionsProvider((construtoraId: 'c1', obraId: 'obraA'))
              .overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Loteamentos'), findsNothing);
    expect(find.text('Diário de Loteamento'), findsNothing);
  });

  testWidgets('SigoSidebar normaliza modulos legados e exibe item correto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final router = GoRouter(
      initialLocation: '/construtoras/c1/obra/obraA',
      routes: [
        GoRoute(
          path: '/construtoras/:cId/obra/:oId',
          builder: (context, state) {
            final cId = state.pathParameters['cId']!;
            final oId = state.pathParameters['oId']!;
            return ObraDashboardScreen(construtoraId: cId, obraId: oId);
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedDevProvider.overrideWith((ref) => Stream.value(false)),
          currentPermissionsProvider((construtoraId: 'c1', obraId: 'obraA'))
              .overrideWith(
                (ref) => Stream.value(
                  ObraMember(
                    userId: 'u1',
                    isActive: true,
                    isAdmin: false,
                    modules: ['rdo'],
                    joinedAt: DateTime(2025),
                  ),
                ),
              ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Diário de Loteamento'), findsWidgets);
  });
}
