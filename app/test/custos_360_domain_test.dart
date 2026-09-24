import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/custos_360/domain/custo_lote_consolidado.dart';

void main() {
  group('CustoLoteConsolidado & ResumoCustosObra Domain Tests', () {
    test('soma exata dos 4 cubos compõe totalCustoLoteCents', () {
      final loteCusto = CustoLoteConsolidado(
        loteId: 'lote-101',
        loteNome: 'Lote 101 - Quadra A',
        materiaisCents: 500000, // R$ 5.000,00
        maoDeObraCents: 800000, // R$ 8.000,00
        despesasDiretasCents: 200000, // R$ 2.000,00
        rateioIndiretoCents: 150000, // R$ 1.500,00
        orcamentoPrevistoCents: 2000000, // R$ 20.000,00
      );

      expect(loteCusto.totalCustoLoteCents, 1650000); // R$ 16.500,00
      expect(loteCusto.totalCustoLote, 16500.0);
      expect(loteCusto.materiais, 5000.0);
      expect(loteCusto.maoDeObra, 8000.0);
      expect(loteCusto.despesasDiretas, 2000.0);
      expect(loteCusto.rateioIndireto, 1500.0);
      expect(loteCusto.orcamentoPrevisto, 20000.0);
      expect(loteCusto.varianciaCents, -350000); // Sobrou R$ 3.500,00
      expect(loteCusto.variancia, -3500.0);
      expect(loteCusto.temDesvioPositivo, isFalse);
      expect(loteCusto.estourado, isFalse);
      expect(loteCusto.percentualConsumido, 1650000 / 2000000);
      expect(loteCusto.emAlerta, isFalse);
    });

    test('alerta orçamentário quando consumo entre 85% e 100%', () {
      final loteEmAlerta = CustoLoteConsolidado(
        loteId: 'lote-102',
        loteNome: 'Lote 102',
        materiaisCents: 450000,
        maoDeObraCents: 450000,
        despesasDiretasCents: 0,
        rateioIndiretoCents: 0,
        orcamentoPrevistoCents: 1000000, // 900.000 de 1.000.000 = 90%
      );

      expect(loteEmAlerta.percentualConsumido, 0.9);
      expect(loteEmAlerta.emAlerta, isTrue);
      expect(loteEmAlerta.estourado, isFalse);
    });

    test('estouro orçamentário com desvio positivo', () {
      final loteEstourado = CustoLoteConsolidado(
        loteId: 'lote-103',
        loteNome: 'Lote 103',
        materiaisCents: 600000,
        maoDeObraCents: 600000,
        despesasDiretasCents: 0,
        rateioIndiretoCents: 0,
        orcamentoPrevistoCents: 1000000, // 1.200.000 de 1.000.000 = 120%
      );

      expect(loteEstourado.totalCustoLoteCents, 1200000);
      expect(loteEstourado.varianciaCents, 200000);
      expect(loteEstourado.variancia, 2000.0);
      expect(loteEstourado.temDesvioPositivo, isTrue);
      expect(loteEstourado.estourado, isTrue);
      expect(loteEstourado.emAlerta, isFalse);
    });

    test('lote zerado inicial sem orçamento não quebra e mantém tudo em 0', () {
      final loteZerado = CustoLoteConsolidado(
        loteId: 'lote-zero',
        loteNome: 'Lote Novo',
        materiaisCents: 0,
        maoDeObraCents: 0,
        despesasDiretasCents: 0,
        rateioIndiretoCents: 0,
        orcamentoPrevistoCents: 0,
      );

      expect(loteZerado.totalCustoLoteCents, 0);
      expect(loteZerado.percentualConsumido, 0.0);
      expect(loteZerado.estourado, isFalse);
      expect(loteZerado.emAlerta, isFalse);
    });

    test('serialização e desserialização de CustoLoteConsolidado e ResumoCustosObra', () {
      final lote = CustoLoteConsolidado(
        loteId: 'lote-1',
        loteNome: 'Lote 1',
        materiaisCents: 1000,
        maoDeObraCents: 2000,
        despesasDiretasCents: 500,
        rateioIndiretoCents: 250,
        orcamentoPrevistoCents: 5000,
      );

      final map = lote.toMap();
      final recovered = CustoLoteConsolidado.fromMap(map);

      expect(recovered.loteId, lote.loteId);
      expect(recovered.loteNome, lote.loteNome);
      expect(recovered.totalCustoLoteCents, lote.totalCustoLoteCents);
      expect(recovered.orcamentoPrevistoCents, lote.orcamentoPrevistoCents);
      expect(recovered.varianciaCents, lote.varianciaCents);

      final resumo = ResumoCustosObra(
        loteamentoId: 'obra-sp-01', quadraId: 'obra-sp-01', status: LoteStatus.noPrazo,
        totalGeralCents: 3750,
        totalMateriaisCents: 1000,
        totalMaoDeObraCents: 2000,
        totalDespesasDiretasCents: 500,
        totalDespesasIndiretasCents: 250,
        orcamentoTotalPrevistoCents: 5000,
        lotesCustos: [recovered],
      );

      final resumoMap = resumo.toMap();
      final recoveredResumo = ResumoCustosObra.fromMap(resumoMap);

      expect(recoveredResumo.obraId, 'obra-sp-01');
      expect(recoveredResumo.totalGeralCents, 3750);
      expect(recoveredResumo.lotesCustos.length, 1);
      expect(recoveredResumo.lotesCustos.first.loteNome, 'Lote 1');
    });

    test('ExtratoItemCusto toMap e fromMap', () {
      final item = ExtratoItemCusto(
        id: 'ext-1',
        cubo: CuboCusto.material,
        descricao: 'Cimento CP-II 50kg (10 sc)',
        data: DateTime(2026, 9, 18, 14, 30),
        valorCents: 45000,
        documentoReferencia: 'NF-12345',
        responsavelNome: 'Almoxarife Carlos',
      );

      final map = item.toMap();
      final rec = ExtratoItemCusto.fromMap(map);

      expect(rec.id, 'ext-1');
      expect(rec.cubo, CuboCusto.material);
      expect(rec.descricao, 'Cimento CP-II 50kg (10 sc)');
      expect(rec.valorCents, 45000);
      expect(rec.valor, 450.0);
      expect(rec.documentoReferencia, 'NF-12345');
      expect(rec.responsavelNome, 'Almoxarife Carlos');
    });
  });
}
