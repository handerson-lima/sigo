import 'package:go_router/go_router.dart';

import '../presentation/loteamentos_list_screen.dart';
import '../presentation/loteamento_import_screen.dart';
import '../presentation/loteamento_processing_screen.dart';
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
        module: 'lotes',
        child: LoteamentosListScreen(construtoraId: cId),
      );
    },
    routes: [
      GoRoute(
        path: 'import',
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          return AccessGuard(
            construtoraId: cId,
            module: 'lotes',
            child: LoteamentoImportScreen(construtoraId: cId),
          );
        },
        routes: [
          GoRoute(
            path: 'processing/:draftId',
            builder: (context, state) {
              final cId = state.pathParameters['cId']!;
              final draftId = state.pathParameters['draftId']!;
              return AccessGuard(
                construtoraId: cId,
                module: 'lotes',
                child: LoteamentoProcessingScreen(
                  construtoraId: cId,
                  draftId: draftId,
                ),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: ':loteamentoId',
        redirect: (context, state) => state.uri.path == state.matchedLocation
            ? state.uri
                  .replace(path: '${state.matchedLocation}/quadras')
                  .toString()
            : null,
        routes: [...quadrasRoutes],
      ),
    ],
  ),
];
