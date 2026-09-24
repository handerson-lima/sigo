import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/lote_repository.dart';
import '../../../common_widgets/sigo_breadcrumbs.dart';

class LotesListScreen extends ConsumerWidget {
  final String construtoraId;
  final String loteamentoId;
  final String quadraId;

  const LotesListScreen({
    super.key,
    required this.construtoraId,
    required this.loteamentoId,
    required this.quadraId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotesAsync = ref.watch(
      watchLotesProvider((
        construtoraId: construtoraId,
        loteamentoId: loteamentoId,
        quadraId: quadraId,
      )),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Lotes')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SigoBreadcrumbs(),
          Expanded(
            child: lotesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => const Center(
                child: Text('Não foi possível carregar os lotes. Tente novamente.'),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text('Nenhum registro encontrado.'),
                  );
                }

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        'Status: ${item.status} | Phase: ${item.phase}',
                      ),
                      onTap: () {
                        context.go(
                          '/construtora/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId/lotes/${item.id}/setores',
                        );
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
