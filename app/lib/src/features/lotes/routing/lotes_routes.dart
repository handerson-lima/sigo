import 'package:go_router/go_router.dart';
import '../presentation/lotes_list_screen.dart';
import '../presentation/add_lote_screen.dart';
import '../../../common_widgets/access_guard.dart';
import '../../setores/routing/setores_routes.dart';

abstract class LotesPaths {
  static const list = 'lotes';
  static const novo = 'novo';
}

List<RouteBase> get lotesRoutes => [
      GoRoute(
        path: LotesPaths.list,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final loteamentoId = state.pathParameters['loteamentoId']!;
          final quadraId = state.pathParameters['quadraId']!;
          return AccessGuard(
            construtoraId: cId,
            module: 'lotes',
            child: LotesListScreen(
              construtoraId: cId,
              loteamentoId: loteamentoId,
              quadraId: quadraId,
            ),
          );
        },
        routes: [
          GoRoute(
            path: LotesPaths.novo,
            builder: (context, state) {
              final cId = state.pathParameters['cId']!;
              final loteamentoId = state.pathParameters['loteamentoId']!;
              final quadraId = state.pathParameters['quadraId']!;
              return AccessGuard(
                construtoraId: cId,
                module: 'lotes',
                adminOnly: true,
                child: AddLoteScreen(
                  construtoraId: cId,
                  loteamentoId: loteamentoId,
                  quadraId: quadraId,
                ),
              );
            },
          ),
          GoRoute(
            path: ':loteId',
            redirect: (context, state) => state.uri.path == state.matchedLocation
                ? state.uri
                      .replace(path: '${state.matchedLocation}/setores')
                      .toString()
                : null,
            routes: [
              ...setoresRoutes,
            ],
          )
        ],
      ),
    ];
