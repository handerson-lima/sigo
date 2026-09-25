import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/etapa_repository.dart';
import 'package:intl/intl.dart';
import '../../../common_widgets/sigo_breadcrumbs.dart';
import '../../../common_widgets/sigo_empty_state.dart';
import '../../../common_widgets/sigo_error_state.dart';
import '../../../common_widgets/sigo_layout.dart';

class EtapasListScreen extends ConsumerWidget {
  final String construtoraId;
  final String loteamentoId;
  final String quadraId;
  final String loteId;

  const EtapasListScreen({
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
    final etapasAsync = ref.watch(watchEtapasProvider(params));
    final baseRoute =
        '/construtoras/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId/etapas';

    return SigoLayout(
      title: 'Etapas',
      activeRoute: baseRoute,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SigoBreadcrumbs(),
          Expanded(
            child: etapasAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => SigoErrorState(
                message: 'Não foi possível carregar as etapas.',
                cause: err,
                onRetry: () => ref.invalidate(watchEtapasProvider(params)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const SigoEmptyState(
                    message: 'Nenhuma etapa cadastrada',
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
                      title: Text(item.nome),
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