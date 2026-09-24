import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/despesas_adm/domain/despesa_adm.dart';
import 'package:app/src/features/despesas_adm/presentation/widgets/despesa_card.dart';

void main() {
  group('DespesaCard Widget Tests', () {
    testWidgets('Renderiza despesa à vista pendente com valor e badges',
        (tester) async {
      final despesa = DespesaAdm(
        id: 'd1',
        construtoraId: 'c1',
        loteamentoId: 'l1', quadraId: 'q1', status: LoteStatus.noPrazo,
        descricao: 'Locação de Andaimes Fachadeiros',
        categoria: CategoriaDespesa.locacao,
        fornecedorNome: 'Andaimes Top',
        valorTotalCents: 150000,
        status: StatusDespesaAdm.pendente,
        dataEmissao: DateTime(2026, 9, 1),
        dataVencimento: DateTime(2026, 10, 10),
        responsavelId: 'u1',
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );

      bool liquidarClicado = false;
      bool cancelarClicado = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DespesaCard(
              despesa: despesa,
              onLiquidar: () => liquidarClicado = true,
              onCancelar: () => cancelarClicado = true,
            ),
          ),
        ),
      );

      expect(find.text('Locação de Andaimes Fachadeiros'), findsOneWidget);
      expect(find.text('Andaimes Top'), findsOneWidget);
      expect(find.textContaining('1.500,00'), findsOneWidget);
      expect(find.text('Pendente'), findsOneWidget);
      expect(find.text('Liquidar / Pagar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      await tester.tap(find.text('Liquidar / Pagar'));
      await tester.pump();
      expect(liquidarClicado, isTrue);

      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      expect(cancelarClicado, isTrue);
    });

    testWidgets('Renderiza despesa parcelada com progresso e lote associado',
        (tester) async {
      final parcelas = [
        ParcelaDespesa(
          numero: 1,
          valorCents: 50000,
          dataVencimento: DateTime(2026, 9, 1),
          status: StatusDespesaAdm.pago,
        ),
        ParcelaDespesa(
          numero: 2,
          valorCents: 50000,
          dataVencimento: DateTime(2026, 10, 1),
          status: StatusDespesaAdm.pendente,
        ),
      ];

      final despesa = DespesaAdm(
        id: 'd2',
        construtoraId: 'c1',
        loteamentoId: 'l1', quadraId: 'q1', status: LoteStatus.noPrazo,
        descricao: 'Pintura Externa Especial',
        categoria: CategoriaDespesa.servicosTerceiros,
        loteId: 'Lote 12',
        valorTotalCents: 100000,
        status: StatusDespesaAdm.pendente,
        dataEmissao: DateTime(2026, 8, 1),
        dataVencimento: DateTime(2026, 10, 1),
        isParcelado: true,
        parcelas: parcelas,
        responsavelId: 'u1',
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DespesaCard(despesa: despesa),
          ),
        ),
      );

      expect(find.text('Pintura Externa Especial'), findsOneWidget);
      expect(find.text('Lote: Lote 12'), findsOneWidget);
      expect(find.text('2x parcelas'), findsOneWidget);
      expect(find.textContaining('Pago:'), findsOneWidget);
      expect(find.textContaining('Saldo:'), findsOneWidget);
      expect(find.textContaining('500,00'), findsAtLeastNWidgets(2));
    });

    testWidgets('Despesa paga não exibe botões de liquidação/cancelamento',
        (tester) async {
      final despesa = DespesaAdm(
        id: 'd3',
        construtoraId: 'c1',
        loteamentoId: 'l1', quadraId: 'q1', status: LoteStatus.noPrazo,
        descricao: 'Conta de Água Provisória',
        categoria: CategoriaDespesa.utilidades,
        valorTotalCents: 25000,
        status: StatusDespesaAdm.pago,
        dataEmissao: DateTime(2026, 9, 1),
        dataVencimento: DateTime(2026, 9, 15),
        responsavelId: 'u1',
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 15),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DespesaCard(despesa: despesa),
          ),
        ),
      );

      expect(find.text('Conta de Água Provisória'), findsOneWidget);
      expect(find.text('Pago'), findsOneWidget);
      expect(find.text('Liquidar / Pagar'), findsNothing);
      expect(find.text('Cancelar'), findsNothing);
    });
  });
}
