import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/lote.dart';
import 'obra_lotes_provider.dart';

class LotesListScreen extends ConsumerWidget {
  final String construtoraId;
  final String obraId;

  const LotesListScreen({super.key, required this.construtoraId, required this.obraId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotesAsync = ref.watch(obraLotesProvider((construtoraId: construtoraId, obraId: obraId)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Lotes'),
      ),
      body: lotesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erro: $e')),
        data: (lotes) {
          if (lotes.isEmpty) {
            return const Center(child: Text('Nenhum lote cadastrado nesta obra.'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 1,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: lotes.length,
            itemBuilder: (context, index) {
              final lote = lotes[index];
              return _LoteCard(lote: lote);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/construtora/$construtoraId/obra/$obraId/lotes/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Novo Lote'),
      ),
    );
  }
}

class _LoteCard extends StatelessWidget {
  final Lote lote;
  const _LoteCard({required this.lote});

  Color _getStatusColor() {
    switch (lote.status) {
      case LoteStatus.noPrazo:
        return Colors.green[100]!;
      case LoteStatus.atrasado:
        return Colors.red[100]!;
      case LoteStatus.paralisado:
        return Colors.orange[100]!;
      case LoteStatus.concluido:
        return Colors.blue[100]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _getStatusColor(),
      child: InkWell(
        onTap: () {
          // TODO: Abrir bottom sheet para alterar fase/status futuramente
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lote.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Text('Fase: ${lote.phase}', style: const TextStyle(fontSize: 12)),
              Text('Status: ${lote.status.name}', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
