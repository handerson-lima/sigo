/// Algoritmo de Rateio Indireto de Despesas Gerais da Obra.
///
/// Garante a invariante algébrica estrita da conservação de centavos:
/// sum(rateioIndiretoCents) == totalDespesasIndiretasCents.
/// Não utiliza números de ponto flutuante para dinheiro.
class RateioIndiretoMath {
  /// Distribui [totalDespesasIndiretasCents] igualmente entre [lotesIds].
  /// O resto da divisão inteira é distribuído de forma determinística,
  /// 1 centavo para cada um dos primeiros lotes até exaurir o resto.
  static Map<String, int> distribuir({
    required int totalDespesasIndiretasCents,
    required List<String> lotesIds,
  }) {
    if (lotesIds.isEmpty) {
      return const {};
    }
    if (totalDespesasIndiretasCents <= 0) {
      return {for (final id in lotesIds) id: 0};
    }

    final n = lotesIds.length;
    final baseQuota = totalDespesasIndiretasCents ~/ n;
    final resto = totalDespesasIndiretasCents % n;

    final resultado = <String, int>{};
    for (var i = 0; i < n; i++) {
      final extra = i < resto ? 1 : 0;
      resultado[lotesIds[i]] = baseQuota + extra;
    }

    return resultado;
  }
}
