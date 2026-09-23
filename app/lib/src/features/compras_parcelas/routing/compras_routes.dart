import 'package:go_router/go_router.dart';

import '../../../common_widgets/access_guard.dart';
import '../presentation/compras_list_screen.dart';
import '../presentation/compra_form_screen.dart';
import '../presentation/compra_detalhes_screen.dart';

/// Constantes de path para compras e parcelas.
abstract class ComprasPaths {
  static const list = 'obra/:oId/compras';
  static const nova = 'obra/:oId/compras/nova';
  static const detalhes = 'obra/:oId/compras/:compraId';
  static const editar =
      'obra/:oId/compras/:compraId/editar';

  static String listFor(String cId, String oId) =>
      '/construtora/$cId/obra/$oId/compras';
  static String novaFor(String cId, String oId) =>
      '/construtora/$cId/obra/$oId/compras/nova';
  static String detalhesFor(String cId, String oId, String compraId) =>
      '/construtora/$cId/obra/$oId/compras/$compraId';
  static String editarFor(String cId, String oId, String compraId) =>
      '/construtora/$cId/obra/$oId/compras/$compraId/editar';
}

/// Rotas do módulo de compras e parcelas.
List<RouteBase> get comprasRoutes => [
      GoRoute(
        path: ComprasPaths.list,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            module: 'compras',
            child: ComprasListScreen(
              construtoraId: cId,
              obraId: oId,
            ),
          );
        },
      ),
      GoRoute(
        path: ComprasPaths.nova,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            module: 'compras',
            child: CompraFormScreen(
              construtoraId: cId,
              obraId: oId,
            ),
          );
        },
      ),
      GoRoute(
        path: ComprasPaths.detalhes,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          final compraId = state.pathParameters['compraId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            module: 'compras',
            child: CompraDetalhesScreen(
              construtoraId: cId,
              obraId: oId,
              compraId: compraId,
            ),
          );
        },
      ),
      GoRoute(
        path: ComprasPaths.editar,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          final compraId = state.pathParameters['compraId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            module: 'compras',
            child: CompraFormScreen(
              construtoraId: cId,
              obraId: oId,
              compraId: compraId,
            ),
          );
        },
      ),
    ];
