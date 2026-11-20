import 'package:app/src/common_widgets/sigo_sidebar.dart';
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

  testWidgets(
    'SigoSidebar exibe Loteamentos para membro com modulo lotes na obra e oculta Membros para obraAdmin',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
            construtoraPermissionProvider('c1').overrideWith(
              (ref) => Stream.value({
                'isActive': true,
                'isAdmin': false,
                'modules': <String>[],
              }),
            ),
            effectiveLoteamentoObraIdProvider((
              construtoraId: 'c1',
              loteamentoId: 'L1',
            )).overrideWithValue(const AsyncValue.data('O1')),
            currentPermissionsProvider((construtoraId: 'c1', obraId: 'O1'))
                .overrideWith(
                  (ref) => Stream.value(
                    ObraMember(
                      userId: 'u1',
                      isActive: true,
                      isAdmin: true,
                      modules: const ['lotes'],
                      joinedAt: DateTime(2025),
                    ),
                  ),
                ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SigoSidebar(
                activeRoute: '/construtoras/c1/loteamentos/L1/quadras',
                isCollapsed: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Loteamentos'), findsOneWidget);
      expect(find.text('Membros & Acessos'), findsNothing);
    },
  );

  testWidgets(
    'SigoSidebar ignora segmento vazio com trailing slash sem consultar obra',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
            construtoraPermissionProvider('c1').overrideWith(
              (ref) => Stream.value({
                'isActive': true,
                'isAdmin': false,
                'modules': <String>[],
              }),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SigoSidebar(
                activeRoute: '/construtoras/c1/loteamentos/',
                isCollapsed: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsNothing);
      expect(find.text('Minhas Construtoras'), findsOneWidget);
    },
  );
}
