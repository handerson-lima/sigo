import 'package:go_router/go_router.dart';

import '../../../common_widgets/access_guard.dart';
import '../presentation/fornecedores_list_screen.dart';
import '../presentation/fornecedor_form_screen.dart';

/// Constantes de path para fornecedores.
abstract class FornecedoresPaths {
  static const list = 'fornecedores';
  static const novo = 'fornecedores/novo';
  static const editar = 'fornecedores/:fornecedorId/editar';

  static String listFor(String cId) => '/construtoras/$cId/fornecedores';
  static String novoFor(String cId) => '/construtoras/$cId/fornecedores/novo';
  static String editarFor(String cId, String fornecedorId) =>
      '/construtoras/$cId/fornecedores/$fornecedorId/editar';
}

/// Rotas do módulo de fornecedores.
List<RouteBase> get fornecedoresRoutes => [
      GoRoute(
        path: FornecedoresPaths.list,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          return AccessGuard(
            construtoraId: cId,
            child: FornecedoresListScreen(construtoraId: cId),
          );
        },
      ),
      GoRoute(
        path: FornecedoresPaths.novo,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          return AccessGuard(
            construtoraId: cId,
            child: FornecedorFormScreen(construtoraId: cId),
          );
        },
      ),
      GoRoute(
        path: FornecedoresPaths.editar,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final fornecedorId = state.pathParameters['fornecedorId']!;
          return AccessGuard(
            construtoraId: cId,
            child: FornecedorFormScreen(
              construtoraId: cId,
              fornecedorId: fornecedorId,
            ),
          );
        },
      ),
    ];
