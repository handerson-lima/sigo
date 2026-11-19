import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/lote_repository.dart';
import 'atribuir_lotacao_lote_sheet.dart';
import 'lote_summary_card.dart';
import '../../../common_widgets/sigo_breadcrumbs.dart';
import '../../../common_widgets/sigo_empty_state.dart';
import '../../../common_widgets/sigo_error_state.dart';
import '../../../common_widgets/sigo_layout.dart';
import '../../authentication/data/user_repository.dart';
import '../../obras/presentation/current_permissions_provider.dart';

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
    final params = (
      construtoraId: construtoraId,
      loteamentoId: loteamentoId,
      quadraId: quadraId,
    );
    final lotesAsync = ref.watch(watchLotesProvider(params));
    final dev = ref.watch(trustedDevProvider).value == true;
    final member = ref
        .watch(construtoraPermissionProvider(construtoraId))
        .value;
    final isAdmin =
        dev ||
        (member?['isActive'] == true &&
            (member?['isAdmin'] == true || member?['isOwner'] == true));

    final baseRoute =
        '/construtoras/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId/lotes';

    return SigoLayout(
      title: 'Lotes',
      activeRoute: baseRoute,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.go('$baseRoute/novo'),
              icon: const Icon(Icons.add),
              label: const Text('Novo Lote'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SigoBreadcrumbs(),
          Expanded(
            child: lotesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => SigoErrorState(
                message: 'Não foi possível carregar os lotes.',
                cause: err,
                onRetry: () => ref.invalidate(watchLotesProvider(params)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return SigoEmptyState(
                    message: 'Nenhum lote cadastrado',
                    icon: Icons.crop_landscape_outlined,
                    action: isAdmin
                        ? ElevatedButton.icon(
                            onPressed: () => context.go('$baseRoute/novo'),
                            icon: const Icon(Icons.add),
                            label: const Text('Novo Lote'),
                          )
                        : null,
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1200
                        ? 3
                        : constraints.maxWidth >= 820
                        ? 2
                        : 1;
                    final rowCount = (items.length / columns).ceil();

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                      itemCount: rowCount,
                      itemBuilder: (context, rowIndex) {
                        if (columns == 1) {
                          final item = items[rowIndex];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: LoteSummaryCard(
                              lote: item,
                              isAdmin: isAdmin,
                              onTap: () =>
                                  context.go('$baseRoute/${item.id}/detalhes'),
                              onAtribuirTap: isAdmin
                                  ? () => showAtribuirLotacaoLoteSheet(
                                      context: context,
                                      construtoraId: construtoraId,
                                      lote: item,
                                    )
                                  : null,
                            ),
                          );
                        }

                        final start = rowIndex * columns;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(columns, (colIndex) {
                              final itemIndex = start + colIndex;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: colIndex == 0 ? 0 : 6,
                                    right: colIndex == columns - 1 ? 0 : 6,
                                  ),
                                  child: itemIndex < items.length
                                      ? LoteSummaryCard(
                                          lote: items[itemIndex],
                                          isAdmin: isAdmin,
                                          onTap: () => context.go(
                                            '$baseRoute/${items[itemIndex].id}/detalhes',
                                          ),
                                          onAtribuirTap: isAdmin
                                              ? () =>
                                                    showAtribuirLotacaoLoteSheet(
                                                      context: context,
                                                      construtoraId:
                                                          construtoraId,
                                                      lote: items[itemIndex],
                                                    )
                                              : null,
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              );
                            }),
                          ),
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
