import 'package:flutter/material.dart';

import '../../../design_system/sigo_theme.dart';
import '../domain/quadra.dart';
import 'quadra_summary_provider.dart';

/// Card operacional escaneável de uma [Quadra] na grade/lista do loteamento.
class QuadraSummaryCard extends StatelessWidget {
  final Quadra quadra;
  final QuadraSummary? summary;
  final VoidCallback? onTap;

  const QuadraSummaryCard({
    super.key,
    required this.quadra,
    this.summary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sigo =
        Theme.of(context).extension<SigoThemeExtension>() ?? SigoTheme.extension;
    final textTheme = Theme.of(context).textTheme;

    final effectiveSummary = summary ?? QuadraSummary.empty;
    final totalLotes = effectiveSummary.totalLotes;
    final hasLotes = totalLotes > 0;
    final rawProgress = effectiveSummary.progressoMedio.clamp(0, 100);

    final isComplete =
        hasLotes &&
        (rawProgress >= 100 || effectiveSummary.concluidos == totalLotes);
    final isInProgress =
        hasLotes &&
        !isComplete &&
        (rawProgress > 0 ||
            effectiveSummary.emAndamento > 0 ||
            effectiveSummary.concluidos > 0);
    final displayProgress = isComplete ? 100 : rawProgress;

    final statusBadgeLabel = !hasLotes
        ? 'Sem lotes'
        : isComplete
        ? 'Concluída • 100%'
        : isInProgress
        ? 'Em andamento • $displayProgress%'
        : 'Pendente • $displayProgress%';

    final statusBadgeBg = isComplete
        ? sigo.lotCompleteBg
        : isInProgress
        ? sigo.lotOnTimeBg
        : sigo.surfaceBase;
    final statusBadgeInk = isComplete
        ? sigo.lotCompleteInk
        : isInProgress
        ? sigo.lotOnTimeInk
        : sigo.inkSecondary;

    final trimmedLogradouro = quadra.logradouroPadrao?.trim();
    final hasLogradouro =
        trimmedLogradouro != null && trimmedLogradouro.isNotEmpty;
    final logradouroDisplay = hasLogradouro
        ? trimmedLogradouro
        : 'Sem logradouro padrão';

    final lotesCountLabel = totalLotes == 0
        ? '0 lotes cadastrados'
        : totalLotes == 1
        ? '1 lote'
        : '$totalLotes lotes';

    final hasStatusPills =
        hasLotes &&
        (effectiveSummary.concluidos > 0 ||
            effectiveSummary.emAndamento > 0 ||
            effectiveSummary.pendentes > 0);

    final semanticsLabel =
        '${quadra.name}, $logradouroDisplay, $lotesCountLabel, $statusBadgeLabel';

    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      child: Material(
        color: sigo.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: sigo.surfaceBase,
          mouseCursor: onTap != null
              ? SystemMouseCursors.click
              : MouseCursor.defer,
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
                // Cabeçalho: Ícone identificador + Nome/Logradouro + Badge de status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: sigo.surfaceBase,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sigo.borderHairline),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.grid_view_rounded,
                        size: 20,
                        color: sigo.actionBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quadra.name,
                            style: textTheme.titleMedium?.copyWith(
                              color: sigo.inkPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Icon(
                                  Icons.signpost_outlined,
                                  size: 14,
                                  color: hasLogradouro
                                      ? sigo.inkSecondary
                                      : sigo.inkDisabled,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  logradouroDisplay,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: hasLogradouro
                                        ? sigo.inkSecondary
                                        : sigo.inkDisabled,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
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
                        border: !isComplete && !isInProgress
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

                // Seção de progresso consolidado da quadra
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        lotesCountLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: hasLotes
                              ? sigo.inkPrimary
                              : sigo.inkSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$displayProgress%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isComplete
                            ? sigo.lotCompleteInk
                            : hasLotes
                            ? sigo.brandBlue
                            : sigo.inkSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: displayProgress / 100.0,
                    minHeight: 6,
                    backgroundColor: sigo.borderHairline,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isComplete ? sigo.lotCompleteInk : sigo.brandBlue,
                    ),
                  ),
                ),

                // Rodapé: pílulas compactas de status ou CTA "Abrir lotes" + chevron
                const SizedBox(height: 12),
                Divider(height: 1, color: sigo.borderHairline),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: hasStatusPills
                          ? Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (effectiveSummary.concluidos > 0)
                                  _StatusPill(
                                    icon: Icons.check_circle,
                                    label:
                                        '${effectiveSummary.concluidos} concl.',
                                    bg: sigo.lotCompleteBg,
                                    fg: sigo.lotCompleteInk,
                                    border: sigo.lotCompleteBg,
                                  ),
                                if (effectiveSummary.emAndamento > 0)
                                  _StatusPill(
                                    icon: Icons.timelapse,
                                    label:
                                        '${effectiveSummary.emAndamento} andam.',
                                    bg: sigo.lotOnTimeBg,
                                    fg: sigo.lotOnTimeInk,
                                    border: sigo.lotOnTimeBg,
                                  ),
                                if (effectiveSummary.pendentes > 0)
                                  _StatusPill(
                                    icon: Icons.radio_button_unchecked,
                                    label:
                                        '${effectiveSummary.pendentes} pend.',
                                    bg: sigo.surfaceBase,
                                    fg: sigo.inkSecondary,
                                    border: sigo.borderHairline,
                                  ),
                              ],
                            )
                          : Text(
                              'Abrir lotes',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sigo.actionBlue,
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: sigo.inkSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final Color border;

  const _StatusPill({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
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
            label,
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
}
