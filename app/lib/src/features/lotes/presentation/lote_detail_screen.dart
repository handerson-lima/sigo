import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common_widgets/sigo_breadcrumbs.dart';
import '../../../common_widgets/sigo_empty_state.dart';
import '../../../common_widgets/sigo_error_state.dart';
import '../../../common_widgets/sigo_layout.dart';
import '../../../design_system/sigo_theme.dart';
import '../../etapas/data/etapa_repository.dart';
import '../../etapas/domain/etapa.dart';
import '../../obras/presentation/current_permissions_provider.dart';
import '../data/lote_repository.dart';
import '../domain/lote.dart';
import 'atribuir_lotacao_lote_sheet.dart';
import 'lote_mass_generator_section.dart';

class LoteDetailScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final String loteamentoId;
  final String quadraId;
  final String loteId;

  const LoteDetailScreen({
    super.key,
    required this.construtoraId,
    required this.loteamentoId,
    required this.quadraId,
    required this.loteId,
  });

  @override
  ConsumerState<LoteDetailScreen> createState() => _LoteDetailScreenState();
}

class _LoteDetailScreenState extends ConsumerState<LoteDetailScreen> {
  final Set<String> _busyEtapaIds = <String>{};
  final Map<String, double> _sliderDrafts = <String, double>{};
  final Set<String> _removingVinculos = <String>{};

  String get _baseLoteRoute =>
      '/construtoras/${widget.construtoraId}/loteamentos/${widget.loteamentoId}/quadras/${widget.quadraId}/lotes/${widget.loteId}';

  List<Etapa> _resolveFiveEtapas(Lote lote, List<Etapa> loaded) {
    final byTipo = <EtapaTipo, Etapa>{};
    for (final etapa in loaded) {
      final tipo = etapa.tipo;
      if (tipo != null) {
        byTipo[tipo] = etapa;
      }
    }

    return EtapaTipo.values.map((tipo) {
      final existing = byTipo[tipo];
      if (existing != null) return existing;
      final status = lote.statusEtapasMap[tipo.name] ?? EtapaStatus.pendente;
      final percentual = switch (status) {
        EtapaStatus.concluida => 100,
        EtapaStatus.emAndamento => 50,
        _ => 0,
      };
      return Etapa(
        id: '${lote.id}_${tipo.name}',
        construtoraId: lote.construtoraId,
        loteamentoId: lote.loteamentoId,
        quadraId: lote.quadraId,
        loteId: lote.id,
        nome: tipo.label,
        ordem: tipo.ordem,
        status: status,
        percentual: percentual,
        createdAt: lote.createdAt,
        updatedAt: lote.updatedAt,
      );
    }).toList();
  }

  String _resolveEtapaLabel(String? etapaId, List<Etapa> etapas) {
    if (etapaId == null || etapaId.trim().isEmpty) {
      return 'Lote inteiro';
    }
    for (final etapa in etapas) {
      if (etapa.id == etapaId) return etapa.nome;
    }
    final tipo = resolveEtapaTipo(id: etapaId);
    return tipo?.label ?? 'Etapa';
  }

