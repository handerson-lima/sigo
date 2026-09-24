import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/equipe_repository.dart';
import 'package:intl/intl.dart';
import '../../../common_widgets/sigo_breadcrumbs.dart';

class EquipesListScreen extends ConsumerWidget {
  final String construtoraId;
  final String loteamentoId;
  final String quadraId;
  final String loteId;
  final String setorId;

  const EquipesListScreen({
    super.key,
    required this.construtoraId,
    required this.loteamentoId,
    required this.quadraId,
    required this.loteId,
    required this.setorId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipesAsync = ref.watch(watchEquipesProvider((construtoraId: construtoraId, loteamentoId: loteamentoId, quadraId: quadraId, loteId: loteId, setorId: setorId)));

    return Scaffold(
      appBar: AppBar(title: const Text('Equipes')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SigoBreadcrumbs(),
          Expanded(
            child: equipesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Não foi possível carregar as equipes. Tente novamente.')),
              data: (items) {
                if (items.isEmpty) return const Center(child: Text('Nenhum registro encontrado.'));

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt);
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text('Criado em: $dateStr'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
