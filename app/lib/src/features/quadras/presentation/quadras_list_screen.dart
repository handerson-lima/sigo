import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../common_widgets/sigo_breadcrumbs.dart';
import '../../../common_widgets/sigo_empty_state.dart';
import '../../../common_widgets/sigo_error_state.dart';
import '../../../common_widgets/sigo_layout.dart';
import '../../../design_system/sigo_theme.dart';
import '../../lotes/presentation/lote_mass_generator_section.dart';
import '../../obras/presentation/current_permissions_provider.dart';
import '../data/quadra_repository.dart';
import '../domain/quadra.dart';
import 'quadra_summary_card.dart';
import 'quadra_summary_provider.dart';

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
    final params = (construtoraId: construtoraId, loteamentoId: loteamentoId);
    final quadrasAsync = ref.watch(watchQuadrasProvider(params));
    final summaryMap = ref.watch(quadraSummaryMapProvider(params)).value;
    final admin = ref.watch(isLoteamentoAdminProvider(params));
    final effectiveObraId =
        ref.watch(effectiveLoteamentoObraIdProvider(params)).value ??
        loteamentoId;
    final obraMember = ref
        .watch(
          currentPermissionsProvider((
            construtoraId: construtoraId,
            obraId: effectiveObraId,
          )),
        )
        .value;
    final canOpenPainel = obraMember != null && obraMember.isActive;

    return SigoLayout(
      title: 'Quadras',
      activeRoute:
          '/construtoras/$construtoraId/loteamentos/$loteamentoId/quadras',
      actions: [
        if (canOpenPainel)
          IconButton(
            key: const Key('quadras-painel-loteamento-btn'),
            icon: const Icon(Icons.dashboard_outlined, color: Colors.black54),
            tooltip: 'Painel do Loteamento',
            onPressed: () =>
                context.go('/construtoras/$construtoraId/obra/$effectiveObraId'),
          ),
        if (admin)
          IconButton(
            icon: const Icon(Icons.add_box_outlined, color: Colors.black54),
            tooltip: 'Nova Quadra',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => _AddQuadraDialog(
                  construtoraId: construtoraId,
                  loteamentoId: loteamentoId,
                ),
              );
            },
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SigoBreadcrumbs(),
          Expanded(
            child: quadrasAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => SigoErrorState(
                message: 'Não foi possível carregar as quadras.',
                cause: err,
                onRetry: () => ref.invalidate(watchQuadrasProvider(params)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return SigoEmptyState(
                    message: 'Nenhuma quadra cadastrada',
                    icon: Icons.grid_on_outlined,
                    action: admin
                        ? ElevatedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => _AddQuadraDialog(
                                  construtoraId: construtoraId,
                                  loteamentoId: loteamentoId,
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Criar Nova Quadra'),
                          )
                        : null,
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1200
                        ? 3
                        : constraints.maxWidth >= 720
                        ? 2
                        : 1;
                    final rowCount = (items.length / columns).ceil();

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: rowCount,
                      itemBuilder: (context, rowIndex) {
                        if (columns == 1) {
                          final item = items[rowIndex];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: QuadraSummaryCard(
                              quadra: item,
                              summary: summaryMap?[item.id],
                              onTap: () {
                                context.go(
                                  '/construtoras/$construtoraId/loteamentos/$loteamentoId/quadras/${item.id}/lotes',
                                );
                              },
                            ),
                          );
                        }

                        final start = rowIndex * columns;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(columns, (colIndex) {
                              final itemIndex = start + colIndex;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: colIndex == 0 ? 0 : 6,
                                    right: colIndex == columns - 1 ? 0 : 6,
                                  ),
                                  child: itemIndex < items.length
                                      ? QuadraSummaryCard(
                                          quadra: items[itemIndex],
                                          summary:
                                              summaryMap?[items[itemIndex].id],
                                          onTap: () {
                                            context.go(
                                              '/construtoras/$construtoraId/loteamentos/$loteamentoId/quadras/${items[itemIndex].id}/lotes',
                                            );
                                          },
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              );
                            }),
                          ),
                        );
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

class _AddQuadraDialog extends ConsumerStatefulWidget {
  final String construtoraId;
  final String loteamentoId;

  const _AddQuadraDialog({
    required this.construtoraId,
    required this.loteamentoId,
  });

  @override
  ConsumerState<_AddQuadraDialog> createState() => _AddQuadraDialogState();
}

class _AddQuadraDialogState extends ConsumerState<_AddQuadraDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _logradouroPadraoController = TextEditingController();

  List<LoteMassDraft> _massDrafts = const [];
  String? _massErrorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _logradouroPadraoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _massErrorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_massDrafts.isNotEmpty) {
      final draftValidation = validateMassLoteDrafts(_massDrafts);
      if (draftValidation != null) {
        setState(() => _massErrorMessage = draftValidation);
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      const uuid = Uuid();
      final now = DateTime.now();
      final quadraId = uuid.v4();
      final quadra = Quadra(
        id: quadraId,
        construtoraId: widget.construtoraId,
        loteamentoId: widget.loteamentoId,
        name: _nameController.text.trim(),
        logradouroPadrao: nullIfBlankText(_logradouroPadraoController.text),
        createdAt: now,
        updatedAt: now,
      );

      final repo = ref.read(quadraRepositoryProvider);
      if (_massDrafts.isNotEmpty) {
        final lotes = _massDrafts
            .map(
              (draft) => draft.toLote(
                id: uuid.v4(),
                construtoraId: widget.construtoraId,
                loteamentoId: widget.loteamentoId,
                quadraId: quadraId,
                now: now,
              ),
            )
            .toList();
        await repo.createQuadraComLotes(quadra: quadra, lotes: lotes);
      } else {
        await repo.createQuadra(quadra);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sigoExt = Theme.of(context).extension<SigoThemeExtension>();
    final dangerColor =
        sigoExt?.danger ?? Theme.of(context).colorScheme.error;

    return AlertDialog(
      title: const Text('Nova Quadra'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('quadra-name-field'),
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Quadra',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Nome é obrigatório'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('quadra-logradouro-field'),
                  controller: _logradouroPadraoController,
                  decoration: const InputDecoration(
                    labelText: 'Logradouro Padrão (Opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ExpansionTile(
                  key: const Key('quadra-mass-tile'),
                  maintainState: true,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
                  title: const Text('Gerar Lotes em Massa (Opcional)'),
                  children: [
                    LoteMassGeneratorSection(
                      drafts: _massDrafts,
                      showLogradouroPadraoField: false,
                      defaultLogradouroProvider: () =>
                          _logradouroPadraoController.text,
                      onDraftsChanged: (next) {
                        setState(() {
                          _massDrafts = next;
                          _massErrorMessage = null;
                        });
                      },
                    ),
                  ],
                ),
                if (_massErrorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _massErrorMessage!,
                    style: TextStyle(color: dangerColor),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Criar'),
        ),
      ],
    );
  }
}
