import 'package:flutter/material.dart';

import '../../../design_system/sigo_theme.dart';
import '../../lotes/presentation/lote_mass_generator_section.dart';
import '../domain/loteamento.dart';
import 'loteamento_summary_provider.dart';

/// Formata a localização de um [Loteamento] no padrão `bairro • cidade - UF`.
String? formatLoteamentoLocalizacao(Loteamento item) {
  final bairro = nullIfBlankText(item.bairro);
  final cidade = nullIfBlankText(item.cidade);
  final uf = nullIfBlankText(item.uf)?.toUpperCase();

  final cidadeUf = switch ((cidade, uf)) {
    (final c?, final u?) => '$c - $u',
    (final c?, null) => c,
    (null, final u?) => u,
    (null, null) => null,
  };

  return switch ((bairro, cidadeUf)) {
    (final b?, final cu?) => '$b • $cu',
    (final b?, null) => b,
    (null, final cu?) => cu,
    (null, null) => null,
  };
}

/// Card visual executivo de um [Loteamento] na grade/lista da construtora.
class LoteamentoSummaryCard extends StatelessWidget {
  final Loteamento loteamento;
  final LoteamentoSummary? summary;
  final VoidCallback? onTap;

  const LoteamentoSummaryCard({
    super.key,
    required this.loteamento,
    this.summary,
    this.onTap,
  });

  static String _pluralize(int count, String singular, String plural) =>
      '$count ${count == 1 ? singular : plural}';

  String _buildDistributionText(LoteamentoSummary metrics) {
    if (metrics.totalLotes <= 0) return 'Ver quadras';

    final parts = <String>[
      if (metrics.lotesConcluidos > 0)
        _pluralize(metrics.lotesConcluidos, 'concluído', 'concluídos'),
      if (metrics.lotesEmAndamento > 0)
        '${metrics.lotesEmAndamento} em andamento',
      if (metrics.lotesPendentes > 0)
        _pluralize(metrics.lotesPendentes, 'pendente', 'pendentes'),
    ];
    if (parts.isEmpty) return 'Ver quadras';
    return parts.join(' • ');
  }

  String _buildSemanticsLabel(
    String? localizacao,
    LoteamentoSummary? metrics,
  ) {
    final buffer = StringBuffer('Loteamento ${loteamento.name}');
    buffer.write(', ${localizacao ?? 'Localização não informada'}');
    if (metrics != null) {
      final progress = metrics.progressoMedio.clamp(0, 100);
      buffer.write(
        ', $progress% concluído, '
        '${_pluralize(metrics.totalQuadras, 'quadra', 'quadras')} e '
        '${_pluralize(metrics.totalLotes, 'lote', 'lotes')}',
      );
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final sigo =
        Theme.of(context).extension<SigoThemeExtension>() ?? SigoTheme.extension;
    final textTheme = Theme.of(context).textTheme;

    final localizacao = formatLoteamentoLocalizacao(loteamento);
    final hasLocalizacao = localizacao != null;

    final proprietario = nullIfBlankText(loteamento.proprietarioNome);
    final respNome = nullIfBlankText(loteamento.responsavelTecnicoNome);
    final respRegistro = nullIfBlankText(loteamento.responsavelTecnicoRegistro);
    final hasCarimbo = proprietario != null || respNome != null;

    final metrics = summary;
    final progress = metrics?.progressoMedio.clamp(0, 100) ?? 0;
    final isComplete = metrics?.isComplete ?? false;
    final hasAnyActivity = metrics?.hasAnyActivity ?? false;

    final statusBadgeLabel = metrics == null
        ? null
        : isComplete
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

    final footerText = metrics != null
        ? _buildDistributionText(metrics)
        : 'Ver quadras';
    final hasFooterMetrics = metrics != null && metrics.totalLotes > 0;

    return Semantics(
      container: true,
      button: onTap != null,
      excludeSemantics: true,
      label: _buildSemanticsLabel(localizacao, metrics),
      child: Material(
        color: sigo.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: sigo.surfaceBase,
          focusColor: sigo.lotCompleteBg,
          mouseCursor: onTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
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
                // Cabeçalho: Ícone identificador + Nome/Localização + Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: sigo.lotCompleteBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.map_outlined,
                        size: 22,
                        color: sigo.actionBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loteamento.name,
                            style: textTheme.titleMedium?.copyWith(
                              color: sigo.inkPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: hasLocalizacao
                                    ? sigo.inkSecondary
                                    : sigo.inkDisabled,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  localizacao ?? 'Localização não informada',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: hasLocalizacao
                                        ? sigo.inkSecondary
                                        : sigo.inkDisabled,
                                    fontStyle: hasLocalizacao
                                        ? FontStyle.normal
                                        : FontStyle.italic,
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
                    if (statusBadgeLabel != null) ...[
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
                  ],
                ),

                // Faixa de carimbo (condicional)
                if (hasCarimbo) ...[
                  const SizedBox(height: 12),
                  Container(
                    key: Key('loteamento_card_carimbo_${loteamento.id}'),
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
                      children: [
                        if (proprietario != null)
                          _CarimboItem(
                            icon: Icons.person_outline,
                            label: proprietario,
                            sigo: sigo,
                          ),
                        if (respNome != null)
                          _CarimboItem(
                            icon: Icons.engineering_outlined,
                            label: respRegistro != null
                                ? '$respNome ($respRegistro)'
                                : respNome,
                            sigo: sigo,
                          ),
                      ],
                    ),
                  ),
                ],

                // Progresso macro (quando métricas disponíveis)
                if (metrics != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Progresso Geral ('
                          '${_pluralize(metrics.totalQuadras, 'quadra', 'quadras')} • '
                          '${_pluralize(metrics.totalLotes, 'lote', 'lotes')})',
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
                          color: isComplete
                              ? sigo.lotCompleteInk
                              : sigo.brandBlue,
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
                ],

                // Rodapé: Distribuição de lotes ou CTA + chevron
                const SizedBox(height: 12),
                Divider(height: 1, color: sigo.borderHairline),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        footerText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: hasFooterMetrics
                              ? FontWeight.w500
                              : FontWeight.w600,
                          color: hasFooterMetrics
                              ? sigo.inkSecondary
                              : sigo.actionBlue,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
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

class _CarimboItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final SigoThemeExtension sigo;

  const _CarimboItem({
    required this.icon,
    required this.label,
    required this.sigo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: sigo.inkSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: sigo.inkPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
