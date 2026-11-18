import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../design_system/sigo_theme.dart';
import '../domain/lote.dart';

final _plainDecimalRegex = RegExp(r'^[+-]?\d+([.,]\d+)?$');
final _brThousandsDecimalRegex = RegExp(r'^[+-]?\d{1,3}(\.\d{3})+(,\d+)?$');
final _usThousandsDecimalRegex = RegExp(r'^[+-]?\d{1,3}(,\d{3})+(\.\d+)?$');

/// Interpreta números decimais aceitando vírgula ou ponto no padrão pt-br.
double? parseDecimalPtBr(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) return null;

  String? normalized;
  if (_plainDecimalRegex.hasMatch(trimmed)) {
    normalized = trimmed.replaceAll(',', '.');
  } else if (_brThousandsDecimalRegex.hasMatch(trimmed)) {
    normalized = trimmed.replaceAll('.', '').replaceAll(',', '.');
  } else if (_usThousandsDecimalRegex.hasMatch(trimmed)) {
    normalized = trimmed.replaceAll(',', '');
  }
  if (normalized == null) return null;

  final parsed = double.tryParse(normalized);
  if (parsed == null || !parsed.isFinite) return null;
  return parsed;
}

/// Formata números decimais sem zeros supérfluos usando vírgula decimal em pt-br.
String formatDecimalPtBr(double value) {
  if (!value.isFinite) return '';
  if ((value - value.roundToDouble()).abs() < 1e-9 &&
      value.abs() <= 9007199254740991) {
    return value.round().toString();
  }
  final fixed = value
      .toStringAsFixed(6)
      .replaceFirst(RegExp(r'\.?0+$'), '');
  return fixed.replaceAll('.', ',');
}

/// Valida um campo decimal opcional aceitando vírgula ou ponto.
String? validateOptionalDecimalPtBr(
  String? raw, {
  bool requirePositive = false,
  double? maxValue,
}) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) return null;

  final parsed = parseDecimalPtBr(trimmed);
  if (parsed == null) return 'Valor inválido';
  if (requirePositive && parsed <= 0) return 'Deve ser > 0';
  if (parsed < 0) return 'Não pode ser negativo';
  if (maxValue != null && parsed > maxValue) {
    return 'Máximo ${formatDecimalPtBr(maxValue)}';
  }
  return null;
}

