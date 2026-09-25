import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/setor_repository.dart';
import 'package:intl/intl.dart';
import '../../../common_widgets/sigo_breadcrumbs.dart';
import '../../../common_widgets/sigo_empty_state.dart';
import '../../../common_widgets/sigo_error_state.dart';
import '../../../common_widgets/sigo_layout.dart';

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
    final params = (
      construtoraId: construtoraId,
      loteamentoId: loteamentoId,
      quadraId: quadraId,
      loteId: loteId,
    );
    final setoresAsync = ref.watch(watchSetoresProvider(params));
    final baseRoute =
        '/construtora/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId/setores';

    return SigoLayout(
      title: 'Setores',
      activeRoute: baseRoute,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SigoBreadcrumbs(),
          Expanded(
            child: setoresAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => SigoErrorState(
                message: 'Não foi possível carregar os setores.',
                cause: err,
                onRetry: () => ref.invalidate(watchSetoresProvider(params)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const SigoEmptyState(
                    message: 'Nenhum setor cadastrado',
                    icon: Icons.view_module_outlined,
                  );
                }

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final dateStr =
                        DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt);
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text('Criado em: $dateStr'),
                      onTap: () {
                        context.go(
                          '$baseRoute/${item.id}/equipes',
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
