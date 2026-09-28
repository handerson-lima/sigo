import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/loteamentos_import_repository.dart';
import 'widgets/geojson_canvas_widget.dart';
import 'widgets/lote_correcao_panel.dart';

// O mesmo provider que escuta o draft no processamento.
final canvasDraftStreamProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, draftId) {
      final repo = ref.watch(loteamentosImportRepositoryProvider);
      return repo.watchDraft(draftId);
    });

class LoteamentoCanvasScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final String draftId;

  const LoteamentoCanvasScreen({
    super.key,
    required this.construtoraId,
    required this.draftId,
  });

  @override
  ConsumerState<LoteamentoCanvasScreen> createState() =>
      _LoteamentoCanvasScreenState();
}

class _LoteamentoCanvasScreenState
    extends ConsumerState<LoteamentoCanvasScreen> {
  int? _selectedFeatureIndex;
  bool _isApproving = false;

  @override
  Widget build(BuildContext context) {
    final draftStream = ref.watch(canvasDraftStreamProvider(widget.draftId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisão do Loteamento'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions:
            draftStream.whenOrNull(
              data: (data) {
                if (data == null) return null;
                final features = data['features'] as List<dynamic>? ?? [];
                final ambiguos = features.where((f) {
                  if (f is! Map<String, dynamic>) return false;
                  final props = f['properties'];
                  if (props is! Map<String, dynamic>) return false;
                  return props['status'] == 'ambiguo';
                }).length;
                return [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Chip(
                        label: Text('$ambiguos Pendências'),
                        backgroundColor: ambiguos > 0
                            ? Colors.orange.withAlpha(153)
                            : Colors.green.withAlpha(153),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: FilledButton(
                      onPressed:
                          (ambiguos == 0 && !_isApproving)
                          ? () async {
                              setState(() => _isApproving = true);
                              try {
                                final repo = ref.read(
                                  loteamentosImportRepositoryProvider,
                                );
                                await repo.approveDraft(widget.draftId);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Consolidação iniciada. O loteamento aparecerá na lista ao concluir.',
                                    ),
                                  ),
                                );
                                context.go(
                                  '/construtoras/${widget.construtoraId}/loteamentos',
                                );
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Erro ao aprovar rascunho: $e',
                                      ),
                                    ),
                                  );
                                }
                              } finally {
                                if (context.mounted) {
                                  setState(() => _isApproving = false);
                                }
                              }
                            }
                          : null,
                      child: _isApproving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Aprovar Definitivamente'),
                    ),
                  ),
                ];
              },
            ) ??
            [],
      ),
      body: draftStream.when(
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Rascunho não encontrado.'));
          }

          final features = data['features'] as List<dynamic>? ?? [];

          return Row(
            children: [
              Expanded(
                child: ClipRect(
                  child: GeojsonCanvasWidget(
                    geojsonData: data,
                    selectedFeatureIndex: _selectedFeatureIndex,
                    onFeatureTap: (index) {
                      setState(() {
                        if (index == -1) {
                          _selectedFeatureIndex = null;
                        } else {
                          _selectedFeatureIndex = index;
                        }
                      });
                    },
                  ),
                ),
              ),
              if (_selectedFeatureIndex != null &&
                  _selectedFeatureIndex! < features.length)
                LoteCorrecaoPanel(
                  properties:
                      features[_selectedFeatureIndex!]['properties']
                          as Map<String, dynamic>? ??
                      {},
                  onSave: (newName) async {
                    try {
                      final repo = ref.read(
                        loteamentosImportRepositoryProvider,
                      );
                      await repo.updateDraftFeature(
                        widget.draftId,
                        _selectedFeatureIndex!,
                        {'nome': newName, 'status': 'resolvido'},
                      );
                      if (!context.mounted) return;
                      setState(() {
                        _selectedFeatureIndex = null;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lote atualizado com sucesso.'),
                        ),
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao atualizar lote: $e')),
                        );
                      }
                    }
                  },
                  onCancel: () {
                    setState(() {
                      _selectedFeatureIndex = null;
                    });
                  },
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                'Erro ao carregar o rascunho:\n$err',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
