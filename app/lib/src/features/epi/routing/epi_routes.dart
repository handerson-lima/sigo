import 'package:go_router/go_router.dart';

import '../../../common_widgets/access_guard.dart';
import '../presentation/catalogo_epis_screen.dart';
import '../presentation/entrega_epi_screen.dart';

/// Constantes de path para EPIs.
abstract class EpiPaths {
  static const catalogo = 'epis';
  static const entrega = 'obra/:oId/epis/entrega';

  static String catalogoFor(String cId) => '/construtoras/$cId/epis';
  static String entregaFor(String cId, String oId) =>
      '/construtoras/$cId/obra/$oId/epis/entrega';
}

/// Rotas do módulo de EPIs.
List<RouteBase> get epiRoutes => [
      GoRoute(
        path: EpiPaths.catalogo,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          return AccessGuard(
            construtoraId: cId,
            module: 'epi',
            child: CatalogoEpisScreen(construtoraId: cId),
          );
        },
      ),
      GoRoute(
        path: EpiPaths.entrega,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            module: 'epi',
            child: EntregaEpiScreen(
              construtoraId: cId,
              obraId: oId,
            ),
          );
        },
      ),
    ];
