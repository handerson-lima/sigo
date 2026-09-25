import 'chamada_diaria.dart';

class RhInvarianteValidator {
  static List<String> validarApontamento(ApontamentoTrabalhador apontamento) {
    final erros = <String>[];

    switch (apontamento.status) {
      case PresencaStatus.presente:
        if (apontamento.allocations.isEmpty) {
          erros.add(
            'Trabalhador presente deve ter ao menos 1 lote alocado: ${apontamento.workerName}.',
          );
        } else if (apontamento.totalPercentage != 100) {
          erros.add(
            'Alocação de trabalhador presente deve somar exatamente 100% '
            '(atual: ${apontamento.totalPercentage}% para ${apontamento.workerName}).',
          );
        }
        break;

      case PresencaStatus.meioPeriodo:
        if (apontamento.allocations.isEmpty) {
          erros.add(
            'Trabalhador em meio-período deve ter ao menos 1 lote alocado: ${apontamento.workerName}.',
          );
        } else if (apontamento.totalPercentage != 50) {
          erros.add(
            'Alocação de trabalhador em meio-período deve somar exatamente 50% '
            '(atual: ${apontamento.totalPercentage}% para ${apontamento.workerName}).',
          );
        }
        break;

      case PresencaStatus.falta:
        if (apontamento.allocations.isNotEmpty) {
          erros.add(
            'Trabalhador com falta não pode ter lotes alocados: ${apontamento.workerName}.',
          );
        }
        break;
    }

    return erros;
  }

  static List<String> validarChamada({
    required List<ApontamentoTrabalhador> apontamentos,
    Set<String>? lotesValidosDaObra,
  }) {
    final erros = <String>[];
    final operariosVistos = <String>{};

    for (final ap in apontamentos) {
      // Unicidade nominal na chamada
      if (!operariosVistos.add(ap.workerId)) {
        erros.add(
          'Colaborador duplicado na chamada: ${ap.workerName} (ID: ${ap.workerId}).',
        );
      }

      // Invariantes de presença
      erros.addAll(validarApontamento(ap));

      // Pertencimento de lotes à obra
      if (lotesValidosDaObra != null && lotesValidosDaObra.isNotEmpty) {
        for (final alloc in ap.allocations) {
          if (!lotesValidosDaObra.contains(alloc.lotId)) {
            erros.add(
              'Lote inválido ou não pertencente ao loteamento: ${alloc.lotName} (ID: ${alloc.lotId}).',
            );
          }
        }
      }
    }

    return erros;
  }

  static String? validarConflitoCrossObra({
    required String workerId,
    required String workerName,
    required PresencaStatus statusNovo,
    required PresencaStatus statusExistenteEmOutraObra,
    required String nomeOutraObra,
  }) {
    if (statusExistenteEmOutraObra == PresencaStatus.falta) {
      return null;
    }

    if (statusExistenteEmOutraObra == PresencaStatus.presente) {
      return 'Colaborador $workerName já possui apontamento em tempo integral (100%) no loteamento "$nomeOutraObra" nesta mesma data.';
    }

    if (statusExistenteEmOutraObra == PresencaStatus.meioPeriodo) {
      if (statusNovo == PresencaStatus.presente) {
        return 'Colaborador $workerName já possui meio-período (50%) no loteamento "$nomeOutraObra". Alocação em tempo integral (100%) excederia o limite diário de 100%.';
      }
    }

    return null;
  }
}
