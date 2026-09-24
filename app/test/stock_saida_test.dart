import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/src/features/almoxarifado/domain/material.dart' as mat;
import 'package:app/src/features/almoxarifado/domain/movimentacao.dart';
import 'package:app/src/features/almoxarifado/presentation/movimentacao_screen.dart';
import 'package:app/src/features/obras/domain/obra.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/obras/presentation/construtora_obras_provider.dart';
import 'package:app/src/features/lotes/presentation/obra_lotes_provider.dart';
import 'package:app/src/sync/operation_queue.dart';

void main() {
  group('Story 3.3 — Estoque: Saída via Requisição por Lote', () {
    test('Movimentacao serializa e desserializa apropriacaoLote e solicitante', () {
      final now = DateTime.now();
      final mov = Movimentacao(
        id: 'mov-saida-001',
        materialId: 'mat-cimento-01',
        type: MovimentacaoType.saida,
        quantity: 15.0,
        date: now,
        responsavelId: 'user-almoxarife',
        loteamentoId: 'obra-alphaville-01', quadraId: 'obra-alphaville-01', status: LoteStatus.noPrazo,
        loteId: 'lote-12',
        apropriacaoLote: true,
        solicitante: 'Mestre Carlos',
        observacao: 'Concretagem da viga baldrame',
      );

      final json = mov.toJson();
      expect(json['id'], 'mov-saida-001');
      expect(json['type'], 'saida');
      expect(json['quantity'], 15.0);
      expect(json['obraId'], 'obra-alphaville-01');
      expect(json['loteId'], 'lote-12');
      expect(json['apropriacaoLote'], true);
      expect(json['solicitante'], 'Mestre Carlos');
      expect(json['observacao'], 'Concretagem da viga baldrame');

      final restored = Movimentacao.fromJson(json);
      expect(restored.id, mov.id);
      expect(restored.materialId, mov.materialId);
      expect(restored.type, MovimentacaoType.saida);
      expect(restored.quantity, 15.0);
      expect(restored.obraId, 'obra-alphaville-01');
      expect(restored.loteId, 'lote-12');
      expect(restored.apropriacaoLote, true);
      expect(restored.solicitante, 'Mestre Carlos');
    });

    test('Movimentacao mantém retrocompatibilidade com saídas sem novos atributos', () {
      final legacyJson = {
        'id': 'mov-legacy-saida',
        'materialId': 'mat-areia-01',
        'type': 'saida',
        'quantity': 5.0,
        'date': DateTime.now().toIso8601String(),
        'responsavelId': 'user-antigo',
        'obraId': 'obra-antiga',
      };

      final restored = Movimentacao.fromJson(legacyJson);
      expect(restored.id, 'mov-legacy-saida');
      expect(restored.type, MovimentacaoType.saida);
      expect(restored.obraId, 'obra-antiga');
      expect(restored.loteId, isNull);
      expect(restored.apropriacaoLote, isNull);
      expect(restored.solicitante, isNull);
    });

    test('Enfileiramento de stockCommand de saída preserva apropriacaoLote e destino no OperationQueue', () async {
      final memoryStore = <String, dynamic>{};
      final executedCalls = <Map<String, dynamic>>[];

      final queue = OperationQueue(
        sessionUid: () => 'user-test',
        store: (String action, String input) async {
          final data = jsonDecode(input);
          if (action == 'insert') {
            final key = data['key'] as String;
            memoryStore[key] = data;
            return jsonEncode(data);
          }
          if (action == 'list') {
            return jsonEncode(memoryStore.values.toList());
          }
          if (action == 'claim') {
            final key = data['key'] as String;
            final item = memoryStore[key];
            if (item == null) return 'null';
            item['state'] = 'syncing';
            return jsonEncode(item);
          }
          if (action == 'finish') {
            final key = data['key'] as String;
            final item = memoryStore[key];
            if (item == null) return 'null';
            item['state'] = data['state'];
            item['result'] = data['result'];
            return jsonEncode(item);
          }
          return 'null';
        },
        upload: (attachment, bytes, uid) async {},
        execute: (action, payload) async {
          executedCalls.add({'action': action, 'payload': payload});
          return {'movementId': payload['operationId'], 'quantityUnits': 85000};
        },
        autoSync: false,
      );

      await queue.enqueue('stockCommand', {
        'operationId': 'op-saida-123',
        'construtoraId': 'c1',
        'materialId': 'mat-cimento',
        'type': 'saida',
        'quantity': 15.0,
        'obraId': 'obra-alpha',
        'loteId': 'lote-casa-04',
        'apropriacaoLote': true,
        'solicitante': 'Encarregado Marcos',
        'observacao': 'Alvenaria da sala',
      });

      expect(await queue.pendingCount, 1);
      await queue.sync();

      expect(executedCalls.length, 1);
      final call = executedCalls.first;
      expect(call['action'], 'stockCommand');
      expect(call['payload']['type'], 'saida');
      expect(call['payload']['obraId'], 'obra-alpha');
      expect(call['payload']['loteId'], 'lote-casa-04');
      expect(call['payload']['apropriacaoLote'], true);
      expect(call['payload']['solicitante'], 'Encarregado Marcos');
    });

    testWidgets('MovimentacaoScreen exibe controles de saída, switch de apropriação e solicitante', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testMaterial = mat.Material(
        id: 'mat-tijolo',
        construtoraId: 'c1',
        name: 'Tijolo Cerâmico 8 furos',
        unit: 'milheiro',
        currentQuantity: 40.0,
      );

      final fakeObras = [
        Obra(
          id: 'obra-1',
          construtoraId: 'c1',
          name: 'Residencial Horizonte',
          createdAt: DateTime(2026),
        ),
      ];

      final fakeLotes = [
        Lote(
          id: 'lote-101',
          construtoraId: 'c1',
          loteamentoId: 'obra-1', quadraId: 'obra-1', status: LoteStatus.noPrazo,
          name: 'Casa 01',
          phase: 'Alvenaria',
          status: LoteStatus.noPrazo,
          createdAt: DateTime(2026),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            construtoraObrasProvider('c1').overrideWith((ref) => fakeObras),
            obraLotesProvider((construtoraId: 'c1', loteamentoId: 'obra-1')).overrideWith((ref) => Stream.value(fakeLotes)), quadraId: 'obra-1')).overrideWith((ref) => Stream.value(fakeLotes)), status: LoteStatus.noPrazo,
          ],
          child: MaterialApp(
            home: MovimentacaoScreen(
              construtoraId: 'c1',
              material: testMaterial,
              type: MovimentacaoType.saida,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Saída de Material'), findsOneWidget);
      expect(find.text('Obra de Destino'), findsOneWidget);
      expect(find.text('Apropriar diretamente ao Lote'), findsOneWidget);
      expect(find.text('Solicitante / Retirado por (Opcional)'), findsOneWidget);

      await tester.ensureVisible(find.text('Confirmar Saída'));
      expect(find.text('Confirmar Saída'), findsOneWidget);

      // Não deve exibir campos de recebimento
      expect(find.text('Número da Nota Fiscal (NF)'), findsNothing);
      expect(find.text('Fornecedor'), findsNothing);
    });

    testWidgets('MovimentacaoScreen bloqueia saída com estoque insuficiente', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testMaterial = mat.Material(
        id: 'mat-tijolo',
        construtoraId: 'c1',
        name: 'Tijolo Cerâmico',
        unit: 'milheiro',
        currentQuantity: 5.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MovimentacaoScreen(
              construtoraId: 'c1',
              material: testMaterial,
              type: MovimentacaoType.saida,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tenta informar quantidade 10 quando estoque é 5
      final quantityField = find.widgetWithText(TextFormField, 'Quantidade (milheiro)');
      await tester.enterText(quantityField, '10');

      final submitBtn = find.text('Confirmar Saída');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Estoque insuficiente'), findsOneWidget);
    });

    testWidgets('MovimentacaoScreen valida apropriação obrigatória por lote quando switch ativo', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testMaterial = mat.Material(
        id: 'mat-cimento',
        construtoraId: 'c1',
        name: 'Cimento CP-II',
        unit: 'saco',
        currentQuantity: 50.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MovimentacaoScreen(
              construtoraId: 'c1',
              material: testMaterial,
              type: MovimentacaoType.saida,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Preenche quantidade válida e obra
      await tester.enterText(find.widgetWithText(TextFormField, 'Quantidade (saco)'), '5');
      await tester.enterText(find.widgetWithText(TextFormField, 'ID da Obra de Destino'), 'obra-teste');

      // Ativa switch de apropriação
      final switchFinder = find.byKey(const Key('apropriacao-lote-switch'));
      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Tenta submeter sem preencher o lote
      final submitBtn = find.text('Confirmar Saída');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Selecione o lote para apropriação'), findsOneWidget);
    });
  });
}
