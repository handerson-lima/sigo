import '../../../core/contracts.dart';
import 'stock_history_screen.dart';
import '../../authentication/data/user_repository.dart';
import '../../obras/presentation/current_permissions_provider.dart';
import '../../../sync/operation_queue.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'almoxarifado_provider.dart';
import '../domain/material.dart' as mat;

class AlmoxarifadoListScreen extends ConsumerWidget {
  final String construtoraId;

  const AlmoxarifadoListScreen({super.key, required this.construtoraId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cm = ref.watch(construtoraPermissionProvider(construtoraId)).value;
    final admin =
        ref.watch(trustedDevProvider).value == true ||
        cm?['isActive'] == true &&
            (cm?['isAdmin'] == true || cm?['isOwner'] == true);
    final materiaisAsync = ref.watch(
      construtoraMateriaisProvider(construtoraId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Almoxarifado Central')),
      body: materiaisAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erro: $e')),
        data: (materiais) {
          if (materiais.isEmpty) {
            return const Center(
              child: Text('Nenhum material cadastrado no catálogo.'),
            );
          }

          return ListView.builder(
            itemCount: materiais.length,
            itemBuilder: (context, index) {
              final mat.Material material = materiais[index];
              return ListTile(
                title: Text(
                  material.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: OperationQueue.instance.watch(),
                  builder: (context, snapshot) {
                    final rows = (snapshot.data ?? []).where(
                      (r) =>
                          r['action'] == 'stockCommand' &&
                          r['payload']['construtoraId'] == construtoraId &&
                          r['payload']['materialId'] == material.id &&
                          ['pending', 'syncing', 'failed'].contains(r['state']),
                    );
                    double delta = 0;
                    for (final row in rows) {
                      final d = row['payload'];
                      final q =
                          num.tryParse(d['quantity'].toString())?.toDouble() ??
                          0;
                      if (d['type'] == 'entrada') delta += q;
                      if (d['type'] == 'saida') delta -= q;
                      if (d['type'] == 'ajuste') delta += q;
                      if (d['type'] == 'estorno') {
                        final rev = num.tryParse(
                          d['reversalDelta']?.toString() ?? '',
                        )?.toDouble();
                        if (rev != null) delta += rev;
                      }
                    }
                    final confirmed = material.displayQuantity;
                    final confirmedStr = formatQuantityWithScale(confirmed);
                    final est = confirmed + delta;
                    final estStr = formatQuantityWithScale(est);
                    return Text(
                      'Confirmado: $confirmedStr ${material.unit}${rows.isEmpty ? '' : '\nEstimativa com pendências: $estStr ${material.unit}'}',
                    );
                  },
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.amber.shade100,
                  child: Icon(Icons.inventory_2_outlined, color: Colors.amber.shade900),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StockHistoryScreen(
                      c: construtoraId,
                      material: material,
                      canManage: admin,
                    ),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward, color: Colors.green),
                      tooltip: 'Registrar Entrada',
                      onPressed: () => context.go(
                        '/construtora/$construtoraId/almoxarifado/movimentacao',
                        extra: {'material': material, 'type': 'entrada'},
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward, color: Colors.red),
                      tooltip: 'Registrar Saída',
                      onPressed: () => context.go(
                        '/construtora/$construtoraId/almoxarifado/movimentacao',
                        extra: {'material': material, 'type': 'saida'},
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.history, color: Colors.blueGrey),
                      tooltip: 'Histórico, Ajustes e Estorno',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => StockHistoryScreen(
                            c: construtoraId,
                            material: material,
                            canManage: admin,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(
          '/construtora/$construtoraId/almoxarifado/novo_material',
        ),
        icon: const Icon(Icons.add),
        label: const Text('Novo Material'),
      ),
    );
  }
}
