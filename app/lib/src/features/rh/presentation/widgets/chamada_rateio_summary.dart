import 'package:flutter/material.dart';

import '../../data/custo_mao_de_obra_service.dart';
import '../../domain/chamada_diaria.dart';
import '../../domain/funcionario.dart';
import 'chamada_sticky_bottom_bar.dart';

class ChamadaRateioSummary extends StatelessWidget {
  final List<ApontamentoTrabalhador> workers;
  final List<Funcionario> funcionarios;
  final ChamadaDiaria? existingChamada;
  final String formattedDate;
  final bool isSaving;
  final bool isFormValid;
  final VoidCallback onSave;

  const ChamadaRateioSummary({
    super.key,
    required this.workers,
    required this.funcionarios,
    required this.existingChamada,
    required this.formattedDate,
    required this.isSaving,
    required this.isFormValid,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final currentCosts = CustoMaoDeObraService.computeChamadaCosts(
      funcionarios: funcionarios,
      apontamentos: workers,
    );

    return ChamadaStickyBottomBar(
      existingChamada: existingChamada,
      currentCosts: currentCosts,
      formattedDate: formattedDate,
      workersCount: workers.length,
      presentCount: workers
          .where((w) => w.status == PresencaStatus.presente)
          .length,
      meioPeriodoCount: workers
          .where((w) => w.status == PresencaStatus.meioPeriodo)
          .length,
      faltaCount: workers.where((w) => w.status == PresencaStatus.falta).length,
      isSaving: isSaving,
      isFormValid: isFormValid,
      onSave: onSave,
    );
  }
}
