import 'package:go_router/go_router.dart';
import '../presentation/equipes_list_screen.dart';
import '../../../common_widgets/access_guard.dart';

abstract class EquipesPaths {
  static const list = 'equipes';
}

List<RouteBase> get equipesRoutes => [
      GoRoute(
        path: EquipesPaths.list,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final loteamentoId = state.pathParameters['loteamentoId']!;
          final quadraId = state.pathParameters['quadraId']!;
          final loteId = state.pathParameters['loteId']!;
          final setorId = state.pathParameters['setorId']!;
          return AccessGuard(
            construtoraId: cId,
            module: 'lotes',
            child: EquipesListScreen(
              construtoraId: cId,
              loteamentoId: loteamentoId,
              quadraId: quadraId,
              loteId: loteId,
              setorId: setorId,
            ),
          );
        },
      ),
    ];
