import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/loteamentos_import_repository.dart';

final draftStreamProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, draftId) {
  final repo = ref.watch(loteamentosImportRepositoryProvider);
  return repo.watchDraft(draftId);
});

class LoteamentoProcessingScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final String draftId;

  const LoteamentoProcessingScreen({
    super.key,
    required this.construtoraId,
    required this.draftId,
  });

  @override
  ConsumerState<LoteamentoProcessingScreen> createState() => _LoteamentoProcessingScreenState();
}

class _LoteamentoProcessingScreenState extends ConsumerState<LoteamentoProcessingScreen> {
  @override
  Widget build(BuildContext context) {
    final draftStream = ref.watch(draftStreamProvider(widget.draftId));

    return Scaffold(
      body: Center(
        child: draftStream.when(
          data: (data) {
            if (data == null) {
              // Ainda não existe (processando background)
              return const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 24),
                  Text(
                    'Processando Geometria...',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('Aguarde enquanto o servidor converte os polígonos. Não feche esta tela.'),
                ],
              );
            }

            // Quando houver data, redireciona automaticamente
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                // Para o futuro canvas de revisão (Epic 3)
                context.replace('/construtoras/${widget.construtoraId}/loteamentos/draft/${widget.draftId}');
              }
            });

            return const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 64),
                SizedBox(height: 16),
                Text('Rascunho gerado com sucesso! Redirecionando...'),
              ],
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (err, stack) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text('Erro ao escutar processamento:\n$err', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
