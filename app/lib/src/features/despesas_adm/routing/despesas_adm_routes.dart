import 'package:go_router/go_router.dart';

import '../../../common_widgets/access_guard.dart';
import '../presentation/despesas_adm_list_screen.dart';
import '../presentation/despesa_adm_form_screen.dart';
import '../presentation/despesa_adm_details_screen.dart';

/// Constantes de path para despesas administrativas.
abstract class DespesasAdmPaths {
  static const list = 'obra/:oId/despesas';
  static const nova = 'obra/:oId/despesas/nova';
  static const detalhes = 'obra/:oId/despesas/:despesaId';
  static const editar = 'obra/:oId/despesas/:despesaId/editar';

  static String listFor(String cId, String oId) =>
      '/construtoras/$cId/obra/$oId/despesas';
  static String novaFor(String cId, String oId) =>
      '/construtoras/$cId/obra/$oId/despesas/nova';
  static String detalhesFor(String cId, String oId, String despesaId) =>
      '/construtoras/$cId/obra/$oId/despesas/$despesaId';
  static String editarFor(String cId, String oId, String despesaId) =>
      '/construtoras/$cId/obra/$oId/despesas/$despesaId/editar';
}

/// Rotas do módulo de despesas administrativas.
List<RouteBase> get despesasAdmRoutes => [
  GoRoute(
    path: DespesasAdmPaths.list,
    builder: (context, state) {
      final cId = state.pathParameters['cId']!;
      final oId = state.pathParameters['oId']!;
      return AccessGuard(
        construtoraId: cId,
        obraId: oId,
        module: 'adm',
        child: DespesasAdmListScreen(construtoraId: cId, obraId: oId),
      );
    },
  ),
  GoRoute(
    path: DespesasAdmPaths.nova,
    builder: (context, state) {
      final cId = state.pathParameters['cId']!;
      final oId = state.pathParameters['oId']!;
      return AccessGuard(
        construtoraId: cId,
        obraId: oId,
        module: 'adm',
        child: DespesaAdmFormScreen(construtoraId: cId, obraId: oId),
      );
    },
  ),
  GoRoute(
    path: DespesasAdmPaths.detalhes,
    builder: (context, state) {
      final cId = state.pathParameters['cId']!;
      final oId = state.pathParameters['oId']!;
      final despesaId = state.pathParameters['despesaId']!;
      return AccessGuard(
        construtoraId: cId,
        obraId: oId,
        module: 'adm',
        child: DespesaAdmDetailsScreen(
          construtoraId: cId,
          obraId: oId,
          despesaId: despesaId,
        ),
      );
    },
  ),
  GoRoute(
    path: DespesasAdmPaths.editar,
    builder: (context, state) {
      final cId = state.pathParameters['cId']!;
      final oId = state.pathParameters['oId']!;
      final despesaId = state.pathParameters['despesaId']!;
      return AccessGuard(
        construtoraId: cId,
        obraId: oId,
        module: 'adm',
        child: DespesaAdmFormScreen(
          construtoraId: cId,
          obraId: oId,
          despesaId: despesaId,
        ),
      );
    },
  ),
];
