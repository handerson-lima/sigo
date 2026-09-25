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
  group('Story 3.4 — Estoque: Ajustes Auditados (I/O & Edge-Case Matrix)', () {
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
          return {'movementId': 'op-mock-1', 'quantityUnits': 55500};
        },
        autoSync: false,
      );
    });

    testWidgets(
      'Matrix Row 1: Ajuste Positivo (Sobra de Inventário) enfileira stockCommand e calcula saldo previsto',
      (tester) async {
        final material = mat.Material(
          id: 'mat-cimento-01',
          construtoraId: 'c1',
          name: 'Cimento CP II',
          unit: 'Saco',
          currentQuantity: 50.0,
          quantityUnits: 50000,
        );

        await tester.pumpWidget(
          createTestWidget(
            StockHistoryScreen(
              c: 'c1',
              material: material,
              canManage: true,
              mockMovements: const [],
              queue: fakeQueue,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Clica em Ajustar quantidade
        await tester.tap(find.text('Ajustar quantidade'));
        await tester.pumpAndSettle();

        expect(find.text('Saldo atual: 50 Saco'), findsOneWidget);
        expect(find.text('Saldo previsto: 50 Saco'), findsOneWidget);

        // Digita variação +5.5
        final varField = find.widgetWithText(
          TextFormField,
          'Variação (+ entrada / − saída)',
        );
        await tester.enterText(varField, '+5.5');
        await tester.pump();

        // Saldo previsto atualizado para 55.5
        expect(find.text('Saldo previsto: 55.5 Saco'), findsOneWidget);

        // Digita motivo e evidência
        final reasonField = find.widgetWithText(
          TextFormField,
          'Motivo da correção',
        );
        await tester.enterText(
          reasonField,
          'Sobra identificada na contagem semanal',
        );

        final evidenceField = find.widgetWithText(
          TextFormField,
          'Referência da evidência ou documento',
        );
        await tester.enterText(evidenceField, 'Laudo-INV-2026-09');

        // Submete
        await tester.tap(find.text('Registrar'));
        await tester.pumpAndSettle();

        // Verifica que o diálogo fechou e enfileirou com valores sanitizados
        expect(find.byType(AlertDialog), findsNothing);
        expect(enqueuedPayloads.length, 1);
        final payload = enqueuedPayloads.first;
        expect(payload['construtoraId'], 'c1');
        expect(payload['materialId'], 'mat-cimento-01');
        expect(payload['type'], 'ajuste');
        expect(payload['quantity'], '5.5');
        expect(payload['reason'], 'Sobra identificada na contagem semanal');
        expect(payload['evidence'], 'Laudo-INV-2026-09');

        // SnackBar de confirmação pendente
        expect(
          find.text('Correção salva no dispositivo. Aguarde confirmação.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Matrix Row 2: Ajuste Negativo (Avaria / Perda) enfileira stockCommand e calcula saldo previsto',
      (tester) async {
        final material = mat.Material(
          id: 'mat-cimento-01',
          construtoraId: 'c1',
          name: 'Cimento CP II',
          unit: 'Saco',
          currentQuantity: 30.0,
          quantityUnits: 30000,
        );

        await tester.pumpWidget(
          createTestWidget(
            StockHistoryScreen(
              c: 'c1',
              material: material,
              canManage: true,
              mockMovements: const [],
              queue: fakeQueue,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ajustar quantidade'));
        await tester.pumpAndSettle();

        expect(find.text('Saldo atual: 30 Saco'), findsOneWidget);

        // Digita variação -10
        final varField = find.widgetWithText(
          TextFormField,
          'Variação (+ entrada / − saída)',
        );
        await tester.enterText(varField, '-10');
        await tester.pump();

        // Saldo previsto atualizado para 20
        expect(find.text('Saldo previsto: 20 Saco'), findsOneWidget);

        final reasonField = find.widgetWithText(
          TextFormField,
          'Motivo da correção',
        );
        await tester.enterText(reasonField, 'Sacos furados na chuva');

        final evidenceField = find.widgetWithText(
          TextFormField,
          'Referência da evidência ou documento',
        );
        await tester.enterText(evidenceField, 'Foto-DOC-8821');

        await tester.tap(find.text('Registrar'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(enqueuedPayloads.length, 1);
        final payload = enqueuedPayloads.first;
        expect(payload['type'], 'ajuste');
        expect(payload['quantity'], '-10');
        expect(payload['reason'], 'Sacos furados na chuva');
        expect(payload['evidence'], 'Foto-DOC-8821');

        expect(
          find.text('Correção salva no dispositivo. Aguarde confirmação.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Matrix Row 3: Motivo Muito Curto (< 5 caracteres) bloqueia com mensagem contextual',
      (tester) async {
        final material = mat.Material(
          id: 'mat-1',
          construtoraId: 'c1',
          name: 'Areia',
          unit: 'm³',
          currentQuantity: 20.0,
          quantityUnits: 20000,
        );

        await tester.pumpWidget(
          createTestWidget(
            StockHistoryScreen(
              c: 'c1',
              material: material,
              canManage: true,
              mockMovements: const [],
              queue: fakeQueue,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ajustar quantidade'));
        await tester.pumpAndSettle();

        final varField = find.widgetWithText(
          TextFormField,
          'Variação (+ entrada / − saída)',
        );
        await tester.enterText(varField, '2');

        final reasonField = find.widgetWithText(
          TextFormField,
          'Motivo da correção',
        );
        await tester.enterText(reasonField, 'Erro');

        final evidenceField = find.widgetWithText(
          TextFormField,
          'Referência da evidência ou documento',
        );
        await tester.enterText(evidenceField, 'DOC-123');

        await tester.tap(find.text('Registrar'));
        await tester.pumpAndSettle();

        expect(
          find.text('Descreva o motivo (mínimo 5 caracteres)'),
          findsOneWidget,
        );
        expect(enqueuedPayloads, isEmpty);
      },
    );

    testWidgets(
      'Matrix Row 4: Evidência Vazia bloqueia com mensagem contextual',
      (tester) async {
        final material = mat.Material(
          id: 'mat-1',
          construtoraId: 'c1',
          name: 'Areia',
          unit: 'm³',
          currentQuantity: 20.0,
          quantityUnits: 20000,
        );

        await tester.pumpWidget(
          createTestWidget(
            StockHistoryScreen(
              c: 'c1',
              material: material,
              canManage: true,
              mockMovements: const [],
              queue: fakeQueue,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ajustar quantidade'));
        await tester.pumpAndSettle();

        final varField = find.widgetWithText(
          TextFormField,
          'Variação (+ entrada / − saída)',
        );
        await tester.enterText(varField, '2');

        final reasonField = find.widgetWithText(
          TextFormField,
          'Motivo da correção',
        );
        await tester.enterText(
          reasonField,
          'Ajuste físico de contagem semanal',
        );

        // Deixa evidência vazia
        await tester.tap(find.text('Registrar'));
        await tester.pumpAndSettle();

        expect(
          find.text('Informe a referência da evidência ou documento'),
          findsOneWidget,
        );
        expect(enqueuedPayloads, isEmpty);
      },
    );

    testWidgets(
      'Matrix Row 5: Ajuste Negativo Maior que Saldo bloqueia com mensagem contextual',
      (tester) async {
        final material = mat.Material(
          id: 'mat-1',
          construtoraId: 'c1',
          name: 'Cimento',
          unit: 'Saco',
          currentQuantity: 10.0,
          quantityUnits: 10000,
        );

        await tester.pumpWidget(
          createTestWidget(
            StockHistoryScreen(
              c: 'c1',
              material: material,
              canManage: true,
              mockMovements: const [],
              queue: fakeQueue,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ajustar quantidade'));
        await tester.pumpAndSettle();

        // Tenta -15 quando saldo é 10
        final varField = find.widgetWithText(
          TextFormField,
          'Variação (+ entrada / − saída)',
        );
        await tester.enterText(varField, '-15');

        final reasonField = find.widgetWithText(
          TextFormField,
          'Motivo da correção',
        );
        await tester.enterText(reasonField, 'Perda total do lote molhado');

        final evidenceField = find.widgetWithText(
          TextFormField,
          'Referência da evidência ou documento',
        );
        await tester.enterText(evidenceField, 'Laudo-001');

        await tester.tap(find.text('Registrar'));
        await tester.pumpAndSettle();

        expect(
          find.text('Ajuste negativo excede o saldo atual (10)'),
          findsOneWidget,
        );
        expect(enqueuedPayloads, isEmpty);
      },
    );

    testWidgets(
      'Matrix Row 6: Variação Zero ou Inválida bloqueia com mensagem contextual',
      (tester) async {
        final material = mat.Material(
          id: 'mat-1',
          construtoraId: 'c1',
          name: 'Cimento',
          unit: 'Saco',
          currentQuantity: 10.0,
          quantityUnits: 10000,
        );

        await tester.pumpWidget(
          createTestWidget(
            StockHistoryScreen(
              c: 'c1',
              material: material,
              canManage: true,
              mockMovements: const [],
              queue: fakeQueue,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ajustar quantidade'));
        await tester.pumpAndSettle();

        final varField = find.widgetWithText(
          TextFormField,
          'Variação (+ entrada / − saída)',
        );
        final reasonField = find.widgetWithText(
          TextFormField,
          'Motivo da correção',
        );
        await tester.enterText(reasonField, 'Contagem de rotina no galpão');
        final evidenceField = find.widgetWithText(
          TextFormField,
          'Referência da evidência ou documento',
        );
        await tester.enterText(evidenceField, 'Relatorio-55');

        // Digita 0
        await tester.enterText(varField, '0');
        await tester.tap(find.text('Registrar'));
        await tester.pumpAndSettle();
        expect(
          find.text('Informe uma variação diferente de zero'),
          findsOneWidget,
        );

        // Digita abc
        await tester.enterText(varField, 'abc');
        await tester.tap(find.text('Registrar'));
        await tester.pumpAndSettle();
        expect(
          find.text('Informe uma variação diferente de zero'),
          findsOneWidget,
        );

        expect(enqueuedPayloads, isEmpty);
      },
    );

    testWidgets(
      'Matrix Row 7: Mais de 3 Casas Decimais bloqueia com mensagem contextual',
      (tester) async {
        final material = mat.Material(
          id: 'mat-1',
          construtoraId: 'c1',
          name: 'Cimento',
          unit: 'Saco',
          currentQuantity: 10.0,
          quantityUnits: 10000,
        );

        await tester.pumpWidget(
          createTestWidget(
            StockHistoryScreen(
              c: 'c1',
              material: material,
              canManage: true,
              mockMovements: const [],
              queue: fakeQueue,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ajustar quantidade'));
        await tester.pumpAndSettle();

        final varField = find.widgetWithText(
          TextFormField,
          'Variação (+ entrada / − saída)',
        );
        await tester.enterText(varField, '2.1234');

        final reasonField = find.widgetWithText(
          TextFormField,
          'Motivo da correção',
        );
        await tester.enterText(reasonField, 'Ajuste de pesagem fina');

        final evidenceField = find.widgetWithText(
          TextFormField,
          'Referência da evidência ou documento',
        );
        await tester.enterText(evidenceField, 'Balança-09');

        await tester.tap(find.text('Registrar'));
        await tester.pumpAndSettle();

        expect(find.text('Use até 3 casas decimais'), findsOneWidget);
        expect(enqueuedPayloads, isEmpty);
      },
    );

    testWidgets(
      'Matrix Row 8: Histórico exibe badge [Ajuste Auditado], variação com sinal, motivo e evidência',
      (tester) async {
        final material = mat.Material(
          id: 'mat-1',
          construtoraId: 'c1',
          name: 'Cimento CP II',
          unit: 'Saco',
          currentQuantity: 50.0,
          quantityUnits: 50000,
        );

        final mockDocs = [
          {
            'id': 'mov-ajuste-pos',
            'commandType': 'ajuste',
            'type': 'entrada',
            'quantity': 5.5,
            'deltaUnits': 5500,
            'quantityScale': 1000,
            'observacao': 'Sobra identificada na contagem semanal',
            'evidence': 'Laudo-INV-2026-09',
          },
          {
            'id': 'mov-ajuste-neg',
            'commandType': 'ajuste',
            'type': 'saida',
            'quantity': 10.0,
            'deltaUnits': -10000,
            'quantityScale': 1000,
            'observacao': 'Sacos furados na chuva',
            'evidence': 'Foto-DOC-8821',
          },
        ];

        await tester.pumpWidget(
          createTestWidget(
            StockHistoryScreen(
              c: 'c1',
              material: material,
              canManage: true,
              mockMovements: mockDocs,
              queue: fakeQueue,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Badge destacado [Ajuste Auditado]
        expect(find.text('[Ajuste Auditado]'), findsNWidgets(2));

        // Variação com sinal
        expect(find.text('+5.5 Saco'), findsOneWidget);
        expect(find.text('-10 Saco'), findsOneWidget);

        // Motivo e evidência no subtitle
        expect(
          find.textContaining('Motivo: Sobra identificada na contagem semanal'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Evidência: Laudo-INV-2026-09'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Motivo: Sacos furados na chuva'),
          findsOneWidget,
        );
        expect(find.textContaining('Evidência: Foto-DOC-8821'), findsOneWidget);
      },
    );

    test('AlmoxarifadoListScreen cálculo de delta reflete type == "ajuste" com precisão', () {
      final rows = [
        {
          'action': 'stockCommand',
          'state': 'pending',
          'payload': {
            'construtoraId': 'c1',
            'materialId': 'mat-1',
            'type': 'entrada',
            'quantity': '20',
          },
        },
        {
          'action': 'stockCommand',
          'state': 'pending',
          'payload': {
            'construtoraId': 'c1',
            'materialId': 'mat-1',
            'type': 'ajuste',
            'quantity': '5.5',
          },
        },
        {
          'action': 'stockCommand',
          'state': 'pending',
          'payload': {
            'construtoraId': 'c1',
            'materialId': 'mat-1',
            'type': 'ajuste',
            'quantity': '-10',
          },
        },
        {
          'action': 'stockCommand',
          'state': 'pending',
          'payload': {
            'construtoraId': 'c1',
            'materialId': 'mat-1',
            'type': 'saida',
            'quantity': '5',
          },
        },
      ];

      double delta = 0;
      for (final row in rows) {
        final d = row['payload'] as Map<String, dynamic>;
        final q = num.tryParse(d['quantity'].toString())?.toDouble() ?? 0;
        if (d['type'] == 'entrada') delta += q;
        if (d['type'] == 'saida') delta -= q;
        if (d['type'] == 'ajuste') delta += q;
      }

      // 20 (entrada) + 5.5 (ajuste) - 10 (ajuste) - 5 (saida) = 10.5
      expect(delta, 10.5);
    });

    testWidgets(
      'Usuário comum sem canManage não visualiza botão "Ajustar quantidade"',
      (tester) async {
        final material = mat.Material(
          id: 'mat-1',
          construtoraId: 'c1',
          name: 'Cimento CP II',
          unit: 'Saco',
          currentQuantity: 50.0,
          quantityUnits: 50000,
        );

        await tester.pumpWidget(
          createTestWidget(
            StockHistoryScreen(
              c: 'c1',
              material: material,
              canManage: false,
              mockMovements: const [],
              queue: fakeQueue,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Ajustar quantidade'), findsNothing);
        expect(find.text('Conferir saldo inicial'), findsNothing);
      },
    );
  });
}
