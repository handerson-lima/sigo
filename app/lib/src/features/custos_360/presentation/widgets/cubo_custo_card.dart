import 'package:flutter/material.dart';
import '../../domain/custo_lote_consolidado.dart';

class CuboCustoCard extends StatelessWidget {
  final CuboCusto cubo;
  final int valorCents;
  final int totalReferenciaCents;
  final VoidCallback? onTap;

  const CuboCustoCard({
    super.key,
    required this.cubo,
    required this.valorCents,
    required this.totalReferenciaCents,
    this.onTap,
  });

  String _formatarMoeda(int cents) {
    final valor = cents / 100.0;
    final valorStr = valor.toStringAsFixed(2).replaceAll('.', ',');
    final partes = valorStr.split(',');
    final inteira = partes[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'R\$ $inteira,${partes[1]}';
  }

  (Color, IconData, String) _configCubo(BuildContext context) {
    switch (cubo) {
      case CuboCusto.material:
        return (Colors.orange.shade700, Icons.inventory_2_outlined, 'Almoxarifado');
      case CuboCusto.maoDeObra:
        return (Colors.blue.shade700, Icons.groups_outlined, 'Equipes e Diárias');
      case CuboCusto.despesaDireta:
        return (Colors.purple.shade700, Icons.receipt_long_outlined, 'Lançamentos Diretos');
      case CuboCusto.rateioIndireto:
        return (Colors.teal.shade700, Icons.pie_chart_outline_rounded, 'Despesas Comuns');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (cor, icone, subtitulo) = _configCubo(context);
    final percentual = totalReferenciaCents > 0
        ? (valorCents / totalReferenciaCents.toDouble()) * 100.0
        : 0.0;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cor.withValues(alpha: 0.25), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 170,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: cor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icone, color: cor, size: 20),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${percentual.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: cor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cubo.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitulo,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatarMoeda(valorCents),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: cor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
