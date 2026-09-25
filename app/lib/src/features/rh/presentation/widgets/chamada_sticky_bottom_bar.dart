import 'package:flutter/material.dart';

import '../../../../core/contracts.dart';
import '../../data/custo_mao_de_obra_service.dart';
import '../../domain/chamada_diaria.dart';
import 'resumo_custos_chamada_dialog.dart';

class ChamadaStickyBottomBar extends StatelessWidget {
  final ChamadaDiaria? existingChamada;
  final ChamadaCostsResult currentCosts;
  final String formattedDate;
  final int workersCount;
  final int presentCount;
  final int meioPeriodoCount;
  final int faltaCount;
  final bool isSaving;
  final bool isFormValid;
  final VoidCallback onSave;

  const ChamadaStickyBottomBar({
    super.key,
    required this.existingChamada,
    required this.currentCosts,
    required this.formattedDate,
    required this.workersCount,
    required this.presentCount,
    required this.meioPeriodoCount,
    required this.faltaCount,
    required this.isSaving,
    required this.isFormValid,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      size: 18,
                      color: Colors.indigo.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Custo Estimado: ${formatCents(currentCosts.totalDayCostCents)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.indigo.shade800,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.analytics_outlined, size: 16),
                  label: const Text(
                    'Resumo por Lote',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    ResumoCustosChamadaDialog.show(
                      context: context,
                      totalDayCostCents: currentCosts.totalDayCostCents,
                      lotCostSummaries: currentCosts.lotCostSummaries,
                      costSnapshots: currentCosts.costSnapshots,
                      date: formattedDate,
                    );
                  },
                ),
              ],
            ),
            const Divider(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryItem(
                  label: 'Total',
                  count: workersCount,
                  color: Colors.blueGrey,
                ),
                _SummaryItem(
                  label: 'Presentes',
                  count: presentCount,
                  color: Colors.green,
                ),
                _SummaryItem(
                  label: '1/2 Período',
                  count: meioPeriodoCount,
                  color: Colors.orange,
                ),
                _SummaryItem(
                  label: 'Faltas',
                  count: faltaCount,
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                icon: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  isSaving
                      ? 'Salvando Chamada...'
                      : (existingChamada != null
                            ? 'Retificar Chamada Diária'
                            : 'Salvar Chamada Diária'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: (isFormValid && !isSaving) ? onSave : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withValues(alpha: 0.85),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
