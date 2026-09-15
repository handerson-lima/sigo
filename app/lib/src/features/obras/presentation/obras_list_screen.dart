import '../../authentication/data/user_repository.dart';
import 'current_permissions_provider.dart';
import '../../financeiro/domain/despesa.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'construtora_obras_provider.dart';

import 'package:fl_chart/fl_chart.dart';

import '../../financeiro/presentation/financeiro_provider.dart';

import '../../../common_widgets/sigo_layout.dart';

class ObrasListScreen extends ConsumerWidget {
  final String construtoraId;

  const ObrasListScreen({super.key, required this.construtoraId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obrasAsync = ref.watch(construtoraObrasProvider(construtoraId));
    final cm = ref.watch(construtoraPermissionProvider(construtoraId)).value;
    final admin =
        ref.watch(trustedDevProvider).value == true ||
        cm?['isActive'] == true &&
            (cm?['isAdmin'] == true ||
                cm?['isOwner'] == true ||
                cm?['role'] == 'admin' ||
                cm?['role'] == 'owner');
    final stock =
        admin ||
        cm?['isActive'] == true &&
            (cm?['modules'] as List? ?? []).any(
              (m) => m == 'estoque' || m == 'almoxarifado',
            );
    final despesasAsync = admin
        ? ref.watch(despesasConstrutoraProvider(construtoraId))
        : const AsyncData<List<Despesa>>([]);

    return SigoLayout(
      title: 'Painel da Construtora',
      activeRoute: '/construtora/$construtoraId',
      actions: [
        if (admin)
          IconButton(
            icon: const Icon(Icons.people, color: Colors.black54),
            tooltip: 'Gerenciar Membros',
            onPressed: () {
              context.go('/construtora/$construtoraId/membros');
            },
          ),
        if (stock)
          IconButton(
            icon: const Icon(Icons.inventory_2, color: Colors.black54),
            tooltip: 'Almoxarifado Global',
            onPressed: () {
              context.go('/construtora/$construtoraId/almoxarifado');
            },
          ),
        if (admin)
          IconButton(
            icon: const Icon(
              Icons.account_balance_wallet,
              color: Colors.black54,
            ),
            tooltip: 'Financeiro Global',
            onPressed: () {
              context.go('/construtora/$construtoraId/financeiro');
            },
          ),
      ],
      child: obrasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
        data: (obras) {
          if (obras.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma obra encontrada para você nesta construtora.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return Column(
            children: [
              despesasAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (_, _) => const SizedBox(),
                data: (despesas) {
                  if (despesas.isEmpty) return const SizedBox();

                  final Map<String, double> categoryTotals = {};
                  for (var d in despesas) {
                    categoryTotals[d.categoria] =
                        (categoryTotals[d.categoria] ?? 0) + d.valor;
                  }

                  final colors = [
                    Colors.blue,
                    Colors.red,
                    Colors.green,
                    Colors.orange,
                    Colors.purple,
                    Colors.teal,
                  ];
                  int cIdx = 0;

                  return SizedBox(
                    height: 200,
                    child: Row(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: categoryTotals.entries.map((e) {
                                final color = colors[cIdx++ % colors.length];
                                return PieChartSectionData(
                                  value: e.value,
                                  color: color,
                                  title: '',
                                  radius: 20,
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: categoryTotals.length,
                            itemBuilder: (context, index) {
                              final entry = categoryTotals.entries.elementAt(
                                index,
                              );
                              final color = colors[index % colors.length];
                              return ListTile(
                                leading: Container(
                                  width: 16,
                                  height: 16,
                                  color: color,
                                ),
                                title: Text(
                                  entry.key,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                subtitle: Text(
                                  'R\$ ${entry.value.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    childAspectRatio: 3 / 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: obras.length,
                  itemBuilder: (context, index) {
                    final obra = obras[index];
                    return Card(
                      elevation: 4,
                      child: InkWell(
                        onTap: () => context.go(
                          '/construtora/$construtoraId/obra/${obra.id}',
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                obra.name,
                                style: Theme.of(context).textTheme.titleLarge,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              if (obra.description != null)
                                Text(
                                  obra.description!,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
