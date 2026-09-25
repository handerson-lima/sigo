import 'package:go_router/go_router.dart';

import '../../../common_widgets/access_guard.dart';
import '../presentation/obra_dashboard_screen.dart';

/// Constantes de path para obras.
abstract class ObraPaths {
  static const dashboard = 'obra/:oId';

  static String dashboardFor(String cId, String oId) =>
      '/construtoras/$cId/obra/$oId';
}

/// Rotas do módulo de obras.
List<RouteBase> get obraRoutes => [
      GoRoute(
        path: ObraPaths.dashboard,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            child: ObraDashboardScreen(construtoraId: cId, obraId: oId),
          );
        },
      ),
    ];
