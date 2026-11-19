import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../../../design_system/sigo_theme.dart';
import '../../epi/presentation/colaborador_epis_tab.dart';
import '../data/rh_repository.dart';
import '../domain/equipe.dart';
import '../domain/funcionario.dart';
import 'equipe_form_dialog.dart';
import 'funcionario_form_screen.dart';

class FuncionariosListScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final int initialTabIndex;

  const FuncionariosListScreen({
    super.key,
    required this.construtoraId,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<FuncionariosListScreen> createState() =>
      _FuncionariosListScreenState();
}

class _FuncionariosListScreenState extends ConsumerState<FuncionariosListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late int _currentTabIndex;

  // Filtros da aba Funcionários
  String _searchQuery = '';
  String _selectedStatus = 'ativos'; // 'todos', 'ativos', 'inativos'
  String _selectedRegime = 'todos'; // 'todos', 'clt', 'pj', 'avulso'

  // Filtros da aba Equipes
  String _equipesSearchQuery = '';
  String _equipesSelectedStatus = 'ativas'; // 'ativas', 'inativas', 'todas'

  @override
  void initState() {
    super.initState();
    _currentTabIndex = widget.initialTabIndex.clamp(0, 1);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _currentTabIndex,
    );
    _tabController.addListener(() {
      if (_tabController.index != _currentTabIndex) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });
  }

  @override
  void didUpdateWidget(covariant FuncionariosListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      final target = widget.initialTabIndex.clamp(0, 1);
      if (_tabController.index != target) {
        _tabController.animateTo(target);
      }
      if (_currentTabIndex != target) {
        setState(() => _currentTabIndex = target);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openCreateEquipeDialog() async {
    final created = await showEquipeFormDialog(
      context,
      construtoraId: widget.construtoraId,
    );
    if (created != null && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Equipe "${created.name}" cadastrada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _openEditEquipeDialog(Equipe eq) async {
    final updated = await showEquipeFormDialog(
      context,
      construtoraId: widget.construtoraId,
      equipe: eq,
    );
    if (updated != null && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Equipe "${updated.name}" atualizada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleToggleEquipeActive(
    Equipe eq,
    int activeMembersCount,
  ) async {
    final newStatus = !eq.isActive;

    if (!newStatus && activeMembersCount > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Inativar Equipe'),
          content: Text(
            'A equipe "${eq.name}" possui $activeMembersCount '
            '${activeMembersCount == 1 ? 'colaborador ativo vinculado' : 'colaboradores ativos vinculados'}.\n\n'
            'A inativação impede novos vínculos de colaboradores a esta equipe, '
            'mas preserva todo o histórico de chamadas já registrado.\n\n'
            'Deseja continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              key: const Key('btn_confirm_inativar_equipe'),
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Inativar Equipe'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    await ref
        .read(rhRepositoryProvider)
        .setEquipeActive(widget.construtoraId, eq.id, newStatus);

    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? 'Equipe "${eq.name}" reativada.'
                : 'Equipe "${eq.name}" inativada.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final funcionariosAsync = ref.watch(
      funcionariosStreamProvider(widget.construtoraId),
    );
    final equipesAsync = ref.watch(equipesStreamProvider(widget.construtoraId));

    final Map<String, String> equipesMap = {};
    if (equipesAsync.hasValue) {
      for (final eq in equipesAsync.value!) {
        equipesMap[eq.id] = eq.name;
      }
    }

    final Map<String, int> activeMembersByEquipe = {};
    if (funcionariosAsync.hasValue) {
      for (final f in funcionariosAsync.value!) {
        if (f.isActive && f.teamId != null && f.teamId!.isNotEmpty) {
          activeMembersByEquipe[f.teamId!] =
              (activeMembersByEquipe[f.teamId!] ?? 0) + 1;
        }
      }
    }

    final sigoTheme = Theme.of(context).extension<SigoThemeExtension>();
    final isEquipesTab = _currentTabIndex == 1;

    return SigoLayout(
      title: isEquipesTab
          ? 'Recursos Humanos — Equipes'
          : 'Recursos Humanos — Funcionários',
      activeRoute: isEquipesTab
          ? '/construtoras/${widget.construtoraId}/rh/equipes'
          : '/construtoras/${widget.construtoraId}/rh/funcionarios',
      actions: [
        IconButton(
          key: const Key('btn_open_equipes'),
          icon: const Icon(Icons.groups),
          tooltip: 'Gerenciar Equipes',
          onPressed: () {
            if (_tabController.index != 1) {
              _tabController.animateTo(1);
            } else {
              _openCreateEquipeDialog();
            }
          },
        ),
        IconButton(
          key: const Key('btn_add_funcionario_appbar'),
          icon: const Icon(Icons.person_add),
          tooltip: 'Novo Funcionário',
          onPressed: () {
            context.push(
              '/construtoras/${widget.construtoraId}/rh/funcionarios/novo',
            );
          },
        ),
      ],
      floatingActionButton: isEquipesTab
          ? FloatingActionButton.extended(
              key: const Key('btn_add_equipe_fab'),
              onPressed: _openCreateEquipeDialog,
              icon: const Icon(Icons.group_add),
              label: const Text('Nova Equipe'),
            )
          : FloatingActionButton.extended(
              key: const Key('btn_add_funcionario_fab'),
              onPressed: () {
                context.push(
                  '/construtoras/${widget.construtoraId}/rh/funcionarios/novo',
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Novo Colaborador'),
            ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: sigoTheme?.surfaceRaised ?? Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: sigoTheme?.borderHairline ?? Colors.grey.shade300,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              onTap: (index) => setState(() => _currentTabIndex = index),
              labelColor: sigoTheme?.brandBlue ?? Colors.indigo,
              unselectedLabelColor:
                  sigoTheme?.inkSecondary ?? Colors.grey.shade600,
              indicatorColor: sigoTheme?.brandBlue ?? Colors.indigo,
              tabs: const [
                Tab(
                  key: Key('tab_rh_funcionarios'),
                  icon: Icon(Icons.people_outline, size: 18),
                  text: 'Funcionários',
                ),
                Tab(
                  key: Key('tab_rh_equipes'),
                  icon: Icon(Icons.groups_outlined, size: 18),
                  text: 'Equipes',
                ),
              ],
            ),
          ),
          Expanded(
            child: isEquipesTab
                ? _buildEquipesTab(
                    context,
                    equipesAsync: equipesAsync,
                    activeMembersByEquipe: activeMembersByEquipe,
                  )
                : _buildFuncionariosTab(
                    context,
                    funcionariosAsync: funcionariosAsync,
                    equipesMap: equipesMap,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuncionariosTab(
    BuildContext context, {
    required AsyncValue<List<Funcionario>> funcionariosAsync,
    required Map<String, String> equipesMap,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('search_funcionarios_input'),
                  decoration: InputDecoration(
                    hintText: 'Pesquisar por nome, cargo ou CPF...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              const Text(
                'Status: ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              ChoiceChip(
                label: const Text('Ativos'),
                selected: _selectedStatus == 'ativos',
                onSelected: (val) => setState(() => _selectedStatus = 'ativos'),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Todos'),
                selected: _selectedStatus == 'todos',
                onSelected: (val) => setState(() => _selectedStatus = 'todos'),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Inativos'),
                selected: _selectedStatus == 'inativos',
                onSelected: (val) =>
                    setState(() => _selectedStatus = 'inativos'),
              ),
              const SizedBox(width: 16),
              const Text(
                'Regime: ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              ChoiceChip(
                label: const Text('Todos'),
                selected: _selectedRegime == 'todos',
                onSelected: (val) => setState(() => _selectedRegime = 'todos'),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('CLT'),
                selected: _selectedRegime == 'clt',
                onSelected: (val) => setState(() => _selectedRegime = 'clt'),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('PJ'),
                selected: _selectedRegime == 'pj',
                onSelected: (val) => setState(() => _selectedRegime = 'pj'),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Avulso'),
                selected: _selectedRegime == 'avulso',
                onSelected: (val) => setState(() => _selectedRegime = 'avulso'),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: funcionariosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Erro ao carregar RH: $e')),
            data: (funcionarios) {
              final filtered = funcionarios.where((f) {
                if (_selectedStatus == 'ativos' && !f.isActive) return false;
                if (_selectedStatus == 'inativos' && f.isActive) return false;

                if (_selectedRegime != 'todos' &&
                    f.employmentType.toLowerCase() != _selectedRegime) {
                  return false;
                }

                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  final matchName = f.name.toLowerCase().contains(q);
                  final matchRole = f.role.toLowerCase().contains(q);
                  final matchCpf = f.cpf.contains(q);
                  if (!matchName && !matchRole && !matchCpf) return false;
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhum colaborador encontrado para os filtros selecionados.',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: 80,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final f = filtered[index];
                  final teamName = f.teamId != null
                      ? equipesMap[f.teamId]
                      : null;

                  return Card(
                    key: Key('funcionario_card_${f.id}'),
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: f.isActive
                            ? Colors.grey.shade300
                            : Colors.red.shade200,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: f.isActive
                                    ? Colors.blue.shade100
                                    : Colors.grey.shade300,
                                child: Icon(
                                  Icons.person,
                                  color: f.isActive
                                      ? Colors.blue.shade800
                                      : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      f.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        decoration: f.isActive
                                            ? null
                                            : TextDecoration.lineThrough,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${f.role} • CPF: ${f.formattedCpf}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (action) async {
                                  if (action == 'edit') {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => FuncionarioFormScreen(
                                          construtoraId: widget.construtoraId,
                                          initialFuncionario: f,
                                        ),
                                      ),
                                    );
                                  } else if (action == 'toggle') {
                                    final newStatus = !f.isActive;
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(
                                          newStatus
                                              ? 'Reativar Colaborador'
                                              : 'Inativar Colaborador',
                                        ),
                                        content: Text(
                                          'Tem certeza que deseja ${newStatus ? "reativar" : "inativar"} ${f.name}?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(false),
                                            child: const Text('Cancelar'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(true),
                                            child: const Text('Confirmar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await ref
                                          .read(rhRepositoryProvider)
                                          .setFuncionarioActive(
                                            widget.construtoraId,
                                            f.id,
                                            newStatus,
                                          );
                                    }
                                  } else if (action == 'epis') {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(16),
                                        ),
                                      ),
                                      builder: (ctx) => SizedBox(
                                        height:
                                            MediaQuery.of(context).size.height *
                                            0.85,
                                        child: Scaffold(
                                          appBar: AppBar(
                                            title: Text(
                                              'Ficha de EPIs — ${f.name}',
                                            ),
                                            automaticallyImplyLeading: false,
                                            actions: [
                                              IconButton(
                                                icon: const Icon(Icons.close),
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(),
                                              ),
                                            ],
                                          ),
                                          body: ColaboradorEpisTab(
                                            construtoraId: widget.construtoraId,
                                            funcionarioId: f.id,
                                            funcionarioNome: f.name,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'epis',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.health_and_safety,
                                          size: 18,
                                          color: Colors.indigo,
                                        ),
                                        SizedBox(width: 8),
                                        Text('Ficha de EPIs'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 18),
                                        SizedBox(width: 8),
                                        Text('Editar'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Row(
                                      children: [
                                        Icon(
                                          f.isActive
                                              ? Icons.block
                                              : Icons.check_circle,
                                          size: 18,
                                          color: f.isActive
                                              ? Colors.red
                                              : Colors.green,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          f.isActive ? 'Inativar' : 'Reativar',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _Badge(
                                label: f.isActive ? 'Ativo' : 'Inativo',
                                color: f.isActive ? Colors.green : Colors.grey,
                              ),
                              _Badge(
                                label: f.employmentTypeLabel,
                                color: Colors.blue,
                              ),
                              if (teamName != null)
                                _Badge(
                                  label: 'Equipe: $teamName',
                                  color: Colors.indigo,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Remuneração Base: ${f.formattedBaseSalary} (${f.salaryBasisLabel})',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      if (f.additionalCostsCents > 0)
                                        Text(
                                          'Adicionais: ${f.formattedAdditionalCosts}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
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
                                    color: Colors.indigo.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.indigo.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    '${f.formattedDailyRate} / dia',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.indigo.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEquipesTab(
    BuildContext context, {
    required AsyncValue<List<Equipe>> equipesAsync,
    required Map<String, int> activeMembersByEquipe,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            key: const Key('search_equipes_input'),
            decoration: InputDecoration(
              hintText: 'Pesquisar por nome da equipe ou líder...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              isDense: true,
            ),
            onChanged: (val) => setState(() => _equipesSearchQuery = val),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              const Text(
                'Status: ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              ChoiceChip(
                label: const Text('Ativas'),
                selected: _equipesSelectedStatus == 'ativas',
                onSelected: (_) =>
                    setState(() => _equipesSelectedStatus = 'ativas'),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Inativas'),
                selected: _equipesSelectedStatus == 'inativas',
                onSelected: (_) =>
                    setState(() => _equipesSelectedStatus = 'inativas'),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Todas'),
                selected: _equipesSelectedStatus == 'todas',
                onSelected: (_) =>
                    setState(() => _equipesSelectedStatus = 'todas'),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: equipesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Erro ao carregar equipes: $e')),
            data: (equipes) {
              if (equipes.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.groups_outlined,
                          size: 56,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Nenhuma equipe cadastrada ainda.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Crie equipes para organizar colaboradores, líderes e apropriações nas obras.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          key: const Key('btn_empty_create_equipe'),
                          onPressed: _openCreateEquipeDialog,
                          icon: const Icon(Icons.group_add),
                          label: const Text('Criar primeira equipe'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final filtered = equipes.where((eq) {
                if (_equipesSelectedStatus == 'ativas' && !eq.isActive) {
                  return false;
                }
                if (_equipesSelectedStatus == 'inativas' && eq.isActive) {
                  return false;
                }
                if (_equipesSearchQuery.isNotEmpty) {
                  final q = _equipesSearchQuery.toLowerCase();
                  final matchName = eq.name.toLowerCase().contains(q);
                  final matchLeader = (eq.leaderName ?? '')
                      .toLowerCase()
                      .contains(q);
                  if (!matchName && !matchLeader) return false;
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhuma equipe encontrada para os filtros selecionados.',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: 80,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final eq = filtered[index];
                  final activeMembersCount = activeMembersByEquipe[eq.id] ?? 0;

                  return Card(
                    key: Key('equipe_card_${eq.id}'),
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: eq.isActive
                            ? Colors.grey.shade300
                            : Colors.red.shade200,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: eq.isActive
                                ? Colors.indigo.shade100
                                : Colors.grey.shade200,
                            child: Icon(
                              Icons.groups,
                              color: eq.isActive
                                  ? Colors.indigo.shade800
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  eq.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    decoration: eq.isActive
                                        ? null
                                        : TextDecoration.lineThrough,
                                    color: eq.isActive
                                        ? null
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (eq.leaderName != null &&
                                    eq.leaderName!.isNotEmpty)
                                  Text(
                                    'Líder: ${eq.leaderName}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  )
                                else
                                  Text(
                                    'Sem líder definido',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    _Badge(
                                      label: eq.isActive ? 'Ativa' : 'Inativa',
                                      color: eq.isActive
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                    _Badge(
                                      label:
                                          '$activeMembersCount ${activeMembersCount == 1 ? 'colaborador ativo' : 'colaboradores ativos'}',
                                      color: Colors.indigo,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            key: Key('btn_edit_equipe_${eq.id}'),
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Editar equipe',
                            onPressed: () => _openEditEquipeDialog(eq),
                          ),
                          IconButton(
                            key: Key('btn_toggle_equipe_${eq.id}'),
                            icon: Icon(
                              eq.isActive ? Icons.toggle_on : Icons.toggle_off,
                              color: eq.isActive ? Colors.green : Colors.grey,
                              size: 34,
                            ),
                            tooltip: eq.isActive
                                ? 'Inativar equipe'
                                : 'Reativar equipe',
                            onPressed: () => _handleToggleEquipeActive(
                              eq,
                              activeMembersCount,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final MaterialColor color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.shade900,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
