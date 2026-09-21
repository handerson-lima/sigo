import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../common_widgets/sigo_layout.dart';
import '../../lotes/data/lote_repository.dart';
import '../../lotes/domain/lote.dart';
import '../data/custo_mao_de_obra_service.dart';
import '../data/rh_repository.dart';
import '../domain/chamada_audit_entry.dart';
import '../domain/custo_mao_de_obra.dart';
import '../domain/equipe.dart';
import '../domain/funcionario.dart';
import '../domain/rh_invariante_validator.dart';
import '../data/chamada_repository.dart';
import '../data/lote_persistido_service.dart';
import '../domain/chamada_diaria.dart';
import 'widgets/apontamento_worker_card.dart';
import 'widgets/chamada_filtros_header.dart';
import 'widgets/chamada_invariantes_banner.dart';
import 'widgets/chamada_sticky_bottom_bar.dart';
import 'widgets/retificacao_chamada_dialog.dart';

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
      _workers.isNotEmpty &&
      RhInvarianteValidator.validarChamada(apontamentos: _workers).isEmpty;

  List<String> _validarInvariantes(List<Lote> lotes) {
    return RhInvarianteValidator.validarChamada(
      apontamentos: _workers,
      lotesValidosDaObra: lotes.map((l) => l.id).toSet(),
    );
  }

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
    } else {
      _checkExistingChamadaForDate(_selectedDate);
    }
    setState(() {
      _initialized = true;
    });
  }

  Future<void> _checkExistingChamadaForDate(DateTime date) async {
    if (widget.chamadaId != null) return;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final repo = ref.read(chamadaRepositoryProvider);
    final existing = await repo.findChamadaByDate(
      widget.construtoraId,
      widget.obraId,
      dateStr,
    );
    if (existing != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.amber.shade900,
          duration: const Duration(seconds: 5),
          content: Text(
            'Já existe uma chamada registrada em $dateStr para esta obra.',
          ),
          action: SnackBarAction(
            label: 'Ver Chamada',
            textColor: Colors.white,
            onPressed: () {
              context.pushReplacement(
                '/construtora/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas/${existing.id}',
              );
            },
          ),
        ),
      );
    }
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
      _checkExistingChamadaForDate(picked);
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
    List<Lote> lotes,
  ) async {
    final erros = _validarInvariantes(lotes);
    if (erros.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Invariantes violadas: ${erros.first}'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 1. Checagem de conflitos Cross-Obra na mesma data
      final crossApontamentos =
          await ref.read(chamadaRepositoryProvider).findCrossObraApontamentos(
                construtoraId: widget.construtoraId,
                currentObraId: widget.obraId,
                date: _formattedDate,
              );

      for (final cross in crossApontamentos) {
        final workerInCurrent = _workers
            .where((w) => w.workerId == cross.apontamento.workerId)
            .firstOrNull;
        if (workerInCurrent != null &&
            workerInCurrent.status != PresencaStatus.falta) {
          final conflito = RhInvarianteValidator.validarConflitoCrossObra(
            workerId: workerInCurrent.workerId,
            workerName: workerInCurrent.workerName,
            statusNovo: workerInCurrent.status,
            statusExistenteEmOutraObra: cross.apontamento.status,
            nomeOutraObra: cross.obraId,
          );
          if (conflito != null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.red.shade800,
                  content: Text(conflito),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
            setState(() {
              _isSaving = false;
            });
            return;
          }
        }
      }

      final costResult = CustoMaoDeObraService.computeChamadaCosts(
        funcionarios: allFuncionarios,
        apontamentos: _workers,
      );

      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? 'unknown';
      final userName = user?.displayName ?? uid;
      final equipeName = _selectedTeamId != null
          ? equipes.where((e) => e.id == _selectedTeamId).firstOrNull?.name
          : null;

      String? motivoRetificacao;
      ChamadaAuditEntry? auditEntry;

      // 2. Fluxo de retificação para chamadas já fechadas/retificadas
      if (_existingChamada != null) {
        if (!mounted) return;
        final motivo = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => RetificacaoChamadaDialog(
            totalCostCentsAnterior: _existingChamada!.totalDayCostCents,
            totalCostCentsNovo: costResult.totalDayCostCents,
          ),
        );

        if (motivo == null) {
          setState(() {
            _isSaving = false;
          });
          return;
        }

        motivoRetificacao = motivo;
        auditEntry = ChamadaAuditEntry(
          id: const Uuid().v4(),
          userId: uid,
          userName: userName,
          timestamp: DateTime.now(),
          motivo: motivo,
          totalCostCentsAnterior: _existingChamada!.totalDayCostCents,
          totalCostCentsNovo: costResult.totalDayCostCents,
          versaoAnterior: _existingChamada!.versaoAuditoria,
          snapshotAnterior: _existingChamada!.toMap(),
        );
      }

      final novaVersao = _existingChamada != null
          ? _existingChamada!.versaoAuditoria + 1
          : 1;
      final novoAuditTrail = _existingChamada != null
          ? [..._existingChamada!.auditTrail, ?auditEntry]
          : <ChamadaAuditEntry>[];

      final chamada = ChamadaDiaria(
        id: _existingChamada?.id ?? const Uuid().v4(),
        construtoraId: widget.construtoraId,
        obraId: widget.obraId,
        date: _formattedDate,
        teamId: _selectedTeamId,
        teamName: equipeName,
        createdByUid: _existingChamada?.createdByUid ?? uid,
        defaultLotId: _defaultLotId,
        status: _existingChamada != null ? 'retificada' : 'fechada',
        observacoes: _existingChamada?.observacoes,
        workers: _workers,
        totalDayCostCents: costResult.totalDayCostCents,
        costPolicyVersion: 'v1',
        costPolicy: const CostPolicy(),
        costSnapshots: costResult.costSnapshots,
        lotCostSummaries: costResult.lotCostSummaries,
        versaoAuditoria: novaVersao,
        auditTrail: novoAuditTrail,
        retificadoPor: _existingChamada != null ? userName : null,
        retificadoEm: _existingChamada != null ? DateTime.now() : null,
        motivoRetificacao: motivoRetificacao,
        createdAt: _existingChamada?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        schemaVersion: 1,
      );

      await ref.read(chamadaRepositoryProvider).saveChamada(chamada);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              _existingChamada != null
                  ? 'Chamada retificada e registrada na auditoria com sucesso!'
                  : 'Chamada diária salva e fechada com sucesso!',
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

                return SigoLayout(
                  title: _existingChamada != null
                      ? 'Retificar Chamada Diária'
                      : 'Nova Chamada Diária',
                  activeRoute: '/construtora/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas',
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
                  child: Column(
                    children: [
                      // Cabeçalho de Seleção extraído
                      ChamadaFiltrosHeader(
                        selectedDate: _selectedDate,
                        onPickDate: _pickDate,
                        defaultLotId: _defaultLotId,
                        lotes: lotes,
                        onDefaultLotChanged: _onDefaultLotChanged,
                        selectedTeamId: _selectedTeamId,
                        equipes: equipes,
                        onTeamChanged: (teamId) {
                          _onTeamChanged(teamId, lotes);
                          _syncWorkersList(allFuncionarios, lotes);
                        },
                      ),

                      // Banner de Feedback Preventivo de Invariantes extraído
                      Builder(
                        builder: (context) {
                          final erros = _validarInvariantes(lotes);
                          return ChamadaInvariantesBanner(erros: erros);
                        },
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

                      // Sticky Bottom Bar com Resumo e Botão Salvar extraída
                      Builder(
                        builder: (context) {
                          final currentCosts =
                              CustoMaoDeObraService.computeChamadaCosts(
                            funcionarios: allFuncionarios,
                            apontamentos: _workers,
                          );

                          return ChamadaStickyBottomBar(
                            existingChamada: _existingChamada,
                            currentCosts: currentCosts,
                            formattedDate: _formattedDate,
                            workersCount: _workers.length,
                            presentCount: _presentCount,
                            meioPeriodoCount: _meioPeriodoCount,
                            faltaCount: _faltaCount,
                            isSaving: _isSaving,
                            isFormValid: _isFormValid,
                            onSave: () => _saveChamada(equipes, allFuncionarios, lotes),
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
