import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/obras/domain/obra.dart';
import 'package:app/src/features/obras/domain/obra_member.dart';
import 'package:app/src/features/obras/presentation/construtora_obras_provider.dart';
import 'package:app/src/features/obras/presentation/current_permissions_provider.dart';
import 'package:app/src/features/obras/presentation/obra_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'alternar de Obra A para Obra B no seletor recalcula layout imediatamente',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final router = GoRouter(
        initialLocation: '/construtora/c1/obra/obraA',
        routes: [
          GoRoute(
            path: '/construtora/:cId/obra/:oId',
            builder: (context, state) {
              final cId = state.pathParameters['cId']!;
              final oId = state.pathParameters['oId']!;
              return ObraDashboardScreen(construtoraId: cId, obraId: oId);
            },
          ),
        ],
      );

      final obrasList = [
        Obra(
          id: 'obraA',
          construtoraId: 'c1',
          name: 'Obra Alfa',
          createdAt: DateTime(2025),
        ),
        Obra(
          id: 'obraB',
          construtoraId: 'c1',
          name: 'Obra Beta',
          createdAt: DateTime(2025),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
            construtoraObrasProvider('c1').overrideWith(
              (ref) => Future.value(obrasList),
            ),
            currentPermissionsProvider((construtoraId: 'c1', obraId: 'obraA'))
                .overrideWith(
                  (ref) => Stream.value(
                    ObraMember(
                      userId: 'u1',
                      isActive: true,
                      isAdmin: false,
                      modules: ['diario'],
                      joinedAt: DateTime(2025),
                    ),
                  ),
                ),
            currentPermissionsProvider((construtoraId: 'c1', obraId: 'obraB'))
                .overrideWith(
                  (ref) => Stream.value(
                    ObraMember(
                      userId: 'u1',
                      isActive: true,
                      isAdmin: false,
                      modules: ['lotes'],
                      joinedAt: DateTime(2025),
                    ),
                  ),
                ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      // Na Obra A: exibe Diário de Obra (na sidebar e no dashboard card), não exibe Lotes
      expect(find.text('Diário de Obra'), findsNWidgets(2));
      expect(find.text('Lotes e Setores'), findsNothing);

      // Abre dropdown do seletor de obra e seleciona Obra Beta
      final dropdown = find.byKey(const Key('obra-switcher-dropdown'));
      expect(dropdown, findsOneWidget);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      final itemB = find.byKey(const Key('obra-switcher-item-obraB')).last;
      await tester.tap(itemB);
      await tester.pumpAndSettle();

      // Na Obra B: atualiza instantaneamente para exibir Lotes e Setores e ocultar Diário
      expect(find.text('Lotes e Setores'), findsNWidgets(2));
      expect(find.text('Diário de Obra'), findsNothing);
    },
  );
}
