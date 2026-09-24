import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/lote_repository.dart';
import '../domain/lote.dart';
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
    final stream = ref
        .watch(loteRepositoryProvider)
        .watchLotes(construtoraId, loteamentoId, quadraId);

    return Scaffold(
      appBar: AppBar(title: const Text('Lotes')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SigoBreadcrumbs(
            segments: [
              BreadcrumbSegment(
                label: 'Loteamento',
                url: '/construtora/$construtoraId/loteamentos/$loteamentoId',
              ),
              BreadcrumbSegment(
                label: 'Quadra',
                url:
                    '/construtora/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId',
              ),
              const BreadcrumbSegment(label: 'Lotes'),
            ],
          ),
          Expanded(
            child: StreamBuilder<List<Lote>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty)
                  return const Center(
                    child: Text('Nenhum registro encontrado.'),
                  );

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
