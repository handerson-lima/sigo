import 'parcela_compra.dart';

class ParcelamentoComprasMath {
  /// Gera determinística de [numeroParcelas] para o montante [totalCompraCents],
  /// distribuindo o resto da divisão inteira na primeira parcela.
  /// Garante rigorosamente a invariante algébrica:
  /// sum(parcelas.valorCents) == totalCompraCents.
  static List<ParcelaCompra> gerarParcelas({
    required int totalCompraCents,
    required int numeroParcelas,
    required DateTime primeiroVencimento,
    int intervaloDias = 30,
  }) {
    if (totalCompraCents <= 0) {
      throw ArgumentError.value(
        totalCompraCents,
        'totalCompraCents',
        'O valor total da compra deve ser positivo.',
      );
    }
    if (numeroParcelas <= 0) {
      throw ArgumentError.value(
        numeroParcelas,
        'numeroParcelas',
        'O número de parcelas deve ser maior que zero.',
      );
    }

    final baseCents = totalCompraCents ~/ numeroParcelas;
    final restoCents = totalCompraCents % numeroParcelas;

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

      return ParcelaCompra(
        numero: index + 1,
        valorCents: valorParcela,
        dataVencimento: vencimento,
        status: StatusParcelaCompra.pendente,
      );
    });
  }

  /// Soma o valor em centavos de todas as parcelas.
  static int calcularSomaParcelas(List<ParcelaCompra> parcelas) {
    return parcelas.fold<int>(0, (acc, p) => acc + p.valorCents);
  }

  /// Valida se a soma das parcelas é identicamente igual ao total da compra.
  static bool validarInvarianteParcelas({
    required int totalCompraCents,
    required List<ParcelaCompra> parcelas,
  }) {
    if (parcelas.isEmpty) return false;
    return calcularSomaParcelas(parcelas) == totalCompraCents;
  }

  /// Calcula a discrepância em centavos entre o total e a soma das parcelas.
  /// Valor positivo significa que as parcelas somam MENOS que o total (falta alocar).
  /// Valor negativo significa que as parcelas somam MAIS que o total (excesso).
  static int calcularDiscrepanciaCents({
    required int totalCompraCents,
    required List<ParcelaCompra> parcelas,
  }) {
    return totalCompraCents - calcularSomaParcelas(parcelas);
  }
}
