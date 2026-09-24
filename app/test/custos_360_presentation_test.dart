import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/src/features/custos_360/domain/custo_lote_consolidado.dart';
import 'package:app/src/features/custos_360/presentation/controllers/custos_360_controller.dart';
import 'package:app/src/features/custos_360/presentation/lote_custo_detalhe_screen.dart';
import 'package:app/src/features/custos_360/presentation/visao_360_custos_screen.dart';
import 'package:app/src/features/custos_360/presentation/widgets/cubo_custo_card.dart';

void main() {
  group('CuboCustoCard Widget Test', () {
    testWidgets('exibe informações formatadas e percentual correto', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CuboCustoCard(
              cubo: CuboCusto.material,
              valorCents: 250000, // R$ 2.500,00
              totalReferenciaCents: 1000000, // 25.0%
            ),
          ),
        ),
      );

      expect(find.text('Materiais'), findsOneWidget);
      expect(find.text('Almoxarifado'), findsOneWidget);
      expect(find.text('25.0%'), findsOneWidget);
      expect(find.text('R\$ 2.500,00'), findsOneWidget);
    });
  });

  group('Visao360CustosScreen Widget Test', () {
    testWidgets('renderiza kpis executivos, cubos e lista de lotes com orçado vs realizado', (tester) async {
      final mockLote1 = CustoLoteConsolidado(
        loteId: 'lote-1',
        loteNome: 'Lote 01 - Fundações',
        materiaisCents: 500000,
        maoDeObraCents: 800000,
        despesasDiretasCents: 200000,
        rateioIndiretoCents: 100000,
        orcamentoPrevistoCents: 2000000,
      );

      final mockLote2 = CustoLoteConsolidado(
        loteId: 'lote-2',
        loteNome: 'Lote 02 - Alvenaria',
        materiaisCents: 600000,
        maoDeObraCents: 600000,
        despesasDiretasCents: 100000,
        rateioIndiretoCents: 100000,
        orcamentoPrevistoCents: 1000000, // Estourado (1.400.000 > 1.000.000)
      );

      final mockResumo = ResumoCustosObra(
        obraId: 'obra-01',
        totalGeralCents: 3000000,
        totalMateriaisCents: 1100000,
        totalMaoDeObraCents: 1400000,
        totalDespesasDiretasCents: 300000,
        totalDespesasIndiretasCents: 200000,
        orcamentoTotalPrevistoCents: 3000000,
        lotesCustos: [mockLote1, mockLote2],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resumoCustosObraStreamProvider(
              (construtoraId: 'c1', obraId: 'o1'),
            ).overrideWith((ref) => Stream.value(mockResumo)),
          ],
          child: const MaterialApp(
            home: Visao360CustosScreen(
              construtoraId: 'c1',
              obraId: 'o1',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica Cabeçalho e KPIs
      expect(find.text('Visão 360º de Custos'), findsOneWidget);
      expect(find.text('Custo Total Realizado da Obra'), findsOneWidget);
      expect(find.text('R\$ 30.000,00'), findsWidgets);

      // Verifica 4 Cubos
      expect(find.text('Materiais'), findsOneWidget);
      expect(find.text('Mão de Obra'), findsOneWidget);
      expect(find.text('Despesas Diretas'), findsOneWidget);
      expect(find.text('Rateio Indireto'), findsOneWidget);

      // Verifica Lotes
      expect(find.text('Lote 01 - Fundações'), findsOneWidget);
      expect(find.text('Lote 02 - Alvenaria'), findsOneWidget);
      expect(find.text('No Orçamento'), findsOneWidget);
      expect(find.text('Estourado'), findsOneWidget);
    });
  });

  group('LoteCustoDetalheScreen Widget Test', () {
    testWidgets('renderiza detalhamento do lote com abas de extrato analítico', (tester) async {
      final mockLote = CustoLoteConsolidado(
        loteId: 'lote-10',
        loteNome: 'Lote 10 - Estrutura',
        materiaisCents: 400000,
        maoDeObraCents: 600000,
        despesasDiretasCents: 100000,
        rateioIndiretoCents: 50000,
        orcamentoPrevistoCents: 1500000,
      );

      final mockResumo = ResumoCustosObra(
        obraId: 'obra-10',
        totalGeralCents: 1150000,
        totalMateriaisCents: 400000,
        totalMaoDeObraCents: 600000,
        totalDespesasDiretasCents: 100000,
        totalDespesasIndiretasCents: 50000,
        orcamentoTotalPrevistoCents: 1500000,
        lotesCustos: [mockLote],
      );

      final mockExtrato = [
        ExtratoItemCusto(
          id: 'ext-1',
          cubo: CuboCusto.material,
          descricao: 'Aço CA-50 10mm (50 barras)',
          data: DateTime(2026, 9, 18),
          valorCents: 350000,
          documentoReferencia: 'NF-9988',
        ),
        ExtratoItemCusto(
          id: 'ext-2',
          cubo: CuboCusto.maoDeObra,
          descricao: 'Equipe de Armadores',
          data: DateTime(2026, 9, 18),
          valorCents: 600000,
          documentoReferencia: 'Chamada #102',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resumoCustosObraStreamProvider(
              (construtoraId: 'c1', obraId: 'o1'),
            ).overrideWith((ref) => Stream.value(mockResumo)),
            extratoLoteFutureProvider(
              (construtoraId: 'c1', obraId: 'o1', loteId: 'lote-10'),
            ).overrideWith((ref) => Future.value(mockExtrato)),
          ],
          child: const MaterialApp(
            home: LoteCustoDetalheScreen(
              construtoraId: 'c1',
              obraId: 'o1',
              loteId: 'lote-10',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Lote 10 - Estrutura'), findsWidgets);
      expect(find.text('Custo Acumulado do Lote'), findsOneWidget);
      expect(find.text('Extrato Analítico de Lançamentos'), findsOneWidget);
      expect(find.text('Aço CA-50 10mm (50 barras)'), findsOneWidget);
      expect(find.text('Equipe de Armadores'), findsOneWidget);
    });
  });
}
