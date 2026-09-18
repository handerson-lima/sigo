import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/compras_parcelas/domain/parcela_compra.dart';
import 'package:app/src/features/compras_parcelas/domain/parcelamento_compras_math.dart';

void main() {
  group('ParcelamentoComprasMath (Invariante Algébrica AD-5)', () {
    test('divide R\$ 1.000,00 (100.000 centavos) em 3 parcelas sem perder centavos', () {
      final primeiroVencimento = DateTime(2026, 10, 10);
      final parcelas = ParcelamentoComprasMath.gerarParcelas(
        totalCompraCents: 100000,
        numeroParcelas: 3,
        primeiroVencimento: primeiroVencimento,
      );

      expect(parcelas.length, 3);
      expect(parcelas[0].valorCents, 33334); // 33333 + 1 de resto
      expect(parcelas[1].valorCents, 33333);
      expect(parcelas[2].valorCents, 33333);

      final soma = ParcelamentoComprasMath.calcularSomaParcelas(parcelas);
      expect(soma, 100000);

      final valida = ParcelamentoComprasMath.validarInvarianteParcelas(
        totalCompraCents: 100000,
        parcelas: parcelas,
      );
      expect(valida, isTrue);

      final discrepancia = ParcelamentoComprasMath.calcularDiscrepanciaCents(
        totalCompraCents: 100000,
        parcelas: parcelas,
      );
      expect(discrepancia, 0);
    });

    test('gera compra em 1 parcela (à vista)', () {
      final primeiroVencimento = DateTime(2026, 9, 20);
      final parcelas = ParcelamentoComprasMath.gerarParcelas(
        totalCompraCents: 365000,
        numeroParcelas: 1,
        primeiroVencimento: primeiroVencimento,
      );

      expect(parcelas.length, 1);
      expect(parcelas[0].numero, 1);
      expect(parcelas[0].valorCents, 365000);
      expect(parcelas[0].valor, 3650.0);
      expect(parcelas[0].status, StatusParcelaCompra.pendente);

      expect(
        ParcelamentoComprasMath.validarInvarianteParcelas(
          totalCompraCents: 365000,
          parcelas: parcelas,
        ),
        isTrue,
      );
    });

    test('detecta discrepância positiva quando a soma das parcelas é menor que o total', () {
      final parcelas = [
        ParcelaCompra(
          numero: 1,
          valorCents: 30000,
          dataVencimento: DateTime(2026, 10, 1),
        ),
        ParcelaCompra(
          numero: 2,
          valorCents: 30000,
          dataVencimento: DateTime(2026, 11, 1),
        ),
      ];

      // Total é 100.000, mas as parcelas somam 60.000
      final valida = ParcelamentoComprasMath.validarInvarianteParcelas(
        totalCompraCents: 100000,
        parcelas: parcelas,
      );
      expect(valida, isFalse);

      final disc = ParcelamentoComprasMath.calcularDiscrepanciaCents(
        totalCompraCents: 100000,
        parcelas: parcelas,
      );
      expect(disc, 40000); // Faltam 40.000 cents
    });

    test('detecta discrepância negativa quando a soma das parcelas é maior que o total', () {
      final parcelas = [
        ParcelaCompra(
          numero: 1,
          valorCents: 60000,
          dataVencimento: DateTime(2026, 10, 1),
        ),
        ParcelaCompra(
          numero: 2,
          valorCents: 50000,
          dataVencimento: DateTime(2026, 11, 1),
        ),
      ];

      // Total é 100.000, soma é 110.000
      final disc = ParcelamentoComprasMath.calcularDiscrepanciaCents(
        totalCompraCents: 100000,
        parcelas: parcelas,
      );
      expect(disc, -10000); // 10.000 cents a mais
    });

    test('ajusta corretamente vencimentos mensais para meses mais curtos', () {
      // 31 de janeiro em 3x -> deve ir para 28 ou 29 de fev, 31 de março
      final primeiroVencimento = DateTime(2026, 1, 31);
      final parcelas = ParcelamentoComprasMath.gerarParcelas(
        totalCompraCents: 30000,
        numeroParcelas: 3,
        primeiroVencimento: primeiroVencimento,
      );

      expect(parcelas[0].dataVencimento, DateTime(2026, 1, 31));
      expect(parcelas[1].dataVencimento, DateTime(2026, 2, 28));
      expect(parcelas[2].dataVencimento, DateTime(2026, 3, 31));
    });

    test('lança ArgumentError para total <= 0 ou numeroParcelas <= 0', () {
      expect(
        () => ParcelamentoComprasMath.gerarParcelas(
          totalCompraCents: 0,
          numeroParcelas: 3,
          primeiroVencimento: DateTime.now(),
        ),
        throwsArgumentError,
      );

      expect(
        () => ParcelamentoComprasMath.gerarParcelas(
          totalCompraCents: 1000,
          numeroParcelas: 0,
          primeiroVencimento: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });
  });
}
