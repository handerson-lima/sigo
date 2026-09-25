import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/loteamento_repository.dart';
import '../../../common_widgets/sigo_breadcrumbs.dart';
import '../../../common_widgets/sigo_empty_state.dart';
import '../../../common_widgets/sigo_error_state.dart';
import '../../../common_widgets/sigo_layout.dart';

class LoteamentosListScreen extends ConsumerWidget {
  final String construtoraId;

  const LoteamentosListScreen({
    super.key,
    required this.construtoraId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (construtoraId: construtoraId);
    final loteamentosAsync = ref.watch(watchLoteamentosProvider(params));

    return SigoLayout(
      title: 'Loteamentos',
      activeRoute: '/construtora/$construtoraId/loteamentos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SigoBreadcrumbs(),
          Expanded(
            child: loteamentosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => SigoErrorState(
                message: 'Não foi possível carregar os loteamentos.',
                cause: err,
                onRetry: () => ref.invalidate(watchLoteamentosProvider(params)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const SigoEmptyState(
                    message: 'Nenhum loteamento cadastrado',
                    icon: Icons.map_outlined,
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
