import 'package:flutter/material.dart';

import '../../../obras/domain/obra.dart';
import '../../../obras/domain/obra_member.dart';
import '../membros_providers.dart';
import 'role_chip.dart';

/// Microcopy congelada do estado vazio (texto estático na 8.3 — sem CTA
/// acionável; o botão Atribuir entra no epic 9).
const String obrasVinculadasVazioLabel = 'Nenhum loteamento vinculado — Atribuir';

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
/// Overflow com `Trocar papel` e `Remover da obra` (epic 10) quando
/// [onTrocarPapel] ou [onRemover] forem não-nulos.
class ObraVinculoRow extends StatelessWidget {
  final Obra obra;
  final ObraMember vinculo;

  /// Chamado ao selecionar "Trocar papel" no overflow. Nulo = item oculto.
  final VoidCallback? onTrocarPapel;

  /// Chamado ao selecionar "Remover da obra" no overflow. Nulo = item oculto.
  final VoidCallback? onRemover;

  const ObraVinculoRow({
    super.key,
    required this.obra,
    required this.vinculo,
    this.onTrocarPapel,
    this.onRemover,
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

    final hasMenu = onTrocarPapel != null || onRemover != null;

    return Padding(
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
                child: Semantics(
                  label: '$nome, $papel, $status',
                  excludeSemantics: true,
                  child: Text(
                    nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
              if (hasMenu)
                SizedBox(
                  width: 48,
                  height: 48,
                  child: PopupMenuButton<_ObraVinculoAction>(
                    key: Key('overflow-${obra.id}'),
                    tooltip: 'Opções de vínculo de $nome',
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert, size: 24),
                    onSelected: (action) {
                      if (action == _ObraVinculoAction.trocarPapel) {
                        onTrocarPapel?.call();
                      } else {
                        onRemover?.call();
                      }
                    },
                    itemBuilder: (_) => [
                      if (onTrocarPapel != null)
                        const PopupMenuItem(
                          value: _ObraVinculoAction.trocarPapel,
                          child: Text('Trocar papel'),
                        ),
                      if (onRemover != null)
                        const PopupMenuItem(
                          value: _ObraVinculoAction.remover,
                          child: Text('Remover do loteamento'),
                        ),
                    ],
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
      );
    }
}

enum _ObraVinculoAction { trocarPapel, remover }
