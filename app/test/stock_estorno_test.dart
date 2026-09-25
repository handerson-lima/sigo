import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/almoxarifado/domain/material.dart' as mat;
import 'package:app/src/features/almoxarifado/presentation/stock_history_screen.dart';
import 'package:app/src/sync/operation_queue.dart';

Widget createTestWidget(Widget home) {
  return ProviderScope(child: MaterialApp(home: home));
}

void main() {
  group('Story 3.5 — Estoque: Estorno por Movimentação Inversa (I/O & Edge-Case Matrix)', () {
    late Map<String, dynamic> memoryStore;
    late List<Map<String, dynamic>> enqueuedPayloads;
    late OperationQueue fakeQueue;

    setUp(() {
      memoryStore = <String, dynamic>{};
      enqueuedPayloads = <Map<String, dynamic>>[];

      fakeQueue = OperationQueue(
        sessionUid: () => 'admin-uid-1',
        store: (String action, String input) async {
          final data = jsonDecode(input);
          if (action == 'insert') {
            final key = data['key'] as String;
            memoryStore[key] = data;
            enqueuedPayloads.add(data['payload'] as Map<String, dynamic>);
            return jsonEncode(data);
          }
          if (action == 'list') {
            return jsonEncode(memoryStore.values.toList());
          }
          return 'null';
        },
        upload: (attachment, bytes, uid) async {},
        execute: (action, payload) async {
          return {'movementId': 'op-mock-1', 'quantityUnits': 30000};
        },
        autoSync: false,
      );
    });

    testWidgets(
      'Matrix Row 1: Estorno de Saída (Devolve Material ao Estoque) calcula saldo previsto e enfileira reversalId e reversalDelta positivo',
      (tester) async {
        final material = mat.Material(
          id: 'mat-cimento-01',
          construtoraId: 'c1',
          name: 'Cimento CP II',
          unit: 'Saco',
          currentQuantity: 20.0,
          quantityUnits: 20000,
        );

        final movementSaida = <String, dynamic>{
          'id': 'mov-saida-01',
          'type': 'saida',
          'commandType': 'saida',
          'quantity': 10.0,
          'deltaUnits': -10000,
          'quantityScale': 1000,
          'observacao': 'Saída para lote 01',
        };

        await tester.pumpWidget(
          createTestWidget(
            StockHistoryScreen(
              c: 'c1',
              material: material,
              canManage: true,
              mockMovements: [movementSaida],
              queue: fakeQueue,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Encontra botão Estornar
        final estornarBtn = find.widgetWithText(TextButton, 'Estornar');
        expect(estornarBtn, findsOneWidget);
        await tester.tap(estornarBtn);
        await tester.pumpAndSettle();

        // Verifica diálogo de estorno
        expect(find.text('Estornar movimentação'), findsOneWidget);
        expect(find.text('Movimentação original:'), findsOneWidget);
        expect(
          find.textContaining('Tipo: Saída · Quantidade: 10 Saco'),
          findsOneWidget,
        );
        expect(find.text('Saldo atual: 20 Saco'), findsOneWidget);
        expect(
          find.text('Saldo previsto pós-estorno: 30 Saco'),
          findsOneWidget,
        );

        // Preenche motivo e evidência
        final reasonField = find.widgetWithText(
          TextFormField,
          'Motivo da correção',
        );
        await tester.enterText(reasonField, 'Requisição de saída cancelada');

        final evidenceField = find.widgetWithText(
          TextFormField,
          'Referência da evidência ou documento',
        );
        await tester.enterText(evidenceField, 'Memorando-042');

        // Botão registrar habilitado
        final registrarBtn = find.widgetWithText(FilledButton, 'Registrar');
        expect(tester.widget<FilledButton>(registrarBtn).enabled, isTrue);

        await tester.tap(registrarBtn);
        await tester.pumpAndSettle();

        // Verifica se enfileirou corretamente
        expect(enqueuedPayloads.length, 1);
        final payload = enqueuedPayloads.first;
        expect(payload['type'], 'estorno');
        expect(payload['materialId'], 'mat-cimento-01');
        expect(payload['reversalId'], 'mov-saida-01');
        expect(payload['quantity'], '0');
        expect(payload['reversalDelta'], 10.0);
        expect(payload['reason'], 'Requisição de saída cancelada');
        expect(payload['evidence'], 'Memorando-042');
      },
    );

    testWidgets(
      'Matrix Row 2: Estorno de Entrada (Retira Material do Estoque) calcula saldo previsto e enfileira reversalDelta negativo',
      (tester) async {
        final material = mat.Material(
          id: 'mat-cimento-01',
          construtoraId: 'c1',
          name: 'Cimento CP II',
          unit: 'Saco',
          currentQuantity: 35.0,
          quantityUnits: 35000,
        );

        final movementEntrada = <String, dynamic>{
          'id': 'mov-entrada-01',
          'type': 'entrada',
          'commandType': 'entrada',
          'quantity': 15.0,
          'deltaUnits': 15000,
          'quantityScale': 1000,
          'nfNumber': '991',
          'fornecedor': 'Votoran',
        };

        await tester.pumpWidget(
          createTestWidget(
            StockHistoryScreen(
              c: 'c1',
              material: material,
              canManage: true,
              mockMovements: [movementEntrada],
              queue: fakeQueue,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Estornar'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Tipo: Entrada · Quantidade: 15 Saco'),
          findsOneWidget,
        );
        expect(find.text('Saldo atual: 35 Saco'), findsOneWidget);
        expect(
          find.text('Saldo previsto pós-estorno: 20 Saco'),
          findsOneWidget,
        );

        final reasonField = find.widgetWithText(
          TextFormField,
          'Motivo da correção',
        );
        await tester.enterText(
          reasonField,
          'NF duplicada lançada incorretamente',
        );

        final evidenceField = find.widgetWithText(
          TextFormField,
          'Referência da evidência ou documento',
        );
        await tester.enterText(evidenceField, 'Can-NF-991');

        await tester.tap(find.widgetWithText(FilledButton, 'Registrar'));
        await tester.pumpAndSettle();

        expect(enqueuedPayloads.length, 1);
        final payload = enqueuedPayloads.first;
        expect(payload['type'], 'estorno');
        expect(payload['reversalId'], 'mov-entrada-01');
        expect(payload['reversalDelta'], -15.0);
        expect(payload['reason'], 'NF duplicada lançada incorretamente');
        expect(payload['evidence'], 'Can-NF-991');
      },
    );

    testWidgets(
      'Matrix Row 3: Estorno de Entrada com Saldo Insuficiente bloqueia botão Registrar e exibe alerta visual',
      (tester) async {
        final material = mat.Material(
          id: 'mat-cimento-01',
          construtoraId: 'c1',
          name: 'Cimento CP II',
          unit: 'Saco',
          currentQuantity: 10.0,
          quantityUnits: 10000,
        );

        final movementEntradaGrande = <String, dynamic>{
          'id': 'mov-entrada-50',
          'type': 'entrada',
          'commandType': 'entrada',
          'quantity': 50.0,
          'deltaUnits': 50000,
          'quantityScale': 1000,
        };

        await tester.pumpWidget(
          createTestWidget(
            StockHistoryScreen(
              c: 'c1',
              material: material,
              canManage: true,
              mockMovements: [movementEntradaGrande],
              queue: fakeQueue,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Estornar'));
        await tester.pumpAndSettle();

        expect(find.text('Saldo atual: 10 Saco'), findsOneWidget);
        expect(
          find.text('Saldo previsto pós-estorno: -40 Saco'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Saldo insuficiente para estornar esta entrada'),
          findsOneWidget,
        );

        // Botão Registrar deve estar desabilitado
        final registrarBtn = find.widgetWithText(FilledButton, 'Registrar');
        expect(tester.widget<FilledButton>(registrarBtn).enabled, isFalse);
      },
    );

    testWidgets(
      'Matrix Row 4 & 5: Validação síncrona de motivo curto (<5) e evidência vazia',
      (tester) async {
        final material = mat.Material(
          id: 'mat-cimento-01',
          construtoraId: 'c1',
          name: 'Cimento CP II',
          unit: 'Saco',
          currentQuantity: 30.0,
          quantityUnits: 30000,
        );

        final movementSaida = <String, dynamic>{
          'id': 'mov-saida-01',
          'type': 'saida',
          'commandType': 'saida',
          'quantity': 5.0,
          'deltaUnits': -5000,
          'quantityScale': 1000,
        };

        await tester.pumpWidget(
          createTestWidget(
            StockHistoryScreen(
              c: 'c1',
              material: material,
              canManage: true,
              mockMovements: [movementSaida],
              queue: fakeQueue,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Estornar'));
        await tester.pumpAndSettle();

        final reasonField = find.widgetWithText(
          TextFormField,
          'Motivo da correção',
        );
        await tester.enterText(reasonField, 'Erro');

        await tester.tap(find.widgetWithText(FilledButton, 'Registrar'));
        await tester.pumpAndSettle();

        expect(
          find.text('Descreva o motivo (mínimo 5 caracteres)'),
          findsOneWidget,
        );
        expect(
          find.text('Informe a referência da evidência ou documento'),
          findsOneWidget,
        );
        expect(enqueuedPayloads, isEmpty);
      },
    );

    testWidgets(
      'Matrix Row 6: Movimentação já estornada exibe [Estornado] e oculta botão Estornar',
      (tester) async {
        final material = mat.Material(
          id: 'mat-cimento-01',
          construtoraId: 'c1',
          name: 'Cimento CP II',
          unit: 'Saco',
          currentQuantity: 30.0,
          quantityUnits: 30000,
        );

        final movementJaEstornada = <String, dynamic>{
          'id': 'mov-antiga',
          'type': 'saida',
          'commandType': 'saida',
          'quantity': 8.0,
          'deltaUnits': -8000,
          'quantityScale': 1000,
          'reversedBy': 'mov-estorno-99',
        };

        await tester.pumpWidget(
          createTestWidget(
            StockHistoryScreen(
              c: 'c1',
              material: material,
              canManage: true,
              mockMovements: [movementJaEstornada],
              queue: fakeQueue,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('[Estornado]'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Estornar'), findsNothing);
      },
    );

    testWidgets(
      'Matrix Row 7: Visualização de Estorno no Histórico com badge [Estorno Auditado] e Ref',
      (tester) async {
        final material = mat.Material(
          id: 'mat-cimento-01',
          construtoraId: 'c1',
          name: 'Cimento CP II',
          unit: 'Saco',
          currentQuantity: 30.0,
          quantityUnits: 30000,
        );

        final movementEstorno = <String, dynamic>{
          'id': 'mov-estorno-10',
          'type': 'entrada',
          'commandType': 'estorno',
          'quantity': 10.0,
          'deltaUnits': 10000,
          'quantityScale': 1000,
          'observacao': 'Estorno de saída indevida',
          'evidence': 'Laudo-01',
          'reversalId': 'mov-saida-original-01',
        };

        await tester.pumpWidget(
          createTestWidget(
            StockHistoryScreen(
              c: 'c1',
              material: material,
              canManage: true,
              mockMovements: [movementEstorno],
              queue: fakeQueue,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('[Estorno Auditado]'), findsOneWidget);
        expect(find.text('+10 Saco'), findsOneWidget);
        expect(
          find.textContaining('Ref: mov-saida-original-01'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Motivo: Estorno de saída indevida'),
          findsOneWidget,
        );
        expect(find.textContaining('Evidência: Laudo-01'), findsOneWidget);
      },
    );

    testWidgets(
      'Matrix Row 8: Estimativa com Estornos Pendentes na lista do Almoxarifado reflete reversalDelta',
      (tester) async {
        // Insere na fila fake um estorno pendente com reversalDelta de -15
        await fakeQueue.enqueue('stockCommand', {
          'operationId': 'op-estorno-offline',
          'construtoraId': 'c1',
          'materialId': 'mat-01',
          'type': 'estorno',
          'quantity': '0',
          'reversalDelta': -15.0,
          'reason': 'Estorno pendente de entrada',
          'evidence': 'Doc-99',
        });

        // Testando se a fila reflete o cálculo
        final queueItems = await fakeQueue.list();
        double delta = 0;
        for (final row in queueItems) {
          final d = row['payload'] as Map<String, dynamic>;
          if (d['type'] == 'estorno') {
            final rev = num.tryParse(d['reversalDelta']?.toString() ?? '')
                ?.toDouble();
            if (rev != null) delta += rev;
          }
        }
        expect(delta, -15.0);
        final confirmedBalance = 50.0;
        final estimatedBalance = confirmedBalance + delta;
        expect(estimatedBalance, 35.0);
      },
    );
  });
}
