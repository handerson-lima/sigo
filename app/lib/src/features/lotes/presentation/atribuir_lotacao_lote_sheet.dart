import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/sigo_theme.dart';
import '../../etapas/domain/etapa.dart';
import '../../rh/data/rh_repository.dart';
import '../../rh/domain/equipe.dart';
import '../../rh/domain/funcionario.dart';
import '../data/lote_repository.dart';
import '../domain/lote.dart';

/// Abre o seletor rápido de atribuição de equipes e funcionários do RH ao lote.
Future<void> showAtribuirLotacaoLoteSheet({
  required BuildContext context,
  required String construtoraId,
  required Lote lote,
  String? initialEtapaId,
  List<Etapa>? etapas,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AtribuirLotacaoLoteSheet(
      construtoraId: construtoraId,
      lote: lote,
      initialEtapaId: initialEtapaId,
      etapas: etapas,
    ),
  );
}

class _EtapaOption {
  final String? id;
  final String label;

  const _EtapaOption({required this.id, required this.label});
}

class AtribuirLotacaoLoteSheet extends ConsumerStatefulWidget {
  final String construtoraId;
  final Lote lote;
  final String? initialEtapaId;
  final List<Etapa>? etapas;

  const AtribuirLotacaoLoteSheet({
    super.key,
    required this.construtoraId,
    required this.lote,
    this.initialEtapaId,
    this.etapas,
  });

  @override
  ConsumerState<AtribuirLotacaoLoteSheet> createState() =>
      _AtribuirLotacaoLoteSheetState();
}

