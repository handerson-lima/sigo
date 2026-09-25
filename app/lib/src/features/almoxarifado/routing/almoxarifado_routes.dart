import 'package:go_router/go_router.dart';

import '../../../common_widgets/access_guard.dart';
import '../presentation/almoxarifado_list_screen.dart';
import '../presentation/add_material_screen.dart';
import '../presentation/movimentacao_screen.dart';
import '../domain/material.dart' as mat;
import '../domain/movimentacao.dart';
import '../../obras/presentation/access_denied_screen.dart';

/// Constantes de path para almoxarifado.
abstract class AlmoxarifadoPaths {
  static const list = 'almoxarifado';
  static const novoMaterial = 'almoxarifado/novo_material';
  static const movimentacao = 'almoxarifado/movimentacao';

  static String listFor(String cId) => '/construtoras/$cId/almoxarifado';
  static String novoMaterialFor(String cId) =>
      '/construtoras/$cId/almoxarifado/novo_material';
  static String movimentacaoFor(String cId) =>
      '/construtoras/$cId/almoxarifado/movimentacao';
}

/// Rotas do módulo de almoxarifado.
List<RouteBase> get almoxarifadoRoutes => [
  GoRoute(
    path: AlmoxarifadoPaths.list,
    builder: (context, state) {
      final cId = state.pathParameters['cId']!;
      return AccessGuard(
        construtoraId: cId,
        module: 'estoque',
        child: AlmoxarifadoListScreen(construtoraId: cId),
      );
    },
  ),
  GoRoute(
    path: AlmoxarifadoPaths.novoMaterial,
    builder: (context, state) {
      final cId = state.pathParameters['cId']!;
      return AccessGuard(
        construtoraId: cId,
        module: 'estoque',
        child: AddMaterialScreen(construtoraId: cId),
      );
    },
  ),
  GoRoute(
    path: AlmoxarifadoPaths.movimentacao,
    builder: (context, state) {
      final cId = state.pathParameters['cId']!;
      if (state.extra is! Map<String, dynamic>) {
        return const AccessDeniedScreen();
      }
      final extra = state.extra as Map<String, dynamic>;
      final material = extra['material'] as mat.Material;
      final typeStr = extra['type'] as String;
      final type = typeStr == 'entrada'
          ? MovimentacaoType.entrada
          : MovimentacaoType.saida;
      return AccessGuard(
        construtoraId: cId,
        module: 'estoque',
        child: MovimentacaoScreen(
          construtoraId: cId,
          material: material,
          type: type,
        ),
      );
    },
  ),
];
