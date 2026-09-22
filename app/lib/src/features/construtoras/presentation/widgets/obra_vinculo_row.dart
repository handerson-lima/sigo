import 'package:flutter/material.dart';

import '../../../obras/domain/obra.dart';
import '../../../obras/domain/obra_member.dart';
import '../membros_providers.dart';
import 'role_chip.dart';

/// Microcopy congelada do estado vazio (texto estático na 8.3 — sem CTA
/// acionável; o botão Atribuir entra no epic 9).
const String obrasVinculadasVazioLabel = 'Nenhuma obra vinculada — Atribuir';

/// Estado vazio do bloco Obras do detalhe (UX-DR3).
class ObraVinculoVazio extends StatelessWidget {
  const ObraVinculoVazio({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: obrasVinculadasVazioLabel,
      excludeSemantics: true,
      child: Text(
        obrasVinculadasVazioLabel,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Linha do vínculo obra ↔ membro: nome + papel obra + status.
/// Sem menu overflow na 8.3 (epic 10).
class ObraVinculoRow extends StatelessWidget {
  final Obra obra;
  final ObraMember vinculo;

  const ObraVinculoRow({
    super.key,
    required this.obra,
    required this.vinculo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final papel = rotuloPapelObra(vinculo);
    final ativo = vinculo.isActive;
    final status = rotuloStatusVinculo(ativo);
    final nome = obra.name.trim().isEmpty ? 'Obra ${obra.id}' : obra.name;

    final statusBg = ativo ? const Color(0xFFECFDF5) : Colors.grey.shade100;
    final statusBorder = ativo ? const Color(0xFF10B981) : Colors.grey.shade400;
    final statusInk = ativo ? const Color(0xFF065F46) : Colors.grey.shade700;
    final statusIcon =
        ativo ? Icons.check_circle_outline : Icons.remove_circle_outline;

    return Semantics(
      label: '$nome, $papel, $status',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.business, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                RoleChip(
                  papel: vinculo.isAdmin
                      ? PapelChip.administrador
                      : PapelChip.operario,
                  label: papel,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusInk),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusInk,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
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
