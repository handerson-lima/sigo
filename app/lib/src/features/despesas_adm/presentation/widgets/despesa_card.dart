import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/despesa_adm.dart';

class DespesaCard extends StatelessWidget {
  final DespesaAdm despesa;
  final VoidCallback? onTap;
  final VoidCallback? onLiquidar;
  final VoidCallback? onCancelar;

  const DespesaCard({
    super.key,
    required this.despesa,
    this.onTap,
    this.onLiquidar,
    this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFormat = DateFormat('dd/MM/yyyy');

    final isPendente = despesa.status == StatusDespesaAdm.pendente;
    final isAtrasada = despesa.isVencida;
    final isPaga = despesa.status == StatusDespesaAdm.pago;
    final isCancelada = despesa.status == StatusDespesaAdm.cancelado;

    final Color statusColor = isPaga
        ? Colors.green.shade700
        : isCancelada
            ? Colors.grey.shade600
            : isAtrasada
                ? Colors.red.shade700
                : Colors.orange.shade800;

    final Color statusBg = isPaga
        ? Colors.green.shade50
        : isCancelada
            ? Colors.grey.shade100
            : isAtrasada
                ? Colors.red.shade50
                : Colors.orange.shade50;

    final String statusLabel = isCancelada
        ? 'Cancelado'
        : isPaga
            ? 'Pago'
            : isAtrasada
                ? 'Atrasado'
                : 'Pendente';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isAtrasada ? Colors.red.shade200 : Colors.grey.shade200,
          width: isAtrasada ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha Superior: Categoria, Lote e Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blueGrey.shade200),
                          ),
                          child: Text(
                            despesa.categoria.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey.shade800,
                            ),
                          ),
                        ),
                        if (despesa.loteId != null && despesa.loteId!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.indigo.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.home_work_outlined,
                                    size: 12, color: Colors.indigo.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  'Lote: ${despesa.loteId}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.indigo.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (despesa.isParcelado)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.purple.shade200),
                            ),
                            child: Text(
                              '${despesa.parcelas.length}x parcelas',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple.shade800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Descrição e Valor
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      despesa.descricao,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    currencyFormat.format(despesa.valorTotal),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isPaga ? Colors.green.shade800 : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Fornecedor (se houver)
              if (despesa.fornecedorNome != null &&
                  despesa.fornecedorNome!.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.business_outlined,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        despesa.fornecedorNome!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],

              // Datas e Comprovante
              Row(
                children: [
                  Icon(
                    isAtrasada ? Icons.warning_amber_rounded : Icons.calendar_today_outlined,
                    size: 14,
                    color: isAtrasada ? Colors.red.shade700 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Vencimento: ${dateFormat.format(despesa.dataVencimento)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isAtrasada ? Colors.red.shade800 : Colors.grey.shade700,
                      fontWeight: isAtrasada ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  if (despesa.comprovanteUrl != null &&
                      despesa.comprovanteUrl!.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.attach_file,
                            size: 14, color: Colors.blue.shade700),
                        const SizedBox(width: 2),
                        Text(
                          'Anexo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              // Se parcelada, progresso de pagamento
              if (despesa.isParcelado && despesa.parcelas.isNotEmpty) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: despesa.valorTotalCents > 0
                        ? (despesa.valorPagoCents / despesa.valorTotalCents)
                        : 0,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pago: ${currencyFormat.format(despesa.valorPagoCents / 100.0)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    Text(
                      'Saldo: ${currencyFormat.format(despesa.saldoDevedorCents / 100.0)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: despesa.saldoDevedorCents > 0
                            ? Colors.orange.shade900
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],

              // Botões de Ação Rápida
              if (isPendente || isAtrasada) ...[
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onCancelar != null)
                      TextButton.icon(
                        onPressed: onCancelar,
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: const Text('Cancelar'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (onLiquidar != null)
                      ElevatedButton.icon(
                        onPressed: onLiquidar,
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Liquidar / Pagar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
