import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/loteamento_repository.dart';
import '../../../common_widgets/sigo_breadcrumbs.dart';

class LoteamentosListScreen extends ConsumerWidget {
  final String construtoraId;

  const LoteamentosListScreen({
    super.key,
    required this.construtoraId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loteamentosAsync = ref.watch(
      watchLoteamentosProvider((construtoraId: construtoraId)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Loteamentos')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SigoBreadcrumbs(),
          Expanded(
            child: loteamentosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => const Center(
                child: Text('Não foi possível carregar os loteamentos. Tente novamente.'),
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
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        context.go(
                          '/construtora/$construtoraId/loteamentos/${item.id}/quadras',
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
