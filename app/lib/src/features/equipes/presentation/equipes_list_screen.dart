import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/equipe_repository.dart';
import 'package:intl/intl.dart';
import '../../../common_widgets/sigo_breadcrumbs.dart';
import '../../../common_widgets/sigo_empty_state.dart';
import '../../../common_widgets/sigo_error_state.dart';
import '../../../common_widgets/sigo_layout.dart';

class EquipesListScreen extends ConsumerWidget {
  final String construtoraId;
  final String loteamentoId;
  final String quadraId;
  final String loteId;
  final String etapaId;

  const EquipesListScreen({
    super.key,
    required this.construtoraId,
    required this.loteamentoId,
    required this.quadraId,
    required this.loteId,
    required this.etapaId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (
      construtoraId: construtoraId,
      loteamentoId: loteamentoId,
      quadraId: quadraId,
      loteId: loteId,
      etapaId: etapaId,
    );
    final equipesAsync = ref.watch(watchEquipesProvider(params));

    return SigoLayout(
      title: 'Equipes',
      activeRoute:
          '/construtora/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId/etapas/$etapaId/equipes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SigoBreadcrumbs(),
          Expanded(
            child: equipesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => SigoErrorState(
                message: 'Não foi possível carregar as equipes.',
                cause: err,
                onRetry: () => ref.invalidate(watchEquipesProvider(params)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const SigoEmptyState(
                    message: 'Nenhuma equipe cadastrada',
                    icon: Icons.groups_outlined,
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
