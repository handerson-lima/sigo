import 'despesa_adm.dart';

class ParcelamentoMath {
  /// Gera uma lista determinística de [numeroParcelas] para o montante [totalCents],
  /// distribuindo o resto da divisão inteira na primeira parcela.
  /// Garante a invariante: sum(parcelas.valorCents) == totalCents.
  static List<ParcelaDespesa> gerarParcelas({
    required int totalCents,
    required int numeroParcelas,
    required DateTime primeiroVencimento,
  }) {
    if (totalCents <= 0) {
      throw ArgumentError.value(
        totalCents,
        'totalCents',
        'O valor total deve ser positivo.',
      );
    }
    if (numeroParcelas <= 0) {
      throw ArgumentError.value(
        numeroParcelas,
        'numeroParcelas',
        'O número de parcelas deve ser maior que zero.',
      );
    }

    final baseCents = totalCents ~/ numeroParcelas;
    final restoCents = totalCents % numeroParcelas;

    return List.generate(numeroParcelas, (index) {
      final valorParcela = index == 0 ? baseCents + restoCents : baseCents;

      // Cálculo de vencimento mês a mês mantendo o mesmo dia base ou ajustando para o final do mês
      final anoBase = primeiroVencimento.year;
      final mesBase = primeiroVencimento.month + index;
      final diaBase = primeiroVencimento.day;

      final anoAlvo = anoBase + ((mesBase - 1) ~/ 12);
      final mesAlvo = ((mesBase - 1) % 12) + 1;
      final diasNoMes = DateTime(anoAlvo, mesAlvo + 1, 0).day;
      final diaAjustado = diaBase > diasNoMes ? diasNoMes : diaBase;

      final vencimento = DateTime(anoAlvo, mesAlvo, diaAjustado);

      return ParcelaDespesa(
        numero: index + 1,
        valorCents: valorParcela,
        dataVencimento: vencimento,
        status: StatusDespesaAdm.pendente,
      );
    });
  }

  /// Soma o valor em centavos de todas as parcelas.
  static int calcularSomaParcelas(List<ParcelaDespesa> parcelas) {
    return parcelas.fold<int>(0, (acc, p) => acc + p.valorCents);
  }

  /// Valida se a soma das parcelas é identicamente igual ao valor total do documento.
  static bool validarInvarianteParcelas({
    required int totalCents,
    required List<ParcelaDespesa> parcelas,
  }) {
    if (parcelas.isEmpty) return false;
    return calcularSomaParcelas(parcelas) == totalCents;
  }

  /// Calcula a diferença em centavos entre o total do documento e a soma das parcelas.
  /// Valor positivo significa que as parcelas somam MENOS que o total (falta alocar).
  /// Valor negativo significa que as parcelas somam MAIS que o total (excesso).
  static int calcularDiscrepanciaCents({
    required int totalCents,
    required List<ParcelaDespesa> parcelas,
  }) {
    return totalCents - calcularSomaParcelas(parcelas);
  }
}
