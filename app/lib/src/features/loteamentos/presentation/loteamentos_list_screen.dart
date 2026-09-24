import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/loteamento_repository.dart';
import '../domain/loteamento.dart';

class LoteamentosListScreen extends ConsumerWidget {
  final String construtoraId;

  const LoteamentosListScreen({
    super.key,
    required this.construtoraId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(loteamentoRepositoryProvider).watchLoteamentos(construtoraId);

    return Scaffold(
      appBar: AppBar(title: const Text('Loteamentos')),
      body: StreamBuilder<List<Loteamento>>(
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
                  context.go('/construtora/$construtoraId/loteamentos/${item.id}');
                },
              );
            },
          );
        },
      ),
    );
  }
}
