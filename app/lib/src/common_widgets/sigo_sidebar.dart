import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/contracts.dart';
import '../features/authentication/data/auth_repository.dart';
import '../features/authentication/data/user_repository.dart';
import '../features/obras/presentation/current_permissions_provider.dart';
import '../design_system/sigo_theme.dart';
import 'sidebar_state.dart';

class SigoSidebar extends ConsumerWidget {
  final String activeRoute;
  final bool? isCollapsed;

  const SigoSidebar({
    super.key,
    required this.activeRoute,
    this.isCollapsed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = Uri.parse(activeRoute);
    final pathSegments = uri.pathSegments;
    String? cId;
    String? oId;
    if (pathSegments.length >= 2 && pathSegments[0] == 'construtora') {
      cId = pathSegments[1];
      if (pathSegments.length >= 4 && pathSegments[2] == 'obra') {
        oId = pathSegments[3];
      }
    }

    final isDev = ref.watch(trustedDevProvider).value == true;

    final obra = cId != null && oId != null
        ? ref
              .watch(
                currentPermissionsProvider((construtoraId: cId, obraId: oId)),
              )
              .value
        : null;

    final construtoraMember = cId != null
        ? ref.watch(construtoraPermissionProvider(cId)).value
        : null;

    final isConstrutoraAdmin = construtoraMember != null &&
        construtoraMember['isActive'] == true &&
        (construtoraMember['isAdmin'] == true ||
            construtoraMember['isOwner'] == true ||
            construtoraMember['role'] == 'admin' ||
            construtoraMember['role'] == 'owner');

    final construtoraModules = (construtoraMember?['modules'] as List? ?? [])
        .map((m) => normalizeModule(m.toString()))
        .toSet();

    final canRh = isDev ||
        (obra != null &&
            obra.isActive &&
            (obra.isAdmin ||
                obra.modules.map(normalizeModule).contains('rh') ||
                obra.modules.map(normalizeModule).contains('recursos_humanos'))) ||
        isConstrutoraAdmin ||
        (construtoraMember != null &&
            construtoraMember['isActive'] == true &&
            (construtoraModules.contains('rh') ||
                construtoraModules.contains('recursos_humanos')));

    final canEstoque = isDev ||
        (obra != null &&
            obra.isActive &&
            (obra.isAdmin ||
                obra.modules.map(normalizeModule).contains('estoque') ||
                obra.modules.map(normalizeModule).contains('almoxarifado'))) ||
        isConstrutoraAdmin ||
        (construtoraMember != null &&
            construtoraMember['isActive'] == true &&
            (construtoraModules.contains('estoque') ||
                construtoraModules.contains('almoxarifado')));

    final canFinanceiro = isDev ||
        (obra != null && obra.isActive && obra.isAdmin) ||
        isConstrutoraAdmin;

    final canMembros = isDev ||
        (obra != null && obra.isActive && obra.isAdmin) ||
        isConstrutoraAdmin;

    final canAdm = isDev ||
        (obra != null &&
            obra.isActive &&
            (obra.isAdmin ||
                obra.modules.map(normalizeModule).contains('adm') ||
                obra.modules.map(normalizeModule).contains('financeiro')));

    final canCompras = isDev ||
        (obra != null &&
            obra.isActive &&
            (obra.isAdmin ||
                obra.modules.map(normalizeModule).contains('compras') ||
                obra.modules.map(normalizeModule).contains('almoxarifado') ||
                obra.modules.map(normalizeModule).contains('estoque') ||
                obra.modules.map(normalizeModule).contains('adm') ||
                obra.modules.map(normalizeModule).contains('financeiro')));

    final canEpi = isDev ||
        (obra != null &&
            obra.isActive &&
            (obra.isAdmin ||
                obra.modules.map(normalizeModule).contains('epi') ||
                obra.modules.map(normalizeModule).contains('rh')));

    final canEpiCatalogo = isDev ||
        isConstrutoraAdmin ||
        (construtoraMember != null &&
            construtoraMember['isActive'] == true &&
            (construtoraModules.contains('epi') ||
                construtoraModules.contains('rh') ||
                construtoraModules.contains('seguranca')));

    final canValidacao = isDev ||
        isConstrutoraAdmin ||
        (construtoraMember != null &&
            construtoraMember['isActive'] == true &&
            (construtoraModules.contains('validacao') ||
                construtoraModules.contains('qualidade')));

    final canFornecedores = isDev ||
        isConstrutoraAdmin ||
        canEstoque ||
        canAdm ||
        canFinanceiro ||
        (construtoraMember != null && construtoraMember['isActive'] == true);

    final bool collapsed = isCollapsed ?? ref.watch(sidebarCollapsedProvider);

    return _SidebarScope(
      isCollapsed: collapsed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: collapsed ? 72 : 250,
        clipBehavior: Clip.hardEdge,
        color: Theme.of(context).extension<SigoThemeExtension>()?.sidebar ?? const Color(0xFF0F172A),
        child: OverflowBox(
          minWidth: 0,
          maxWidth: 250,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: collapsed ? 72 : 250,
            child: Column(
          children: [
            const SizedBox(height: 32),
            // Logo
            Padding(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 8.0 : 16.0),
              child: collapsed
                  ? Center(
                      child: Tooltip(
                        message: 'SIGO - Sistema Inteligente de Gestão de Obras',
                        preferBelow: false,
                        child: Image.asset(
                          'assets/images/sigo_icon.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.contain,
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Image.asset(
                          'assets/images/sigo_icon.png',
                          width: 38,
                          height: 38,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'SIGO',
                                style: TextStyle(
                                  color: Theme.of(context).extension<SigoThemeExtension>()?.sidebarInk ?? Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              Text(
                                'Sistema Inteligente de Gestão de Obras',
                                style: TextStyle(
                                  color: Theme.of(context).extension<SigoThemeExtension>()?.sidebarMuted ?? Colors.white70,
                                  fontSize: 9,
                                  height: 1.1,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 32),
            Divider(color: Theme.of(context).extension<SigoThemeExtension>()?.sidebarMuted.withValues(alpha: 0.2) ?? Colors.white24, height: 1),
            const SizedBox(height: 16),
            // Nav items
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: collapsed ? 8.0 : 16.0),
                children: [
                if (oId != null) ...[
                  _NavItem(
                    icon: Icons.dashboard,
                    title: 'Dashboard',
                    isActive: activeRoute == '/construtora/$cId/obra/$oId',
                    onTap: () {
                      Scaffold.maybeOf(context)?.closeDrawer();
                      context.go('/construtora/$cId/obra/$oId');
                    },
                  ),
                  if (isDev ||
                      isConstrutoraAdmin ||
                      (construtoraMember != null &&
                          construtoraMember['isActive'] == true &&
                          construtoraModules.contains('lotes')))
                    _NavItem(
                      icon: Icons.map,
                      title: 'Lotes e Setores',
                      isActive: activeRoute.contains('/lotes'),
                      onTap: () {
                        Scaffold.maybeOf(context)?.closeDrawer();
                        context.go('/construtora/$cId/loteamentos');
                      },
                    ),
                  if (obra != null &&
                      obra.isActive &&
                      (obra.isAdmin ||
                          obra.modules.map(normalizeModule).contains('diario')))
                    _NavItem(
                      icon: Icons.assignment,
                      title: 'Diário de Obra',
                      isActive: activeRoute.contains('/diarios'),
                      onTap: () {
                        Scaffold.maybeOf(context)?.closeDrawer();
                        context.go('/construtora/$cId/obra/$oId/diarios');
                      },
                    ),
                  if (obra != null &&
                      obra.isActive &&
                      (obra.isAdmin ||
                          obra.modules.map(normalizeModule).contains('rh') ||
                          obra.modules.map(normalizeModule).contains('recursos_humanos')))
                    _NavItem(
                      icon: Icons.playlist_add_check,
                      title: 'Chamada Diária (RH)',
                      isActive: activeRoute.contains('/rh/chamadas'),
                      onTap: () {
                        Scaffold.maybeOf(context)?.closeDrawer();
                        context.go('/construtora/$cId/obra/$oId/rh/chamadas');
                      },
                    ),
                  if (canEpi)
                    _NavItem(
                      icon: Icons.health_and_safety,
                      title: 'Entrega de EPIs',
                      isActive: activeRoute.contains('/epis/entrega'),
                      onTap: () {
                        Scaffold.maybeOf(context)?.closeDrawer();
                        context.go('/construtora/$cId/obra/$oId/epis/entrega');
                      },
                    ),
                  if (canAdm)
                    _NavItem(
                      icon: Icons.receipt_long,
                      title: 'Contas a Pagar / ADM',
                      isActive: activeRoute.contains('/despesas'),
                      onTap: () {
                        Scaffold.maybeOf(context)?.closeDrawer();
                        context.go('/construtora/$cId/obra/$oId/despesas');
                      },
                    ),
                  if (canCompras)
                    _NavItem(
                      icon: Icons.shopping_cart_outlined,
                      title: 'Compras e NF',
                      isActive: activeRoute.contains('/compras'),
                      onTap: () {
                        Scaffold.maybeOf(context)?.closeDrawer();
                        context.go('/construtora/$cId/obra/$oId/compras');
                      },
                    ),
                  if (canAdm || canFinanceiro)
                    _NavItem(
                      icon: Icons.query_stats_rounded,
                      title: 'Visão 360 Custos',
                      isActive: activeRoute.contains('/custos-360'),
                      onTap: () {
                        Scaffold.maybeOf(context)?.closeDrawer();
                        context.go('/construtora/$cId/obra/$oId/custos-360');
                      },
                    ),
                  if (!collapsed) ...[
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 8),
                      child: Text(
                        'NAVEGAÇÃO GLOBAL',
                        style: TextStyle(
                          color: Theme.of(context).extension<SigoThemeExtension>()?.sidebarMuted.withValues(alpha: 0.6) ?? Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                      child: Divider(color: Theme.of(context).extension<SigoThemeExtension>()?.sidebarMuted.withValues(alpha: 0.2) ?? Colors.white12, height: 1),
                    ),
                  ],
                ],

                _NavItem(
                  icon: Icons.business,
                  title: 'Minhas Construtoras',
                  isActive: activeRoute == '/',
                  onTap: () {
                    Scaffold.maybeOf(context)?.closeDrawer();
                    context.go('/');
                  },
                ),
                if (cId != null)
                  _NavItem(
                    icon: Icons.sync,
                    title: 'Fila deste dispositivo',
                    isActive: activeRoute.endsWith('/sync'),
                    onTap: () => context.go('/construtora/$cId/sync'),
                  ),
                if (cId != null && canRh)
                  _NavItem(
                    icon: Icons.people,
                    title: 'Funcionários (RH)',
                    isActive: activeRoute.contains('/rh') &&
                        !activeRoute.contains('/chamadas'),
                    onTap: () {
                      Scaffold.maybeOf(context)?.closeDrawer();
                      context.go('/construtora/$cId/rh/funcionarios');
                    },
                  ),
                if (cId != null && canEpiCatalogo)
                  _NavItem(
                    icon: Icons.health_and_safety_outlined,
                    title: 'Catálogo de EPIs',
                    isActive: activeRoute.contains('/epis') && !activeRoute.contains('/obra/'),
                    onTap: () {
                      Scaffold.maybeOf(context)?.closeDrawer();
                      context.go('/construtora/$cId/epis');
                    },
                  ),
                if (cId != null && canValidacao)
                  _NavItem(
                    icon: Icons.rule,
                    title: 'Templates de Validação',
                    isActive: activeRoute.contains('/validacao/templates'),
                    onTap: () {
                      Scaffold.maybeOf(context)?.closeDrawer();
                      context.go('/construtora/$cId/validacao/templates');
                    },
                  ),
                if (cId != null && canFornecedores)
                  _NavItem(
                    icon: Icons.business,
                    title: 'Fornecedores',
                    isActive: activeRoute.contains('/fornecedores'),
                    onTap: () {
                      Scaffold.maybeOf(context)?.closeDrawer();
                      context.go('/construtora/$cId/fornecedores');
                    },
                  ),
                if (cId != null && canEstoque)
                  _NavItem(
                    icon: Icons.inventory_2,
                    title: 'Almoxarifado',
                    isActive: activeRoute.contains('/almoxarifado'),
                    onTap: () {
                      Scaffold.maybeOf(context)?.closeDrawer();
                      context.go('/construtora/$cId/almoxarifado');
                    },
                  ),
                if (cId != null && canFinanceiro)
                  _NavItem(
                    icon: Icons.account_balance_wallet,
                    title: 'Financeiro',
                    isActive: activeRoute.contains('/financeiro'),
                    onTap: () {
                      Scaffold.maybeOf(context)?.closeDrawer();
                      context.go('/construtora/$cId/financeiro');
                    },
                  ),
                if (cId != null && canMembros)
                  _NavItem(
                    icon: Icons.group,
                    title: 'Membros',
                    isActive: activeRoute.contains('/membros'),
                    onTap: () {
                      Scaffold.maybeOf(context)?.closeDrawer();
                      context.go('/construtora/$cId/membros');
                    },
                  ),
                if (isDev)
                  _NavItem(
                    icon: Icons.build,
                    title: 'Painel Dev',
                    isActive: activeRoute == '/dev',
                    onTap: () {
                      Scaffold.maybeOf(context)?.closeDrawer();
                      context.go('/dev');
                    },
                  ),
              ],
            ),
          ),
          Divider(color: Theme.of(context).extension<SigoThemeExtension>()?.sidebarMuted.withValues(alpha: 0.2) ?? Colors.white24, height: 1),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 8.0 : 16.0, vertical: 8.0),
            child: InkWell(
              onTap: () {
                Scaffold.maybeOf(context)?.closeDrawer();
                ref.read(authRepositoryProvider).signOut();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: collapsed ? 8 : 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: collapsed
                    ? Tooltip(
                        message: 'Sair',
                        preferBelow: false,
                        child: Center(
                          child: Icon(Icons.logout, color: Theme.of(context).extension<SigoThemeExtension>()?.sidebarMuted ?? Colors.white70),
                        ),
                      )
                    : Row(
                        children: [
                          Icon(Icons.logout, color: Theme.of(context).extension<SigoThemeExtension>()?.sidebarMuted ?? Colors.white70),
                          const SizedBox(width: 12),
                          Text('Sair', style: TextStyle(color: Theme.of(context).extension<SigoThemeExtension>()?.sidebarMuted ?? Colors.white70)),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  ),
),
  );
  }
}

class _SidebarScope extends InheritedWidget {
  final bool isCollapsed;

  const _SidebarScope({
    required this.isCollapsed,
    required super.child,
  });

  static bool of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_SidebarScope>()?.isCollapsed ?? false;
  }

  @override
  bool updateShouldNotify(_SidebarScope oldWidget) => isCollapsed != oldWidget.isCollapsed;
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCollapsed = _SidebarScope.of(context);
    final theme = Theme.of(context).extension<SigoThemeExtension>();

    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 8 : 16,
        vertical: 12,
      ),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive
            ? (theme?.focusSidebar.withValues(alpha: 0.2) ?? Colors.amber[900]?.withValues(alpha: 0.2))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: isCollapsed
          ? Center(
              child: Icon(
                icon,
                color: isActive ? (theme?.focusSidebar ?? Colors.amber[700]) : (theme?.sidebarMuted ?? Colors.white70),
              ),
            )
          : Row(
              children: [
                Icon(icon, color: isActive ? (theme?.focusSidebar ?? Colors.amber[700]) : (theme?.sidebarMuted ?? Colors.white70)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isActive ? (theme?.focusSidebar ?? Colors.amber[700]) : (theme?.sidebarMuted ?? Colors.white70),
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );

    final inkWell = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: content,
    );

    if (isCollapsed) {
      return Tooltip(
        message: title,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 300),
        child: inkWell,
      );
    }

    return inkWell;
  }
}
