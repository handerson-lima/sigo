import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../common_widgets/sigo_breadcrumbs.dart';
import '../../../common_widgets/sigo_empty_state.dart';
import '../../../common_widgets/sigo_error_state.dart';
import '../../../common_widgets/sigo_layout.dart';
import '../../../design_system/sigo_theme.dart';
import '../../authentication/data/user_repository.dart';
import '../../lotes/presentation/lote_mass_generator_section.dart';
import '../../obras/presentation/current_permissions_provider.dart';
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
    final params = (construtoraId: construtoraId, loteamentoId: loteamentoId);
    final quadrasAsync = ref.watch(watchQuadrasProvider(params));
    final cm = ref.watch(construtoraPermissionProvider(construtoraId)).value;
    final admin =
        ref.watch(trustedDevProvider).value == true ||
        cm?['isActive'] == true &&
            (cm?['isAdmin'] == true ||
                cm?['isOwner'] == true ||
                cm?['role'] == 'admin' ||
                cm?['role'] == 'owner');

    return SigoLayout(
      title: 'Quadras',
      activeRoute:
          '/construtoras/$construtoraId/loteamentos/$loteamentoId/quadras',
      actions: [
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

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final logradouro = nullIfBlankText(item.logradouroPadrao);
                    return ListTile(
                      title: Text(item.name),
                      subtitle: logradouro != null ? Text(logradouro) : null,
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        context.go(
                          '/construtoras/$construtoraId/loteamentos/$loteamentoId/quadras/${item.id}/lotes',
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
