import 'package:go_router/go_router.dart';
import '../presentation/etapas_list_screen.dart';
import '../../../common_widgets/access_guard.dart';
import '../../equipes/routing/equipes_routes.dart';

abstract class EtapasPaths {
  static const list = 'etapas';
}

List<RouteBase> get etapasRoutes => [
      GoRoute(
        path: EtapasPaths.list,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final loteamentoId = state.pathParameters['loteamentoId']!;
          final quadraId = state.pathParameters['quadraId']!;
          final loteId = state.pathParameters['loteId']!;
          return AccessGuard(
            construtoraId: cId,
            module: 'lotes',
            child: EtapasListScreen(
              construtoraId: cId,
              loteamentoId: loteamentoId,
              quadraId: quadraId,
              loteId: loteId,
            ),
          );
        },
        routes: [
          GoRoute(
            path: ':etapaId',
            redirect: (context, state) => state.uri.path == state.matchedLocation
                ? state.uri
                      .replace(path: '${state.matchedLocation}/equipes')
                      .toString()
                : null,
            routes: [
              ...equipesRoutes,
            ],
          )
        ],
      ),
    ];