import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/loteamento_repository.dart';
import '../data/loteamentos_import_repository.dart';
import '../domain/loteamento.dart';
import 'loteamento_import_screen.dart';

final draftReviewStreamProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, draftId) {
      final repo = ref.watch(loteamentosImportRepositoryProvider);
      return repo.watchDraft(draftId);
    });

/// Faz o parse de números em formato brasileiro (vírgula ou ponto decimal).
double? parseDraftBrDouble(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final normalized = trimmed.contains(',')
      ? trimmed.replaceAll('.', '').replaceAll(',', '.')
      : trimmed;
  return double.tryParse(normalized);
}

/// Formata números para exibição tabular em pt-BR.
String formatDraftBrDouble(num? value) {
  if (value == null) return '';
  final d = value.toDouble();
  if (d == d.roundToDouble()) {
    return d.toInt().toString();
  }
  return d.toStringAsFixed(2).replaceAll('.', ',');
}

String? _nullIfBlank(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return parseDraftBrDouble(value);
  return null;
}

int? _extractLeadingOrTrailingNumber(String text) {
  final match = RegExp(r'(\d+)').firstMatch(text.trim());
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

class LoteModelGenerationResult {
  final List<Map<String, dynamic>> items;
  final int createdCount;
  final int skippedCount;

  const LoteModelGenerationResult({
    required this.items,
    required this.createdCount,
    required this.skippedCount,
  });
}

/// Gera lotes no intervalo `[startNumber..endNumber]` na mesma quadra do
/// [modelItem], copiando suas medidas e campos cadastrais sem duplicar lotes
/// já existentes naquela quadra.
LoteModelGenerationResult generateQuadraFromLoteModel({
  required Map<String, dynamic> modelItem,
  required int startNumber,
  required int endNumber,
  required List<Map<String, dynamic>> existingItems,
  String prefix = 'Lote',
}) {
  if (startNumber < 1 || endNumber < startNumber) {
    throw ArgumentError('Intervalo inválido: $startNumber..$endNumber');
  }

  final quadra = _nullIfBlank(modelItem['quadra'] as String?) ?? 'Quadra 1';
  final quadraKey = quadra.toLowerCase();
  final effectivePrefix = prefix.trim();

  final existingNames = <String>{};
  final existingNumbers = <int>{};

  for (final item in existingItems) {
    final itemQuadra =
        (_nullIfBlank(item['quadra'] as String?) ?? '').toLowerCase();
    if (itemQuadra != quadraKey) continue;
    final itemName = (_nullIfBlank(item['nome'] as String?) ?? '');
    if (itemName.isEmpty) continue;
    existingNames.add(itemName.toLowerCase());
    final number = _extractLeadingOrTrailingNumber(itemName);
    if (number != null) {
      existingNumbers.add(number);
    }
  }

  const copiedFields = <String>[
    'frenteM',
    'profundidadeM',
    'areaTerrenoM2',
    'areaConstruidaM2',
    'logradouro',
    'taxaOcupacaoPercent',
    'coeficienteAproveitamento',
    'areaPermeavelM2',
    'taxaPermeabilidadePercent',
    'areaImpermeavelM2',
    'recuoFrontalM',
    'recuoFundoM',
    'recuoLateralEsquerdoM',
    'recuoLateralDireitoM',
    'proprietarioNome',
    'proprietarioDocumento',
    'responsavelTecnicoNome',
    'responsavelTecnicoRegistro',
    'dataProjeto',
  ];

  final generated = <Map<String, dynamic>>[];
  var skipped = 0;

  for (var n = startNumber; n <= endNumber; n++) {
    final candidateName =
        effectivePrefix.isEmpty ? '$n' : '$effectivePrefix $n';
    if (existingNumbers.contains(n) ||
        existingNames.contains(candidateName.toLowerCase())) {
      skipped++;
      continue;
    }

    final clone = <String, dynamic>{
      'quadra': quadra,
      'nome': candidateName,
      'status': 'valido',
    };

    for (final field in copiedFields) {
      if (modelItem[field] != null) {
        clone[field] = modelItem[field];
      }
    }

    generated.add(clone);
    existingNumbers.add(n);
    existingNames.add(candidateName.toLowerCase());
  }

  return LoteModelGenerationResult(
    items: [
      ...existingItems.map((e) => Map<String, dynamic>.from(e)),
      ...generated,
    ],
    createdCount: generated.length,
    skippedCount: skipped,
  );
}

class LoteamentoDraftReviewScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final String draftId;

  const LoteamentoDraftReviewScreen({
    super.key,
    required this.construtoraId,
    required this.draftId,
  });

  @override
  ConsumerState<LoteamentoDraftReviewScreen> createState() =>
      _LoteamentoDraftReviewScreenState();
}

