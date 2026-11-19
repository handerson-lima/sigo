import 'package:flutter/material.dart';

import '../../../design_system/sigo_theme.dart';
import '../../etapas/domain/etapa.dart';
import '../domain/lote.dart';
import 'lote_mass_generator_section.dart';

/// Card visual executivo de um [Lote] na grade/lista da quadra.
class LoteSummaryCard extends StatelessWidget {
  final Lote lote;
  final bool isAdmin;
  final VoidCallback? onTap;
  final VoidCallback? onAtribuirTap;

  const LoteSummaryCard({
    super.key,
    required this.lote,
    this.isAdmin = false,
    this.onTap,
    this.onAtribuirTap,
  });

  static String shortEtapaLabel(EtapaTipo tipo) => switch (tipo) {
    EtapaTipo.muro => 'Muro',
    EtapaTipo.cinza1 => '1ª',
    EtapaTipo.cinza2 => '2ª',
    EtapaTipo.cinza3 => '3ª',
    EtapaTipo.branca => 'Branca',
  };

  @override
  Widget build(BuildContext context) {
    final sigo =
        Theme.of(context).extension<SigoThemeExtension>() ?? SigoTheme.extension;
    final textTheme = Theme.of(context).textTheme;

    final progress = lote.progressoPercentual.clamp(0, 100);
    final totalEtapas = lote.etapasTotalCount > 0 ? lote.etapasTotalCount : 5;
    final concluidas = lote.etapasConcluidasCount.clamp(0, totalEtapas);

    final isComplete = progress >= 100 || concluidas >= totalEtapas;
    final hasAnyActivity =
        progress > 0 ||
        concluidas > 0 ||
        lote.statusEtapasMap.values.any(
          (status) =>
              status == EtapaStatus.emAndamento ||
              status == EtapaStatus.concluida,
        );

    final statusBadgeLabel = isComplete
        ? 'Concluído • $progress%'
        : hasAnyActivity
        ? 'Em andamento • $progress%'
        : 'Pendente • $progress%';
    final statusBadgeBg = isComplete
        ? sigo.lotCompleteBg
        : hasAnyActivity
        ? sigo.lotOnTimeBg
        : sigo.surfaceBase;
    final statusBadgeInk = isComplete
        ? sigo.lotCompleteInk
        : hasAnyActivity
        ? sigo.lotOnTimeInk
        : sigo.inkSecondary;

    final medidasText = _buildMedidasResumo();
    final alocacoesText = _buildAlocacoesResumo();
    final logradouro = lote.logradouro?.trim();

    return Material(
      color: sigo.surfaceRaised,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sigo.borderHairline),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cabeçalho: Nome + Badge de status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lote.name,
                          style: textTheme.titleMedium?.copyWith(
                            color: sigo.inkPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (logradouro != null && logradouro.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            logradouro,
                            style: textTheme.bodyMedium?.copyWith(
                              color: sigo.inkSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBadgeBg,
                      borderRadius: BorderRadius.circular(999),
                      border: !isComplete && !hasAnyActivity
                          ? Border.all(color: sigo.borderHairline)
                          : null,
                    ),
                    child: Text(
                      statusBadgeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusBadgeInk,
                      ),
                    ),
                  ),
                ],
              ),

              // Medidas resumidas
              if (medidasText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: sigo.surfaceBase,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sigo.borderHairline),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: medidasText
                        .map(
                          (item) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.icon,
                                size: 14,
                                color: sigo.inkSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: sigo.inkPrimary,
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],

              // Barra e percentual de conclusão das 5 etapas
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Conclusão das Etapas ($concluidas/$totalEtapas)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sigo.inkPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$progress%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isComplete ? sigo.lotCompleteInk : sigo.brandBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress / 100.0,
                  minHeight: 8,
                  backgroundColor: sigo.borderHairline,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isComplete ? sigo.lotCompleteInk : sigo.brandBlue,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: EtapaTipo.values
                    .map((tipo) => _buildEtapaBadge(tipo, sigo))
                    .toList(),
              ),

              // Rodapé: Equipes/Funcionários vinculados + botão rápido "+ Atribuir"
              const SizedBox(height: 12),
              Divider(height: 1, color: sigo.borderHairline),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 16,
                    color: sigo.inkSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      alocacoesText ?? 'Sem equipe ou funcionário vinculado',
                      style: TextStyle(
                        fontSize: 12,
                        color: alocacoesText != null
                            ? sigo.inkPrimary
                            : sigo.inkSecondary,
                        fontWeight: alocacoesText != null
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isAdmin && onAtribuirTap != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      key: Key('lote_card_atribuir_${lote.id}'),
                      onPressed: onAtribuirTap,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Atribuir'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: sigo.actionBlue,
                        side: BorderSide(color: sigo.actionBlue),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEtapaBadge(EtapaTipo tipo, SigoThemeExtension sigo) {
    final status = lote.statusEtapasMap[tipo.name] ?? EtapaStatus.pendente;
    final (IconData icon, Color bg, Color fg, Color border) = switch (status) {
      EtapaStatus.concluida => (
        Icons.check_circle,
        sigo.lotCompleteBg,
        sigo.lotCompleteInk,
        sigo.lotCompleteBg,
      ),
      EtapaStatus.emAndamento => (
        Icons.timelapse,
        sigo.lotOnTimeBg,
        sigo.lotOnTimeInk,
        sigo.brandGold,
      ),
      _ => (
        Icons.radio_button_unchecked,
        sigo.surfaceBase,
        sigo.inkSecondary,
        sigo.borderHairline,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            shortEtapaLabel(tipo),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  List<_MedidaItem> _buildMedidasResumo() {
    final items = <_MedidaItem>[];
    if (lote.frenteM != null && lote.profundidadeM != null) {
      items.add(
        _MedidaItem(
          icon: Icons.straighten,
          label:
              '${formatDecimalPtBr(lote.frenteM!)}m × ${formatDecimalPtBr(lote.profundidadeM!)}m',
        ),
      );
    } else if (lote.frenteM != null) {
      items.add(
        _MedidaItem(
          icon: Icons.straighten,
          label: 'Frente: ${formatDecimalPtBr(lote.frenteM!)}m',
        ),
      );
    } else if (lote.profundidadeM != null) {
      items.add(
        _MedidaItem(
          icon: Icons.straighten,
          label: 'Prof.: ${formatDecimalPtBr(lote.profundidadeM!)}m',
        ),
      );
    }

    if (lote.areaTerrenoM2 != null) {
      items.add(
        _MedidaItem(
          icon: Icons.square_foot,
          label: 'Terreno: ${formatDecimalPtBr(lote.areaTerrenoM2!)} m²',
        ),
      );
    }

    if (lote.areaConstruidaM2 != null) {
      items.add(
        _MedidaItem(
          icon: Icons.home_work_outlined,
          label: 'Construída: ${formatDecimalPtBr(lote.areaConstruidaM2!)} m²',
        ),
      );
    }

    return items;
  }

  String? _buildAlocacoesResumo() {
    final labels = <String>[];
    final seen = <String>{};

    for (final equipe in lote.equipesVinculadas) {
      final name = equipe['name']?.toString().trim() ?? '';
      if (name.isNotEmpty && seen.add('eq:$name')) {
        labels.add(name);
      }
    }

    for (final func in lote.funcionariosVinculados) {
      final name = func['name']?.toString().trim() ?? '';
      final role = func['role']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final formatted = role.isNotEmpty ? '$name ($role)' : name;
      if (seen.add('fn:$formatted')) {
        labels.add(formatted);
      }
    }

    if (labels.isEmpty) return null;
    return labels.join(' • ');
  }
}

class _MedidaItem {
  final IconData icon;
  final String label;

  const _MedidaItem({required this.icon, required this.label});
}
