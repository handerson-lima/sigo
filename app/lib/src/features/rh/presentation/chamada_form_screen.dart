import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../authentication/data/auth_repository.dart';
import '../../lotes/data/lote_repository.dart';
import '../../lotes/domain/lote.dart';
import '../../lotes/presentation/widgets/lote_hierarchy_selector.dart';
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
import 'widgets/chamada_form_view.dart';
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
  String? _loteamentoId;
  String? _quadraId;
  final List<ApontamentoTrabalhador> _workers = [];
  bool _isSaving = false;
  bool _initialized = false;
  ChamadaDiaria? _existingChamada;

  String get _formattedDate => DateFormat('yyyy-MM-dd').format(_selectedDate);

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
    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
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
    if (_isSaving || !mounted) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && picked != _selectedDate && mounted) {
      setState(() {
        _selectedDate = picked;
      });
      _checkExistingChamadaForDate(picked);
    }
  }

  void _syncWorkersList(List<Funcionario> allFuncionarios, List<Lote> lotes) {
    if (_existingChamada != null) return; // Não sobrescreve chamada existente

    final activeFuncionarios = allFuncionarios
        .where((f) => f.isActive)
        .toList();
    final filtered = _selectedTeamId == null || _selectedTeamId!.isEmpty
        ? activeFuncionarios
        : activeFuncionarios.where((f) => f.teamId == _selectedTeamId).toList();

    if (_workers.isEmpty || _workers.length != filtered.length) {
      final targetLot =
          lotes.where((l) => l.id == _defaultLotId).firstOrNull ??
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
    if (_isSaving || !mounted) return;
    setState(() {
      _selectedTeamId = teamId;
      _workers.clear(); // Limpa para recalcular pela equipe
    });

    if (teamId != null && teamId.isNotEmpty) {
      final savedLot = await ref
          .read(lotePersistidoServiceProvider)
          .getDefaultLot(obraId: widget.obraId, teamId: teamId);
      if (savedLot != null &&
          lotes.any((l) => l.id == savedLot) &&
          mounted &&
          !_isSaving) {
        setState(() {
          _defaultLotId = savedLot;
        });
      }
    }
  }

  void _onDefaultLotChanged(String? lotId) {
    if (_isSaving || !mounted) return;
    setState(() {
      _defaultLotId = lotId;
    });
    if (lotId != null &&
        _selectedTeamId != null &&
        _selectedTeamId!.isNotEmpty) {
      ref
          .read(lotePersistidoServiceProvider)
          .saveDefaultLot(
            obraId: widget.obraId,
            teamId: _selectedTeamId!,
            lotId: lotId,
          );
    }
  }

  void _markAllPresent(List<Lote> lotes) {
    if (_isSaving || !mounted) return;
    final targetLot =
        lotes.where((l) => l.id == _defaultLotId).firstOrNull ??
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
    if (_isSaving || !mounted) return;
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

    final repo = ref.read(chamadaRepositoryProvider);
    final user = ref.read(authRepositoryProvider).currentUser;
    final uid = user?.uid ?? 'unknown';
    final userName = user?.displayName ?? uid;
    final date = _formattedDate;
    final teamId = _selectedTeamId;
    final teamName = teamId != null
        ? equipes.where((e) => e.id == teamId).firstOrNull?.name
        : null;
    final defaultLotId = _defaultLotId;
    final existing = _existingChamada;
    final funcionarios = List<Funcionario>.unmodifiable(allFuncionarios);
    final workers = [
      for (final w in _workers)
        w.copyWith(allocations: List<AlocacaoLote>.unmodifiable(w.allocations)),
    ];

    try {
      final crossApontamentos = await repo.findCrossObraApontamentos(
        construtoraId: widget.construtoraId,
        currentObraId: widget.obraId,
        date: date,
      );
      if (!mounted) return;

      for (final cross in crossApontamentos) {
        final workerInCurrent = workers
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
            return;
          }
        }
      }

      final costResult = CustoMaoDeObraService.computeChamadaCosts(
        funcionarios: funcionarios,
        apontamentos: workers,
      );

      String? motivoRetificacao;
      ChamadaAuditEntry? auditEntry;

      if (existing != null) {
        if (!mounted) return;
        final motivo = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => RetificacaoChamadaDialog(
            totalCostCentsAnterior: existing.totalDayCostCents,
            totalCostCentsNovo: costResult.totalDayCostCents,
          ),
        );
        if (!mounted) return;
        if (motivo == null) return;

        motivoRetificacao = motivo;
        auditEntry = ChamadaAuditEntry(
          id: const Uuid().v4(),
          userId: uid,
          userName: userName,
          timestamp: DateTime.now(),
          motivo: motivo,
          totalCostCentsAnterior: existing.totalDayCostCents,
          totalCostCentsNovo: costResult.totalDayCostCents,
          versaoAnterior: existing.versaoAuditoria,
          snapshotAnterior: existing.toMap(),
        );
      }

      final chamada = ChamadaDiaria(
        id: existing?.id ?? const Uuid().v4(),
        construtoraId: widget.construtoraId,
        obraId: widget.obraId,
        date: date,
        teamId: teamId,
        teamName: teamName,
        createdByUid: existing?.createdByUid ?? uid,
        defaultLotId: defaultLotId,
        status: existing != null ? 'retificada' : 'fechada',
        observacoes: existing?.observacoes,
        workers: workers,
        totalDayCostCents: costResult.totalDayCostCents,
        costPolicyVersion: 'v1',
        costPolicy: const CostPolicy(),
        costSnapshots: costResult.costSnapshots,
        lotCostSummaries: costResult.lotCostSummaries,
        versaoAuditoria: existing != null ? existing.versaoAuditoria + 1 : 1,
        auditTrail: existing != null
            ? [...existing.auditTrail, ?auditEntry]
            : <ChamadaAuditEntry>[],
        retificadoPor: existing != null ? userName : null,
        retificadoEm: existing != null ? DateTime.now() : null,
        motivoRetificacao: motivoRetificacao,
        createdAt: existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        schemaVersion: 1,
      );

      await repo.saveChamada(chamada);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              existing != null
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
    final funcionariosAsync = ref.watch(
      funcionariosStreamProvider(widget.construtoraId),
    );
    final equipesAsync = ref.watch(equipesStreamProvider(widget.construtoraId));
    final lotesAsync = (_loteamentoId != null && _quadraId != null)
        ? ref.watch(
            watchLotesProvider((
              construtoraId: widget.construtoraId,
              loteamentoId: _loteamentoId!,
              quadraId: _quadraId!,
            )),
          )
        : const AsyncData<List<Lote>>([]);
    final lotes = lotesAsync.value ?? [];
    final lotesComErro =
        _loteamentoId != null && _quadraId != null && lotesAsync.hasError;

    final hierarchySelector = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LoteHierarchySelector(
          construtoraId: widget.construtoraId,
          loteamentoId: _loteamentoId,
          quadraId: _quadraId,
          loteId: _defaultLotId,
          enabled: !_isSaving,
          showLoteField: false,
          onLoteamentoChanged: (val) {
            setState(() {
              _loteamentoId = val;
              _quadraId = null;
              _defaultLotId = null;
            });
          },
          onQuadraChanged: (val) {
            setState(() {
              _quadraId = val;
              _defaultLotId = null;
            });
          },
        ),
        if (lotesComErro)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Não foi possível carregar os lotes.'),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(
                    watchLotesProvider((
                      construtoraId: widget.construtoraId,
                      loteamentoId: _loteamentoId!,
                      quadraId: _quadraId!,
                    )),
                  ),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
      ],
    );

    return funcionariosAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
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
            if (_initialized &&
                _workers.isEmpty &&
                _existingChamada == null) {
              _syncWorkersList(allFuncionarios, lotes);
            }

            return ChamadaFormView(
              activeRoute:
                  '/construtora/${widget.construtoraId}/obra/${widget.obraId}/rh/chamadas',
              existingChamada: _existingChamada,
              selectedDate: _selectedDate,
              formattedDate: _formattedDate,
              selectedTeamId: _selectedTeamId,
              defaultLotId: _defaultLotId,
              workers: _workers,
              funcionarios: allFuncionarios,
              equipes: equipes,
              lotes: lotes,
              hierarchySelector: hierarchySelector,
              erros: _validarInvariantes(lotes),
              isSaving: _isSaving,
              isFormValid: _isFormValid,
              onPickDate: _pickDate,
              onTeamChanged: (teamId) {
                if (_isSaving) return;
                _onTeamChanged(teamId, lotes);
                _syncWorkersList(allFuncionarios, lotes);
              },
              onDefaultLotChanged: _onDefaultLotChanged,
              onMarkAllPresent: () => _markAllPresent(lotes),
              onWorkerChanged: (index, updated) {
                if (_isSaving || !mounted) return;
                setState(() {
                  _workers[index] = updated;
                });
              },
              onSave: () => _saveChamada(equipes, allFuncionarios, lotes),
            );
          },
        );
      },
    );
  }
}