class _LoteamentoDraftReviewScreenState
    extends ConsumerState<LoteamentoDraftReviewScreen> {
  final _nameController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _ufController = TextEditingController();
  final _proprietarioNomeController = TextEditingController();
  final _proprietarioDocController = TextEditingController();
  final _rtNomeController = TextEditingController();
  final _rtRegistroController = TextEditingController();

  ImportDestinationMode _destinationMode = ImportDestinationMode.novoLoteamento;
  String? _selectedLoteamentoId;
  List<Map<String, dynamic>> _items = [];

  bool _hydrated = false;
  bool _hasLocalEdits = false;
  int _lastHydratedServerCount = 0;
  bool _isSaving = false;
  bool _isApproving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _ufController.dispose();
    _proprietarioNomeController.dispose();
    _proprietarioDocController.dispose();
    _rtNomeController.dispose();
    _rtRegistroController.dispose();
    super.dispose();
  }

  void _hydrateFromDraft(Map<String, dynamic> data, {bool force = false}) {
    final rawItems = data['items'] as List<dynamic>? ?? const [];
    if (_hydrated && !force) {
      if (!_hasLocalEdits && rawItems.length != _lastHydratedServerCount) {
        // Novos itens chegaram do processamento multi-arquivo sem conflito local.
        _applyDraftData(data);
      }
      return;
    }
    _applyDraftData(data);
  }

  void _applyDraftData(Map<String, dynamic> data) {
    final loteamento =
        data['loteamento'] is Map
            ? Map<String, dynamic>.from(data['loteamento'] as Map)
            : <String, dynamic>{};

    _nameController.text =
        (loteamento['name'] as String?) ??
        (data['loteamentoName'] as String?) ??
        '';
    _bairroController.text = (loteamento['bairro'] as String?) ?? '';
    _cidadeController.text = (loteamento['cidade'] as String?) ?? '';
    _ufController.text = (loteamento['uf'] as String?) ?? '';
    _proprietarioNomeController.text =
        (loteamento['proprietarioNome'] as String?) ?? '';
    _proprietarioDocController.text =
        (loteamento['proprietarioDocumento'] as String?) ?? '';
    _rtNomeController.text =
        (loteamento['responsavelTecnicoNome'] as String?) ?? '';
    _rtRegistroController.text =
        (loteamento['responsavelTecnicoRegistro'] as String?) ?? '';

    final targetId = _nullIfBlank(data['targetLoteamentoId'] as String?);
    _selectedLoteamentoId = targetId;
    _destinationMode =
        targetId != null
            ? ImportDestinationMode.loteamentoExistente
            : ImportDestinationMode.novoLoteamento;

    final rawItems = data['items'] as List<dynamic>? ?? const [];
    _items = rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    _lastHydratedServerCount = _items.length;
    _hydrated = true;
    _hasLocalEdits = false;
  }

  Map<String, dynamic> _buildLoteamentoPayload() {
    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
    };
    void putIfNotBlank(String key, String value) {
      final normalized = _nullIfBlank(value);
      if (normalized != null) {
        payload[key] = normalized;
      }
    }

    putIfNotBlank('bairro', _bairroController.text);
    putIfNotBlank('cidade', _cidadeController.text);
    putIfNotBlank('uf', _ufController.text.toUpperCase());
    putIfNotBlank('proprietarioNome', _proprietarioNomeController.text);
    putIfNotBlank('proprietarioDocumento', _proprietarioDocController.text);
    putIfNotBlank('responsavelTecnicoNome', _rtNomeController.text);
    putIfNotBlank('responsavelTecnicoRegistro', _rtRegistroController.text);
    return payload;
  }

  String? _effectiveTargetLoteamentoId() {
    if (_destinationMode != ImportDestinationMode.loteamentoExistente) {
      return null;
    }
    return _nullIfBlank(_selectedLoteamentoId);
  }

  int _countPendingItems() {
    return _items.where((item) {
      final nome = _nullIfBlank(item['nome'] as String?);
      final status = (item['status'] as String?)?.toLowerCase();
      return nome == null || status == 'ambiguo';
    }).length;
  }

  int _countQuadras() {
    return _items
        .map((item) => (_nullIfBlank(item['quadra'] as String?) ?? '').toLowerCase())
        .where((q) => q.isNotEmpty)
        .toSet()
        .length;
  }

  Future<void> _saveDraft() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(loteamentosImportRepositoryProvider);
      await repo.saveDraftReview(
        draftId: widget.draftId,
        loteamento: _buildLoteamentoPayload(),
        targetLoteamentoId: _effectiveTargetLoteamentoId(),
        items: _items,
      );
      if (!mounted) return;
      setState(() {
        _hasLocalEdits = false;
        _lastHydratedServerCount = _items.length;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alterações do rascunho salvas.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar rascunho: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _approveDraft() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione ao menos um lote antes de aprovar.'),
        ),
      );
      return;
    }

    if (_destinationMode == ImportDestinationMode.novoLoteamento &&
        _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o nome do loteamento antes de aprovar.'),
        ),
      );
      return;
    }

    if (_destinationMode == ImportDestinationMode.loteamentoExistente &&
        _effectiveTargetLoteamentoId() == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione o loteamento existente para mesclar.'),
        ),
      );
      return;
    }

    final pending = _countPendingItems();
    if (pending > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Aprovar com pendências?'),
          content: Text(
            '$pending lote(s) estão sem nome ou marcados como ambíguos e poderão ser ajustados depois.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Aprovar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _isApproving = true);
    try {
      final repo = ref.read(loteamentosImportRepositoryProvider);
      await repo.approveTabularDraft(
        draftId: widget.draftId,
        loteamento: _buildLoteamentoPayload(),
        targetLoteamentoId: _effectiveTargetLoteamentoId(),
        items: _items,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rascunho aprovado e enviado para consolidação.'),
        ),
      );
      context.go('/construtoras/${widget.construtoraId}/loteamentos');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao aprovar rascunho: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isApproving = false);
      }
    }
  }

  Future<void> _openItemEditor({int? index}) async {
    final initial =
        index != null
            ? Map<String, dynamic>.from(_items[index])
            : <String, dynamic>{
              'quadra':
                  _items.isNotEmpty
                      ? (_items.last['quadra'] ?? 'Quadra 1')
                      : 'Quadra 1',
              'nome': '',
              'status': 'valido',
            };

    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => _DraftItemEditorDialog(initialItem: initial),
    );

    if (updated == null || !mounted) return;

    setState(() {
      if (index != null) {
        _items[index] = updated;
      } else {
        _items.add(updated);
      }
      _hasLocalEdits = true;
    });
  }

  Future<void> _openCompleteQuadraDialog({int initialModelIndex = 0}) async {
    if (_items.isEmpty) return;

    final result = await showDialog<LoteModelGenerationResult>(
      context: context,
      builder: (dialogContext) => _CompleteQuadraFromModelDialog(
        items: _items,
        initialModelIndex: initialModelIndex.clamp(0, _items.length - 1),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _items = result.items;
      _hasLocalEdits = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.skippedCount > 0
              ? '${result.createdCount} lote(s) gerado(s); ${result.skippedCount} já existente(s) preservado(s).'
              : '${result.createdCount} lote(s) gerado(s) a partir do lote-modelo.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draftStream = ref.watch(draftReviewStreamProvider(widget.draftId));
    final loteamentosAsync = ref.watch(
      watchLoteamentosProvider((construtoraId: widget.construtoraId)),
    );
    final loteamentos = loteamentosAsync.asData?.value ?? const <Loteamento>[];

    final data = draftStream.asData?.value;
    if (data != null) {
      _hydrateFromDraft(data);
    }

    final pendingCount = _countPendingItems();
    final quadrasCount = _countQuadras();
    final serverItemsCount =
        (data?['items'] as List<dynamic>? ?? const []).length;
    final hasServerUpdates =
        _hydrated && _hasLocalEdits && serverItemsCount > _lastHydratedServerCount;

    final effectiveSelectedLoteamentoId =
        loteamentos.any((l) => l.id == _selectedLoteamentoId)
            ? _selectedLoteamentoId
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisão Tabular do Loteamento'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (data != null) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  label: Text('$pendingCount Pendências'),
                  backgroundColor: pendingCount > 0
                      ? Colors.orange.withValues(alpha: 0.25)
                      : Colors.green.withValues(alpha: 0.25),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: (_isSaving || _isApproving) ? null : _saveDraft,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Salvar Rascunho'),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton.icon(
                onPressed: (_items.isNotEmpty && !_isApproving && !_isSaving)
                    ? _approveDraft
                    : null,
                icon: _isApproving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('Aprovar e Consolidar'),
              ),
            ),
          ],
        ],
      ),
      body: draftStream.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
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
        data: (draftData) {
          if (draftData == null) {
            return const Center(child: Text('Rascunho não encontrado.'));
          }

          final sourceFiles =
              (draftData['sourceFiles'] as List<dynamic>? ?? const [])
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasServerUpdates)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MaterialBanner(
                      content: Text(
                        'Novos itens foram extraídos no servidor ($serverItemsCount no total).',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _hydrateFromDraft(draftData, force: true);
                            });
                          },
                          child: const Text('Recarregar do servidor'),
                        ),
                      ],
                    ),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Dados do Loteamento',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            if (sourceFiles.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                children: sourceFiles
                                    .map(
                                      (f) => Chip(
                                        avatar: const Icon(
                                          Icons.description_outlined,
                                          size: 16,
                                        ),
                                        label: Text(
                                          '${f['filename'] ?? 'arquivo'}'
                                          '${f['pageCount'] != null ? ' (${f['pageCount']} pág.)' : ''}',
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<ImportDestinationMode>(
                          segments: const [
                            ButtonSegment(
                              value: ImportDestinationMode.novoLoteamento,
                              icon: Icon(Icons.add_business_outlined),
                              label: Text('Novo Loteamento'),
                            ),
                            ButtonSegment(
                              value: ImportDestinationMode.loteamentoExistente,
                              icon: Icon(Icons.merge_type_outlined),
                              label: Text('Mesclar em Existente'),
                            ),
                          ],
                          selected: {_destinationMode},
                          onSelectionChanged: (selection) {
                            setState(() {
                              _destinationMode = selection.first;
                              _hasLocalEdits = true;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_destinationMode ==
                            ImportDestinationMode.loteamentoExistente)
                          loteamentosAsync.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (err, _) => Text(
                              'Erro ao carregar loteamentos: $err',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            data: (list) {
                              if (list.isEmpty) {
                                return const Text(
                                  'Nenhum loteamento cadastrado. Altere para "Novo Loteamento".',
                                );
                              }
                              return DropdownButtonFormField<String>(
                                initialValue: effectiveSelectedLoteamentoId,
                                decoration: const InputDecoration(
                                  labelText: 'Loteamento de destino',
                                  border: OutlineInputBorder(),
                                ),
                                items: list
                                    .map(
                                      (l) => DropdownMenuItem(
                                        value: l.id,
                                        child: Text(l.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedLoteamentoId = value;
                                    _hasLocalEdits = true;
                                  });
                                },
                              );
                            },
                          )
                        else
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: 320,
                                child: TextField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nome do Loteamento *',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => _hasLocalEdits = true,
                                ),
                              ),
                              SizedBox(
                                width: 200,
                                child: TextField(
                                  controller: _bairroController,
                                  decoration: const InputDecoration(
                                    labelText: 'Bairro',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => _hasLocalEdits = true,
                                ),
                              ),
                              SizedBox(
                                width: 200,
                                child: TextField(
                                  controller: _cidadeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Cidade',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => _hasLocalEdits = true,
                                ),
                              ),
                              SizedBox(
                                width: 90,
                                child: TextField(
                                  controller: _ufController,
                                  decoration: const InputDecoration(
                                    labelText: 'UF',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLength: 2,
                                  onChanged: (_) => _hasLocalEdits = true,
                                ),
                              ),
                              SizedBox(
                                width: 280,
                                child: TextField(
                                  controller: _proprietarioNomeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Proprietário',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => _hasLocalEdits = true,
                                ),
                              ),
                              SizedBox(
                                width: 200,
                                child: TextField(
                                  controller: _proprietarioDocController,
                                  decoration: const InputDecoration(
                                    labelText: 'CPF/CNPJ',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => _hasLocalEdits = true,
                                ),
                              ),
                              SizedBox(
                                width: 260,
                                child: TextField(
                                  controller: _rtNomeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Responsável Técnico',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => _hasLocalEdits = true,
                                ),
                              ),
                              SizedBox(
                                width: 180,
                                child: TextField(
                                  controller: _rtRegistroController,
                                  decoration: const InputDecoration(
                                    labelText: 'CREA / CAU',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => _hasLocalEdits = true,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Lotes Extraídos (${_items.length} lotes • $quadrasCount quadra(s))',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _items.isEmpty
                                      ? null
                                      : () => _openCompleteQuadraDialog(),
                                  icon: const Icon(Icons.copy_all_outlined),
                                  label: const Text(
                                    'Completar Quadra via Lote-Modelo',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _openItemEditor(),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Adicionar Lote'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text(
                                'Nenhum lote encontrado no rascunho. Adicione um lote manualmente.',
                              ),
                            ),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Quadra')),
                                DataColumn(label: Text('Lote')),
                                DataColumn(label: Text('Logradouro')),
                                DataColumn(
                                  label: Text('Frente (m)'),
                                  numeric: true,
                                ),
                                DataColumn(
                                  label: Text('Prof. (m)'),
                                  numeric: true,
                                ),
                                DataColumn(
                                  label: Text('Terreno (m²)'),
                                  numeric: true,
                                ),
                                DataColumn(
                                  label: Text('Construída (m²)'),
                                  numeric: true,
                                ),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Ações')),
                              ],
                              rows: List<DataRow>.generate(_items.length, (
                                index,
                              ) {
                                final item = _items[index];
                                final quadra =
                                    (item['quadra'] as String?) ?? '';
                                final nome = (item['nome'] as String?) ?? '';
                                final logradouro =
                                    (item['logradouro'] as String?) ?? '';
                                final frente = _asDouble(item['frenteM']);
                                final prof = _asDouble(item['profundidadeM']);
                                final areaTerreno = _asDouble(
                                  item['areaTerrenoM2'],
                                );
                                final areaConstruida = _asDouble(
                                  item['areaConstruidaM2'],
                                );
                                final isAmbiguous =
                                    nome.trim().isEmpty ||
                                    (item['status'] as String?)
                                            ?.toLowerCase() ==
                                        'ambiguo';

                                return DataRow(
                                  cells: [
                                    DataCell(Text(quadra)),
                                    DataCell(
                                      Text(
                                        nome.isEmpty ? '(sem nome)' : nome,
                                        style: nome.isEmpty
                                            ? const TextStyle(
                                                color: Colors.orange,
                                                fontStyle: FontStyle.italic,
                                              )
                                            : null,
                                      ),
                                    ),
                                    DataCell(Text(logradouro)),
                                    DataCell(Text(formatDraftBrDouble(frente))),
                                    DataCell(Text(formatDraftBrDouble(prof))),
                                    DataCell(
                                      Text(formatDraftBrDouble(areaTerreno)),
                                    ),
                                    DataCell(
                                      Text(formatDraftBrDouble(areaConstruida)),
                                    ),
                                    DataCell(
                                      Chip(
                                        label: Text(
                                          isAmbiguous ? 'Pendência' : 'Válido',
                                        ),
                                        backgroundColor: isAmbiguous
                                            ? Colors.orange.withValues(
                                                alpha: 0.2,
                                              )
                                            : Colors.green.withValues(
                                                alpha: 0.2,
                                              ),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                            tooltip: 'Editar lote',
                                            onPressed: () =>
                                                _openItemEditor(index: index),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.copy_all_outlined,
                                            ),
                                            tooltip: 'Usar como lote-modelo',
                                            onPressed: () =>
                                                _openCompleteQuadraDialog(
                                                  initialModelIndex: index,
                                                ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                            tooltip: 'Remover lote',
                                            onPressed: () {
                                              setState(() {
                                                _items.removeAt(index);
                                                _hasLocalEdits = true;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DraftItemEditorDialog extends StatefulWidget {
  final Map<String, dynamic> initialItem;

  const _DraftItemEditorDialog({required this.initialItem});

  @override
  State<_DraftItemEditorDialog> createState() => _DraftItemEditorDialogState();
}

class _DraftItemEditorDialogState extends State<_DraftItemEditorDialog> {
  late final TextEditingController _quadraCtrl;
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _logradouroCtrl;
  late final TextEditingController _frenteCtrl;
  late final TextEditingController _profCtrl;
  late final TextEditingController _areaTerrenoCtrl;
  late final TextEditingController _areaConstruidaCtrl;

  // Campos opcionais do PDF
  late final TextEditingController _taxaOcupacaoCtrl;
  late final TextEditingController _coefAprovCtrl;
  late final TextEditingController _areaPermCtrl;
  late final TextEditingController _taxaPermCtrl;
  late final TextEditingController _areaImpermCtrl;
  late final TextEditingController _recuoFrontalCtrl;
  late final TextEditingController _recuoFundoCtrl;
  late final TextEditingController _recuoLatEsqCtrl;
  late final TextEditingController _recuoLatDirCtrl;
  late final TextEditingController _dataProjetoCtrl;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _quadraCtrl = TextEditingController(text: (item['quadra'] as String?) ?? '');
    _nomeCtrl = TextEditingController(text: (item['nome'] as String?) ?? '');
    _logradouroCtrl = TextEditingController(
      text: (item['logradouro'] as String?) ?? '',
    );
    _frenteCtrl = TextEditingController(
      text: formatDraftBrDouble(_asDouble(item['frenteM'])),
    );
    _profCtrl = TextEditingController(
      text: formatDraftBrDouble(_asDouble(item['profundidadeM'])),
    );
    _areaTerrenoCtrl = TextEditingController(
      text: formatDraftBrDouble(_asDouble(item['areaTerrenoM2'])),
    );
    _areaConstruidaCtrl = TextEditingController(
      text: formatDraftBrDouble(_asDouble(item['areaConstruidaM2'])),
    );

    _taxaOcupacaoCtrl = TextEditingController(
      text: formatDraftBrDouble(_asDouble(item['taxaOcupacaoPercent'])),
    );
    _coefAprovCtrl = TextEditingController(
      text: formatDraftBrDouble(_asDouble(item['coeficienteAproveitamento'])),
    );
    _areaPermCtrl = TextEditingController(
      text: formatDraftBrDouble(_asDouble(item['areaPermeavelM2'])),
    );
    _taxaPermCtrl = TextEditingController(
      text: formatDraftBrDouble(_asDouble(item['taxaPermeabilidadePercent'])),
    );
    _areaImpermCtrl = TextEditingController(
      text: formatDraftBrDouble(_asDouble(item['areaImpermeavelM2'])),
    );
    _recuoFrontalCtrl = TextEditingController(
      text: formatDraftBrDouble(_asDouble(item['recuoFrontalM'])),
    );
    _recuoFundoCtrl = TextEditingController(
      text: formatDraftBrDouble(_asDouble(item['recuoFundoM'])),
    );
    _recuoLatEsqCtrl = TextEditingController(
      text: formatDraftBrDouble(_asDouble(item['recuoLateralEsquerdoM'])),
    );
    _recuoLatDirCtrl = TextEditingController(
      text: formatDraftBrDouble(_asDouble(item['recuoLateralDireitoM'])),
    );
    _dataProjetoCtrl = TextEditingController(
      text: (item['dataProjeto'] as String?) ?? '',
    );
  }

  @override
  void dispose() {
    _quadraCtrl.dispose();
    _nomeCtrl.dispose();
    _logradouroCtrl.dispose();
    _frenteCtrl.dispose();
    _profCtrl.dispose();
    _areaTerrenoCtrl.dispose();
    _areaConstruidaCtrl.dispose();
    _taxaOcupacaoCtrl.dispose();
    _coefAprovCtrl.dispose();
    _areaPermCtrl.dispose();
    _taxaPermCtrl.dispose();
    _areaImpermCtrl.dispose();
    _recuoFrontalCtrl.dispose();
    _recuoFundoCtrl.dispose();
    _recuoLatEsqCtrl.dispose();
    _recuoLatDirCtrl.dispose();
    _dataProjetoCtrl.dispose();
    super.dispose();
  }

  void _recalculateTerrenoArea() {
    final frente = parseDraftBrDouble(_frenteCtrl.text);
    final prof = parseDraftBrDouble(_profCtrl.text);
    if (frente != null && prof != null && frente > 0 && prof > 0) {
      _areaTerrenoCtrl.text = formatDraftBrDouble(frente * prof);
    }
  }

  void _save() {
    final result = Map<String, dynamic>.from(widget.initialItem);

    void setString(String key, String text) {
      final value = _nullIfBlank(text);
      if (value != null) {
        result[key] = value;
      } else {
        result.remove(key);
      }
    }

    void setNum(String key, String text) {
      final value = parseDraftBrDouble(text);
      if (value != null) {
        result[key] = value;
      } else {
        result.remove(key);
      }
    }

    result['quadra'] = _quadraCtrl.text.trim();
    result['nome'] = _nomeCtrl.text.trim();
    result['status'] =
        _nomeCtrl.text.trim().isEmpty ? 'ambiguo' : 'valido';

    setString('logradouro', _logradouroCtrl.text);
    setNum('frenteM', _frenteCtrl.text);
    setNum('profundidadeM', _profCtrl.text);
    setNum('areaTerrenoM2', _areaTerrenoCtrl.text);
    setNum('areaConstruidaM2', _areaConstruidaCtrl.text);
    setNum('taxaOcupacaoPercent', _taxaOcupacaoCtrl.text);
    setNum('coeficienteAproveitamento', _coefAprovCtrl.text);
    setNum('areaPermeavelM2', _areaPermCtrl.text);
    setNum('taxaPermeabilidadePercent', _taxaPermCtrl.text);
    setNum('areaImpermeavelM2', _areaImpermCtrl.text);
    setNum('recuoFrontalM', _recuoFrontalCtrl.text);
    setNum('recuoFundoM', _recuoFundoCtrl.text);
    setNum('recuoLateralEsquerdoM', _recuoLatEsqCtrl.text);
    setNum('recuoLateralDireitoM', _recuoLatDirCtrl.text);
    setString('dataProjeto', _dataProjetoCtrl.text);

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Lote do Rascunho'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quadraCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Quadra',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _nomeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Lote',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _logradouroCtrl,
                decoration: const InputDecoration(
                  labelText: 'Logradouro',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _frenteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Frente (m)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => _recalculateTerrenoArea(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _profCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Profundidade (m)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => _recalculateTerrenoArea(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _areaTerrenoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Área do Terreno (m²)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _areaConstruidaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Área Construída (m²)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                title: const Text(
                  'Índices urbanísticos, recuos e carimbo (opcionais)',
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 8, bottom: 4),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _taxaOcupacaoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Taxa Ocupação (%)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _coefAprovCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Coef. Aproveitamento',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _areaPermCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Área Permeável (m²)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _taxaPermCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Taxa Permeab. (%)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _areaImpermCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Área Impermeável (m²)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _dataProjetoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Data do Projeto',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _recuoFrontalCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Recuo Frontal (m)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _recuoFundoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Recuo Fundo (m)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _recuoLatEsqCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Recuo Lat. Esq. (m)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _recuoLatDirCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Recuo Lat. Dir. (m)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Salvar Lote')),
      ],
    );
  }
}

class _CompleteQuadraFromModelDialog extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int initialModelIndex;

  const _CompleteQuadraFromModelDialog({
    required this.items,
    required this.initialModelIndex,
  });

  @override
  State<_CompleteQuadraFromModelDialog> createState() =>
      _CompleteQuadraFromModelDialogState();
}

class _CompleteQuadraFromModelDialogState
    extends State<_CompleteQuadraFromModelDialog> {
  late int _selectedIndex;
  final _prefixCtrl = TextEditingController(text: 'Lote');
  final _startCtrl = TextEditingController(text: '1');
  final _endCtrl = TextEditingController(text: '30');

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialModelIndex;
  }

  @override
  void dispose() {
    _prefixCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  LoteModelGenerationResult? _computePreview() {
    final start = int.tryParse(_startCtrl.text.trim());
    final end = int.tryParse(_endCtrl.text.trim());
    if (start == null || end == null || start < 1 || end < start) {
      return null;
    }
    return generateQuadraFromLoteModel(
      modelItem: widget.items[_selectedIndex],
      startNumber: start,
      endNumber: end,
      existingItems: widget.items,
      prefix: _prefixCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.items[_selectedIndex];
    final quadra = _nullIfBlank(model['quadra'] as String?) ?? 'Quadra 1';
    final frente = formatDraftBrDouble(_asDouble(model['frenteM']));
    final prof = formatDraftBrDouble(_asDouble(model['profundidadeM']));
    final terreno = formatDraftBrDouble(_asDouble(model['areaTerrenoM2']));
    final preview = _computePreview();

    return AlertDialog(
      title: const Text('Completar Quadra via Lote-Modelo'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _selectedIndex,
                decoration: const InputDecoration(
                  labelText: 'Lote-modelo',
                  border: OutlineInputBorder(),
                ),
                items: List<DropdownMenuItem<int>>.generate(
                  widget.items.length,
                  (i) {
                    final item = widget.items[i];
                    final label =
                        '${item['quadra'] ?? 'Sem quadra'} — ${item['nome'] ?? 'Sem nome'}';
                    return DropdownMenuItem(value: i, child: Text(label));
                  },
                ),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedIndex = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              Text(
                'Quadra: $quadra'
                '${frente.isNotEmpty && prof.isNotEmpty ? ' • ${frente}m x ${prof}m' : ''}'
                '${terreno.isNotEmpty ? ' • $terreno m²' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _prefixCtrl,
                decoration: const InputDecoration(
                  labelText: 'Prefixo do nome',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _startCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Número inicial',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _endCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Número final',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (preview != null)
                Text(
                  'Serão gerados ${preview.createdCount} novo(s) lote(s) em $quadra '
                  '(${preview.skippedCount} já existente(s) serão mantidos sem duplicação).',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                Text(
                  'Informe um intervalo válido (número inicial >= 1 e final >= inicial).',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed:
              preview != null && preview.createdCount > 0
                  ? () => Navigator.of(context).pop(preview)
                  : null,
          child: const Text('Gerar Lotes'),
        ),
      ],
    );
  }
}
