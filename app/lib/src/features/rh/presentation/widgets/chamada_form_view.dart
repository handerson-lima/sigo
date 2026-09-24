import 'package:flutter/material.dart';

import '../../../../common_widgets/sigo_layout.dart';
import '../../../lotes/domain/lote.dart';
import '../../domain/chamada_diaria.dart';
import '../../domain/equipe.dart';
import '../../domain/funcionario.dart';
import 'apontamento_worker_card.dart';
import 'chamada_filtros_header.dart';
import 'chamada_invariantes_banner.dart';
import 'chamada_rateio_summary.dart';

class ChamadaFormView extends StatelessWidget {
  final String activeRoute;
  final ChamadaDiaria? existingChamada;
  final DateTime selectedDate;
  final String formattedDate;
  final String? selectedTeamId;
  final String? defaultLotId;
  final List<ApontamentoTrabalhador> workers;
  final List<Funcionario> funcionarios;
  final List<Equipe> equipes;
  final List<Lote> lotes;
  final List<String> erros;
  final bool isSaving;
  final bool isFormValid;
  final VoidCallback onPickDate;
  final ValueChanged<String?> onTeamChanged;
  final ValueChanged<String?> onDefaultLotChanged;
  final VoidCallback onMarkAllPresent;
  final void Function(int index, ApontamentoTrabalhador updated)
  onWorkerChanged;
  final VoidCallback onSave;

  const ChamadaFormView({
    super.key,
    required this.activeRoute,
    required this.existingChamada,
    required this.selectedDate,
    required this.formattedDate,
    required this.selectedTeamId,
    required this.defaultLotId,
    required this.workers,
    required this.funcionarios,
    required this.equipes,
    required this.lotes,
    required this.erros,
    required this.isSaving,
    required this.isFormValid,
    required this.onPickDate,
    required this.onTeamChanged,
    required this.onDefaultLotChanged,
    required this.onMarkAllPresent,
    required this.onWorkerChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SigoLayout(
      title: existingChamada != null
          ? 'Retificar Chamada Diária'
          : 'Nova Chamada Diária',
      activeRoute: activeRoute,
      actions: [
        if (lotes.isNotEmpty && workers.isNotEmpty)
          TextButton.icon(
            icon: const Icon(Icons.done_all, color: Colors.green),
            label: const Text(
              'Todos Presentes',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: isSaving ? null : onMarkAllPresent,
          ),
      ],
      child: Column(
        children: [
          ChamadaFiltrosHeader(
            selectedDate: selectedDate,
            onPickDate: onPickDate,
            defaultLotId: defaultLotId,
            lotes: lotes,
            onDefaultLotChanged: onDefaultLotChanged,
            selectedTeamId: selectedTeamId,
            equipes: equipes,
            onTeamChanged: onTeamChanged,
            isSaving: isSaving,
          ),
          ChamadaInvariantesBanner(erros: erros),
          Expanded(
            child: workers.isEmpty
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
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: workers.length,
                    itemBuilder: (context, index) {
                      final worker = workers[index];
                      final func = funcionarios
                          .where((f) => f.id == worker.workerId)
                          .firstOrNull;
                      return ApontamentoWorkerCard(
                        apontamento: worker,
                        availableLotes: lotes,
                        defaultLotId: defaultLotId,
                        baseDailyRateCents: func?.totalDailyRateCents,
                        onChanged: (updated) => onWorkerChanged(index, updated),
                      );
                    },
                  ),
          ),
          ChamadaRateioSummary(
            workers: workers,
            funcionarios: funcionarios,
            existingChamada: existingChamada,
            formattedDate: formattedDate,
            isSaving: isSaving,
            isFormValid: isFormValid,
            onSave: onSave,
          ),
        ],
      ),
    );
  }
}
