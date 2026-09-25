import 'package:go_router/go_router.dart';
import '../presentation/quadras_list_screen.dart';
import '../../../common_widgets/access_guard.dart';
import '../../lotes/routing/lotes_routes.dart';

abstract class QuadrasPaths {
  static const list = 'quadras';
  static const detail = 'quadras/:quadraId';
}

List<RouteBase> get quadrasRoutes => [
      GoRoute(
        path: QuadrasPaths.list,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final loteamentoId = state.pathParameters['loteamentoId']!;
          return AccessGuard(
            construtoraId: cId,
            module: 'lotes',
            child: QuadrasListScreen(
              construtoraId: cId,
              loteamentoId: loteamentoId,
            ),
          );
        },
        routes: [
          GoRoute(
            path: ':quadraId',
            redirect: (context, state) => state.uri.path == state.matchedLocation
                ? state.uri
                      .replace(path: '${state.matchedLocation}/lotes')
                      .toString()
                : null,
            routes: [
              ...lotesRoutes,
            ],
          )
        ],
      ),
    ];
