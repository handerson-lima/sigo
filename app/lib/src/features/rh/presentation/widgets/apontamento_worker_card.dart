import 'package:flutter/material.dart';
import '../../../../core/contracts.dart';
import '../../../lotes/domain/lote.dart';
import '../../domain/chamada_diaria.dart';
import 'rateio_lotes_sheet.dart';

class ApontamentoWorkerCard extends StatelessWidget {
  final ApontamentoTrabalhador apontamento;
  final List<Lote> availableLotes;
  final String? defaultLotId;
  final int? baseDailyRateCents;
  final ValueChanged<ApontamentoTrabalhador> onChanged;

  const ApontamentoWorkerCard({
    super.key,
    required this.apontamento,
    required this.availableLotes,
    this.defaultLotId,
    this.baseDailyRateCents,
    required this.onChanged,
  });

  int get effectiveCostCents {
    if (baseDailyRateCents == null) return 0;
    if (apontamento.status == PresencaStatus.falta) return 0;
    if (apontamento.status == PresencaStatus.meioPeriodo) {
      return baseDailyRateCents! ~/ 2;
    }
    return baseDailyRateCents!;
  }

  void _setStatus(PresencaStatus newStatus) {
    if (newStatus == apontamento.status) return;

    List<AlocacaoLote> newAllocations = [];
    if (newStatus == PresencaStatus.falta) {
      newAllocations = [];
    } else {
      // Se estava em falta ou sem alocação, usa o lote padrão ou o primeiro lote disponível
      final targetLotId = defaultLotId ??
          (availableLotes.isNotEmpty ? availableLotes.first.id : null);
      final targetLot = availableLotes.where((l) => l.id == targetLotId).firstOrNull ??
          (availableLotes.isNotEmpty ? availableLotes.first : null);

      final percentage = newStatus == PresencaStatus.meioPeriodo ? 50 : 100;

      if (targetLot != null) {
        newAllocations = [
          AlocacaoLote(
            lotId: targetLot.id,
            lotName: targetLot.name,
            percentage: percentage,
          ),
        ];
      }
    }

    onChanged(
      apontamento.copyWith(
        status: newStatus,
        allocations: newAllocations,
      ),
    );
  }

  void _openRateioSheet(BuildContext context) {
    RateioLotesSheet.show(
      context: context,
      workerName: apontamento.workerName,
      status: apontamento.status,
      availableLotes: availableLotes,
      initialAllocations: apontamento.allocations,
      effectiveCostCents: effectiveCostCents,
      onSave: (allocations) {
        onChanged(apontamento.copyWith(allocations: allocations));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFalta = apontamento.status == PresencaStatus.falta;
    final isMeio = apontamento.status == PresencaStatus.meioPeriodo;
    final isPresente = apontamento.status == PresencaStatus.presente;
    final hasError = !apontamento.isValidAllocation;

    Color statusColor;
    if (isFalta) {
      statusColor = Colors.red;
    } else if (isMeio) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.green;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasError
              ? Colors.red
              : statusColor.withValues(alpha: 0.3),
          width: hasError ? 2.0 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Text(
                    apontamento.workerName.isNotEmpty
                        ? apontamento.workerName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        apontamento.workerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        apontamento.workerRole,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (baseDailyRateCents != null) ...[
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          formatCents(effectiveCostCents),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatCents(baseDailyRateCents!)}/dia',
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Botões de Presença / Meio-Período / Falta
            LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  children: [
                    Expanded(
                      child: _StatusOptionButton(
                        label: 'Presente',
                        shortLabel: 'P',
                        isSelected: isPresente,
                        activeColor: Colors.green,
                        onTap: () => _setStatus(PresencaStatus.presente),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _StatusOptionButton(
                        label: '1/2 Período',
                        shortLabel: '1/2',
                        isSelected: isMeio,
                        activeColor: Colors.orange,
                        onTap: () => _setStatus(PresencaStatus.meioPeriodo),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _StatusOptionButton(
                        label: 'Falta',
                        shortLabel: 'F',
                        isSelected: isFalta,
                        activeColor: Colors.red,
                        onTap: () => _setStatus(PresencaStatus.falta),
                      ),
                    ),
                  ],
                );
              },
            ),

            if (!isFalta) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: apontamento.allocations.isEmpty
                          ? [
                              Chip(
                                label: const Text('Nenhum lote'),
                                backgroundColor: Colors.red.withValues(alpha: 0.1),
                                labelStyle: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ]
                          : apontamento.allocations.map((alloc) {
                              return Chip(
                                avatar: const Icon(Icons.home_work_outlined, size: 14),
                                label: Text(
                                  '${alloc.lotName.isEmpty ? "Lote" : alloc.lotName} (${alloc.percentage}%)',
                                ),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: colorScheme.surfaceContainerHighest,
                                labelStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }).toList(),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Lotes / Rateio', style: TextStyle(fontSize: 12)),
                    onPressed: () => _openRateioSheet(context),
                  ),
                ],
              ),
            ],

            if (hasError) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.error_outline, size: 14, color: Colors.red),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      apontamento.validationError ?? 'Alocação inválida',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusOptionButton extends StatelessWidget {
  final String label;
  final String shortLabel;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _StatusOptionButton({
    required this.label,
    required this.shortLabel,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 44, // Generoso para toque em campo
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? activeColor : Colors.grey.shade700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
