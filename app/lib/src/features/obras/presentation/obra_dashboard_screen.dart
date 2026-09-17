import '../../../core/contracts.dart';
import '../../lotes/domain/lote.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'current_permissions_provider.dart';
import 'access_denied_screen.dart';

import 'package:fl_chart/fl_chart.dart';

import '../../lotes/presentation/obra_lotes_provider.dart';

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
    final canLotes = activeMember != null &&
        activeMember.isActive &&
        (activeMember.isAdmin ||
            activeMember.modules.map(normalizeModule).contains('lotes'));
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
    final lotesAsync = canLotes
        ? ref.watch(
            obraLotesProvider((construtoraId: construtoraId, obraId: obraId)),
          )
        : const AsyncData<List<Lote>>([]);

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
                const SizedBox(height: 24),

                // Módulos (Cards)
                Text(
                  'Módulos Disponíveis',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    if (canLotes)
                      SigoModuleCard(
                        icon: Icons.map,
                        title: 'Lotes e Setores',
                        onTap: () => context.go(
                          '/construtora/$construtoraId/obra/$obraId/lotes',
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
                    if (canRh)
                      SigoModuleCard(
                        icon: Icons.playlist_add_check,
                        title: 'Chamada Diária (RH)',
                        onTap: () => context.go(
                          '/construtora/$construtoraId/obra/$obraId/rh/chamadas',
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
                const SizedBox(height: 32),

                // Analytics
                lotesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const SizedBox(),
                  data: (lotes) {
                    if (lotes.isEmpty) return const SizedBox();

                    final Map<String, int> statusCount = {};
                    for (var lote in lotes) {
                      statusCount[lote.phase] =
                          (statusCount[lote.phase] ?? 0) + 1;
                    }
                    final colors = [
                      Colors.blue,
                      Colors.orange,
                      Colors.purple,
                      Colors.green,
                      Colors.teal,
                    ];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status dos Lotes',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 150,
                          child: Row(
                            children: [
                              Expanded(
                                child: PieChart(
                                  PieChartData(
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 30,
                                    sections: statusCount.entries.map((e) {
                                      final idx = statusCount.keys
                                          .toList()
                                          .indexOf(e.key);
                                      return PieChartSectionData(
                                        value: e.value.toDouble(),
                                        color: colors[idx % colors.length],
                                        title: '${e.value}',
                                        radius: 20,
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: statusCount.length,
                                  itemBuilder: (context, index) {
                                    final entry = statusCount.entries.elementAt(
                                      index,
                                    );
                                    return ListTile(
                                      leading: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: colors[index % colors.length],
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        entry.key,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