  Future<void> _updateEtapaProgresso({
    required Lote lote,
    required Etapa etapa,
    required String status,
    int? percentual,
  }) async {
    if (_busyEtapaIds.contains(etapa.id)) return;
    setState(() => _busyEtapaIds.add(etapa.id));

    try {
      await ref
          .read(etapaRepositoryProvider)
          .updateEtapaProgresso(
            loteId: lote.id,
            etapaId: etapa.id,
            status: status,
            percentual: percentual,
            construtoraId: lote.construtoraId,
            loteamentoId: lote.loteamentoId,
            quadraId: lote.quadraId,
            tipo: etapa.tipo,
          );
      if (mounted) {
        setState(() => _sliderDrafts.remove(etapa.id));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar etapa "${etapa.nome}": $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyEtapaIds.remove(etapa.id));
      }
    }
  }

  Future<void> _removerEquipe({
    required Lote lote,
    required String equipeId,
    required String equipeNome,
    String? etapaId,
  }) async {
    final key = 'eq:$equipeId:${etapaId ?? ''}';
    if (_removingVinculos.contains(key)) return;
    setState(() => _removingVinculos.add(key));

    try {
      await ref
          .read(loteRepositoryProvider)
          .removerEquipe(
            loteId: lote.id,
            equipeId: equipeId,
            etapaId: etapaId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vínculo da equipe "$equipeNome" removido.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao remover equipe: $e')));
    } finally {
      if (mounted) {
        setState(() => _removingVinculos.remove(key));
      }
    }
  }

  Future<void> _removerFuncionario({
    required Lote lote,
    required String funcionarioId,
    required String funcionarioNome,
    String? etapaId,
  }) async {
    final key = 'fn:$funcionarioId:${etapaId ?? ''}';
    if (_removingVinculos.contains(key)) return;
    setState(() => _removingVinculos.add(key));

    try {
      await ref
          .read(loteRepositoryProvider)
          .removerFuncionario(
            loteId: lote.id,
            funcionarioId: funcionarioId,
            etapaId: etapaId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vínculo de "$funcionarioNome" removido.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao remover funcionário: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _removingVinculos.remove(key));
      }
    }
  }

  Future<void> _openEditLoteDialog(Lote lote) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _EditLoteDialog(lote: lote),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sigo =
        Theme.of(context).extension<SigoThemeExtension>() ?? SigoTheme.extension;
    final loteAsync = ref.watch(watchLoteProvider(widget.loteId));
    final etapasParams = (
      construtoraId: widget.construtoraId,
      loteamentoId: widget.loteamentoId,
      quadraId: widget.quadraId,
      loteId: widget.loteId,
    );
    final etapasAsync = ref.watch(watchEtapasProvider(etapasParams));

    final isAdmin = ref.watch(
      isLoteamentoAdminProvider((
        construtoraId: widget.construtoraId,
        loteamentoId: widget.loteamentoId,
      )),
    );

    final title = loteAsync.value?.name ?? 'Detalhes do Lote';

    return SigoLayout(
      title: title,
      activeRoute: '$_baseLoteRoute/detalhes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SigoBreadcrumbs(),
          Expanded(
            child: loteAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => SigoErrorState(
                message: 'Não foi possível carregar os detalhes do lote.',
                cause: err,
                onRetry: () => ref.invalidate(watchLoteProvider(widget.loteId)),
              ),
              data: (lote) {
                if (lote == null) {
                  return SigoEmptyState(
                    message: 'Lote não encontrado',
                    icon: Icons.crop_landscape_outlined,
                    action: OutlinedButton.icon(
                      onPressed: () => context.go(
                        '/construtoras/${widget.construtoraId}/loteamentos/${widget.loteamentoId}/quadras/${widget.quadraId}/lotes',
                      ),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Voltar para Lotes'),
                    ),
                  );
                }

                final loadedEtapas = etapasAsync.value ?? const <Etapa>[];
                final etapas = _resolveFiveEtapas(lote, loadedEtapas);

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeaderCard(context, sigo, lote, isAdmin),
                          const SizedBox(height: 16),
                          _buildFichaTecnicaCard(context, sigo, lote),
                          const SizedBox(height: 16),
                          _buildAlocacoesCard(
                            context,
                            sigo,
                            lote,
                            etapas,
                            isAdmin,
                          ),
                          const SizedBox(height: 16),
                          _buildChecklistEtapasCard(
                            context,
                            sigo,
                            lote,
                            etapas,
                            isAdmin,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    SigoThemeExtension sigo,
    Lote lote,
    bool isAdmin,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final progress = lote.progressoPercentual.clamp(0, 100);
    final total = lote.etapasTotalCount > 0 ? lote.etapasTotalCount : 5;
    final concluidas = lote.etapasConcluidasCount.clamp(0, total);
    final isComplete = progress >= 100 || concluidas >= total;
    final logradouro = lote.logradouro?.trim();

    return Container(
      decoration: BoxDecoration(
        color: sigo.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sigo.borderHairline),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lote.name,
                    style: textTheme.displaySmall?.copyWith(
                      color: sigo.inkPrimary,
                    ),
                  ),
                  if (logradouro != null && logradouro.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: sigo.inkSecondary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            logradouro,
                            style: textTheme.bodyMedium?.copyWith(
                              color: sigo.inkSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('lote_detail_ver_etapas_btn'),
                    onPressed: () => context.go('$_baseLoteRoute/etapas'),
                    icon: const Icon(Icons.view_module_outlined, size: 18),
                    label: const Text('Ver Etapas'),
                  ),
                  if (isAdmin)
                    FilledButton.icon(
                      key: const Key('lote_detail_editar_btn'),
                      onPressed: () => _openEditLoteDialog(lote),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar Lote'),
                      style: FilledButton.styleFrom(
                        backgroundColor: sigo.actionBlue,
                        foregroundColor: sigo.surfaceRaised,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Progresso Geral ($concluidas/$total etapas concluídas)',
                  style: textTheme.labelLarge?.copyWith(color: sigo.inkPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$progress%',
                style: textTheme.titleMedium?.copyWith(
                  color: isComplete ? sigo.lotCompleteInk : sigo.brandBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress / 100.0,
              minHeight: 10,
              backgroundColor: sigo.borderHairline,
              valueColor: AlwaysStoppedAnimation<Color>(
                isComplete ? sigo.lotCompleteInk : sigo.brandBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFichaTecnicaCard(
    BuildContext context,
    SigoThemeExtension sigo,
    Lote lote,
  ) {
    final textTheme = Theme.of(context).textTheme;

    final medidasPrincipais = <_FichaField>[
      if (lote.frenteM != null)
        _FichaField('Frente', '${formatDecimalPtBr(lote.frenteM!)} m'),
      if (lote.profundidadeM != null)
        _FichaField(
          'Profundidade',
          '${formatDecimalPtBr(lote.profundidadeM!)} m',
        ),
      if (lote.areaTerrenoM2 != null)
        _FichaField(
          'Área do Terreno',
          '${formatDecimalPtBr(lote.areaTerrenoM2!)} m²',
        ),
      if (lote.areaConstruidaM2 != null)
        _FichaField(
          'Área Construída',
          '${formatDecimalPtBr(lote.areaConstruidaM2!)} m²',
        ),
    ];

    final indicesUrbanisticos = <_FichaField>[
      if (lote.taxaOcupacaoPercent != null)
        _FichaField(
          'Taxa de Ocupação',
          '${formatDecimalPtBr(lote.taxaOcupacaoPercent!)}%',
        ),
      if (lote.coeficienteAproveitamento != null)
        _FichaField(
          'Coef. de Aproveitamento',
          formatDecimalPtBr(lote.coeficienteAproveitamento!),
        ),
      if (lote.areaPermeavelM2 != null)
        _FichaField(
          'Área Permeável',
          '${formatDecimalPtBr(lote.areaPermeavelM2!)} m²',
        ),
      if (lote.taxaPermeabilidadePercent != null)
        _FichaField(
          'Taxa de Permeabilidade',
          '${formatDecimalPtBr(lote.taxaPermeabilidadePercent!)}%',
        ),
      if (lote.areaImpermeavelM2 != null)
        _FichaField(
          'Área Impermeável',
          '${formatDecimalPtBr(lote.areaImpermeavelM2!)} m²',
        ),
    ];

    final recuos = <_FichaField>[
      if (lote.recuoFrontalM != null)
        _FichaField(
          'Recuo Frontal',
          '${formatDecimalPtBr(lote.recuoFrontalM!)} m',
        ),
      if (lote.recuoFundoM != null)
        _FichaField(
          'Recuo de Fundo',
          '${formatDecimalPtBr(lote.recuoFundoM!)} m',
        ),
      if (lote.recuoLateralEsquerdoM != null)
        _FichaField(
          'Recuo Lateral Esq.',
          '${formatDecimalPtBr(lote.recuoLateralEsquerdoM!)} m',
        ),
      if (lote.recuoLateralDireitoM != null)
        _FichaField(
          'Recuo Lateral Dir.',
          '${formatDecimalPtBr(lote.recuoLateralDireitoM!)} m',
        ),
    ];

    final carimbo = <_FichaField>[
      if (lote.proprietarioNome != null &&
          lote.proprietarioNome!.trim().isNotEmpty)
        _FichaField('Proprietário', lote.proprietarioNome!.trim()),
      if (lote.proprietarioDocumento != null &&
          lote.proprietarioDocumento!.trim().isNotEmpty)
        _FichaField('CPF/CNPJ', lote.proprietarioDocumento!.trim()),
      if (lote.responsavelTecnicoNome != null &&
          lote.responsavelTecnicoNome!.trim().isNotEmpty)
        _FichaField(
          'Responsável Técnico',
          lote.responsavelTecnicoNome!.trim(),
        ),
      if (lote.responsavelTecnicoRegistro != null &&
          lote.responsavelTecnicoRegistro!.trim().isNotEmpty)
        _FichaField('CREA/CAU', lote.responsavelTecnicoRegistro!.trim()),
      if (lote.dataProjeto != null && lote.dataProjeto!.trim().isNotEmpty)
        _FichaField('Data do Projeto', lote.dataProjeto!.trim()),
    ];

    return Container(
      decoration: BoxDecoration(
        color: sigo.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sigo.borderHairline),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.architecture_outlined, color: sigo.actionBlue),
              const SizedBox(width: 8),
              Text(
                'Ficha Técnica',
                style: textTheme.titleLarge?.copyWith(color: sigo.inkPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Medidas Principais',
            style: textTheme.labelLarge?.copyWith(color: sigo.inkSecondary),
          ),
          const SizedBox(height: 8),
          if (medidasPrincipais.isEmpty)
            Text(
              'Nenhuma medida cadastrada.',
              style: textTheme.bodyMedium?.copyWith(color: sigo.inkSecondary),
            )
          else
            _buildFichaGrid(sigo, medidasPrincipais),
          if (indicesUrbanisticos.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Índices Urbanísticos',
              style: textTheme.labelLarge?.copyWith(color: sigo.inkSecondary),
            ),
            const SizedBox(height: 8),
            _buildFichaGrid(sigo, indicesUrbanisticos),
          ],
          if (recuos.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Recuos',
              style: textTheme.labelLarge?.copyWith(color: sigo.inkSecondary),
            ),
            const SizedBox(height: 8),
            _buildFichaGrid(sigo, recuos),
          ],
          if (carimbo.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Carimbo e Responsáveis',
              style: textTheme.labelLarge?.copyWith(color: sigo.inkSecondary),
            ),
            const SizedBox(height: 8),
            _buildFichaGrid(sigo, carimbo),
          ],
        ],
      ),
    );
  }

  Widget _buildFichaGrid(SigoThemeExtension sigo, List<_FichaField> fields) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: fields
          .map(
            (field) => Container(
              constraints: const BoxConstraints(minWidth: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: sigo.surfaceBase,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: sigo.borderHairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    field.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: sigo.inkSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    field.value,
                    style: TextStyle(
                      fontSize: 15,
                      color: sigo.inkPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAlocacoesCard(
    BuildContext context,
    SigoThemeExtension sigo,
    Lote lote,
    List<Etapa> etapas,
    bool isAdmin,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final hasAny =
        lote.equipesVinculadas.isNotEmpty ||
        lote.funcionariosVinculados.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: sigo.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sigo.borderHairline),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.groups_outlined, color: sigo.actionBlue),
                  const SizedBox(width: 8),
                  Text(
                    'Equipes e Funcionários Vinculados',
                    style: textTheme.titleLarge?.copyWith(
                      color: sigo.inkPrimary,
                    ),
                  ),
                ],
              ),
              if (isAdmin)
                FilledButton.icon(
                  key: const Key('lote_detail_atribuir_btn'),
                  onPressed: () => showAtribuirLotacaoLoteSheet(
                    context: context,
                    construtoraId: widget.construtoraId,
                    lote: lote,
                    etapas: etapas,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Atribuir Equipe ou Funcionário'),
                  style: FilledButton.styleFrom(
                    backgroundColor: sigo.actionBlue,
                    foregroundColor: sigo.surfaceRaised,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasAny)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sigo.surfaceBase,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: sigo.borderHairline),
              ),
              child: Text(
                'Nenhuma equipe ou funcionário vinculado a este lote.',
                style: textTheme.bodyMedium?.copyWith(color: sigo.inkSecondary),
              ),
            )
          else
            Column(
              children: [
                ...lote.equipesVinculadas.map((entry) {
                  final id = entry['id']?.toString().trim() ?? '';
                  final name = entry['name']?.toString().trim() ?? 'Equipe';
                  final leader = entry['leaderName']?.toString().trim();
                  final rawEtapaId = entry['etapaId']?.toString().trim();
                  final etapaId = (rawEtapaId == null || rawEtapaId.isEmpty)
                      ? null
                      : rawEtapaId;
                  final etapaLabel = _resolveEtapaLabel(etapaId, etapas);
                  final removingKey = 'eq:$id:${etapaId ?? ''}';
                  final isRemoving = _removingVinculos.contains(removingKey);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: sigo.surfaceBase,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sigo.borderHairline),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: sigo.lotCompleteBg,
                          foregroundColor: sigo.lotCompleteInk,
                          child: const Icon(Icons.groups_outlined, size: 20),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: sigo.inkPrimary,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (leader != null && leader.isNotEmpty)
                              'Líder: $leader',
                            etapaLabel,
                          ].join(' • '),
                          style: TextStyle(color: sigo.inkSecondary),
                        ),
                        trailing: isAdmin && id.isNotEmpty
                            ? IconButton(
                                key: Key(
                                  'remover_equipe_${id}_${etapaId ?? 'geral'}',
                                ),
                                tooltip: 'Remover equipe',
                                onPressed: isRemoving
                                    ? null
                                    : () => _removerEquipe(
                                        lote: lote,
                                        equipeId: id,
                                        equipeNome: name,
                                        etapaId: etapaId,
                                      ),
                                icon: isRemoving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        Icons.delete_outline,
                                        color: sigo.danger,
                                      ),
                              )
                            : null,
                      ),
                    ),
                  );
                }),
                ...lote.funcionariosVinculados.map((entry) {
                  final id = entry['id']?.toString().trim() ?? '';
                  final name =
                      entry['name']?.toString().trim() ?? 'Funcionário';
                  final role = entry['role']?.toString().trim();
                  final rawEtapaId = entry['etapaId']?.toString().trim();
                  final etapaId = (rawEtapaId == null || rawEtapaId.isEmpty)
                      ? null
                      : rawEtapaId;
                  final etapaLabel = _resolveEtapaLabel(etapaId, etapas);
                  final removingKey = 'fn:$id:${etapaId ?? ''}';
                  final isRemoving = _removingVinculos.contains(removingKey);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: sigo.surfaceBase,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sigo.borderHairline),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: sigo.lotOnTimeBg,
                          foregroundColor: sigo.lotOnTimeInk,
                          child: const Icon(Icons.person_outline, size: 20),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: sigo.inkPrimary,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (role != null && role.isNotEmpty) role,
                            etapaLabel,
                          ].join(' • '),
                          style: TextStyle(color: sigo.inkSecondary),
                        ),
                        trailing: isAdmin && id.isNotEmpty
                            ? IconButton(
                                key: Key(
                                  'remover_funcionario_${id}_${etapaId ?? 'geral'}',
                                ),
                                tooltip: 'Remover funcionário',
                                onPressed: isRemoving
                                    ? null
                                    : () => _removerFuncionario(
                                        lote: lote,
                                        funcionarioId: id,
                                        funcionarioNome: name,
                                        etapaId: etapaId,
                                      ),
                                icon: isRemoving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        Icons.delete_outline,
                                        color: sigo.danger,
                                      ),
                              )
                            : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildChecklistEtapasCard(
    BuildContext context,
    SigoThemeExtension sigo,
    Lote lote,
    List<Etapa> etapas,
    bool isAdmin,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: sigo.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sigo.borderHairline),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, color: sigo.actionBlue),
              const SizedBox(width: 8),
              Text(
                'Checklist das 5 Etapas',
                style: textTheme.titleLarge?.copyWith(color: sigo.inkPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...etapas.map(
            (etapa) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildEtapaTile(
                context,
                sigo,
                lote,
                etapa,
                etapas,
                isAdmin,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEtapaTile(
    BuildContext context,
    SigoThemeExtension sigo,
    Lote lote,
    Etapa etapa,
    List<Etapa> allEtapas,
    bool isAdmin,
  ) {
    final isBusy = _busyEtapaIds.contains(etapa.id);
    final canEdit = isAdmin && !isBusy;
    final status = etapa.status;
    final sliderValue =
        _sliderDrafts[etapa.id] ?? etapa.percentual.toDouble().clamp(0, 100);

    final (Color badgeBg, Color badgeFg, String statusText) = switch (status) {
      EtapaStatus.concluida => (
        sigo.lotCompleteBg,
        sigo.lotCompleteInk,
        'Concluída',
      ),
      EtapaStatus.emAndamento => (
        sigo.lotOnTimeBg,
        sigo.lotOnTimeInk,
        'Em andamento',
      ),
      _ => (sigo.surfaceRaised, sigo.inkSecondary, 'Pendente'),
    };

    final vinculosEtapa = <String>[
      if (etapa.equipeNome != null && etapa.equipeNome!.trim().isNotEmpty)
        'Equipe: ${etapa.equipeNome!.trim()}',
      if (etapa.funcionarioNome != null &&
          etapa.funcionarioNome!.trim().isNotEmpty)
        'Funcionário: ${etapa.funcionarioNome!.trim()}',
    ];

    return Container(
      key: Key('etapa_item_${etapa.tipo?.name ?? etapa.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: sigo.surfaceBase,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: status == EtapaStatus.concluida
              ? sigo.lotCompleteInk.withValues(alpha: 0.3)
              : status == EtapaStatus.emAndamento
              ? sigo.brandGold
              : sigo.borderHairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${etapa.ordem}. ${etapa.nome}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: sigo.inkPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                  border: status == EtapaStatus.pendente
                      ? Border.all(color: sigo.borderHairline)
                      : null,
                ),
                child: Text(
                  '$statusText • ${sliderValue.round()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: badgeFg,
                  ),
                ),
              ),
              if (isBusy) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildStatusChoiceChip(
                key: Key('etapa_status_${etapa.tipo?.name ?? etapa.id}_pendente'),
                label: 'Pendente',
                selected: status == EtapaStatus.pendente,
                enabled: canEdit,
                selectedColor: sigo.surfaceRaised,
                selectedTextColor: sigo.inkPrimary,
                onSelected: () => _updateEtapaProgresso(
                  lote: lote,
                  etapa: etapa,
                  status: EtapaStatus.pendente,
                  percentual: 0,
                ),
              ),
              _buildStatusChoiceChip(
                key: Key(
                  'etapa_status_${etapa.tipo?.name ?? etapa.id}_em_andamento',
                ),
                label: 'Em andamento',
                selected: status == EtapaStatus.emAndamento,
                enabled: canEdit,
                selectedColor: sigo.lotOnTimeBg,
                selectedTextColor: sigo.lotOnTimeInk,
                onSelected: () => _updateEtapaProgresso(
                  lote: lote,
                  etapa: etapa,
                  status: EtapaStatus.emAndamento,
                  percentual: (etapa.percentual > 0 && etapa.percentual < 100)
                      ? etapa.percentual
                      : 50,
                ),
              ),
              _buildStatusChoiceChip(
                key: Key(
                  'etapa_status_${etapa.tipo?.name ?? etapa.id}_concluida',
                ),
                label: 'Concluída',
                selected: status == EtapaStatus.concluida,
                enabled: canEdit,
                selectedColor: sigo.lotCompleteBg,
                selectedTextColor: sigo.lotCompleteInk,
                onSelected: () => _updateEtapaProgresso(
                  lote: lote,
                  etapa: etapa,
                  status: EtapaStatus.concluida,
                  percentual: 100,
                ),
              ),
            ],
          ),
          if (status == EtapaStatus.emAndamento) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Progresso:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sigo.inkSecondary,
                  ),
                ),
                Expanded(
                  child: Slider(
                    key: Key('etapa_slider_${etapa.tipo?.name ?? etapa.id}'),
                    value: sliderValue,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${sliderValue.round()}%',
                    activeColor: sigo.brandBlue,
                    onChanged: !canEdit
                        ? null
                        : (value) {
                            setState(() => _sliderDrafts[etapa.id] = value);
                          },
                    onChangeEnd: !canEdit
                        ? null
                        : (value) {
                            final rounded = value.round().clamp(0, 100);
                            final nextStatus = rounded == 100
                                ? EtapaStatus.concluida
                                : rounded == 0
                                ? EtapaStatus.pendente
                                : EtapaStatus.emAndamento;
                            _updateEtapaProgresso(
                              lote: lote,
                              etapa: etapa,
                              status: nextStatus,
                              percentual: rounded,
                            );
                          },
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [25, 50, 75]
                  .map(
                    (pct) => ActionChip(
                      key: Key(
                        'etapa_pct_${etapa.tipo?.name ?? etapa.id}_$pct',
                      ),
                      label: Text('$pct%'),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        color: sigo.inkPrimary,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: !canEdit
                          ? null
                          : () => _updateEtapaProgresso(
                              lote: lote,
                              etapa: etapa,
                              status: EtapaStatus.emAndamento,
                              percentual: pct,
                            ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  vinculosEtapa.isEmpty
                      ? 'Sem equipe ou funcionário vinculado nesta etapa'
                      : vinculosEtapa.join(' • '),
                  style: TextStyle(
                    fontSize: 12,
                    color: vinculosEtapa.isEmpty
                        ? sigo.inkSecondary
                        : sigo.inkPrimary,
                    fontWeight: vinculosEtapa.isEmpty
                        ? FontWeight.w400
                        : FontWeight.w500,
                  ),
                ),
              ),
              if (isAdmin)
                TextButton.icon(
                  key: Key('etapa_vincular_${etapa.tipo?.name ?? etapa.id}'),
                  onPressed: () => showAtribuirLotacaoLoteSheet(
                    context: context,
                    construtoraId: widget.construtoraId,
                    lote: lote,
                    initialEtapaId: etapa.id,
                    etapas: allEtapas,
                  ),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                  label: const Text('Vincular'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChoiceChip({
    required Key key,
    required String label,
    required bool selected,
    required bool enabled,
    required Color selectedColor,
    required Color selectedTextColor,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      key: key,
      label: Text(label),
      selected: selected,
      selectedColor: selectedColor,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? selectedTextColor : null,
      ),
      onSelected: enabled && !selected ? (_) => onSelected() : null,
    );
  }
}

class _FichaField {
  final String label;
  final String value;

  const _FichaField(this.label, this.value);
}

class _EditLoteDialog extends ConsumerStatefulWidget {
  final Lote lote;

  const _EditLoteDialog({required this.lote});

  @override
  ConsumerState<_EditLoteDialog> createState() => _EditLoteDialogState();
}

class _EditLoteDialogState extends ConsumerState<_EditLoteDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _logradouroController;
  late final TextEditingController _frenteController;
  late final TextEditingController _profundidadeController;
  late final TextEditingController _areaTerrenoController;
  late final TextEditingController _areaConstruidaController;
  late final TextEditingController _taxaOcupacaoController;
  late final TextEditingController _coefAproveitamentoController;
  late final TextEditingController _areaPermeavelController;
  late final TextEditingController _taxaPermeabilidadeController;
  late final TextEditingController _areaImpermeavelController;
  late final TextEditingController _recuoFrontalController;
  late final TextEditingController _recuoFundoController;
  late final TextEditingController _recuoLateralEsqController;
  late final TextEditingController _recuoLateralDirController;
  late final TextEditingController _proprietarioNomeController;
  late final TextEditingController _proprietarioDocController;
  late final TextEditingController _respTecnicoNomeController;
  late final TextEditingController _respTecnicoRegController;
  late final TextEditingController _dataProjetoController;

  late final DimensionalAreaCoordinator _areaCoordinator;
  bool _isSaving = false;

  String _fmt(double? value) => value == null ? '' : formatDecimalPtBr(value);

  @override
  void initState() {
    super.initState();
    final l = widget.lote;
    _nameController = TextEditingController(text: l.name);
    _logradouroController = TextEditingController(text: l.logradouro ?? '');
    _frenteController = TextEditingController(text: _fmt(l.frenteM));
    _profundidadeController = TextEditingController(
      text: _fmt(l.profundidadeM),
    );
    _areaTerrenoController = TextEditingController(text: _fmt(l.areaTerrenoM2));
    _areaConstruidaController = TextEditingController(
      text: _fmt(l.areaConstruidaM2),
    );
    _taxaOcupacaoController = TextEditingController(
      text: _fmt(l.taxaOcupacaoPercent),
    );
    _coefAproveitamentoController = TextEditingController(
      text: _fmt(l.coeficienteAproveitamento),
    );
    _areaPermeavelController = TextEditingController(
      text: _fmt(l.areaPermeavelM2),
    );
    _taxaPermeabilidadeController = TextEditingController(
      text: _fmt(l.taxaPermeabilidadePercent),
    );
    _areaImpermeavelController = TextEditingController(
      text: _fmt(l.areaImpermeavelM2),
    );
    _recuoFrontalController = TextEditingController(
      text: _fmt(l.recuoFrontalM),
    );
    _recuoFundoController = TextEditingController(text: _fmt(l.recuoFundoM));
    _recuoLateralEsqController = TextEditingController(
      text: _fmt(l.recuoLateralEsquerdoM),
    );
    _recuoLateralDirController = TextEditingController(
      text: _fmt(l.recuoLateralDireitoM),
    );
    _proprietarioNomeController = TextEditingController(
      text: l.proprietarioNome ?? '',
    );
    _proprietarioDocController = TextEditingController(
      text: l.proprietarioDocumento ?? '',
    );
    _respTecnicoNomeController = TextEditingController(
      text: l.responsavelTecnicoNome ?? '',
    );
    _respTecnicoRegController = TextEditingController(
      text: l.responsavelTecnicoRegistro ?? '',
    );
    _dataProjetoController = TextEditingController(text: l.dataProjeto ?? '');

    final expectedAuto = Lote.calcularAreaTerreno(l.frenteM, l.profundidadeM);
    final isManualArea =
        l.areaTerrenoM2 != null &&
        (expectedAuto == null ||
            (l.areaTerrenoM2! - expectedAuto).abs() > 1e-6);
    _areaCoordinator = DimensionalAreaCoordinator(
      areaEditadaManualmente: isManualArea,
    );
  }

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _logradouroController,
      _frenteController,
      _profundidadeController,
      _areaTerrenoController,
      _areaConstruidaController,
      _taxaOcupacaoController,
      _coefAproveitamentoController,
      _areaPermeavelController,
      _taxaPermeabilidadeController,
      _areaImpermeavelController,
      _recuoFrontalController,
      _recuoFundoController,
      _recuoLateralEsqController,
      _recuoLateralDirController,
      _proprietarioNomeController,
      _proprietarioDocController,
      _respTecnicoNomeController,
      _respTecnicoRegController,
      _dataProjetoController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncArea() {
    _areaCoordinator.onFrenteOrProfundidadeChanged(
      frenteController: _frenteController,
      profundidadeController: _profundidadeController,
      areaTerrenoController: _areaTerrenoController,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      final frente = parseDecimalPtBr(_frenteController.text);
      final profundidade = parseDecimalPtBr(_profundidadeController.text);
      final areaTerreno =
          parseDecimalPtBr(_areaTerrenoController.text) ??
          Lote.calcularAreaTerreno(frente, profundidade);
      final areaConstruida = parseDecimalPtBr(_areaConstruidaController.text);
      final logradouro = nullIfBlankText(_logradouroController.text);
      final taxaOcupacao = parseDecimalPtBr(_taxaOcupacaoController.text);
      final coefAprov = parseDecimalPtBr(_coefAproveitamentoController.text);
      final areaPerm = parseDecimalPtBr(_areaPermeavelController.text);
      final taxaPerm = parseDecimalPtBr(_taxaPermeabilidadeController.text);
      final areaImperm = parseDecimalPtBr(_areaImpermeavelController.text);
      final recuoFrontal = parseDecimalPtBr(_recuoFrontalController.text);
      final recuoFundo = parseDecimalPtBr(_recuoFundoController.text);
      final recuoLatEsq = parseDecimalPtBr(_recuoLateralEsqController.text);
      final recuoLatDir = parseDecimalPtBr(_recuoLateralDirController.text);
      final propNome = nullIfBlankText(_proprietarioNomeController.text);
      final propDoc = nullIfBlankText(_proprietarioDocController.text);
      final rtNome = nullIfBlankText(_respTecnicoNomeController.text);
      final rtReg = nullIfBlankText(_respTecnicoRegController.text);
      final dataProjeto = nullIfBlankText(_dataProjetoController.text);

      final updated = widget.lote.copyWith(
        name: _nameController.text.trim(),
        logradouro: logradouro,
        clearLogradouro: logradouro == null,
        frenteM: frente,
        clearFrenteM: frente == null,
        profundidadeM: profundidade,
        clearProfundidadeM: profundidade == null,
        areaTerrenoM2: areaTerreno,
        clearAreaTerrenoM2: areaTerreno == null,
        areaConstruidaM2: areaConstruida,
        clearAreaConstruidaM2: areaConstruida == null,
        taxaOcupacaoPercent: taxaOcupacao,
        clearTaxaOcupacaoPercent: taxaOcupacao == null,
        coeficienteAproveitamento: coefAprov,
        clearCoeficienteAproveitamento: coefAprov == null,
        areaPermeavelM2: areaPerm,
        clearAreaPermeavelM2: areaPerm == null,
        taxaPermeabilidadePercent: taxaPerm,
        clearTaxaPermeabilidadePercent: taxaPerm == null,
        areaImpermeavelM2: areaImperm,
        clearAreaImpermeavelM2: areaImperm == null,
        recuoFrontalM: recuoFrontal,
        clearRecuoFrontalM: recuoFrontal == null,
        recuoFundoM: recuoFundo,
        clearRecuoFundoM: recuoFundo == null,
        recuoLateralEsquerdoM: recuoLatEsq,
        clearRecuoLateralEsquerdoM: recuoLatEsq == null,
        recuoLateralDireitoM: recuoLatDir,
        clearRecuoLateralDireitoM: recuoLatDir == null,
        proprietarioNome: propNome,
        clearProprietarioNome: propNome == null,
        proprietarioDocumento: propDoc,
        clearProprietarioDocumento: propDoc == null,
        responsavelTecnicoNome: rtNome,
        clearResponsavelTecnicoNome: rtNome == null,
        responsavelTecnicoRegistro: rtReg,
        clearResponsavelTecnicoRegistro: rtReg == null,
        dataProjeto: dataProjeto,
        clearDataProjeto: dataProjeto == null,
      );

      await ref.read(loteRepositoryProvider).updateLote(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados do lote atualizados com sucesso.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao atualizar lote: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Lote'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Lote *',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Campo obrigatório'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _logradouroController,
                  decoration: const InputDecoration(labelText: 'Logradouro'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _frenteController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Frente (m)',
                        ),
                        onChanged: (_) => _syncArea(),
                        validator: (v) =>
                            validateOptionalDecimalPtBr(v, requirePositive: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _profundidadeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Profundidade (m)',
                        ),
                        onChanged: (_) => _syncArea(),
                        validator: (v) =>
                            validateOptionalDecimalPtBr(v, requirePositive: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _areaTerrenoController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Área do Terreno (m²)',
                        ),
                        onChanged: _areaCoordinator.onAreaTerrenoChanged,
                        validator: (v) =>
                            validateOptionalDecimalPtBr(v, requirePositive: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _areaConstruidaController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Área Construída (m²)',
                        ),
                        validator: (v) => validateOptionalDecimalPtBr(v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Índices Urbanísticos, Recuos e Carimbo'),
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _taxaOcupacaoController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Taxa de Ocupação (%)',
                            ),
                            validator: (v) =>
                                validateOptionalDecimalPtBr(v, maxValue: 100),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _coefAproveitamentoController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Coef. Aproveitamento',
                            ),
                            validator: validateOptionalDecimalPtBr,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _areaPermeavelController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Área Permeável (m²)',
                            ),
                            validator: validateOptionalDecimalPtBr,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _taxaPermeabilidadeController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Taxa Permeabilidade (%)',
                            ),
                            validator: (v) =>
                                validateOptionalDecimalPtBr(v, maxValue: 100),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _areaImpermeavelController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Área Impermeável (m²)',
                      ),
                      validator: validateOptionalDecimalPtBr,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _recuoFrontalController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Recuo Frontal (m)',
                            ),
                            validator: validateOptionalDecimalPtBr,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _recuoFundoController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Recuo de Fundo (m)',
                            ),
                            validator: validateOptionalDecimalPtBr,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _recuoLateralEsqController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Recuo Lat. Esq. (m)',
                            ),
                            validator: validateOptionalDecimalPtBr,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _recuoLateralDirController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Recuo Lat. Dir. (m)',
                            ),
                            validator: validateOptionalDecimalPtBr,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _proprietarioNomeController,
                      decoration: const InputDecoration(
                        labelText: 'Proprietário',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _proprietarioDocController,
                      decoration: const InputDecoration(labelText: 'CPF/CNPJ'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _respTecnicoNomeController,
                      decoration: const InputDecoration(
                        labelText: 'Responsável Técnico',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _respTecnicoRegController,
                            decoration: const InputDecoration(
                              labelText: 'CREA/CAU',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _dataProjetoController,
                            decoration: const InputDecoration(
                              labelText: 'Data do Projeto',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
