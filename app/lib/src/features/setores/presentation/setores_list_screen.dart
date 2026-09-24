import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/setor_repository.dart';
import '../domain/setor.dart';
import '../../../common_widgets/sigo_breadcrumbs.dart';

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
    final stream = ref.watch(setorRepositoryProvider).watchSetores(construtoraId, loteamentoId, quadraId, loteId);

    return Scaffold(
      appBar: AppBar(title: const Text('Setores')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SigoBreadcrumbs(
            segments: [
              BreadcrumbSegment(label: 'Loteamento', url: '/loteamentos/$loteamentoId'),
              BreadcrumbSegment(label: 'Quadra', url: '/loteamentos/$loteamentoId/quadras/$quadraId'),
              BreadcrumbSegment(label: 'Lote', url: '/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId'),
              const BreadcrumbSegment(label: 'Setores'),
            ],
          ),
          Expanded(
            child: StreamBuilder<List<Setor>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) return const Center(child: Text('Nenhum registro encontrado.'));

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text('Criado em: ${item.createdAt}'),
                      onTap: () {
                        context.go('/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId/setores/${item.id}/equipes');
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
