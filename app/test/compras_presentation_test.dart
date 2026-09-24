import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/src/features/compras_parcelas/data/compras_repository.dart';
import 'package:app/src/features/compras_parcelas/domain/compra_nf.dart';
import 'package:app/src/features/compras_parcelas/domain/item_compra.dart';
import 'package:app/src/features/compras_parcelas/domain/parcela_compra.dart';
import 'package:app/src/common_widgets/sigo_layout.dart';
import 'package:app/src/features/compras_parcelas/presentation/compras_list_screen.dart';
import 'package:app/src/features/compras_parcelas/presentation/compra_detalhes_screen.dart';
import 'package:app/src/features/compras_parcelas/presentation/widgets/liquidar_parcela_dialog.dart';
import 'package:app/src/features/compras_parcelas/presentation/widgets/receber_materiais_dialog.dart';

void main() {
  group('Compras Presentation & Widget Tests', () {
    final now = DateTime(2026, 9, 18);

    final mockCompras = [
      CompraNf(
        id: 'compra-1',
        construtoraId: 'c1',
        loteamentoId: 'l1', quadraId: 'q1', status: LoteStatus.noPrazo,
        fornecedorId: 'f1',
        fornecedorNome: 'Votorantim Cimentos S/A',
        fornecedorDocumento: '01234567000189',
        numeroNf: '12345',
        serieNf: '1',
        dataEmissao: now,
        status: StatusCompra.parcial,
        statusRecebimento: StatusRecebimentoCompra.parcial,
        valorItensCents: 350000,
        freteCents: 15000,
        despesasAcessoriasCents: 0,
        descontoCents: 0,
        totalCompraCents: 365000,
        itens: [
          const ItemCompraNf(
            id: 'item-1',
            materialId: 'mat-1',
            materialNome: 'Cimento CP II-E-32',
            unidadeMedida: 'sc',
            quantidade: 100.0,
            valorUnitarioCents: 3500,
            valorTotalCents: 350000,
            quantidadeRecebida: 50.0,
          ),
        ],
        parcelas: [
          ParcelaCompra(
            numero: 1,
            valorCents: 182500,
            dataVencimento: now,
            status: StatusParcelaCompra.pago,
            dataPagamento: now,
            metodoPagamento: MetodoPagamentoCompra.pix,
          ),
          ParcelaCompra(
            numero: 2,
            valorCents: 182500,
            dataVencimento: now.add(const Duration(days: 30)),
            status: StatusParcelaCompra.pendente,
          ),
        ],
        criadoPorUid: 'uid1',
        createdAt: now,
        updatedAt: now,
      ),
      CompraNf(
        id: 'compra-2',
        construtoraId: 'c1',
        loteamentoId: 'l1', quadraId: 'q1', status: LoteStatus.noPrazo,
        fornecedorId: 'f2',
        fornecedorNome: 'Gerdau Aços S/A',
        numeroNf: '54321',
        dataEmissao: now,
        status: StatusCompra.pago,
        statusRecebimento: StatusRecebimentoCompra.recebido,
        valorItensCents: 500000,
        totalCompraCents: 500000,
        itens: [
          const ItemCompraNf(
            id: 'item-2',
            materialId: 'mat-2',
            materialNome: 'Aço CA-50 10mm',
            unidadeMedida: 'barra',
            quantidade: 50.0,
            valorUnitarioCents: 10000,
            valorTotalCents: 500000,
            quantidadeRecebida: 50.0,
          ),
        ],
        parcelas: [
          ParcelaCompra(
            numero: 1,
            valorCents: 500000,
            dataVencimento: now,
            status: StatusParcelaCompra.pago,
            dataPagamento: now,
          ),
        ],
        criadoPorUid: 'uid1',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    testWidgets('ComprasListScreen renderiza métricas financeiras e lista de compras',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            comprasObraStreamProvider.overrideWith((ref, arg) {
              return Stream.value(mockCompras);
            }),
          ],
          child: const MaterialApp(
            home: ComprasListScreen(
              construtoraId: 'c1',
              loteamentoId: 'l1', quadraId: 'q1', status: LoteStatus.noPrazo,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Métricas
      expect(find.text('Total Comprado'), findsOneWidget);
      expect(find.text('Total Pago'), findsOneWidget);
      expect(find.text('A Pagar'), findsOneWidget);

      // Valores formatados:
      // Total Comprado: 3650 + 5000 = 8650.00
      expect(find.text('R\$ 8650.00'), findsOneWidget);
      // Total Pago: 1825 + 5000 = 6825.00
      expect(find.text('R\$ 6825.00'), findsOneWidget);
      // A Pagar: 1825.00
      expect(find.text('R\$ 1825.00'), findsOneWidget);

      // Itens da lista
      expect(find.textContaining('NF 12345'), findsOneWidget);
      expect(find.text('Votorantim Cimentos S/A'), findsOneWidget);
      expect(find.textContaining('NF 54321'), findsOneWidget);
      expect(find.text('Gerdau Aços S/A'), findsOneWidget);

      // FAB de Nova Compra
      expect(find.text('Nova Compra / NF'), findsOneWidget);
    });

    testWidgets('CompraDetalhesScreen exibe composição financeira, itens e botão liquidar',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            compraDetailsFutureProvider.overrideWith((ref, arg) {
              return Future.value(mockCompras[0]);
            }),
          ],
          child: const MaterialApp(
            home: CompraDetalhesScreen(
              construtoraId: 'c1',
              loteamentoId: 'l1', quadraId: 'q1', status: LoteStatus.noPrazo,
              compraId: 'compra-1',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Cabeçalho
      expect(find.textContaining('Nota Fiscal: 12345'), findsOneWidget);
      expect(find.text('Votorantim Cimentos S/A'), findsOneWidget);
      expect(find.text('CNPJ/CPF: 01234567000189'), findsOneWidget);

      // Resumo financeiro
      expect(find.text('Composição Financeira da Compra'), findsOneWidget);
      expect(find.text('R\$ 3650.00'), findsOneWidget); // Total da compra
      expect(find.text('R\$ 1825.00'), findsNWidgets(4)); // Total pago, saldo, parcela 1, parcela 2

      // Seção de Itens e ação de recebimento
      expect(find.textContaining('Itens Faturados'), findsOneWidget);
      expect(find.text('Cimento CP II-E-32'), findsOneWidget);
      expect(find.text('Receber no Estoque'), findsOneWidget);

      // Seção de Parcelas
      expect(find.textContaining('Parcelas e Vencimentos'), findsOneWidget);
      expect(find.text('Liquidar'), findsOneWidget); // Apenas na parcela 2 que está pendente
    });

    testWidgets('LiquidarParcelaDialog exibe dados da parcela e confirma quitação',
        (tester) async {
      final parcela = mockCompras[0].parcelas[1];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => LiquidarParcelaDialog(
                      parcela: parcela,
                      fornecedorNome: 'Votorantim Cimentos S/A',
                    ),
                  );
                },
                child: const Text('Abrir Dialog'),
              ),
            ),
          ),
        ),
      );

      // Clica para abrir o modal
      await tester.tap(find.text('Abrir Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Liquidar Parcela 2'), findsOneWidget);
      expect(find.text('Fornecedor: Votorantim Cimentos S/A'), findsOneWidget);
      expect(find.text('R\$ 1825.00'), findsOneWidget);
      expect(find.text('Confirmar Liquidação'), findsOneWidget);
    });

    testWidgets('ReceberMateriaisDialog calcula quantidades pendentes e botão receber tudo',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => ReceberMateriaisDialog(
                      compra: mockCompras[0],
                    ),
                  );
                },
                child: const Text('Abrir Recebimento'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Recebimento'));
      await tester.pumpAndSettle();

      expect(find.text('Receber Materiais no Almoxarifado'), findsOneWidget);
      expect(find.text('Receber Saldo Total'), findsOneWidget);
      expect(find.text('Cimento CP II-E-32'), findsOneWidget);
      expect(find.textContaining('Saldo Pendente: 50.0'), findsOneWidget);
      expect(find.text('Confirmar Entrada no Estoque'), findsOneWidget);
    });

    testWidgets('Telas de compras utilizam SigoLayout com sidebar e topbar',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            comprasObraStreamProvider.overrideWith((ref, arg) {
              return Stream.value(mockCompras);
            }),
          ],
          child: const MaterialApp(
            home: ComprasListScreen(
              construtoraId: 'c1',
              loteamentoId: 'l1', quadraId: 'q1', status: LoteStatus.noPrazo,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(SigoLayout), findsOneWidget);
      expect(find.text('Compras e Notas Fiscais'), findsOneWidget);
    });
  });
}
