import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/custos_360/domain/rateio_indireto_math.dart';

void main() {
  group('RateioIndiretoMath', () {
    test('distribui R\$ 100,00 (10000 cents) entre 3 lotes com resto de 1 centavo alocado determinístico no 1º lote', () {
      final lotes = ['lote-1', 'lote-2', 'lote-3'];
      final res = RateioIndiretoMath.distribuir(
        totalDespesasIndiretasCents: 10000,
        lotesIds: lotes,
      );

      expect(res['lote-1'], 3334);
      expect(res['lote-2'], 3333);
      expect(res['lote-3'], 3333);

      final soma = res.values.fold(0, (acc, v) => acc + v);
      expect(soma, 10000);
    });

    test('distribui com resto de 2 centavos entre 3 lotes (lote-1 e lote-2 recebem 1 centavo extra)', () {
      final lotes = ['lote-1', 'lote-2', 'lote-3'];
      final res = RateioIndiretoMath.distribuir(
        totalDespesasIndiretasCents: 10001,
        lotesIds: lotes,
      );

      expect(res['lote-1'], 3334);
      expect(res['lote-2'], 3334);
      expect(res['lote-3'], 3333);

      final soma = res.values.fold(0, (acc, v) => acc + v);
      expect(soma, 10001);
    });

    test('distribuição exata sem resto (9000 cents entre 3 lotes)', () {
      final lotes = ['lote-A', 'lote-B', 'lote-C'];
      final res = RateioIndiretoMath.distribuir(
        totalDespesasIndiretasCents: 9000,
        lotesIds: lotes,
      );

      expect(res['lote-A'], 3000);
      expect(res['lote-B'], 3000);
      expect(res['lote-C'], 3000);
      expect(res.values.fold(0, (acc, v) => acc + v), 9000);
    });

    test('lote único recebe 100% da despesa indireta', () {
      final lotes = ['lote-unico'];
      final res = RateioIndiretoMath.distribuir(
        totalDespesasIndiretasCents: 54321,
        lotesIds: lotes,
      );

      expect(res['lote-unico'], 54321);
    });

    test('despesa indireta zero ou negativa retorna zero para todos os lotes', () {
      final lotes = ['l1', 'l2'];
      final resZero = RateioIndiretoMath.distribuir(
        totalDespesasIndiretasCents: 0,
        lotesIds: lotes,
      );
      expect(resZero['l1'], 0);
      expect(resZero['l2'], 0);

      final resNeg = RateioIndiretoMath.distribuir(
        totalDespesasIndiretasCents: -500,
        lotesIds: lotes,
      );
      expect(resNeg['l1'], 0);
      expect(resNeg['l2'], 0);
    });

    test('sem lotes cadastrados não gera divisão por zero', () {
      final res = RateioIndiretoMath.distribuir(
        totalDespesasIndiretasCents: 50000,
        lotesIds: [],
      );
      expect(res.isEmpty, isTrue);
    });

    test('conservação estrita de centavos para valores elevados e número arbitrário de lotes', () {
      final lotes = List.generate(17, (i) => 'lote-$i');
      const totalCents = 123456789; // R$ 1.234.567,89

      final res = RateioIndiretoMath.distribuir(
        totalDespesasIndiretasCents: totalCents,
        lotesIds: lotes,
      );

      final soma = res.values.fold(0, (acc, v) => acc + v);
      expect(soma, totalCents, reason: 'A soma dos rateios deve ser rigorosamente idêntica ao total.');
    });
  });
}
