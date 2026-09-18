import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../data/rh_repository.dart';
import 'equipes_dialog.dart';
import 'funcionario_form_screen.dart';
import '../../epi/presentation/colaborador_epis_tab.dart';

class FuncionariosListScreen extends ConsumerStatefulWidget {
  final String construtoraId;

  const FuncionariosListScreen({super.key, required this.construtoraId});

  @override
  ConsumerState<FuncionariosListScreen> createState() =>
      _FuncionariosListScreenState();
}

class _FuncionariosListScreenState
    extends ConsumerState<FuncionariosListScreen> {
  String _searchQuery = '';
  String _selectedStatus = 'ativos'; // 'todos', 'ativos', 'inativos'
  String _selectedRegime = 'todos'; // 'todos', 'clt', 'pj', 'avulso'

  @override
  Widget build(BuildContext context) {
    final funcionariosAsync =
        ref.watch(funcionariosStreamProvider(widget.construtoraId));
    final equipesAsync =
        ref.watch(equipesStreamProvider(widget.construtoraId));

    final Map<String, String> equipesMap = {};
    if (equipesAsync.hasValue) {
      for (final eq in equipesAsync.value!) {
        equipesMap[eq.id] = eq.name;
      }
    }

    return SigoLayout(
      title: 'Recursos Humanos — Funcionários',
      activeRoute: '/construtora/${widget.construtoraId}/rh',
      actions: [
        IconButton(
          key: const Key('btn_open_equipes'),
          icon: const Icon(Icons.groups),
          tooltip: 'Gerenciar Equipes',
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) =>
                  EquipesDialog(construtoraId: widget.construtoraId),
            );
          },
        ),
        IconButton(
          key: const Key('btn_add_funcionario_appbar'),
          icon: const Icon(Icons.person_add),
          tooltip: 'Novo Funcionário',
          onPressed: () {
            context.push(
              '/construtora/${widget.construtoraId}/rh/funcionarios/novo',
            );
          },
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('btn_add_funcionario_fab'),
        onPressed: () {
          context.push(
            '/construtora/${widget.construtoraId}/rh/funcionarios/novo',
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo Colaborador'),
      ),
      child: Column(
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
                  onSelected: (val) =>
                      setState(() => _selectedStatus = 'ativos'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _selectedStatus == 'todos',
                  onSelected: (val) =>
                      setState(() => _selectedStatus = 'todos'),
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
                  onSelected: (val) =>
                      setState(() => _selectedRegime = 'todos'),
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
                  onSelected: (val) =>
                      setState(() => _selectedRegime = 'avulso'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: funcionariosAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Erro ao carregar RH: $e')),
              data: (funcionarios) {
                final filtered = funcionarios.where((f) {
                  // Filtro status
                  if (_selectedStatus == 'ativos' && !f.isActive) return false;
                  if (_selectedStatus == 'inativos' && f.isActive) return false;

                  // Filtro regime
                  if (_selectedRegime != 'todos' &&
                      f.employmentType.toLowerCase() != _selectedRegime) {
                    return false;
                  }

                  // Filtro busca texto
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
                    final teamName =
                        f.teamId != null ? equipesMap[f.teamId] : null;

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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          builder: (_) =>
                                              FuncionarioFormScreen(
                                            construtoraId:
                                                widget.construtoraId,
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
                                          height: MediaQuery.of(context).size.height * 0.85,
                                          child: Scaffold(
                                            appBar: AppBar(
                                              title: Text('Ficha de EPIs — ${f.name}'),
                                              automaticallyImplyLeading: false,
                                              actions: [
                                                IconButton(
                                                  icon: const Icon(Icons.close),
                                                  onPressed: () => Navigator.of(ctx).pop(),
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
                                          Icon(Icons.health_and_safety, size: 18, color: Colors.indigo),
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
                                            f.isActive
                                                ? 'Inativar'
                                                : 'Reativar',
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
                                  color: f.isActive
                                      ? Colors.green
                                      : Colors.grey,
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
      ),
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
