import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/quadra_repository.dart';
import '../../../common_widgets/sigo_breadcrumbs.dart';

class QuadrasListScreen extends ConsumerWidget {
  final String construtoraId;
  final String loteamentoId;

  const QuadrasListScreen({
    super.key,
    required this.construtoraId,
    required this.loteamentoId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quadrasAsync = ref.watch(
      watchQuadrasProvider((
        construtoraId: construtoraId,
        loteamentoId: loteamentoId,
      )),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Quadras')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SigoBreadcrumbs(),
          Expanded(
            child: quadrasAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => const Center(
                child: Text('Não foi possível carregar as quadras. Tente novamente.'),
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
                          '/construtora/$construtoraId/loteamentos/$loteamentoId/quadras/${item.id}/lotes',
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
