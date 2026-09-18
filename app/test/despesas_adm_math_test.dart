import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/despesas_adm/domain/despesa_adm.dart';
import 'package:app/src/features/despesas_adm/domain/parcelamento_math.dart';

void main() {
  group('ParcelamentoMath Invariant Tests', () {
    test('Divisão exata sem resto (R\$ 300,00 em 3 parcelas)', () {
      final primeiroVencimento = DateTime(2026, 10, 10);
      final parcelas = ParcelamentoMath.gerarParcelas(
        totalCents: 30000,
        numeroParcelas: 3,
        primeiroVencimento: primeiroVencimento,
      );

      expect(parcelas.length, 3);
      expect(parcelas[0].valorCents, 10000);
      expect(parcelas[1].valorCents, 10000);
      expect(parcelas[2].valorCents, 10000);

      expect(ParcelamentoMath.calcularSomaParcelas(parcelas), 30000);
      expect(
        ParcelamentoMath.validarInvarianteParcelas(
          totalCents: 30000,
          parcelas: parcelas,
        ),
        isTrue,
      );
      expect(
        ParcelamentoMath.calcularDiscrepanciaCents(
          totalCents: 30000,
          parcelas: parcelas,
        ),
        0,
      );
    });

    test('Divisão com resto de centavos (R\$ 100,00 em 3 parcelas)', () {
      final primeiroVencimento = DateTime(2026, 10, 15);
      final parcelas = ParcelamentoMath.gerarParcelas(
        totalCents: 10000,
        numeroParcelas: 3,
        primeiroVencimento: primeiroVencimento,
      );

      expect(parcelas.length, 3);
      expect(parcelas[0].valorCents, 3334);
      expect(parcelas[1].valorCents, 3333);
      expect(parcelas[2].valorCents, 3333);

      expect(ParcelamentoMath.calcularSomaParcelas(parcelas), 10000);
      expect(
        ParcelamentoMath.validarInvarianteParcelas(
          totalCents: 10000,
          parcelas: parcelas,
        ),
        isTrue,
      );
    });

    test('Divisão com resto complexo (R\$ 1.234,57 em 7 parcelas)', () {
      const totalCents = 123457; // R$ 1.234,57
      final parcelas = ParcelamentoMath.gerarParcelas(
        totalCents: totalCents,
        numeroParcelas: 7,
        primeiroVencimento: DateTime(2026, 1, 15),
      );

      expect(parcelas.length, 7);
      expect(ParcelamentoMath.calcularSomaParcelas(parcelas), totalCents);
      expect(
        ParcelamentoMath.validarInvarianteParcelas(
          totalCents: totalCents,
          parcelas: parcelas,
        ),
        isTrue,
      );
    });

    test('Parcelamento em 12x (R\$ 5.000,00)', () {
      const totalCents = 500000;
      final parcelas = ParcelamentoMath.gerarParcelas(
        totalCents: totalCents,
        numeroParcelas: 12,
        primeiroVencimento: DateTime(2026, 5, 20),
      );

      expect(parcelas.length, 12);
      expect(ParcelamentoMath.calcularSomaParcelas(parcelas), totalCents);
      expect(
        ParcelamentoMath.validarInvarianteParcelas(
          totalCents: totalCents,
          parcelas: parcelas,
        ),
        isTrue,
      );
    });

    test('Ajuste correto de vencimento em virada de ano e dia 31', () {
      final parcelas = ParcelamentoMath.gerarParcelas(
        totalCents: 60000,
        numeroParcelas: 4,
        primeiroVencimento: DateTime(2026, 12, 31),
      );

      expect(parcelas[0].dataVencimento, DateTime(2026, 12, 31));
      // Jan tem 31 dias
      expect(parcelas[1].dataVencimento, DateTime(2027, 1, 31));
      // Fev/2027 tem 28 dias -> ajustado para dia 28
      expect(parcelas[2].dataVencimento, DateTime(2027, 2, 28));
      // Mar tem 31 dias
      expect(parcelas[3].dataVencimento, DateTime(2027, 3, 31));
    });

    test('Rejeição de parâmetros inválidos (total <= 0 ou parcelas <= 0)', () {
      expect(
        () => ParcelamentoMath.gerarParcelas(
          totalCents: 0,
          numeroParcelas: 3,
          primeiroVencimento: DateTime.now(),
        ),
        throwsArgumentError,
      );

      expect(
        () => ParcelamentoMath.gerarParcelas(
          totalCents: 1000,
          numeroParcelas: 0,
          primeiroVencimento: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });

    test('Detecção de discrepância quando usuário altera parcelas manualmente', () {
      final parcelasOriginais = ParcelamentoMath.gerarParcelas(
        totalCents: 10000,
        numeroParcelas: 2,
        primeiroVencimento: DateTime(2026, 1, 1),
      );

      // Usuário altera parcela 1 para 4999 centavos
      final parcelasAlteradas = [
        parcelasOriginais[0].copyWith(valorCents: 4999),
        parcelasOriginais[1], // 5000 centavos
      ];

      expect(
        ParcelamentoMath.validarInvarianteParcelas(
          totalCents: 10000,
          parcelas: parcelasAlteradas,
        ),
        isFalse,
      );
      // Faltou 1 centavo (10000 - 9999 = 1)
      expect(
        ParcelamentoMath.calcularDiscrepanciaCents(
          totalCents: 10000,
          parcelas: parcelasAlteradas,
        ),
        1,
      );
    });
  });

  group('DespesaAdm Entity & Lifecycle Tests', () {
    test('Serialização e desserialização JSON completas', () {
      final despesa = DespesaAdm(
        id: 'desp_123',
        construtoraId: 'const_1',
        obraId: 'obra_1',
        descricao: 'Locação de Betoneira',
        categoria: CategoriaDespesa.locacao,
        fornecedorNome: 'Equipamentos Alfa',
        fornecedorId: 'forn_99',
        loteId: 'lote_04',
        valorTotalCents: 75000,
        status: StatusDespesaAdm.pendente,
        dataEmissao: DateTime(2026, 9, 10),
        dataVencimento: DateTime(2026, 10, 10),
        isParcelado: false,
        parcelas: const [],
        responsavelId: 'user_456',
        createdAt: DateTime(2026, 9, 10, 8, 30),
        updatedAt: DateTime(2026, 9, 10, 8, 30),
      );

      final json = despesa.toJson();
      expect(json['id'], 'desp_123');
      expect(json['categoria'], 'locacao');
      expect(json['valorTotalCents'], 75000);
      expect(json['valor'], 750.0);
      expect(json['status'], 'pendente');
      expect(json['loteId'], 'lote_04');

      final deserializada = DespesaAdm.fromJson(json);
      expect(deserializada.id, despesa.id);
      expect(deserializada.categoria, CategoriaDespesa.locacao);
      expect(deserializada.valorTotalCents, 75000);
      expect(deserializada.loteId, 'lote_04');
    });

    test('Cálculo de saldo devedor e valor pago para despesa parcelada', () {
      final parcelas = [
        ParcelaDespesa(
          numero: 1,
          valorCents: 5000,
          dataVencimento: DateTime(2026, 9, 1),
          status: StatusDespesaAdm.pago,
        ),
        ParcelaDespesa(
          numero: 2,
          valorCents: 5000,
          dataVencimento: DateTime(2026, 10, 1),
          status: StatusDespesaAdm.pendente,
        ),
      ];

      final despesa = DespesaAdm(
        id: 'desp_parc',
        construtoraId: 'c1',
        obraId: 'o1',
        descricao: 'Serviço de Topografia',
        categoria: CategoriaDespesa.servicosTerceiros,
        valorTotalCents: 10000,
        status: StatusDespesaAdm.pendente,
        dataEmissao: DateTime(2026, 8, 1),
        dataVencimento: DateTime(2026, 10, 1),
        isParcelado: true,
        parcelas: parcelas,
        responsavelId: 'u1',
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      );

      expect(despesa.valorPagoCents, 5000);
      expect(despesa.saldoDevedorCents, 5000);
    });

    test('Identificação de vencimento atrasado (isVencida)', () {
      final despesaVencida = DespesaAdm(
        id: 'desp_old',
        construtoraId: 'c1',
        obraId: 'o1',
        descricao: 'Conta de Energia Antiga',
        categoria: CategoriaDespesa.utilidades,
        valorTotalCents: 20000,
        status: StatusDespesaAdm.pendente,
        dataEmissao: DateTime(2026, 1, 1),
        dataVencimento: DateTime(2026, 2, 1), // Vencida
        responsavelId: 'u1',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(despesaVencida.isVencida, isTrue);

      final despesaPaga = despesaVencida.copyWith(status: StatusDespesaAdm.pago);
      expect(despesaPaga.isVencida, isFalse);
    });
  });
}
