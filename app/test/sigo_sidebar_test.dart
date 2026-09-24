import 'package:app/src/features/authentication/data/user_repository.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/lotes/presentation/obra_lotes_provider.dart';
import 'package:app/src/features/obras/domain/obra_member.dart';
import 'package:app/src/features/obras/presentation/current_permissions_provider.dart';
import 'package:app/src/features/obras/presentation/obra_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'SigoSidebar nav items hidden for inactive obra',
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
              return ObraDashboardScreen(construtoraId: cId, loteamentoId: oId);
            }, quadraId: oId);
            }, status: LoteStatus.noPrazo,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
            currentPermissionsProvider(
              (construtoraId: 'c1', loteamentoId: 'obraA'), quadraId: 'obraA'), status: LoteStatus.noPrazo,
            ).overrideWith((ref) => Stream.value(null)),
            obraLotesProvider((construtoraId: 'c1', loteamentoId: 'obraA'))
                .overrideWith((ref) => Stream.value(<Lote>[])), quadraId: 'obraA'))
                .overrideWith((ref) => Stream.value(<Lote>[])), status: LoteStatus.noPrazo,
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Lotes e Setores'), findsNothing);
      expect(find.text('Diário de Obra'), findsNothing);
    },
  );

  testWidgets(
    'SigoSidebar normaliza modulos legados e exibe item correto',
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
              return ObraDashboardScreen(construtoraId: cId, loteamentoId: oId);
            }, quadraId: oId);
            }, status: LoteStatus.noPrazo,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustedDevProvider.overrideWith((ref) => Stream.value(false)),
            currentPermissionsProvider(
              (construtoraId: 'c1', loteamentoId: 'obraA'), quadraId: 'obraA'), status: LoteStatus.noPrazo,
            ).overrideWith(
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
            obraLotesProvider((construtoraId: 'c1', loteamentoId: 'obraA'))
                .overrideWith((ref) => Stream.value(<Lote>[])), quadraId: 'obraA'))
                .overrideWith((ref) => Stream.value(<Lote>[])), status: LoteStatus.noPrazo,
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Diário de Obra'), findsWidgets);
    },
  );
}
