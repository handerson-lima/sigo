import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/quadra_repository.dart';
import '../domain/quadra.dart';

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
    final stream = ref.watch(quadraRepositoryProvider).watchQuadras(construtoraId, loteamentoId);

    return Scaffold(
      appBar: AppBar(title: const Text('Quadras')),
      body: StreamBuilder<List<Quadra>>(
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
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  context.go('/construtora/$construtoraId/loteamentos/$loteamentoId/quadras/${item.id}');
                },
              );
            },
          );
        },
      ),
    );
  }
}