/// Retorna `null` para strings vazias ou preenchidas apenas com espaços.
String? nullIfBlankText(String? raw) {
  final trimmed = raw?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

/// Coordena o cálculo automático de `areaTerrenoM2` a partir de frente e profundidade,
/// respeitando sobrescritas manuais até o usuário esvaziar o campo de área.
class DimensionalAreaCoordinator {
  bool areaEditadaManualmente;

  DimensionalAreaCoordinator({this.areaEditadaManualmente = false});

  void onFrenteOrProfundidadeChanged({
    required TextEditingController frenteController,
    required TextEditingController profundidadeController,
    required TextEditingController areaTerrenoController,
  }) {
    if (areaEditadaManualmente) return;
    final frente = parseDecimalPtBr(frenteController.text);
    final profundidade = parseDecimalPtBr(profundidadeController.text);
    final area = Lote.calcularAreaTerreno(frente, profundidade);
    areaTerrenoController.text = area == null ? '' : formatDecimalPtBr(area);
  }

  void onAreaTerrenoChanged(String value) {
    areaEditadaManualmente = value.trim().isNotEmpty;
  }
}

class LoteMassDraft {
  final String uid;
  final String name;
  final String? logradouro;
  final double? frenteM;
  final double? profundidadeM;
  final double? areaTerrenoM2;
  final double? areaConstruidaM2;

  const LoteMassDraft({
    required this.uid,
    required this.name,
    this.logradouro,
    this.frenteM,
    this.profundidadeM,
    this.areaTerrenoM2,
    this.areaConstruidaM2,
  });

  LoteMassDraft copyWith({
    String? uid,
    String? name,
    String? logradouro,
    bool clearLogradouro = false,
    double? frenteM,
    bool clearFrenteM = false,
    double? profundidadeM,
    bool clearProfundidadeM = false,
    double? areaTerrenoM2,
    bool clearAreaTerrenoM2 = false,
    double? areaConstruidaM2,
    bool clearAreaConstruidaM2 = false,
  }) {
    return LoteMassDraft(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      logradouro: clearLogradouro ? null : (logradouro ?? this.logradouro),
      frenteM: clearFrenteM ? null : (frenteM ?? this.frenteM),
      profundidadeM: clearProfundidadeM
          ? null
          : (profundidadeM ?? this.profundidadeM),
      areaTerrenoM2: clearAreaTerrenoM2
          ? null
          : (areaTerrenoM2 ?? this.areaTerrenoM2),
      areaConstruidaM2: clearAreaConstruidaM2
          ? null
          : (areaConstruidaM2 ?? this.areaConstruidaM2),
    );
  }

  Lote toLote({
    required String id,
    required String construtoraId,
    required String loteamentoId,
    required String quadraId,
    required DateTime now,
  }) {
    return Lote(
      id: id,
      construtoraId: construtoraId,
      loteamentoId: loteamentoId,
      quadraId: quadraId,
      name: name.trim(),
      logradouro: nullIfBlankText(logradouro),
      frenteM: frenteM,
      profundidadeM: profundidadeM,
      areaTerrenoM2: areaTerrenoM2,
      areaConstruidaM2: areaConstruidaM2,
      createdAt: now,
      updatedAt: now,
    );
  }
}

/// Gera rascunhos sequenciais de lotes com medidas padrão para revisão em prévia.
List<LoteMassDraft> buildMassLoteDrafts({
  required int quantidade,
  required String prefixo,
  required int numeroInicial,
  String? logradouroPadrao,
  double? frentePadraoM,
  double? profundidadePadraoM,
  double? areaTerrenoPadraoM2,
  double? areaConstruidaPadraoM2,
}) {
  if (quantidade < 1 || quantidade > 500) {
    throw RangeError.range(quantidade, 1, 500, 'quantidade');
  }
  if (numeroInicial < 0) {
    throw RangeError.value(numeroInicial, 'numeroInicial', 'Deve ser >= 0');
  }

  const uuid = Uuid();
  final normalizedLogradouro = nullIfBlankText(logradouroPadrao);
  final resolvedArea =
      areaTerrenoPadraoM2 ??
      Lote.calcularAreaTerreno(frentePadraoM, profundidadePadraoM);

  return List.generate(quantidade, (index) {
    final numero = numeroInicial + index;
    final composed = '$prefixo$numero'.trim();
    return LoteMassDraft(
      uid: uuid.v4(),
      name: composed.isEmpty ? 'Lote $numero' : composed,
      logradouro: normalizedLogradouro,
      frenteM: frentePadraoM,
      profundidadeM: profundidadePadraoM,
      areaTerrenoM2: resolvedArea,
      areaConstruidaM2: areaConstruidaPadraoM2,
    );
  });
}

/// Valida os rascunhos da prévia antes do envio para o repositório.
String? validateMassLoteDrafts(List<LoteMassDraft> drafts) {
  if (drafts.isEmpty) {
    return 'Gere a prévia dos lotes antes de salvar.';
  }
  for (var i = 0; i < drafts.length; i++) {
    final item = drafts[i];
    if (item.name.trim().isEmpty) {
      return 'O lote #${i + 1} na prévia precisa de um nome.';
    }
    if (item.frenteM != null && item.frenteM! <= 0) {
      return 'Frente inválida no lote "${item.name}".';
    }
    if (item.profundidadeM != null && item.profundidadeM! <= 0) {
      return 'Profundidade inválida no lote "${item.name}".';
    }
    if (item.areaTerrenoM2 != null && item.areaTerrenoM2! <= 0) {
      return 'Área do terreno inválida no lote "${item.name}".';
    }
    if (item.areaConstruidaM2 != null && item.areaConstruidaM2! < 0) {
      return 'Área construída inválida no lote "${item.name}".';
    }
  }
  return null;
}

class LoteMassGeneratorSection extends StatefulWidget {
  final List<LoteMassDraft> drafts;
  final ValueChanged<List<LoteMassDraft>> onDraftsChanged;
  final bool showLogradouroPadraoField;
  final String? Function()? defaultLogradouroProvider;
  final ValueChanged<String>? onLogradouroPadraoChanged;
  final String initialQuantidade;
  final String initialPrefixo;
  final String initialNumeroInicial;

  const LoteMassGeneratorSection({
    super.key,
    required this.drafts,
    required this.onDraftsChanged,
    this.showLogradouroPadraoField = true,
    this.defaultLogradouroProvider,
    this.onLogradouroPadraoChanged,
    this.initialQuantidade = '10',
    this.initialPrefixo = 'Lote ',
    this.initialNumeroInicial = '1',
  });

  @override
  State<LoteMassGeneratorSection> createState() =>
      _LoteMassGeneratorSectionState();
}

class _LoteMassGeneratorSectionState extends State<LoteMassGeneratorSection> {
  // Form isolado para os parâmetros do gerador: não bloqueia o Form pai na criação simples.
  final _generatorFormKey = GlobalKey<FormState>();
  late final TextEditingController _quantidadeController;
  late final TextEditingController _prefixoController;
  late final TextEditingController _numeroInicialController;
  late final TextEditingController _logradouroController;
  late final TextEditingController _frenteController;
  late final TextEditingController _profundidadeController;
  late final TextEditingController _areaTerrenoController;
  late final TextEditingController _areaConstruidaController;
  final _areaCoordinator = DimensionalAreaCoordinator();

  @override
  void initState() {
    super.initState();
    _quantidadeController = TextEditingController(
      text: widget.initialQuantidade,
    );
    _prefixoController = TextEditingController(text: widget.initialPrefixo);
    _numeroInicialController = TextEditingController(
      text: widget.initialNumeroInicial,
    );
    _logradouroController = TextEditingController();
    _frenteController = TextEditingController();
    _profundidadeController = TextEditingController();
    _areaTerrenoController = TextEditingController();
    _areaConstruidaController = TextEditingController();
  }

  @override
  void dispose() {
    _quantidadeController.dispose();
    _prefixoController.dispose();
    _numeroInicialController.dispose();
    _logradouroController.dispose();
    _frenteController.dispose();
    _profundidadeController.dispose();
    _areaTerrenoController.dispose();
    _areaConstruidaController.dispose();
    super.dispose();
  }

  void _syncAreaTerreno() {
    _areaCoordinator.onFrenteOrProfundidadeChanged(
      frenteController: _frenteController,
      profundidadeController: _profundidadeController,
      areaTerrenoController: _areaTerrenoController,
    );
  }

  void _gerarPrevia() {
    if (!(_generatorFormKey.currentState?.validate() ?? false)) return;

    final quantidade = int.parse(_quantidadeController.text.trim());
    final numeroInicial = int.parse(_numeroInicialController.text.trim());
    final frente = parseDecimalPtBr(_frenteController.text);
    final profundidade = parseDecimalPtBr(_profundidadeController.text);
    final areaTerreno = parseDecimalPtBr(_areaTerrenoController.text);
    final areaConstruida = parseDecimalPtBr(_areaConstruidaController.text);
    final logradouro = widget.showLogradouroPadraoField
        ? _logradouroController.text
        : (widget.defaultLogradouroProvider?.call() ?? '');

    final generated = buildMassLoteDrafts(
      quantidade: quantidade,
      prefixo: _prefixoController.text,
      numeroInicial: numeroInicial,
      logradouroPadrao: logradouro,
      frentePadraoM: frente,
      profundidadePadraoM: profundidade,
      areaTerrenoPadraoM2: areaTerreno,
      areaConstruidaPadraoM2: areaConstruida,
    );

    widget.onDraftsChanged(generated);
  }

  void _limparPrevia() {
    widget.onDraftsChanged(const []);
  }

  void _updateDraft(int index, LoteMassDraft updated) {
    final next = List<LoteMassDraft>.from(widget.drafts);
    next[index] = updated;
    widget.onDraftsChanged(next);
  }

  void _removeDraft(int index) {
    final next = List<LoteMassDraft>.from(widget.drafts)..removeAt(index);
    widget.onDraftsChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final sigoExt = Theme.of(context).extension<SigoThemeExtension>();
    final borderColor =
        sigoExt?.borderHairline ?? Theme.of(context).dividerColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Form(
          key: _generatorFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('mass-gen-quantidade'),
                      controller: _quantidadeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade de Lotes',
                        isDense: true,
                      ),
                      validator: (val) {
                        final n = int.tryParse(val?.trim() ?? '');
                        if (n == null || n < 1 || n > 500) {
                          return 'Entre 1 e 500';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      key: const Key('mass-gen-prefixo'),
                      controller: _prefixoController,
                      decoration: const InputDecoration(
                        labelText: 'Prefixo do Nome',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      key: const Key('mass-gen-numero-inicial'),
                      controller: _numeroInicialController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Número Inicial',
                        isDense: true,
                      ),
                      validator: (val) {
                        final n = int.tryParse(val?.trim() ?? '');
                        if (n == null || n < 0) return 'Deve ser >= 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              if (widget.showLogradouroPadraoField) ...[
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('mass-gen-logradouro'),
                  controller: _logradouroController,
                  decoration: const InputDecoration(
                    labelText: 'Logradouro Padrão (Opcional)',
                    isDense: true,
                  ),
                  onChanged: widget.onLogradouroPadraoChanged,
                ),
              ],
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('mass-gen-frente'),
                      controller: _frenteController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Frente Padrão (m)',
                        isDense: true,
                      ),
                      onChanged: (_) => _syncAreaTerreno(),
                      validator: (v) => validateOptionalDecimalPtBr(
                        v,
                        requirePositive: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      key: const Key('mass-gen-profundidade'),
                      controller: _profundidadeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Profundidade Padrão (m)',
                        isDense: true,
                      ),
                      onChanged: (_) => _syncAreaTerreno(),
                      validator: (v) => validateOptionalDecimalPtBr(
                        v,
                        requirePositive: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('mass-gen-area-terreno'),
                      controller: _areaTerrenoController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Área do Terreno Padrão (m²)',
                        helperText: 'Automática (Frente x Prof.) ou manual',
                        isDense: true,
                      ),
                      onChanged: _areaCoordinator.onAreaTerrenoChanged,
                      validator: (v) => validateOptionalDecimalPtBr(
                        v,
                        requirePositive: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      key: const Key('mass-gen-area-construida'),
                      controller: _areaConstruidaController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Área Construída Padrão (m²)',
                        isDense: true,
                      ),
                      validator: validateOptionalDecimalPtBr,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: const Key('mass-gen-preview-btn'),
              onPressed: _gerarPrevia,
              icon: const Icon(Icons.playlist_add_check),
              label: const Text('Gerar Prévia'),
            ),
            if (widget.drafts.isNotEmpty)
              TextButton.icon(
                key: const Key('mass-gen-clear-btn'),
                onPressed: _limparPrevia,
                icon: const Icon(Icons.clear_all),
                label: const Text('Limpar Prévia'),
              ),
          ],
        ),
        if (widget.drafts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Prévia Editável (${widget.drafts.length} ${widget.drafts.length == 1 ? 'lote' : 'lotes'})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Ajuste medidas ou nomes de exceções individuais antes de gravar.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < widget.drafts.length; i++)
                  _LotePreviewItemEditor(
                    key: ValueKey(widget.drafts[i].uid),
                    index: i,
                    draft: widget.drafts[i],
                    onChanged: (updated) => _updateDraft(i, updated),
                    onRemove: () => _removeDraft(i),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _LotePreviewItemEditor extends StatefulWidget {
  final int index;
  final LoteMassDraft draft;
  final ValueChanged<LoteMassDraft> onChanged;
  final VoidCallback onRemove;

  const _LotePreviewItemEditor({
    super.key,
    required this.index,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_LotePreviewItemEditor> createState() => _LotePreviewItemEditorState();
}

class _LotePreviewItemEditorState extends State<_LotePreviewItemEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _logradouroController;
  late final TextEditingController _frenteController;
  late final TextEditingController _profundidadeController;
  late final TextEditingController _areaTerrenoController;
  late final TextEditingController _areaConstruidaController;
  late final DimensionalAreaCoordinator _areaCoordinator;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _nameController = TextEditingController(text: d.name);
    _logradouroController = TextEditingController(text: d.logradouro ?? '');
    _frenteController = TextEditingController(
      text: d.frenteM == null ? '' : formatDecimalPtBr(d.frenteM!),
    );
    _profundidadeController = TextEditingController(
      text: d.profundidadeM == null ? '' : formatDecimalPtBr(d.profundidadeM!),
    );
    _areaTerrenoController = TextEditingController(
      text: d.areaTerrenoM2 == null ? '' : formatDecimalPtBr(d.areaTerrenoM2!),
    );
    _areaConstruidaController = TextEditingController(
      text: d.areaConstruidaM2 == null
          ? ''
          : formatDecimalPtBr(d.areaConstruidaM2!),
    );

    final calculated = Lote.calcularAreaTerreno(d.frenteM, d.profundidadeM);
    final isManualOverride =
        d.areaTerrenoM2 != null &&
        calculated != null &&
        (d.areaTerrenoM2! - calculated).abs() > 1e-6;
    _areaCoordinator = DimensionalAreaCoordinator(
      areaEditadaManualmente: isManualOverride,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _logradouroController.dispose();
    _frenteController.dispose();
    _profundidadeController.dispose();
    _areaTerrenoController.dispose();
    _areaConstruidaController.dispose();
    super.dispose();
  }

  void _emitUpdated() {
    final frente = parseDecimalPtBr(_frenteController.text);
    final profundidade = parseDecimalPtBr(_profundidadeController.text);
    final areaTerreno = parseDecimalPtBr(_areaTerrenoController.text);
    final areaConstruida = parseDecimalPtBr(_areaConstruidaController.text);
    final logradouro = nullIfBlankText(_logradouroController.text);

    widget.onChanged(
      widget.draft.copyWith(
        name: _nameController.text,
        logradouro: logradouro,
        clearLogradouro: logradouro == null,
        frenteM: frente,
        clearFrenteM: frente == null,
        profundidadeM: profundidade,
        clearProfundidadeM: profundidade == null,
        areaTerrenoM2: areaTerreno,
        clearAreaTerrenoM2: areaTerreno == null,
        areaConstruidaM2: areaConstruida,
        clearAreaConstruidaM2: areaConstruida == null,
      ),
    );
  }

  void _onDimensionChanged() {
    _areaCoordinator.onFrenteOrProfundidadeChanged(
      frenteController: _frenteController,
      profundidadeController: _profundidadeController,
      areaTerrenoController: _areaTerrenoController,
    );
    _emitUpdated();
  }

  void _onAreaChanged(String value) {
    _areaCoordinator.onAreaTerrenoChanged(value);
    _emitUpdated();
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.index;
    final sigoExt = Theme.of(context).extension<SigoThemeExtension>();
    final borderColor =
        sigoExt?.borderHairline ?? Theme.of(context).dividerColor;

    return Card(
      key: Key('mass-preview-item-$i'),
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: Key('mass-preview-name-$i'),
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do Lote',
                      isDense: true,
                    ),
                    onChanged: (_) => _emitUpdated(),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Obrigatório'
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    key: Key('mass-preview-logradouro-$i'),
                    controller: _logradouroController,
                    decoration: const InputDecoration(
                      labelText: 'Logradouro',
                      isDense: true,
                    ),
                    onChanged: (_) => _emitUpdated(),
                  ),
                ),
                IconButton(
                  key: Key('mass-preview-remove-$i'),
                  tooltip: 'Remover lote da prévia',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: Key('mass-preview-frente-$i'),
                    controller: _frenteController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Frente (m)',
                      isDense: true,
                    ),
                    onChanged: (_) => _onDimensionChanged(),
                    validator: (v) =>
                        validateOptionalDecimalPtBr(v, requirePositive: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: Key('mass-preview-profundidade-$i'),
                    controller: _profundidadeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Profundidade (m)',
                      isDense: true,
                    ),
                    onChanged: (_) => _onDimensionChanged(),
                    validator: (v) =>
                        validateOptionalDecimalPtBr(v, requirePositive: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: Key('mass-preview-area-terreno-$i'),
                    controller: _areaTerrenoController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Área Terreno (m²)',
                      isDense: true,
                    ),
                    onChanged: _onAreaChanged,
                    validator: (v) =>
                        validateOptionalDecimalPtBr(v, requirePositive: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: Key('mass-preview-area-construida-$i'),
                    controller: _areaConstruidaController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Área Construída (m²)',
                      isDense: true,
                    ),
                    onChanged: (_) => _emitUpdated(),
                    validator: validateOptionalDecimalPtBr,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
