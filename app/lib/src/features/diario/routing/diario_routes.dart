import 'package:go_router/go_router.dart';

import '../../../common_widgets/access_guard.dart';
import '../presentation/diarios_list_screen.dart';
import '../presentation/add_diario_screen.dart';
import '../presentation/sync_queue_screen.dart';

/// Constantes de path para diário de obra.
abstract class DiarioPaths {
  static const syncConstrutora = 'sync';
  static const list = 'obra/:oId/diarios';
  static const novo = 'obra/:oId/diarios/novo';
  static const sync = 'obra/:oId/diarios/sync';

  static String syncConstrutoraFor(String cId) => '/construtora/$cId/sync';
  static String listFor(String cId, String oId) =>
      '/construtora/$cId/obra/$oId/diarios';
  static String novoFor(String cId, String oId) =>
      '/construtora/$cId/obra/$oId/diarios/novo';
  static String syncFor(String cId, String oId) =>
      '/construtora/$cId/obra/$oId/diarios/sync';
}

/// Rotas do módulo de diário de obra.
List<RouteBase> get diarioRoutes => [
      GoRoute(
        path: DiarioPaths.syncConstrutora,
        builder: (context, state) => AccessGuard(
          construtoraId: state.pathParameters['cId']!,
          child: SyncQueueScreen(
            construtoraId: state.pathParameters['cId']!,
            obraId: '',
          ),
        ),
      ),
      GoRoute(
        path: DiarioPaths.list,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            module: 'diario',
            child: DiariosListScreen(construtoraId: cId, obraId: oId),
          );
        },
      ),
      GoRoute(
        path: DiarioPaths.novo,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            module: 'diario',
            child: AddDiarioScreen(construtoraId: cId, obraId: oId),
          );
        },
      ),
      GoRoute(
        path: DiarioPaths.sync,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            module: 'diario',
            child: SyncQueueScreen(construtoraId: cId, obraId: oId),
          );
        },
      ),
    ];
