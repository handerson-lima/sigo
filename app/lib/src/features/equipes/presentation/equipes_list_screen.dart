import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/equipe_repository.dart';
import '../domain/equipe.dart';
import '../../../common_widgets/sigo_breadcrumbs.dart';

class EquipesListScreen extends ConsumerWidget {
  final String construtoraId;
  final String loteamentoId;
  final String quadraId;
  final String loteId;
  final String setorId;

  const EquipesListScreen({
    super.key,
    required this.construtoraId,
    required this.loteamentoId,
    required this.quadraId,
    required this.loteId,
    required this.setorId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(equipeRepositoryProvider).watchEquipes(construtoraId, loteamentoId, quadraId, loteId, setorId);

    return Scaffold(
      appBar: AppBar(title: const Text('Equipes')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SigoBreadcrumbs(
            segments: [
              BreadcrumbSegment(label: 'Loteamento', url: '/loteamentos/$loteamentoId'),
              BreadcrumbSegment(label: 'Quadra', url: '/loteamentos/$loteamentoId/quadras/$quadraId'),
              BreadcrumbSegment(label: 'Lote', url: '/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId'),
              BreadcrumbSegment(label: 'Setor', url: '/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId/setores/$setorId'),
              const BreadcrumbSegment(label: 'Equipes'),
            ],
          ),
          Expanded(
            child: StreamBuilder<List<Equipe>>(
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
