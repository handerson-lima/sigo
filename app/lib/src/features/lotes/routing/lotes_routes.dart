import 'package:go_router/go_router.dart';

import '../../../common_widgets/access_guard.dart';
import '../presentation/lotes_list_screen.dart';
import '../presentation/add_lote_screen.dart';

/// Constantes de path para lotes.
abstract class LotesPaths {
  static const list = 'obra/:oId/lotes';
  static const novo = 'obra/:oId/lotes/novo';

  static String listFor(String cId, String oId) =>
      '/construtora/$cId/obra/$oId/lotes';
  static String novoFor(String cId, String oId) =>
      '/construtora/$cId/obra/$oId/lotes/novo';
}

/// Rotas do módulo de lotes.
List<RouteBase> get lotesRoutes => [
      GoRoute(
        path: LotesPaths.list,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            module: 'lotes',
            child: LotesListScreen(construtoraId: cId, obraId: oId),
          );
        },
      ),
      GoRoute(
        path: LotesPaths.novo,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            module: 'lotes',
            adminOnly: true,
            child: AddLoteScreen(construtoraId: cId, obraId: oId),
          );
        },
      ),
    ];
