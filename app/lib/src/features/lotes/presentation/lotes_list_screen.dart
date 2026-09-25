import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/lote_repository.dart';
import '../domain/lote.dart';
import '../../../common_widgets/sigo_breadcrumbs.dart';
import '../../../common_widgets/sigo_empty_state.dart';
import '../../../common_widgets/sigo_error_state.dart';
import '../../../common_widgets/sigo_layout.dart';
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
    final member = ref.watch(construtoraPermissionProvider(construtoraId)).value;
    final isAdmin = member?['isActive'] == true &&
        (member?['isAdmin'] == true ||
            member?['isOwner'] == true ||
            member?['role'] == 'admin' ||
            member?['role'] == 'owner');

    final baseRoute =
        '/construtora/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId/lotes';

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
                  return const SigoEmptyState(
                    message: 'Nenhum lote cadastrado',
                    icon: Icons.crop_landscape_outlined,
                  );
                }

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        'Status: ${item.status.label} | Fase: ${item.phase}',
                      ),
                      onTap: () {
                        context.go(
                          '$baseRoute/${item.id}/setores',
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
