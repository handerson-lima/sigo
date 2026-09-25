import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common_widgets/sigo_error_state.dart';
import '../../../loteamentos/data/loteamento_repository.dart';
import '../../../quadras/data/quadra_repository.dart';
import '../../data/lote_repository.dart';

String? _valorSeguro(String? value, Iterable<String> ids) =>
    (value != null && ids.contains(value)) ? value : null;

class LoteHierarchySelector extends ConsumerWidget {
  final String construtoraId;
  final String? loteamentoId;
  final String? quadraId;
  final String? loteId;
  final ValueChanged<String?> onLoteamentoChanged;
  final ValueChanged<String?> onQuadraChanged;
  final ValueChanged<String?>? onLoteChanged;
  final bool enabled;
  final bool showLoteField;
  final String? Function(String?)? loteValidator;
  final String loteLabel;
  final String? loteHelperText;

  const LoteHierarchySelector({
    super.key,
    required this.construtoraId,
    required this.loteamentoId,
    required this.quadraId,
    required this.loteId,
    required this.onLoteamentoChanged,
    required this.onQuadraChanged,
    this.onLoteChanged,
    this.enabled = true,
    this.showLoteField = true,
    this.loteValidator,
    this.loteLabel = 'Lote de Destino (Opcional)',
    this.loteHelperText,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loteamentosParams = (construtoraId: construtoraId);
    final loteamentosAsync = ref.watch(
      watchLoteamentosProvider(loteamentosParams),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        loteamentosAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (err, _) => SigoErrorState(
            message: 'Não foi possível carregar os loteamentos.',
            cause: err,
            onRetry: () =>
                ref.invalidate(watchLoteamentosProvider(loteamentosParams)),
          ),
          data: (loteamentos) => DropdownButtonFormField<String>(
            key: const Key('loteamento-dropdown'),
            initialValue: _valorSeguro(
              loteamentoId,
              loteamentos.map((l) => l.id),
            ),
            decoration: const InputDecoration(labelText: 'Loteamento'),
            items: loteamentos
                .map(
                  (l) => DropdownMenuItem(value: l.id, child: Text(l.name)),
                )
                .toList(),
            onChanged: enabled ? onLoteamentoChanged : null,
          ),
        ),
        if (loteamentoId != null) ...[
          const SizedBox(height: 10),
          ref
              .watch(
                watchQuadrasProvider((
                  construtoraId: construtoraId,
                  loteamentoId: loteamentoId!,
                )),
              )
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (err, _) => SigoErrorState(
                  message: 'Não foi possível carregar as quadras.',
                  cause: err,
                  onRetry: () => ref.invalidate(
                    watchQuadrasProvider((
                      construtoraId: construtoraId,
                      loteamentoId: loteamentoId!,
                    )),
                  ),
                ),
                data: (quadras) => DropdownButtonFormField<String>(
                  key: const Key('quadra-dropdown'),
                  initialValue: _valorSeguro(
                    quadraId,
                    quadras.map((q) => q.id),
                  ),
                  decoration: const InputDecoration(labelText: 'Quadra'),
                  items: quadras
                      .map(
                        (q) =>
                            DropdownMenuItem(value: q.id, child: Text(q.name)),
                      )
                      .toList(),
                  onChanged: enabled ? onQuadraChanged : null,
                ),
              ),
        ],
        if (showLoteField && quadraId != null) ...[
          const SizedBox(height: 10),
          ref
              .watch(
                watchLotesProvider((
                  construtoraId: construtoraId,
                  loteamentoId: loteamentoId!,
                  quadraId: quadraId!,
                )),
              )
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (err, _) => SigoErrorState(
                  message: 'Não foi possível carregar os lotes.',
                  cause: err,
                  onRetry: () => ref.invalidate(
                    watchLotesProvider((
                      construtoraId: construtoraId,
                      loteamentoId: loteamentoId!,
                      quadraId: quadraId!,
                    )),
                  ),
                ),
                data: (lotes) => DropdownButtonFormField<String>(
                  key: const Key('lote-dropdown'),
                  initialValue: _valorSeguro(loteId, lotes.map((l) => l.id)),
                  decoration: InputDecoration(
                    labelText: loteLabel,
                    helperText: loteHelperText,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Nenhum lote específico (Geral da Obra)'),
                    ),
                    ...lotes.map(
                      (l) => DropdownMenuItem(
                        value: l.id,
                        child: Text(l.name),
                      ),
                    ),
                  ],
                  validator: loteValidator,
                  onChanged: enabled ? onLoteChanged : null,
                ),
              ),
        ],
      ],
    );
  }
}
