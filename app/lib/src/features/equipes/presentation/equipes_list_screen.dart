import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common_widgets/sigo_breadcrumbs.dart';
import '../../../common_widgets/sigo_empty_state.dart';
import '../../../common_widgets/sigo_error_state.dart';
import '../../../common_widgets/sigo_layout.dart';
import '../../../core/contracts.dart';
import '../../../design_system/sigo_theme.dart';
import '../../authentication/data/user_repository.dart';
import '../../etapas/data/etapa_repository.dart';
import '../../etapas/domain/etapa.dart';
import '../../obras/presentation/current_permissions_provider.dart';
import '../../rh/data/rh_repository.dart';
import '../../rh/domain/equipe.dart';
import '../../rh/domain/funcionario.dart';
import '../../rh/presentation/equipe_form_dialog.dart';

class EquipesListScreen extends ConsumerWidget {
  final String construtoraId;
  final String loteamentoId;
  final String quadraId;
  final String loteId;
  final String etapaId;

  const EquipesListScreen({
    super.key,
    required this.construtoraId,
    required this.loteamentoId,
    required this.quadraId,
    required this.loteId,
    required this.etapaId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etapaParams = (
      construtoraId: construtoraId,
      loteamentoId: loteamentoId,
      quadraId: quadraId,
      loteId: loteId,
    );
    final etapasAsync = ref.watch(watchEtapasProvider(etapaParams));

    final dev = ref.watch(trustedDevProvider).value == true;
    final member = ref
        .watch(construtoraPermissionProvider(construtoraId))
        .value;
    final canEdit =
        dev ||
        (member?['isActive'] == true &&
            (member?['isAdmin'] == true ||
                member?['isOwner'] == true ||
                member?['role'] == 'admin' ||
                member?['role'] == 'owner'));

    return SigoLayout(
      title: 'Equipe da Etapa',
      activeRoute:
          '/construtoras/$construtoraId/loteamentos/$loteamentoId/quadras/$quadraId/lotes/$loteId/etapas/$etapaId/equipes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SigoBreadcrumbs(),
          Expanded(
            child: etapasAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => SigoErrorState(
                message: 'Não foi possível carregar os dados da etapa.',
                cause: err,
                onRetry: () => ref.invalidate(watchEtapasProvider(etapaParams)),
              ),
              data: (etapas) {
                Etapa? etapa;
                for (final item in etapas) {
                  if (item.id == etapaId) {
                    etapa = item;
                    break;
                  }
                }
                if (etapa == null) {
                  return const SigoEmptyState(
                    message: 'Etapa não encontrada',
                    icon: Icons.view_module_outlined,
                  );
                }

                return _EtapaEquipeBody(
                  construtoraId: construtoraId,
                  loteId: loteId,
                  etapa: etapa,
                  canEdit: canEdit,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EtapaEquipeBody extends ConsumerStatefulWidget {
  final String construtoraId;
  final String loteId;
  final Etapa etapa;
  final bool canEdit;

  const _EtapaEquipeBody({
    required this.construtoraId,
    required this.loteId,
    required this.etapa,
    required this.canEdit,
  });

  @override
  ConsumerState<_EtapaEquipeBody> createState() => _EtapaEquipeBodyState();
}

class _EtapaEquipeBodyState extends ConsumerState<_EtapaEquipeBody> {
  bool _isDesvinculando = false;

  Future<void> _openSelecionarEquipeSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SelecionarEquipeRhSheet(
        construtoraId: widget.construtoraId,
        loteId: widget.loteId,
        etapa: widget.etapa,
      ),
    );
  }

  Future<void> _confirmarDesvincular(String equipeNome) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desvincular equipe'),
        content: Text(
          'Deseja remover o vínculo da equipe "$equipeNome" com a etapa "${widget.etapa.nome}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('btn_confirmar_desvincular_equipe'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDesvinculando = true);
    try {
      await ref
          .read(etapaRepositoryProvider)
          .desvincularEquipe(
            etapaId: widget.etapa.id,
            construtoraId: widget.construtoraId,
            loteId: widget.loteId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Equipe desvinculada da etapa.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao desvincular equipe. Tente novamente.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDesvinculando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sigo =
        Theme.of(context).extension<SigoThemeExtension>() ?? SigoTheme.extension;
    final etapa = widget.etapa;
    final equipeId = etapa.equipeId?.trim();
    final equipeNomeFallback = etapa.equipeNome?.trim();
    final hasEquipeId = equipeId != null && equipeId.isNotEmpty;
    final hasEquipeNome =
        equipeNomeFallback != null && equipeNomeFallback.isNotEmpty;
    final hasEquipeVinculada = hasEquipeId || hasEquipeNome;

    if (!hasEquipeVinculada) {
      return SigoEmptyState(
        message: 'Nenhuma equipe vinculada a esta etapa',
        icon: Icons.groups_outlined,
        action: !widget.canEdit
            ? null
            : FilledButton.icon(
                key: const Key('btn_vincular_equipe_etapa'),
                onPressed: _openSelecionarEquipeSheet,
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Vincular Equipe do RH'),
              ),
      );
    }

    final equipesAsync = ref.watch(equipesStreamProvider(widget.construtoraId));
    final funcionariosAsync = ref.watch(
      funcionariosStreamProvider(widget.construtoraId),
    );

    Equipe? equipeRh;
    final equipesList = equipesAsync.value;
    if (hasEquipeId && equipesList != null) {
      for (final item in equipesList) {
        if (item.id == equipeId) {
          equipeRh = item;
          break;
        }
      }
    }

    final displayEquipeNome =
        equipeRh?.name ??
        (hasEquipeNome ? equipeNomeFallback : 'Equipe vinculada');
    final leaderName = equipeRh?.leaderName?.trim();
    final hasLeader = leaderName != null && leaderName.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: sigo.borderHairline),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: sigo.lotCompleteBg,
                      foregroundColor: sigo.lotCompleteInk,
                      child: const Icon(Icons.groups_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Equipe Vinculada • ${etapa.nome}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: sigo.inkSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayEquipeNome,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: sigo.inkPrimary,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (equipeRh != null)
                      _StatusChip(isActive: equipeRh.isActive, sigo: sigo),
                  ],
                ),
                if (hasLeader) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 18,
                        color: sigo.inkSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Líder: $leaderName',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: sigo.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (equipesAsync.hasError) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: sigo.inkSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Detalhes completos do RH indisponíveis para o seu perfil.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: sigo.inkSecondary),
                        ),
                      ),
                    ],
                  ),
                ] else if (equipesAsync.hasValue &&
                    equipeRh == null &&
                    hasEquipeId) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: sigo.inkSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Equipe não localizada no cadastro atual do RH.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: sigo.inkSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
                if (widget.canEdit) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('btn_trocar_equipe_etapa'),
                        onPressed: _isDesvinculando
                            ? null
                            : _openSelecionarEquipeSheet,
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Trocar equipe'),
                      ),
                      TextButton.icon(
                        key: const Key('btn_desvincular_equipe_etapa'),
                        onPressed: _isDesvinculando
                            ? null
                            : () => _confirmarDesvincular(displayEquipeNome),
                        style: TextButton.styleFrom(
                          foregroundColor: sigo.danger,
                        ),
                        icon: _isDesvinculando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.link_off),
                        label: const Text('Desvincular equipe'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _ColaboradoresSection(
          equipeId: hasEquipeId ? equipeId : null,
          funcionariosAsync: funcionariosAsync,
          sigo: sigo,
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isActive;
  final SigoThemeExtension sigo;

  const _StatusChip({required this.isActive, required this.sigo});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        isActive ? 'Ativa' : 'Inativa',
        style: TextStyle(
          color: isActive ? sigo.lotCompleteInk : sigo.inkSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: isActive ? sigo.lotCompleteBg : sigo.surfaceBase,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ColaboradoresSection extends StatelessWidget {
  final String? equipeId;
  final AsyncValue<List<Funcionario>> funcionariosAsync;
  final SigoThemeExtension sigo;

  const _ColaboradoresSection({
    required this.equipeId,
    required this.funcionariosAsync,
    required this.sigo,
  });

  @override
  Widget build(BuildContext context) {
    if (equipeId == null) {
      return Text(
        'Vincule uma equipe do RH para visualizar os colaboradores.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: sigo.inkSecondary),
      );
    }

    return funcionariosAsync.when(
      loading: () => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Colaboradores vinculados',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12),
          Center(child: CircularProgressIndicator()),
        ],
      ),
      error: (err, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Colaboradores vinculados',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: sigo.inkPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: sigo.surfaceBase,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sigo.borderHairline),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: sigo.inkSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Não foi possível carregar os colaboradores do RH.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: sigo.inkSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      data: (funcionarios) {
        final membros =
            funcionarios.where((f) => f.teamId == equipeId).toList()
              ..sort((a, b) {
                if (a.isActive != b.isActive) {
                  return a.isActive ? -1 : 1;
                }
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Colaboradores vinculados (${membros.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: sigo.inkPrimary,
              ),
            ),
            const SizedBox(height: 10),
            if (membros.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: sigo.surfaceBase,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sigo.borderHairline),
                ),
                child: Text(
                  'Nenhum colaborador vinculado a esta equipe no RH.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: sigo.inkSecondary),
                ),
              )
            else
              ...membros.map((funcionario) {
                final role = funcionario.role.trim();
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
                        funcionario.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: sigo.inkPrimary,
                        ),
                      ),
                      subtitle: role.isNotEmpty
                          ? Text(
                              role,
                              style: TextStyle(color: sigo.inkSecondary),
                            )
                          : null,
                      trailing: !funcionario.isActive
                          ? Chip(
                              label: Text(
                                'Inativo',
                                style: TextStyle(
                                  color: sigo.inkSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              side: BorderSide.none,
                              visualDensity: VisualDensity.compact,
                            )
                          : null,
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _SelecionarEquipeRhSheet extends ConsumerStatefulWidget {
  final String construtoraId;
  final String loteId;
  final Etapa etapa;

  const _SelecionarEquipeRhSheet({
    required this.construtoraId,
    required this.loteId,
    required this.etapa,
  });

  @override
  ConsumerState<_SelecionarEquipeRhSheet> createState() =>
      _SelecionarEquipeRhSheetState();
}

class _SelecionarEquipeRhSheetState
    extends ConsumerState<_SelecionarEquipeRhSheet> {
  final TextEditingController _searchController = TextEditingController();
  final List<Equipe> _recentlyCreatedEquipes = [];
  String _searchQuery = '';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _computeCanRh() {
    final isDev = ref.watch(trustedDevProvider).value == true;
    final construtoraMember = ref
        .watch(construtoraPermissionProvider(widget.construtoraId))
        .value;

    final isConstrutoraAdmin =
        construtoraMember != null &&
        construtoraMember['isActive'] == true &&
        (construtoraMember['isAdmin'] == true ||
            construtoraMember['isOwner'] == true ||
            construtoraMember['role'] == 'admin' ||
            construtoraMember['role'] == 'owner');

    final construtoraModules = (construtoraMember?['modules'] as List? ?? [])
        .map((m) => normalizeModule(m.toString()))
        .toSet();

    return isDev ||
        isConstrutoraAdmin ||
        (construtoraMember != null &&
            construtoraMember['isActive'] == true &&
            (construtoraModules.contains('rh') ||
                construtoraModules.contains('recursos_humanos')));
  }

  Future<void> _abrirNovaEquipeDialog() async {
    final created = await showEquipeFormDialog(
      context,
      construtoraId: widget.construtoraId,
    );
    if (created == null || !mounted) return;
    setState(() {
      _recentlyCreatedEquipes.removeWhere((e) => e.id == created.id);
      _recentlyCreatedEquipes.insert(0, created);
      if (_searchQuery.isNotEmpty &&
          !created.name.toLowerCase().contains(_searchQuery)) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          'Equipe "${created.name}" criada e disponível para vínculo.',
        ),
      ),
    );
  }

  Future<void> _vincularEquipe(Equipe equipe) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(etapaRepositoryProvider)
          .vincularEquipe(
            etapaId: widget.etapa.id,
            equipeId: equipe.id,
            equipeNome: equipe.name,
            construtoraId: widget.construtoraId,
            loteId: widget.loteId,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Equipe "${equipe.name}" vinculada à etapa.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao vincular equipe. Tente novamente.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sigo =
        Theme.of(context).extension<SigoThemeExtension>() ?? SigoTheme.extension;
    final canRh = _computeCanRh();
    final equipesAsync = ref.watch(equipesStreamProvider(widget.construtoraId));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: sigo.surfaceRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: sigo.borderHairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vincular Equipe do RH',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: sigo.inkPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Etapa: ${widget.etapa.nome}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: sigo.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              key: const Key('buscar_equipe_rh_field'),
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nome da equipe ou líder...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        tooltip: 'Limpar busca',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.trim().toLowerCase());
              },
            ),
          ),
          const SizedBox(height: 12),
          if (_isSubmitting)
            LinearProgressIndicator(color: sigo.brandBlue, minHeight: 2),
          Expanded(
            child: equipesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Não foi possível carregar as equipes do RH.',
                        style: TextStyle(color: sigo.danger),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(
                          equipesStreamProvider(widget.construtoraId),
                        ),
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (equipes) {
                final mergedById = <String, Equipe>{};
                for (final e in _recentlyCreatedEquipes) {
                  mergedById[e.id] = e;
                }
                for (final e in equipes) {
                  mergedById[e.id] = e;
                }
                final active = mergedById.values.where((e) => e.isActive).where(
                  (e) {
                    if (_searchQuery.isEmpty) return true;
                    final name = e.name.toLowerCase();
                    final leader = (e.leaderName ?? '').toLowerCase();
                    return name.contains(_searchQuery) ||
                        leader.contains(_searchQuery);
                  },
                ).toList();

                if (active.isEmpty) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _searchQuery.isEmpty
                                ? 'Nenhuma equipe ativa encontrada no RH.'
                                : 'Nenhuma equipe ativa corresponde à busca.',
                            style: TextStyle(color: sigo.inkSecondary),
                            textAlign: TextAlign.center,
                          ),
                          if (canRh) ...[
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              key: const Key(
                                'btn_nova_equipe_contextual_etapa',
                              ),
                              onPressed: _isSubmitting
                                  ? null
                                  : _abrirNovaEquipeDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Nova equipe'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    if (canRh)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${active.length} ${active.length == 1 ? 'equipe ativa' : 'equipes ativas'}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: sigo.inkSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                            TextButton.icon(
                              key: const Key(
                                'btn_nova_equipe_contextual_etapa',
                              ),
                              onPressed: _isSubmitting
                                  ? null
                                  : _abrirNovaEquipeDialog,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Nova equipe'),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: active.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final equipe = active[index];
                          final isCurrent = widget.etapa.equipeId == equipe.id;
                          final leader = equipe.leaderName?.trim();
                          final hasLeader = leader != null && leader.isNotEmpty;

                          return Container(
                            decoration: BoxDecoration(
                              color: sigo.surfaceBase,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isCurrent
                                    ? sigo.brandBlue
                                    : sigo.borderHairline,
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: sigo.lotCompleteBg,
                                foregroundColor: sigo.lotCompleteInk,
                                child: const Icon(
                                  Icons.groups_outlined,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                equipe.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: sigo.inkPrimary,
                                ),
                              ),
                              subtitle: hasLeader
                                  ? Text(
                                      'Líder: $leader',
                                      style: TextStyle(
                                        color: sigo.inkSecondary,
                                      ),
                                    )
                                  : null,
                              trailing: isCurrent
                                  ? Chip(
                                      label: Text(
                                        'Vinculada',
                                        style: TextStyle(
                                          color: sigo.lotCompleteInk,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      backgroundColor: sigo.lotCompleteBg,
                                      side: BorderSide.none,
                                    )
                                  : FilledButton(
                                      onPressed: _isSubmitting
                                          ? null
                                          : () => _vincularEquipe(equipe),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: sigo.actionBlue,
                                        foregroundColor: sigo.surfaceRaised,
                                      ),
                                      child: const Text('Vincular'),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
