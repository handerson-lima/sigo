import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/contracts.dart';
import '../../domain/chamada_diaria.dart';

class ChamadaAuditTimelineDialog extends StatelessWidget {
  final ChamadaDiaria chamada;

  const ChamadaAuditTimelineDialog({super.key, required this.chamada});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auditTrail = chamada.auditTrail;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.history, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Trilha de Auditoria'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: auditTrail.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      size: 48,
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Esta chamada é original (versão ${chamada.versaoAuditoria}) e não possui retificações.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: auditTrail.length,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final entry = auditTrail[index];
                  final diffCents =
                      entry.totalCostCentsNovo - entry.totalCostCentsAnterior;
                  final diffFormatted =
                      'Δ ${diffCents >= 0 ? '+' : ''}${formatCents(diffCents)}';
                  final dateStr = DateFormat('dd/MM/yyyy HH:mm')
                      .format(entry.timestamp);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Revisão v${entry.versaoAnterior} ➔ v${entry.versaoAnterior + 1}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            dateStr,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Por: ${entry.userName.isNotEmpty ? entry.userName : entry.userId}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Motivo: "${entry.motivo}"',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text('Impacto: ', style: theme.textTheme.bodySmall),
                          Text(
                            diffFormatted,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: diffCents > 0
                                  ? Colors.orange.shade800
                                  : (diffCents < 0
                                        ? Colors.green.shade800
                                        : Colors.grey),
                            ),
                          ),
                          Text(
                            '(${formatCents(entry.totalCostCentsAnterior)} ➔ ${formatCents(entry.totalCostCentsNovo)})',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
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
