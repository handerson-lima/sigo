import '../../../core/contracts.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'current_permissions_provider.dart';
import 'access_denied_screen.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../../../common_widgets/sigo_module_card.dart';

class ObraDashboardScreen extends ConsumerWidget {
  final String construtoraId;
  final String obraId;

  const ObraDashboardScreen({
    super.key,
    required this.construtoraId,
    required this.obraId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionsAsync = ref.watch(
      currentPermissionsProvider((
        construtoraId: construtoraId,
        obraId: obraId,
      )),
    );
    final activeMember = permissionsAsync.asData?.value;
    final centralMember =
        ref.watch(construtoraPermissionProvider(construtoraId)).value;
    final centralAdmin = centralMember?['isActive'] == true &&
        (centralMember?['isAdmin'] == true ||
            centralMember?['isOwner'] == true);
    final canCentralLotes = centralAdmin ||
        centralMember?['isActive'] == true &&
            normalizeRawModules(
              centralMember?['modules'],
              centralMember?['allowedModules'],
            ).contains('lotes');
    final canRh = activeMember != null &&
        activeMember.isActive &&
        (activeMember.isAdmin ||
            activeMember.modules.map(normalizeModule).contains('rh'));
    final canEstoque = activeMember != null &&
        activeMember.isActive &&
        (activeMember.isAdmin ||
            activeMember.modules.map(normalizeModule).contains('estoque'));
    final canFinanceiro = activeMember != null &&
        activeMember.isActive &&
        activeMember.isAdmin;
    final canAdm = activeMember != null &&
        activeMember.isActive &&
        (activeMember.isAdmin ||
            activeMember.modules.map(normalizeModule).contains('adm') ||
            activeMember.modules.map(normalizeModule).contains('financeiro'));
    final canCompras = activeMember != null &&
        activeMember.isActive &&
        (activeMember.isAdmin ||
            activeMember.modules.map(normalizeModule).contains('compras') ||
            activeMember.modules.map(normalizeModule).contains('almoxarifado') ||
            activeMember.modules.map(normalizeModule).contains('adm') ||
            activeMember.modules.map(normalizeModule).contains('financeiro'));
    final canEpi = activeMember != null &&
        activeMember.isActive &&
        (activeMember.isAdmin ||
            activeMember.modules.map(normalizeModule).contains('epi') ||
            activeMember.modules.map(normalizeModule).contains('rh'));
    final canValidacao = activeMember != null &&
        activeMember.isActive &&
        (activeMember.isAdmin ||
            activeMember.modules.map(normalizeModule).contains('validacao') ||
            activeMember.modules.map(normalizeModule).contains('qualidade'));

    return permissionsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) =>
          Scaffold(body: Center(child: Text('Erro de validação: $err'))),
      data: (member) {
        if (member == null || !member.isActive) {
          return const AccessDeniedScreen();
        }

        return SigoLayout(
          title: 'Painel da Obra',
          activeRoute: '/construtora/$construtoraId/obra/$obraId',
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bem-vindo ao Painel',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      member.isAdmin
                          ? Icons.admin_panel_settings
                          : Icons.person,
                      color: member.isAdmin ? Colors.amber[900] : Colors.blue,
                      size: 32,
                    ),
                    title: Text(
                      member.isAdmin ? 'Nível: Administrador' : 'Nível: Membro',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('ID da Obra: $obraId'),
                  ),
                ),
                const SizedBox(height: 28),

                // Categoria 1: Canteiro & Produção
                Row(
                  children: [
                    Icon(Icons.construction, size: 20, color: Colors.blueGrey[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Canteiro & Produção',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    if (canCentralLotes)
                      SigoModuleCard(
                        icon: Icons.map,
                        title: 'Lotes e Setores',
                        onTap: () => context.go(
                          '/construtora/$construtoraId/loteamentos',
                        ),
                      ),
                    if (member.isAdmin ||
                        member.modules.map(normalizeModule).contains('diario'))
                      SigoModuleCard(
                        icon: Icons.assignment,
                        title: 'Diário de Obra',
                        onTap: () => context.go(
                          '/construtora/$construtoraId/obra/$obraId/diarios',
                        ),
                      ),
                    if (canValidacao)
                      SigoModuleCard(
                        icon: Icons.rule,
                        title: 'Validação & Qualidade',
                        onTap: () => context.go(
                          '/construtora/$construtoraId/validacao/templates',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // Categoria 2: Pessoas & Segurança
                Row(
                  children: [
                    Icon(Icons.health_and_safety_outlined, size: 20, color: Colors.blueGrey[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Pessoas & Segurança',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    if (canRh)
                      SigoModuleCard(
                        icon: Icons.playlist_add_check,
                        title: 'Chamada Diária (RH)',
                        onTap: () => context.go(
                          '/construtora/$construtoraId/obra/$obraId/rh/chamadas',
                        ),
                      ),
                    if (canEpi)
                      SigoModuleCard(
                        icon: Icons.health_and_safety,
                        title: 'Entrega de EPIs',
                        onTap: () => context.go(
                          '/construtora/$construtoraId/obra/$obraId/epis/entrega',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // Categoria 3: Gestão & Suprimentos
                Row(
                  children: [
                    Icon(Icons.account_balance, size: 20, color: Colors.blueGrey[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Gestão & Suprimentos',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    if (canAdm)
                      SigoModuleCard(
                        icon: Icons.receipt_long,
                        title: 'Contas a Pagar / ADM',
                        onTap: () => context.go(
                          '/construtora/$construtoraId/obra/$obraId/despesas',
                        ),
                      ),
                    if (canCompras)
                      SigoModuleCard(
                        icon: Icons.shopping_cart_outlined,
                        title: 'Compras e NF',
                        onTap: () => context.go(
                          '/construtora/$construtoraId/obra/$obraId/compras',
                        ),
                      ),
                    if (canAdm || canFinanceiro)
                      SigoModuleCard(
                        icon: Icons.query_stats_rounded,
                        title: 'Visão 360 Custos',
                        onTap: () => context.go(
                          '/construtora/$construtoraId/obra/$obraId/custos-360',
                        ),
                      ),
                    if (canEstoque)
                      SigoModuleCard(
                        icon: Icons.inventory_2,
                        title: 'Almoxarifado',
                        onTap: () => context.go(
                          '/construtora/$construtoraId/almoxarifado',
                        ),
                      ),
                    if (canFinanceiro)
                      SigoModuleCard(
                        icon: Icons.account_balance_wallet,
                        title: 'Financeiro',
                        onTap: () => context.go(
                          '/construtora/$construtoraId/financeiro',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
