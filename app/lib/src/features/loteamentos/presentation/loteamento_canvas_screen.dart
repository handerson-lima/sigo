import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/loteamentos_import_repository.dart';
import 'widgets/geojson_canvas_widget.dart';

// O mesmo provider que escuta o draft no processamento.
final canvasDraftStreamProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, draftId) {
  final repo = ref.watch(loteamentosImportRepositoryProvider);
  return repo.watchDraft(draftId);
});

class LoteamentoCanvasScreen extends ConsumerWidget {
  final String construtoraId;
  final String draftId;

  const LoteamentoCanvasScreen({
    super.key,
    required this.construtoraId,
    required this.draftId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftStream = ref.watch(canvasDraftStreamProvider(draftId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisão do Loteamento'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: draftStream.when(
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Rascunho não encontrado.'));
          }

          // A estrutura de loteamentos_drafts costuma ter o GeoJSON sob um campo específico ou na raiz.
          // Assumindo que data seja o próprio GeoJSON ou que possua o campo 'features'.
          // Se for envolto, por exemplo data['geojson'], seria necessário ajustar.
          // Como o SPEC diz "o documento GeoJSON contendo a estrutura com as propriedades", vamos passar o objeto direto.
          return ClipRect(
            child: GeojsonCanvasWidget(geojsonData: data),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text('Erro ao carregar o rascunho:\n$err', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
