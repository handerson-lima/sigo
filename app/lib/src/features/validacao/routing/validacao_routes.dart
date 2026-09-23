import 'package:go_router/go_router.dart';

import '../../../common_widgets/access_guard.dart';
import '../presentation/templates_list_screen.dart';
import '../presentation/lote_validacoes_screen.dart';
import '../presentation/validacao_form_screen.dart';

/// Constantes de path para validação.
abstract class ValidacaoPaths {
  static const templates = 'validacao/templates';
  static const loteValidacoes =
      'obra/:oId/lotes/:loteId/validacoes';
  static const novaValidacao =
      'obra/:oId/lotes/:loteId/validacoes/nova';
  static const editarValidacao =
      'obra/:oId/lotes/:loteId/validacoes/:validacaoId';

  static String templatesFor(String cId) =>
      '/construtora/$cId/validacao/templates';
  static String loteValidacoesFor(String cId, String oId, String loteId) =>
      '/construtora/$cId/obra/$oId/lotes/$loteId/validacoes';
  static String novaValidacaoFor(String cId, String oId, String loteId) =>
      '/construtora/$cId/obra/$oId/lotes/$loteId/validacoes/nova';
  static String editarValidacaoFor(
          String cId, String oId, String loteId, String validacaoId) =>
      '/construtora/$cId/obra/$oId/lotes/$loteId/validacoes/$validacaoId';
}

/// Rotas do módulo de validação.
List<RouteBase> get validacaoRoutes => [
      GoRoute(
        path: ValidacaoPaths.templates,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          return AccessGuard(
            construtoraId: cId,
            module: 'validacao',
            child: TemplatesListScreen(construtoraId: cId),
          );
        },
      ),
      GoRoute(
        path: ValidacaoPaths.loteValidacoes,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          final loteId = state.pathParameters['loteId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            module: 'validacao',
            child: LoteValidacoesScreen(
              construtoraId: cId,
              obraId: oId,
              loteId: loteId,
            ),
          );
        },
      ),
      GoRoute(
        path: ValidacaoPaths.novaValidacao,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          final loteId = state.pathParameters['loteId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            module: 'validacao',
            child: ValidacaoFormScreen(
              construtoraId: cId,
              obraId: oId,
              loteId: loteId,
            ),
          );
        },
      ),
      GoRoute(
        path: ValidacaoPaths.editarValidacao,
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          final loteId = state.pathParameters['loteId']!;
          final validacaoId = state.pathParameters['validacaoId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            module: 'validacao',
            child: ValidacaoFormScreen(
              construtoraId: cId,
              obraId: oId,
              loteId: loteId,
              validacaoId: validacaoId,
            ),
          );
        },
      ),
    ];
