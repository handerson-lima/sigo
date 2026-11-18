import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../../../design_system/sigo_theme.dart';
import '../data/lote_repository.dart';
import '../domain/lote.dart';
import 'lote_mass_generator_section.dart';

class AddLoteScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final String loteamentoId;
  final String quadraId;

  const AddLoteScreen({
    super.key,
    required this.construtoraId,
    required this.loteamentoId,
    required this.quadraId,
  });

  @override
  ConsumerState<AddLoteScreen> createState() => _AddLoteScreenState();
}

class _AddLoteScreenState extends ConsumerState<AddLoteScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _logradouroController = TextEditingController();
  final _frenteController = TextEditingController();
  final _profundidadeController = TextEditingController();
  final _areaTerrenoController = TextEditingController();
  final _areaConstruidaController = TextEditingController();

  final _taxaOcupacaoController = TextEditingController();
  final _coefAproveitamentoController = TextEditingController();
  final _areaPermeavelController = TextEditingController();
  final _taxaPermeabilidadeController = TextEditingController();
  final _areaImpermeavelController = TextEditingController();
  final _recuoFrontalController = TextEditingController();
  final _recuoFundoController = TextEditingController();
  final _recuoLateralEsquerdoController = TextEditingController();
  final _recuoLateralDireitoController = TextEditingController();
  final _proprietarioNomeController = TextEditingController();
  final _proprietarioDocController = TextEditingController();
  final _respTecnicoNomeController = TextEditingController();
  final _respTecnicoRegController = TextEditingController();
  final _dataProjetoController = TextEditingController();

  late final List<TextEditingController> _allControllers = [
    _nameController,
    _logradouroController,
    _frenteController,
    _profundidadeController,
    _areaTerrenoController,
    _areaConstruidaController,
    _taxaOcupacaoController,
    _coefAproveitamentoController,
    _areaPermeavelController,
    _taxaPermeabilidadeController,
    _areaImpermeavelController,
    _recuoFrontalController,
    _recuoFundoController,
    _recuoLateralEsquerdoController,
    _recuoLateralDireitoController,
    _proprietarioNomeController,
    _proprietarioDocController,
    _respTecnicoNomeController,
    _respTecnicoRegController,
    _dataProjetoController,
  ];

  final _areaCoordinator = DimensionalAreaCoordinator();

  bool _isMassMode = false;
  List<LoteMassDraft> _massDrafts = const [];
  String? _massErrorMessage;
  bool _isLoading = false;
  late final String _loteId;

  @override
  void initState() {
    super.initState();
    _loteId = const Uuid().v4();
  }

  @override
  void dispose() {
    for (final controller in _allControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncAreaTerreno() {
    _areaCoordinator.onFrenteOrProfundidadeChanged(
      frenteController: _frenteController,
      profundidadeController: _profundidadeController,
      areaTerrenoController: _areaTerrenoController,
    );
  }

  Future<void> _submitIndividual() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final lote = Lote(
        id: _loteId,
        construtoraId: widget.construtoraId,
        loteamentoId: widget.loteamentoId,
        quadraId: widget.quadraId,
        name: _nameController.text.trim(),
        logradouro: nullIfBlankText(_logradouroController.text),
        frenteM: parseDecimalPtBr(_frenteController.text),
        profundidadeM: parseDecimalPtBr(_profundidadeController.text),
        areaTerrenoM2: parseDecimalPtBr(_areaTerrenoController.text),
        areaConstruidaM2: parseDecimalPtBr(_areaConstruidaController.text),
        taxaOcupacaoPercent: parseDecimalPtBr(_taxaOcupacaoController.text),
        coeficienteAproveitamento: parseDecimalPtBr(
          _coefAproveitamentoController.text,
        ),
        areaPermeavelM2: parseDecimalPtBr(_areaPermeavelController.text),
        taxaPermeabilidadePercent: parseDecimalPtBr(
          _taxaPermeabilidadeController.text,
        ),
        areaImpermeavelM2: parseDecimalPtBr(_areaImpermeavelController.text),
        recuoFrontalM: parseDecimalPtBr(_recuoFrontalController.text),
        recuoFundoM: parseDecimalPtBr(_recuoFundoController.text),
        recuoLateralEsquerdoM: parseDecimalPtBr(
          _recuoLateralEsquerdoController.text,
        ),
        recuoLateralDireitoM: parseDecimalPtBr(
          _recuoLateralDireitoController.text,
        ),
        proprietarioNome: nullIfBlankText(_proprietarioNomeController.text),
        proprietarioDocumento: nullIfBlankText(_proprietarioDocController.text),
        responsavelTecnicoNome: nullIfBlankText(
          _respTecnicoNomeController.text,
        ),
        responsavelTecnicoRegistro: nullIfBlankText(
          _respTecnicoRegController.text,
        ),
        dataProjeto: nullIfBlankText(_dataProjetoController.text),
        createdAt: now,
        updatedAt: now,
      );

      await ref
          .read(loteRepositoryProvider)
          .createLoteComEtapas(lote)
          .timeout(const Duration(seconds: 15));
      if (mounted) {
        context.pop();
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A criação está demorando além do esperado. Os dados continuam sendo sincronizados em segundo plano.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar o lote. Tente novamente.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitMass() async {
    setState(() => _massErrorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final draftValidation = validateMassLoteDrafts(_massDrafts);
    if (draftValidation != null) {
      setState(() => _massErrorMessage = draftValidation);
      return;
    }

    setState(() => _isLoading = true);
    try {
      const uuid = Uuid();
      final now = DateTime.now();
      final lotes = _massDrafts
          .map(
            (draft) => draft.toLote(
              id: uuid.v4(),
              construtoraId: widget.construtoraId,
              loteamentoId: widget.loteamentoId,
              quadraId: widget.quadraId,
              now: now,
            ),
          )
          .toList();

      await ref
          .read(loteRepositoryProvider)
          .createLotesEmMassa(lotes)
          .timeout(const Duration(seconds: 15));
      if (mounted) {
        context.pop();
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A criação está demorando além do esperado. Os dados continuam sendo sincronizados em segundo plano.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar os lotes em massa. Tente novamente.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildDecimalField({
    required Key fieldKey,
    required TextEditingController controller,
    required String label,
    String? hintText,
    bool requirePositive = false,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        isDense: true,
      ),
      onChanged: onChanged,
      validator: (v) =>
          validateOptionalDecimalPtBr(v, requirePositive: requirePositive),
    );
  }

  Widget _buildIndividualForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const Key('lote-individual-name'),
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Nome/Identificação do Lote (Ex: Casa 1)',
            isDense: true,
          ),
          validator: (val) =>
              val == null || val.trim().isEmpty ? 'Campo obrigatório' : null,
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('lote-individual-logradouro'),
          controller: _logradouroController,
          decoration: const InputDecoration(
            labelText: 'Logradouro (Opcional)',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildDecimalField(
                fieldKey: const Key('lote-individual-frente'),
                controller: _frenteController,
                label: 'Frente (m)',
                requirePositive: true,
                onChanged: (_) => _syncAreaTerreno(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDecimalField(
                fieldKey: const Key('lote-individual-profundidade'),
                controller: _profundidadeController,
                label: 'Profundidade (m)',
                requirePositive: true,
                onChanged: (_) => _syncAreaTerreno(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildDecimalField(
                fieldKey: const Key('lote-individual-area-terreno'),
                controller: _areaTerrenoController,
                label: 'Área do Terreno (m²)',
                hintText: 'Auto (F x P) ou manual',
                requirePositive: true,
                onChanged: _areaCoordinator.onAreaTerrenoChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDecimalField(
                fieldKey: const Key('lote-individual-area-construida'),
                controller: _areaConstruidaController,
                label: 'Área Construída (m²)',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ExpansionTile(
          key: const Key('lote-dados-tecnicos-tile'),
          maintainState: true,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
          title: const Text('Dados Técnicos / PDF (Opcional)'),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Quadro de Áreas',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildDecimalField(
                    fieldKey: const Key('lote-taxa-ocupacao'),
                    controller: _taxaOcupacaoController,
                    label: 'Taxa de Ocupação (%)',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDecimalField(
                    fieldKey: const Key('lote-coef-aproveitamento'),
                    controller: _coefAproveitamentoController,
                    label: 'Coef. Aproveitamento',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildDecimalField(
                    fieldKey: const Key('lote-area-permeavel'),
                    controller: _areaPermeavelController,
                    label: 'Área Permeável (m²)',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDecimalField(
                    fieldKey: const Key('lote-taxa-permeabilidade'),
                    controller: _taxaPermeabilidadeController,
                    label: 'Taxa Permeabilidade (%)',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDecimalField(
                    fieldKey: const Key('lote-area-impermeavel'),
                    controller: _areaImpermeavelController,
                    label: 'Área Impermeável (m²)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recuos (m)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildDecimalField(
                    fieldKey: const Key('lote-recuo-frontal'),
                    controller: _recuoFrontalController,
                    label: 'Recuo Frontal (m)',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDecimalField(
                    fieldKey: const Key('lote-recuo-fundo'),
                    controller: _recuoFundoController,
                    label: 'Recuo Fundo (m)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildDecimalField(
                    fieldKey: const Key('lote-recuo-esquerdo'),
                    controller: _recuoLateralEsquerdoController,
                    label: 'Recuo Lateral Esq. (m)',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDecimalField(
                    fieldKey: const Key('lote-recuo-direito'),
                    controller: _recuoLateralDireitoController,
                    label: 'Recuo Lateral Dir. (m)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Carimbo',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('lote-proprietario-nome'),
              controller: _proprietarioNomeController,
              decoration: const InputDecoration(
                labelText: 'Proprietário (Opcional)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('lote-proprietario-doc'),
              controller: _proprietarioDocController,
              decoration: const InputDecoration(
                labelText: 'CPF / CNPJ do Proprietário (Opcional)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: const Key('lote-resp-tecnico-nome'),
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
                    key: const Key('lote-resp-tecnico-registro'),
                    controller: _respTecnicoRegController,
                    decoration: const InputDecoration(
                      labelText: 'CREA / CAU',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('lote-data-projeto'),
              controller: _dataProjetoController,
              decoration: const InputDecoration(
                labelText: 'Data do Projeto (Opcional)',
                isDense: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitIndividual,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Criar Lote'),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMassForm(BuildContext context) {
    final sigoExt = Theme.of(context).extension<SigoThemeExtension>();
    final dangerColor =
        sigoExt?.danger ?? Theme.of(context).colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LoteMassGeneratorSection(
          drafts: _massDrafts,
          onDraftsChanged: (next) {
            setState(() {
              _massDrafts = next;
              _massErrorMessage = null;
            });
          },
        ),
        if (_massErrorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _massErrorMessage!,
            style: TextStyle(color: dangerColor),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitMass,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Criar Lotes em Massa'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SigoLayout(
      title: 'Novo Lote',
      activeRoute:
          '/construtoras/${widget.construtoraId}/loteamentos/${widget.loteamentoId}/quadras/${widget.quadraId}/lotes',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  key: const Key('lote-mode-segmented'),
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Individual'),
                      icon: Icon(Icons.home_outlined),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Em Massa'),
                      icon: Icon(Icons.view_module_outlined),
                    ),
                  ],
                  selected: {_isMassMode},
                  onSelectionChanged: _isLoading
                      ? null
                      : (selection) {
                          setState(() {
                            _isMassMode = selection.first;
                            _massErrorMessage = null;
                          });
                        },
                ),
                const SizedBox(height: 10),
                if (_isMassMode)
                  _buildMassForm(context)
                else
                  _buildIndividualForm(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
