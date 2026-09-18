import '../common_widgets/access_guard.dart';
import '../features/obras/presentation/access_denied_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/data/auth_repository.dart';
import '../features/authentication/presentation/login_screen.dart';
import '../features/construtoras/presentation/construtoras_list_screen.dart';
import '../features/obras/presentation/obras_list_screen.dart';
import '../features/obras/presentation/obra_dashboard_screen.dart';
import '../features/lotes/presentation/lotes_list_screen.dart';
import '../features/lotes/presentation/add_lote_screen.dart';
import '../features/almoxarifado/presentation/almoxarifado_list_screen.dart';
import '../features/almoxarifado/presentation/add_material_screen.dart';
import '../features/almoxarifado/presentation/movimentacao_screen.dart';
import '../features/almoxarifado/domain/material.dart' as mat;
import '../features/almoxarifado/domain/movimentacao.dart';
import '../features/diario/presentation/diarios_list_screen.dart';
import '../features/diario/presentation/add_diario_screen.dart';
import '../features/diario/presentation/sync_queue_screen.dart';
import '../features/construtoras/presentation/membros_screen.dart';
import '../features/financeiro/presentation/financeiro_list_screen.dart';
import '../features/financeiro/presentation/add_despesa_screen.dart';
import '../features/developer/presentation/dev_panel_screen.dart';
import '../features/developer/presentation/users_list_screen.dart';
import '../features/developer/presentation/user_details_screen.dart';
import '../features/developer/presentation/dev_construtoras_list_screen.dart';
import '../features/authentication/data/user_repository.dart';
import '../features/rh/presentation/funcionarios_list_screen.dart';
import '../features/rh/presentation/funcionario_form_screen.dart';
import '../features/rh/domain/funcionario.dart';
import '../features/rh/presentation/chamadas_list_screen.dart';
import '../features/rh/presentation/chamada_form_screen.dart';
import '../features/epi/presentation/catalogo_epis_screen.dart';
import '../features/epi/presentation/entrega_epi_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final devState = ref.watch(trustedDevProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoading = authState.isLoading || devState.isLoading;
      if (isLoading) return null; // Can result in a blank screen briefly if no loading route is provided, but typically okay

      final isAuth = authState.value != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isAuth) {
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn) {
        return '/';
      }

      if (state.matchedLocation.startsWith('/dev')) {
        final isDev = devState.value == true;
        if (!isDev) {
          return '/';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/dev',
        builder: (context, state) =>
            const AccessGuard(devOnly: true, child: DevPanelScreen()),
      ),
      GoRoute(
        path: '/dev/users',
        builder: (context, state) =>
            const AccessGuard(devOnly: true, child: UsersListScreen()),
      ),
      GoRoute(
        path: '/dev/users/:uid',
        builder: (context, state) {
          final uid = state.pathParameters['uid']!;
          return AccessGuard(
            devOnly: true,
            child: UserDetailsScreen(userId: uid),
          );
        },
      ),
      GoRoute(
        path: '/dev/construtoras',
        builder: (context, state) => const AccessGuard(
          devOnly: true,
          child: DevConstrutorasListScreen(),
        ),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const ConstrutorasListScreen(),
      ),
      GoRoute(
        path: '/construtora/:cId',
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          return AccessGuard(
            construtoraId: cId,
            child: ObrasListScreen(construtoraId: cId),
          );
        },
      ),
      GoRoute(
        path: '/construtora/:cId/sync',
        builder: (context, state) => AccessGuard(
          construtoraId: state.pathParameters['cId']!,
          child: SyncQueueScreen(
            construtoraId: state.pathParameters['cId']!,
            obraId: '',
          ),
        ),
      ),
      GoRoute(
        path: '/construtora/:cId/membros',
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          return AccessGuard(
            construtoraId: cId,
            adminOnly: true,
            child: MembrosScreen(construtoraId: cId),
          );
        },
      ),
      GoRoute(
        path: '/construtora/:cId/obra/:oId',
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            child: ObraDashboardScreen(construtoraId: cId, obraId: oId),
          );
        },
      ),
      GoRoute(
        path: '/construtora/:cId/obra/:oId/lotes',
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            module: 'lotes',
            child: LotesListScreen(construtoraId: cId, obraId: oId),
          );
        },
      ),
      GoRoute(
        path: '/construtora/:cId/obra/:oId/lotes/novo',
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            module: 'lotes',
            adminOnly: true,
            child: AddLoteScreen(construtoraId: cId, obraId: oId),
          );
        },
      ),
      GoRoute(
        path: '/construtora/:cId/obra/:oId/diarios',
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
        path: '/construtora/:cId/obra/:oId/diarios/novo',
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
        path: '/construtora/:cId/obra/:oId/diarios/sync',
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
      GoRoute(
        path: '/construtora/:cId/obra/:oId/rh/chamadas',
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
        path: '/construtora/:cId/obra/:oId/rh/chamadas/nova',
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
        path: '/construtora/:cId/obra/:oId/rh/chamadas/:chId',
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
      GoRoute(
        path: '/construtora/:cId/almoxarifado',
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
        path: '/construtora/:cId/almoxarifado/novo_material',
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
        path: '/construtora/:cId/almoxarifado/movimentacao',
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
      GoRoute(
        path: '/construtora/:cId/financeiro',
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          return AccessGuard(
            construtoraId: cId,
            module: 'financeiro',
            adminOnly: true,
            child: FinanceiroListScreen(construtoraId: cId),
          );
        },
      ),
      GoRoute(
        path: '/construtora/:cId/financeiro/novo',
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          return AccessGuard(
            construtoraId: cId,
            module: 'financeiro',
            adminOnly: true,
            child: AddDespesaScreen(construtoraId: cId),
          );
        },
      ),
      GoRoute(
        path: '/construtora/:cId/rh',
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
        path: '/construtora/:cId/rh/funcionarios',
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
        path: '/construtora/:cId/rh/funcionarios/novo',
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
        path: '/construtora/:cId/rh/funcionarios/:fId/editar',
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final extra = state.extra;
          return AccessGuard(
            construtoraId: cId,
            module: 'rh',
            child: FuncionarioFormScreen(
              construtoraId: cId,
              initialFuncionario: extra is Funcionario ? extra : null,
            ),
          );
        },
      ),
      GoRoute(
        path: '/construtora/:cId/epis',
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          return AccessGuard(
            construtoraId: cId,
            module: 'epi',
            child: CatalogoEpisScreen(construtoraId: cId),
          );
        },
      ),
      GoRoute(
        path: '/construtora/:cId/obra/:oId/epis/entrega',
        builder: (context, state) {
          final cId = state.pathParameters['cId']!;
          final oId = state.pathParameters['oId']!;
          return AccessGuard(
            construtoraId: cId,
            obraId: oId,
            module: 'epi',
            child: EntregaEpiScreen(
              construtoraId: cId,
              obraId: oId,
            ),
          );
        },
      ),
    ],
  );
});
