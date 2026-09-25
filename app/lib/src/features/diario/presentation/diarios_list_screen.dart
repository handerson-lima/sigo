import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../common_widgets/sigo_layout.dart';
import 'diario_details_dialog.dart';
import 'obra_diarios_provider.dart';

class DiariosListScreen extends ConsumerWidget {
  final String construtoraId;
  final String obraId;

  const DiariosListScreen({super.key, required this.construtoraId, required this.obraId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diariosAsync = ref.watch(obraDiariosProvider((construtoraId: construtoraId, obraId: obraId)));

    return SigoLayout(
      title: 'Diários de Obra (RDO)',
      activeRoute: '/construtoras/$construtoraId/obra/$obraId/diarios',
      actions: [
        IconButton(
          icon: const Icon(Icons.sync),
          tooltip: 'Fila de Sincronização',
          onPressed: () => context.push('/construtoras/$construtoraId/obra/$obraId/diarios/sync'),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/construtoras/$construtoraId/obra/$obraId/diarios/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Novo RDO'),
      ),
      child: diariosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erro: $e')),
        data: (diarios) {
          if (diarios.isEmpty) {
            return const Center(child: Text('Nenhum diário registrado nesta obra.'));
          }
          return ListView.builder(
            itemCount: diarios.length,
            itemBuilder: (context, index) {
              final d = diarios[index];
              final dataStr = '${d.date.day.toString().padLeft(2, '0')}/${d.date.month.toString().padLeft(2, '0')}/${d.date.year}';
              final obsCurta = d.observacoes.length > 30 ? '${d.observacoes.substring(0, 30)}...' : d.observacoes;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(dataStr),
                  subtitle: Text('Clima: ${d.weather.name}\nResumo: $obsCurta'),
                  isThreeLine: true,
                  trailing: d.photoUrls.isNotEmpty ? const Icon(Icons.photo_library) : null,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => DiarioDetailsDialog(diario: d),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
