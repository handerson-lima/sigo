import 'package:flutter/material.dart';

import '../../../../core/contracts.dart';
import '../../domain/custo_mao_de_obra.dart';

class ResumoCustosChamadaDialog extends StatelessWidget {
  final int totalDayCostCents;
  final List<LotCostSummary> lotCostSummaries;
  final List<WorkerCostSnapshot> costSnapshots;
  final String date;

  const ResumoCustosChamadaDialog({
    super.key,
    required this.totalDayCostCents,
    required this.lotCostSummaries,
    required this.costSnapshots,
    required this.date,
  });

  static Future<void> show({
    required BuildContext context,
    required int totalDayCostCents,
    required List<LotCostSummary> lotCostSummaries,
    required List<WorkerCostSnapshot> costSnapshots,
    required String date,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ResumoCustosChamadaDialog(
        totalDayCostCents: totalDayCostCents,
        lotCostSummaries: lotCostSummaries,
        costSnapshots: costSnapshots,
        date: date,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.analytics_outlined, color: Colors.indigo),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fechamento Financeiro',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Data: $date',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 550,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card Totalizador
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.indigo.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total de Mão de Obra:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      formatCents(totalDayCostCents),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Seção de Apropriação por Lote
              Text(
                'Apropriação Consolidada por Lote',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              if (lotCostSummaries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Nenhum lote apropriado neste expediente.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                )
              else
                ...lotCostSummaries.map((lot) {
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 6),
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.home_work_outlined, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lot.lotName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${lot.workerCount} colaborador(es)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatCents(lot.totalCostCents),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 16),
              // Detalhamento por Colaborador
              Text(
                'Detalhamento por Colaborador (${costSnapshots.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              ...costSnapshots.map((worker) {
                final isFalta = worker.status == 'falta';
                final isMeio = worker.status == 'meio-periodo';

                Color statusColor = Colors.green;
                String statusLabel = 'Integral';
                if (isFalta) {
                  statusColor = Colors.red;
                  statusLabel = 'Falta';
                } else if (isMeio) {
                  statusColor = Colors.orange;
                  statusLabel = '1/2 Período';
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              worker.workerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${worker.workerRole} • $statusLabel',
                              style: TextStyle(
                                fontSize: 11,
                                color: statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatCents(worker.effectiveCostCents),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isFalta ? Colors.grey : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
