import 'package:go_router/go_router.dart';
import '../presentation/loteamentos_list_screen.dart';
import '../../../common_widgets/access_guard.dart';
import '../../quadras/routing/quadras_routes.dart';

abstract class LoteamentosPaths {
  static const list = 'loteamentos';
  static const detail = 'loteamentos/:loteamentoId';
}

List<RouteBase> get loteamentosRoutes => [
      GoRoute(
        path: LoteamentosPaths.list,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          return AccessGuard(
            construtoraId: cId,
            child: LoteamentosListScreen(
              construtoraId: cId,
            ),
          );
        },
        routes: [
          GoRoute(
            path: ':loteamentoId',
            redirect: (context, state) => state.uri.path == state.matchedLocation
                ? '${state.matchedLocation}/quadras'
                : null,
            routes: [
              ...quadrasRoutes,
            ],
          )
        ],
      ),
    ];
