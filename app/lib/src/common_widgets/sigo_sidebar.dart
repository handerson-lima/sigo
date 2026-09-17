import '../features/obras/presentation/current_permissions_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/contracts.dart';
import '../features/authentication/data/auth_repository.dart';
import '../features/authentication/data/user_repository.dart';

class SigoSidebar extends ConsumerWidget {
  final String activeRoute;

  const SigoSidebar({super.key, required this.activeRoute});

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
    return Container(
      width: 250,
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Logo placeholder
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Icon(
                  Icons.hexagon_outlined,
                  color: Colors.amber[700],
                  size: 40,
                ),
                const SizedBox(width: 8),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conecta',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      'SIGO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                  if (obra != null &&
                      obra.isActive &&
                      (obra.isAdmin ||
                          obra.modules.map(normalizeModule).contains('lotes')))
                    _NavItem(
                      icon: Icons.map,
                      title: 'Lotes e Setores',
                      isActive: activeRoute.contains('/lotes'),
                      onTap: () {
                        Scaffold.maybeOf(context)?.closeDrawer();
                        context.go('/construtora/$cId/obra/$oId/lotes');
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
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.only(left: 16, bottom: 8),
                    child: Text(
                      'NAVEGAÇÃO GLOBAL',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
                if (cId != null &&
                    (isDev ||
                        obra != null &&
                            obra.isActive &&
                            (obra.isAdmin ||
                                obra.modules
                                    .map(normalizeModule)
                                    .contains('rh'))))
                  _NavItem(
                    icon: Icons.people,
                    title: 'Funcionários (RH)',
                    isActive: activeRoute.contains('/rh/funcionarios'),
                    onTap: () {
                      Scaffold.maybeOf(context)?.closeDrawer();
                      context.go('/construtora/$cId/rh/funcionarios');
                    },
                  ),
                if (cId != null &&
                    (isDev ||
                        obra != null &&
                            obra.isActive &&
                            (obra.isAdmin ||
                                obra.modules
                                    .map(normalizeModule)
                                    .contains('estoque'))))
                  _NavItem(
                    icon: Icons.inventory_2,
                    title: 'Almoxarifado',
                    isActive: activeRoute.contains('/almoxarifado'),
                    onTap: () {
                      Scaffold.maybeOf(context)?.closeDrawer();
                      context.go('/construtora/$cId/almoxarifado');
                    },
                  ),
                if (cId != null && (isDev || obra != null && obra.isAdmin))
                  _NavItem(
                    icon: Icons.account_balance_wallet,
                    title: 'Financeiro',
                    isActive: activeRoute.contains('/financeiro'),
                    onTap: () {
                      Scaffold.maybeOf(context)?.closeDrawer();
                      context.go('/construtora/$cId/financeiro');
                    },
                  ),
                if (cId != null && (isDev || obra != null && obra.isAdmin))
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
          const Divider(color: Colors.white24, height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: InkWell(
              onTap: () {
                ref.read(authRepositoryProvider).signOut();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.logout, color: Colors.white70),
                    SizedBox(width: 12),
                    Text('Sair', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.amber[900]?.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? Colors.amber[700] : Colors.white70),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.amber[700] : Colors.white70,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