class _AtribuirLotacaoLoteSheetState
    extends ConsumerState<AtribuirLotacaoLoteSheet> {
  late String? _selectedEtapaId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedEtapaId = widget.initialEtapaId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_EtapaOption> _buildEtapaOptions() {
    final options = <_EtapaOption>[
      const _EtapaOption(id: null, label: 'Lote inteiro (vínculo geral)'),
    ];

    final existing = widget.etapas;
    if (existing != null && existing.isNotEmpty) {
      final sorted = List<Etapa>.from(existing)
        ..sort((a, b) => a.ordem.compareTo(b.ordem));
      for (final etapa in sorted) {
        options.add(_EtapaOption(id: etapa.id, label: etapa.nome));
      }
      return options;
    }

    for (final tipo in EtapaTipo.values) {
      options.add(
        _EtapaOption(id: '${widget.lote.id}_${tipo.name}', label: tipo.label),
      );
    }
    return options;
  }

  bool _isEquipeVinculada(String equipeId) {
    return widget.lote.equipesVinculadas.any((item) {
      final itemId = item['id']?.toString().trim();
      final rawEtapa = item['etapaId']?.toString().trim();
      final normalizedEtapa = (rawEtapa == null || rawEtapa.isEmpty)
          ? null
          : rawEtapa;
      return itemId == equipeId && normalizedEtapa == _selectedEtapaId;
    });
  }

  bool _isFuncionarioVinculado(String funcionarioId) {
    return widget.lote.funcionariosVinculados.any((item) {
      final itemId = item['id']?.toString().trim();
      final rawEtapa = item['etapaId']?.toString().trim();
      final normalizedEtapa = (rawEtapa == null || rawEtapa.isEmpty)
          ? null
          : rawEtapa;
      return itemId == funcionarioId && normalizedEtapa == _selectedEtapaId;
    });
  }

  Future<void> _atribuirEquipe(Equipe equipe) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(loteRepositoryProvider)
          .atribuirEquipe(
            loteId: widget.lote.id,
            equipeId: equipe.id,
            equipeNome: equipe.name,
            leaderName: equipe.leaderName,
            etapaId: _selectedEtapaId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Equipe "${equipe.name}" atribuída com sucesso.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atribuir equipe: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _atribuirFuncionario(Funcionario funcionario) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(loteRepositoryProvider)
          .atribuirFuncionario(
            loteId: widget.lote.id,
            funcionarioId: funcionario.id,
            funcionarioNome: funcionario.name,
            role: funcionario.role.trim().isEmpty
                ? 'Funcionário'
                : funcionario.role.trim(),
            etapaId: _selectedEtapaId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Funcionário "${funcionario.name}" atribuído com sucesso.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atribuir funcionário: $e')),
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
    final options = _buildEtapaOptions();
    final hasSelectedOption = options.any((o) => o.id == _selectedEtapaId);
    final effectiveSelectedEtapaId = hasSelectedOption
        ? _selectedEtapaId
        : null;

    final equipesAsync = ref.watch(equipesStreamProvider(widget.construtoraId));
    final funcionariosAsync = ref.watch(
      funcionariosStreamProvider(widget.construtoraId),
    );

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: sigo.surfaceRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DefaultTabController(
        length: 2,
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
                          'Atribuir ao ${widget.lote.name}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: sigo.inkPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Selecione uma equipe ou funcionário ativo do RH',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: sigo.inkSecondary),
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
              child: DropdownButtonFormField<String?>(
                key: const Key('atribuir_etapa_dropdown'),
                initialValue: effectiveSelectedEtapaId,
                decoration: const InputDecoration(
                  labelText: 'Vincular a',
                  isDense: true,
                ),
                items: options
                    .map(
                      (option) => DropdownMenuItem<String?>(
                        value: option.id,
                        child: Text(option.label),
                      ),
                    )
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() => _selectedEtapaId = value);
                      },
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                key: const Key('atribuir_search_field'),
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Filtrar por nome, líder ou função...',
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
            TabBar(
              labelColor: sigo.actionBlue,
              unselectedLabelColor: sigo.inkSecondary,
              indicatorColor: sigo.actionBlue,
              tabs: const [
                Tab(text: 'Equipes RH'),
                Tab(text: 'Funcionários RH'),
              ],
            ),
            if (_isSubmitting)
              LinearProgressIndicator(color: sigo.brandBlue, minHeight: 2),
            Expanded(
              child: TabBarView(
                children: [
                  _buildEquipesTab(context, sigo, equipesAsync),
                  _buildFuncionariosTab(context, sigo, funcionariosAsync),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipesTab(
    BuildContext context,
    SigoThemeExtension sigo,
    AsyncValue<List<Equipe>> equipesAsync,
  ) {
    return equipesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Não foi possível carregar as equipes do RH.',
            style: TextStyle(color: sigo.danger),
          ),
        ),
      ),
      data: (equipes) {
        final active = equipes.where((e) => e.isActive).where((e) {
          if (_searchQuery.isEmpty) return true;
          final name = e.name.toLowerCase();
          final leader = (e.leaderName ?? '').toLowerCase();
          return name.contains(_searchQuery) || leader.contains(_searchQuery);
        }).toList();

        if (active.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _searchQuery.isEmpty
                    ? 'Nenhuma equipe ativa encontrada no RH.'
                    : 'Nenhuma equipe ativa corresponde à busca.',
                style: TextStyle(color: sigo.inkSecondary),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: active.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final equipe = active[index];
            final jaVinculada = _isEquipeVinculada(equipe.id);
            final hasLeader =
                equipe.leaderName != null &&
                equipe.leaderName!.trim().isNotEmpty;

            return Container(
              decoration: BoxDecoration(
                color: sigo.surfaceBase,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: jaVinculada ? sigo.brandBlue : sigo.borderHairline,
                ),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: sigo.lotCompleteBg,
                  foregroundColor: sigo.lotCompleteInk,
                  child: const Icon(Icons.groups_outlined, size: 20),
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
                        'Líder: ${equipe.leaderName}',
                        style: TextStyle(color: sigo.inkSecondary),
                      )
                    : null,
                trailing: jaVinculada
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
                            : () => _atribuirEquipe(equipe),
                        style: FilledButton.styleFrom(
                          backgroundColor: sigo.actionBlue,
                          foregroundColor: sigo.surfaceRaised,
                        ),
                        child: const Text('Atribuir'),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFuncionariosTab(
    BuildContext context,
    SigoThemeExtension sigo,
    AsyncValue<List<Funcionario>> funcionariosAsync,
  ) {
    return funcionariosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Não foi possível carregar os funcionários do RH.',
            style: TextStyle(color: sigo.danger),
          ),
        ),
      ),
      data: (funcionarios) {
        final active = funcionarios.where((f) => f.isActive).where((f) {
          if (_searchQuery.isEmpty) return true;
          final name = f.name.toLowerCase();
          final role = f.role.toLowerCase();
          return name.contains(_searchQuery) || role.contains(_searchQuery);
        }).toList();

        if (active.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _searchQuery.isEmpty
                    ? 'Nenhum funcionário ativo encontrado no RH.'
                    : 'Nenhum funcionário ativo corresponde à busca.',
                style: TextStyle(color: sigo.inkSecondary),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: active.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final funcionario = active[index];
            final jaVinculado = _isFuncionarioVinculado(funcionario.id);

            return Container(
              decoration: BoxDecoration(
                color: sigo.surfaceBase,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: jaVinculado ? sigo.brandBlue : sigo.borderHairline,
                ),
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
                    fontWeight: FontWeight.w600,
                    color: sigo.inkPrimary,
                  ),
                ),
                subtitle: funcionario.role.trim().isNotEmpty
                    ? Text(
                        funcionario.role,
                        style: TextStyle(color: sigo.inkSecondary),
                      )
                    : null,
                trailing: jaVinculado
                    ? Chip(
                        label: Text(
                          'Vinculado',
                          style: TextStyle(
                            color: sigo.lotOnTimeInk,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: sigo.lotOnTimeBg,
                        side: BorderSide.none,
                      )
                    : FilledButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => _atribuirFuncionario(funcionario),
                        style: FilledButton.styleFrom(
                          backgroundColor: sigo.actionBlue,
                          foregroundColor: sigo.surfaceRaised,
                        ),
                        child: const Text('Atribuir'),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
