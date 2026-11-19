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
import '../../quadras/domain/quadra.dart';
import '../data/loteamento_repository.dart';
import '../domain/loteamento.dart';
import 'loteamento_summary_card.dart';
import 'loteamento_summary_provider.dart';

class LoteamentosListScreen extends ConsumerWidget {
  final String construtoraId;

  const LoteamentosListScreen({super.key, required this.construtoraId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (construtoraId: construtoraId);
    final loteamentosAsync = ref.watch(watchLoteamentosProvider(params));
    final summaries = ref
        .watch(loteamentoSummaryMapProvider(construtoraId))
        .value;
    final cm = ref.watch(construtoraPermissionProvider(construtoraId)).value;
    final admin =
        ref.watch(trustedDevProvider).value == true ||
        cm?['isActive'] == true &&
            (cm?['isAdmin'] == true ||
                cm?['isOwner'] == true ||
                cm?['role'] == 'admin' ||
                cm?['role'] == 'owner');

    return SigoLayout(
      title: 'Loteamentos',
      activeRoute: '/construtoras/$construtoraId/loteamentos',
      actions: [
        if (admin) ...[
          IconButton(
            icon: const Icon(Icons.file_upload, color: Colors.black54),
            tooltip: 'Importar DXF/DWF',
            onPressed: () =>
                context.go('/construtoras/$construtoraId/loteamentos/import'),
          ),
          IconButton(
            icon: const Icon(Icons.add_business, color: Colors.black54),
            tooltip: 'Novo Loteamento',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) =>
                    _AddLoteamentoDialog(construtoraId: construtoraId),
              );
            },
          ),
        ],
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SigoBreadcrumbs(),
          Expanded(
            child: loteamentosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => SigoErrorState(
                message: 'Não foi possível carregar os loteamentos.',
                cause: err,
                onRetry: () => ref.invalidate(watchLoteamentosProvider(params)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return SigoEmptyState(
                    message: 'Nenhum loteamento cadastrado',
                    icon: Icons.map_outlined,
                    action: admin
                        ? ElevatedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => _AddLoteamentoDialog(
                                  construtoraId: construtoraId,
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Criar Novo Loteamento'),
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
                            child: LoteamentoSummaryCard(
                              loteamento: item,
                              summary: summaries?[item.id],
                              onTap: () {
                                context.go(
                                  '/construtoras/$construtoraId/loteamentos/${item.id}/quadras',
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
                                      ? LoteamentoSummaryCard(
                                          loteamento: items[itemIndex],
                                          summary:
                                              summaries?[items[itemIndex].id],
                                          onTap: () {
                                            context.go(
                                              '/construtoras/$construtoraId/loteamentos/${items[itemIndex].id}/quadras',
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

class _AddLoteamentoDialog extends ConsumerStatefulWidget {
  final String construtoraId;
  const _AddLoteamentoDialog({required this.construtoraId});

  @override
  ConsumerState<_AddLoteamentoDialog> createState() =>
      _AddLoteamentoDialogState();
}

class _AddLoteamentoDialogState extends ConsumerState<_AddLoteamentoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _ufController = TextEditingController();
  final _proprietarioNomeController = TextEditingController();
  final _proprietarioDocController = TextEditingController();
  final _respTecnicoNomeController = TextEditingController();
  final _respTecnicoRegController = TextEditingController();
  final _quadraNameController = TextEditingController();

  String _generatorLogradouroPadrao = '';
  List<LoteMassDraft> _massDrafts = const [];
  String? _massErrorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _ufController.dispose();
    _proprietarioNomeController.dispose();
    _proprietarioDocController.dispose();
    _respTecnicoNomeController.dispose();
    _respTecnicoRegController.dispose();
    _quadraNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _massErrorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final quadraNome = _quadraNameController.text.trim();
    if (_massDrafts.isNotEmpty) {
      if (quadraNome.isEmpty) {
        setState(() {
          _massErrorMessage =
              'Informe o nome da quadra para criar os lotes em massa.';
        });
        return;
      }
      final draftValidation = validateMassLoteDrafts(_massDrafts);
      if (draftValidation != null) {
        setState(() => _massErrorMessage = draftValidation);
        return;
      }
    } else if (quadraNome.isNotEmpty) {
      setState(() {
        _massErrorMessage =
            'Clique em "Gerar Prévia" para incluir os lotes ou limpe o nome da quadra.';
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      const uuid = Uuid();
      final now = DateTime.now();
      final loteamentoId = uuid.v4();
      final uf = nullIfBlankText(_ufController.text)?.toUpperCase();

      final loteamento = Loteamento(
        id: loteamentoId,
        construtoraId: widget.construtoraId,
        name: _nameController.text.trim(),
        bairro: nullIfBlankText(_bairroController.text),
        cidade: nullIfBlankText(_cidadeController.text),
        uf: uf,
        proprietarioNome: nullIfBlankText(_proprietarioNomeController.text),
        proprietarioDocumento: nullIfBlankText(_proprietarioDocController.text),
        responsavelTecnicoNome: nullIfBlankText(_respTecnicoNomeController.text),
        responsavelTecnicoRegistro: nullIfBlankText(
          _respTecnicoRegController.text,
        ),
        createdAt: now,
        updatedAt: now,
      );

      final repo = ref.read(loteamentoRepositoryProvider);
      if (_massDrafts.isNotEmpty) {
        final quadraId = uuid.v4();
        final quadra = Quadra(
          id: quadraId,
          construtoraId: widget.construtoraId,
          loteamentoId: loteamentoId,
          name: quadraNome,
          logradouroPadrao: nullIfBlankText(_generatorLogradouroPadrao),
          createdAt: now,
          updatedAt: now,
        );
        final lotes = _massDrafts
            .map(
              (draft) => draft.toLote(
                id: uuid.v4(),
                construtoraId: widget.construtoraId,
                loteamentoId: loteamentoId,
                quadraId: quadraId,
                now: now,
              ),
            )
            .toList();
        await repo.createLoteamentoEmMassa(
          loteamento: loteamento,
          quadras: [quadra],
          lotes: lotes,
        );
      } else {
        await repo.createLoteamento(loteamento);
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
      title: const Text('Novo Loteamento'),
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
                  key: const Key('loteamento-name-field'),
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Loteamento',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Nome é obrigatório'
                      : null,
                ),
                const SizedBox(height: 12),
                ExpansionTile(
                  key: const Key('loteamento-carimbo-tile'),
                  maintainState: true,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
                  title: const Text('Localização e Carimbo (Opcional)'),
                  children: [
                    TextFormField(
                      key: const Key('loteamento-bairro-field'),
                      controller: _bairroController,
                      decoration: const InputDecoration(
                        labelText: 'Bairro (Opcional)',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            key: const Key('loteamento-cidade-field'),
                            controller: _cidadeController,
                            decoration: const InputDecoration(
                              labelText: 'Cidade (Opcional)',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            key: const Key('loteamento-uf-field'),
                            controller: _ufController,
                            maxLength: 2,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'UF',
                              counterText: '',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      key: const Key('loteamento-proprietario-nome-field'),
                      controller: _proprietarioNomeController,
                      decoration: const InputDecoration(
                        labelText: 'Proprietário / Empreendedor (Opcional)',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      key: const Key('loteamento-proprietario-doc-field'),
                      controller: _proprietarioDocController,
                      decoration: const InputDecoration(
                        labelText: 'CPF / CNPJ do Proprietário (Opcional)',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            key: const Key('loteamento-resp-nome-field'),
                            controller: _respTecnicoNomeController,
                            decoration: const InputDecoration(
                              labelText: 'Responsável Técnico (Opcional)',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            key: const Key('loteamento-resp-registro-field'),
                            controller: _respTecnicoRegController,
                            decoration: const InputDecoration(
                              labelText: 'CREA / CAU',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ExpansionTile(
                  key: const Key('loteamento-mass-tile'),
                  maintainState: true,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
                  title: const Text('Gerar Quadra e Lotes em Massa (Opcional)'),
                  children: [
                    TextFormField(
                      key: const Key('loteamento-quadra-name-field'),
                      controller: _quadraNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome da Quadra (Ex: Quadra 01)',
                        isDense: true,
                      ),
                      validator: (v) {
                        if (_massDrafts.isNotEmpty &&
                            (v == null || v.trim().isEmpty)) {
                          return 'Nome da quadra é obrigatório para geração em massa';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    LoteMassGeneratorSection(
                      drafts: _massDrafts,
                      onDraftsChanged: (next) {
                        setState(() {
                          _massDrafts = next;
                          _massErrorMessage = null;
                        });
                      },
                      onLogradouroPadraoChanged: (val) {
                        _generatorLogradouroPadrao = val;
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
