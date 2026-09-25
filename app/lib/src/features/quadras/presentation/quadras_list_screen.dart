import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/quadra_repository.dart';
import '../../../common_widgets/sigo_breadcrumbs.dart';
import '../../../common_widgets/sigo_empty_state.dart';
import '../../../common_widgets/sigo_error_state.dart';
import '../../../common_widgets/sigo_layout.dart';

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
    final params = (construtoraId: construtoraId, loteamentoId: loteamentoId);
    final quadrasAsync = ref.watch(watchQuadrasProvider(params));

    return SigoLayout(
      title: 'Quadras',
      activeRoute:
          '/construtora/$construtoraId/loteamentos/$loteamentoId/quadras',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SigoBreadcrumbs(),
          Expanded(
            child: quadrasAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => SigoErrorState(
                message: 'Não foi possível carregar as quadras.',
                cause: err,
                onRetry: () => ref.invalidate(watchQuadrasProvider(params)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const SigoEmptyState(
                    message: 'Nenhuma quadra cadastrada',
                    icon: Icons.grid_on_outlined,
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
