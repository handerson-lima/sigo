import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/setor_repository.dart';
import 'package:intl/intl.dart';
import '../../../common_widgets/sigo_breadcrumbs.dart';

class SetoresListScreen extends ConsumerWidget {
  final String construtoraId;
  final String loteamentoId;
  final String quadraId;
  final String loteId;

  const SetoresListScreen({
    super.key,
    required this.construtoraId,
    required this.loteamentoId,
    required this.quadraId,
    required this.loteId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setoresAsync = ref.watch(watchSetoresProvider((construtoraId: construtoraId, loteamentoId: loteamentoId, quadraId: quadraId, loteId: loteId)));

    return Scaffold(
      appBar: AppBar(title: const Text('Setores')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SigoBreadcrumbs(),
          Expanded(
            child: setoresAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Não foi possível carregar os setores. Tente novamente.')),
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
                      onTap: () {
                        context.go('/construtoras/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId/setores/${item.id}/equipes');
                      },
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
