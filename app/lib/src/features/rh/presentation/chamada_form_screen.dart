import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/contracts.dart';
import '../../lotes/data/lote_repository.dart';
import '../../lotes/domain/lote.dart';
import '../data/custo_mao_de_obra_service.dart';
import '../data/rh_repository.dart';
import '../domain/custo_mao_de_obra.dart';
import '../domain/equipe.dart';
import '../domain/funcionario.dart';
import '../data/chamada_repository.dart';
import '../data/lote_persistido_service.dart';
import '../domain/chamada_diaria.dart';
import 'widgets/apontamento_worker_card.dart';
import 'widgets/resumo_custos_chamada_dialog.dart';

class ChamadaFormScreen extends ConsumerStatefulWidget {
  final String construtoraId;
  final String obraId;
  final String? chamadaId;

  const ChamadaFormScreen({
    super.key,
    required this.construtoraId,
    required this.obraId,
    this.chamadaId,
  });

  @override
  ConsumerState<ChamadaFormScreen> createState() => _ChamadaFormScreenState();
}

class _ChamadaFormScreenState extends ConsumerState<ChamadaFormScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedTeamId;
  String? _defaultLotId;
  final List<ApontamentoTrabalhador> _workers = [];
  bool _isSaving = false;
  bool _initialized = false;
  ChamadaDiaria? _existingChamada;

  String get _formattedDate => DateFormat('yyyy-MM-dd').format(_selectedDate);

  int get _presentCount =>
      _workers.where((w) => w.status == PresencaStatus.presente).length;
  int get _meioPeriodoCount =>
      _workers.where((w) => w.status == PresencaStatus.meioPeriodo).length;
  int get _faltaCount =>
      _workers.where((w) => w.status == PresencaStatus.falta).length;

  bool get _isFormValid =>
      _workers.isNotEmpty && _workers.every((w) => w.isValidAllocation);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (widget.chamadaId != null) {
      final repo = ref.read(chamadaRepositoryProvider);
      final ch = await repo.getChamada(
        widget.construtoraId,
        widget.obraId,
        widget.chamadaId!,
      );
      if (ch != null && mounted) {
        setState(() {
          _existingChamada = ch;
          _selectedDate = DateTime.tryParse(ch.date) ?? DateTime.now();
          _selectedTeamId = ch.teamId;
          _defaultLotId = ch.defaultLotId;
          _workers.clear();
          _workers.addAll(ch.workers);
          _initialized = true;
        });
        return;
      }
    }
    setState(() {
      _initialized = true;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _syncWorkersList(List<Funcionario> allFuncionarios, List<Lote> lotes) {
    if (_existingChamada != null) return; // Não sobrescreve chamada existente

    final activeFuncionarios = allFuncionarios.where((f) => f.isActive).toList();
    final filtered = _selectedTeamId == null || _selectedTeamId!.isEmpty
        ? activeFuncionarios
        : activeFuncionarios.where((f) => f.teamId == _selectedTeamId).toList();

    if (_workers.isEmpty || _workers.length != filtered.length) {
      final targetLot = lotes.where((l) => l.id == _defaultLotId).firstOrNull ??
          (lotes.isNotEmpty ? lotes.first : null);

      _workers.clear();
      for (final f in filtered) {
        _workers.add(
          ApontamentoTrabalhador(
            workerId: f.id,
            workerName: f.name,
            workerRole: f.role,
            status: PresencaStatus.presente,
            allocations: targetLot != null
                ? [
                    AlocacaoLote(
                      lotId: targetLot.id,
                      lotName: targetLot.name,
                      percentage: 100,
                    ),
                  ]
                : [],
          ),
        );
      }
    }
  }

  Future<void> _onTeamChanged(String? teamId, List<Lote> lotes) async {
    setState(() {
      _selectedTeamId = teamId;
      _workers.clear(); // Limpa para recalcular pela equipe
    });

    if (teamId != null && teamId.isNotEmpty) {
      final savedLot = await ref
          .read(lotePersistidoServiceProvider)
          .getDefaultLot(obraId: widget.obraId, teamId: teamId);
      if (savedLot != null && lotes.any((l) => l.id == savedLot) && mounted) {
        setState(() {
          _defaultLotId = savedLot;
        });
      }
    }
  }

  void _onDefaultLotChanged(String? lotId) {
    setState(() {
      _defaultLotId = lotId;
    });
    if (lotId != null && _selectedTeamId != null && _selectedTeamId!.isNotEmpty) {
      ref.read(lotePersistidoServiceProvider).saveDefaultLot(
            obraId: widget.obraId,
            teamId: _selectedTeamId!,
            lotId: lotId,
          );
    }
  }

  void _markAllPresent(List<Lote> lotes) {
    final targetLot = lotes.where((l) => l.id == _defaultLotId).firstOrNull ??
        (lotes.isNotEmpty ? lotes.first : null);

    setState(() {
      for (var i = 0; i < _workers.length; i++) {
        _workers[i] = _workers[i].copyWith(
          status: PresencaStatus.presente,
          allocations: targetLot != null
              ? [
                  AlocacaoLote(
                    lotId: targetLot.id,
                    lotName: targetLot.name,
                    percentage: 100,
                  ),
                ]
              : [],
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Todos os operários marcados como presentes!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _saveChamada(
    List<Equipe> equipes,
    List<Funcionario> allFuncionarios,
  ) async {
    if (!_isFormValid) return;

    setState(() {
      _isSaving = true;
    });

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    final equipeName = _selectedTeamId != null
        ? equipes.where((e) => e.id == _selectedTeamId).firstOrNull?.name
        : null;

    final costResult = CustoMaoDeObraService.computeChamadaCosts(
      funcionarios: allFuncionarios,
      apontamentos: _workers,
    );

    final chamada = ChamadaDiaria(
      id: _existingChamada?.id ?? const Uuid().v4(),
      construtoraId: widget.construtoraId,
      obraId: widget.obraId,
      date: _formattedDate,
      teamId: _selectedTeamId,
      teamName: equipeName,
      createdByUid: uid,
      defaultLotId: _defaultLotId,
      status: _existingChamada != null ? 'retificada' : 'confirmada',
      workers: _workers,
      totalDayCostCents: costResult.totalDayCostCents,
      costPolicyVersion: 'v1',
      costPolicy: const CostPolicy(),
      costSnapshots: costResult.costSnapshots,
      lotCostSummaries: costResult.lotCostSummaries,
      createdAt: _existingChamada?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      schemaVersion: 1,
    );

    try {
      await ref.read(chamadaRepositoryProvider).saveChamada(chamada);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              _existingChamada != null
                  ? 'Chamada retificada com sucesso!'
                  : 'Chamada diária salva com sucesso!',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Erro ao salvar chamada: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final funcionariosAsync =
        ref.watch(funcionariosStreamProvider(widget.construtoraId));
    final equipesAsync = ref.watch(equipesStreamProvider(widget.construtoraId));
    final lotesStream = ref.watch(loteRepositoryProvider).watchLotes(
          widget.construtoraId,
          widget.obraId,
        );

    return StreamBuilder<List<Lote>>(
      stream: lotesStream,
      builder: (context, lotesSnap) {
        final lotes = lotesSnap.data ?? [];

        return funcionariosAsync.when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => Scaffold(
            body: Center(child: Text('Erro ao carregar colaboradores: $e')),
          ),
          data: (allFuncionarios) {
            return equipesAsync.when(
              loading: () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
              error: (e, st) => Scaffold(
                body: Center(child: Text('Erro ao carregar equipes: $e')),
              ),
              data: (equipes) {
                if (_initialized && _workers.isEmpty && _existingChamada == null) {
                  _syncWorkersList(allFuncionarios, lotes);
                }

                return Scaffold(
                  appBar: AppBar(
                    title: Text(
                      _existingChamada != null
                          ? 'Retificar Chamada Diária'
                          : 'Nova Chamada Diária',
                    ),
                    actions: [
                      if (lotes.isNotEmpty && _workers.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.done_all, color: Colors.green),
                          label: const Text(
                            'Todos Presentes',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => _markAllPresent(lotes),
                        ),
                    ],
                  ),
                  body: Column(
                    children: [
                      // Cabeçalho de Seleção
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Data da chamada
                                Expanded(
                                  flex: 2,
                                  child: InkWell(
                                    onTap: _pickDate,
                                    borderRadius: BorderRadius.circular(10),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Data do Expediente',
                                        prefixIcon: const Icon(Icons.calendar_today, size: 18),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      child: Text(
                                        DateFormat('dd/MM/yyyy').format(_selectedDate),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Lote Padrão
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _defaultLotId,
                                    decoration: InputDecoration(
                                      labelText: 'Lote Padrão',
                                      prefixIcon: const Icon(Icons.home_work, size: 18),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    hint: const Text('Selecionar lote...'),
                                    items: [
                                      ...lotes.map((l) => DropdownMenuItem(
                                            value: l.id,
                                            child: Text(
                                              l.name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          )),
                                    ],
                                    onChanged: _onDefaultLotChanged,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Seleção de Equipe
                            DropdownButtonFormField<String?>(
                              initialValue: _selectedTeamId,
                              decoration: InputDecoration(
                                labelText: 'Equipe de Trabalho',
                                prefixIcon: const Icon(Icons.groups, size: 18),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Todos os Colaboradores da Obra'),
                                ),
                                ...equipes.map((e) => DropdownMenuItem(
                                      value: e.id,
                                      child: Text(e.name),
                                    )),
                              ],
                              onChanged: (teamId) {
                                _onTeamChanged(teamId, lotes);
                                _syncWorkersList(allFuncionarios, lotes);
                              },
                            ),
                          ],
                        ),
                      ),

                      // Lista de Operários
                      Expanded(
                        child: _workers.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.person_off_outlined,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Nenhum colaborador encontrado para o filtro selecionado.',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: _workers.length,
                                itemBuilder: (context, index) {
                                  final worker = _workers[index];
                                  final func = allFuncionarios
                                      .where((f) => f.id == worker.workerId)
                                      .firstOrNull;
                                  return ApontamentoWorkerCard(
                                    apontamento: worker,
                                    availableLotes: lotes,
                                    defaultLotId: _defaultLotId,
                                    baseDailyRateCents: func?.totalDailyRateCents,
                                    onChanged: (updated) {
                                      setState(() {
                                        _workers[index] = updated;
                                      });
                                    },
                                  );
                                },
                              ),
                      ),

                      // Sticky Bottom Bar com Resumo e Botão Salvar
                      Builder(
                        builder: (context) {
                          final currentCosts =
                              CustoMaoDeObraService.computeChamadaCosts(
                            funcionarios: allFuncionarios,
                            apontamentos: _workers,
                          );

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, -4),
                                ),
                              ],
                            ),
                            child: SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.payments_outlined,
                                              size: 18,
                                              color: Colors.indigo.shade700),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Custo Estimado: ${formatCents(currentCosts.totalDayCostCents)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Colors.indigo.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(Icons.analytics_outlined,
                                            size: 16),
                                        label: const Text('Resumo por Lote',
                                            style: TextStyle(fontSize: 12)),
                                        onPressed: () {
                                          ResumoCustosChamadaDialog.show(
                                            context: context,
                                            totalDayCostCents:
                                                currentCosts.totalDayCostCents,
                                            lotCostSummaries:
                                                currentCosts.lotCostSummaries,
                                            costSnapshots:
                                                currentCosts.costSnapshots,
                                            date: _formattedDate,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 14),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _SummaryItem(
                                        label: 'Total',
                                        count: _workers.length,
                                        color: Colors.blueGrey,
                                      ),
                                      _SummaryItem(
                                        label: 'Presentes',
                                        count: _presentCount,
                                        color: Colors.green,
                                      ),
                                      _SummaryItem(
                                        label: '1/2 Período',
                                        count: _meioPeriodoCount,
                                        color: Colors.orange,
                                      ),
                                      _SummaryItem(
                                        label: 'Faltas',
                                        count: _faltaCount,
                                        color: Colors.red,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: FilledButton.icon(
                                      icon: _isSaving
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.check_circle_outline),
                                      label: Text(
                                        _isSaving
                                            ? 'Salvando Chamada...'
                                            : 'Salvar Chamada Diária',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onPressed: (_isFormValid && !_isSaving)
                                          ? () => _saveChamada(
                                              equipes, allFuncionarios)
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withValues(alpha: 0.85),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
