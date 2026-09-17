import 'package:flutter/material.dart';
import '../../../lotes/domain/lote.dart';
import '../../domain/chamada_diaria.dart';

class RateioLotesSheet extends StatefulWidget {
  final String workerName;
  final PresencaStatus status;
  final List<Lote> availableLotes;
  final List<AlocacaoLote> initialAllocations;
  final ValueChanged<List<AlocacaoLote>> onSave;

  const RateioLotesSheet({
    super.key,
    required this.workerName,
    required this.status,
    required this.availableLotes,
    required this.initialAllocations,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required String workerName,
    required PresencaStatus status,
    required List<Lote> availableLotes,
    required List<AlocacaoLote> initialAllocations,
    required ValueChanged<List<AlocacaoLote>> onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => RateioLotesSheet(
        workerName: workerName,
        status: status,
        availableLotes: availableLotes,
        initialAllocations: initialAllocations,
        onSave: onSave,
      ),
    );
  }

  @override
  State<RateioLotesSheet> createState() => _RateioLotesSheetState();
}

class _RateioLotesSheetState extends State<RateioLotesSheet> {
  late List<AlocacaoLote> _allocations;
  String? _selectedLoteToAdd;

  int get _expectedPercentage =>
      widget.status == PresencaStatus.meioPeriodo ? 50 : 100;

  int get _totalPercentage =>
      _allocations.fold(0, (sum, item) => sum + item.percentage);

  bool get _isValid => _totalPercentage == _expectedPercentage;

  @override
  void initState() {
    super.initState();
    _allocations = List.from(widget.initialAllocations);
    if (_allocations.isEmpty && widget.availableLotes.isNotEmpty) {
      _allocations.add(
        AlocacaoLote(
          lotId: widget.availableLotes.first.id,
          lotName: widget.availableLotes.first.name,
          percentage: _expectedPercentage,
        ),
      );
    }
  }

  void _updatePercentage(int index, int newPercentage) {
    setState(() {
      final clamped = newPercentage.clamp(0, 100);
      _allocations[index] = _allocations[index].copyWith(percentage: clamped);
    });
  }

  void _removeAllocation(int index) {
    setState(() {
      _allocations.removeAt(index);
    });
  }

  void _addAllocation(String loteId) {
    final lote = widget.availableLotes.firstWhere((l) => l.id == loteId);
    if (_allocations.any((a) => a.lotId == loteId)) {
      return;
    }
    final remaining = (_expectedPercentage - _totalPercentage).clamp(0, 100);
    setState(() {
      _allocations.add(
        AlocacaoLote(
          lotId: lote.id,
          lotName: lote.name,
          percentage: remaining > 0 ? remaining : 0,
        ),
      );
      _selectedLoteToAdd = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;

    final unallocatedLotes = widget.availableLotes
        .where((l) => !_allocations.any((a) => a.lotId == l.id))
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rateio de Lotes: ${widget.workerName}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Status: ${widget.status.label} (Meta: $_expectedPercentage%)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Barra de progresso de validação
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isValid
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isValid ? Colors.green : Colors.red,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isValid ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: _isValid ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isValid
                            ? 'Alocação equilibrada ($_totalPercentage%)'
                            : 'Alocação incorreta: $_totalPercentage% de $_expectedPercentage%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isValid ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: _expectedPercentage > 0
                            ? (_totalPercentage / _expectedPercentage)
                                .clamp(0.0, 1.0)
                            : 0,
                        color: _isValid ? Colors.green : Colors.red,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Lista de alocações
          if (_allocations.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Nenhum lote alocado. Adicione um lote abaixo.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ..._allocations.asMap().entries.map((entry) {
              final idx = entry.key;
              final alloc = entry.value;
              return Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.home_work_outlined, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                alloc.lotName.isEmpty ? 'Lote' : alloc.lotName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                '${alloc.percentage}%',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Remover lote',
                                onPressed: () => _removeAllocation(idx),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Slider(
                        value: alloc.percentage.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 20, // passos de 5%
                        label: '${alloc.percentage}%',
                        onChanged: (val) => _updatePercentage(idx, val.round()),
                      ),
                    ],
                  ),
                ),
              );
            }),

          // Adicionar novo lote
          if (unallocatedLotes.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedLoteToAdd,
                    hint: const Text('Adicionar outro lote...'),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: unallocatedLotes.map((l) {
                      return DropdownMenuItem<String>(
                        value: l.id,
                        child: Text(l.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        _addAllocation(val);
                      }
                    },
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),

          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Confirmar Rateio'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isValid
                ? () {
                    widget.onSave(_allocations);
                    Navigator.of(context).pop();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
