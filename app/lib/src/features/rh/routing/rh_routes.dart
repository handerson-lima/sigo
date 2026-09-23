import 'package:go_router/go_router.dart';

import '../../../common_widgets/access_guard.dart';
import '../presentation/funcionarios_list_screen.dart';
import '../presentation/funcionario_form_screen.dart';
import '../domain/funcionario.dart';
import '../presentation/chamadas_list_screen.dart';
import '../presentation/chamada_form_screen.dart';

/// Constantes de path para RH.
abstract class RhPaths {
  
  static const funcionarios = 'rh/funcionarios';
  static const novoFuncionario = 'rh/funcionarios/novo';
  static const editarFuncionario =
      'rh/funcionarios/:fId/editar';
  static const chamadas = 'obra/:oId/rh/chamadas';
  static const novaChamada = 'obra/:oId/rh/chamadas/nova';
  static const editarChamada =
      'obra/:oId/rh/chamadas/:chId';

  static String rhFor(String cId) => '/construtora/$cId/rh';
  static String funcionariosFor(String cId) =>
      '/construtora/$cId/rh/funcionarios';
  static String novoFuncionarioFor(String cId) =>
      '/construtora/$cId/rh/funcionarios/novo';
  static String editarFuncionarioFor(String cId, String fId) =>
      '/construtora/$cId/rh/funcionarios/$fId/editar';
  static String chamadasFor(String cId, String oId) =>
      '/construtora/$cId/obra/$oId/rh/chamadas';
  static String novaChamadaFor(String cId, String oId) =>
      '/construtora/$cId/obra/$oId/rh/chamadas/nova';
  static String editarChamadaFor(String cId, String oId, String chId) =>
      '/construtora/$cId/obra/$oId/rh/chamadas/$chId';
}

/// Rotas do módulo de RH (funcionários + chamadas).
List<RouteBase> get rhRoutes => [

      GoRoute(
        path: RhPaths.funcionarios,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          return AccessGuard(
            construtoraId: cId,
            module: 'rh',
            child: FuncionariosListScreen(construtoraId: cId),
          );
        },
      ),
      GoRoute(
        path: RhPaths.novoFuncionario,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          return AccessGuard(
            construtoraId: cId,
            module: 'rh',
            child: FuncionarioFormScreen(construtoraId: cId),
          );
        },
      ),
      GoRoute(
        path: RhPaths.editarFuncionario,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final fId = state.pathParameters['fId']!;
          return AccessGuard(
            construtoraId: cId,
            module: 'rh',
            child: FuncionarioFormScreen(
              construtoraId: cId,
              funcionarioId: fId,
            ),
          );
        },
      ),
      GoRoute(
        path: RhPaths.chamadas,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            module: 'rh',
            child: ChamadasListScreen(construtoraId: cId, obraId: oId),
          );
        },
      ),
      GoRoute(
        path: RhPaths.novaChamada,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            module: 'rh',
            child: ChamadaFormScreen(construtoraId: cId, obraId: oId),
          );
        },
      ),
      GoRoute(
        path: RhPaths.editarChamada,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          final chId = state.pathParameters['chId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            module: 'rh',
            child: ChamadaFormScreen(
              construtoraId: cId,
              obraId: oId,
              chamadaId: chId,
            ),
          );
        },
      ),
    ];
