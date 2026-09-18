import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/src/features/almoxarifado/domain/material.dart' as mat;
import 'package:app/src/features/almoxarifado/domain/movimentacao.dart';
import 'package:app/src/features/almoxarifado/presentation/movimentacao_screen.dart';
import 'package:app/src/features/almoxarifado/presentation/stock_history_screen.dart';
import 'package:app/src/features/almoxarifado/data/almoxarifado_repository.dart';
import 'package:app/src/sync/operation_queue.dart';

void main() {
  group('Story 3.6 — Estoque: Rateio de Despesas e Frete', () {
    late Map<String, dynamic> memoryStore;
    late List<Map<String, dynamic>> enqueuedPayloads;
    late OperationQueue fakeQueue;

    setUp(() {
      memoryStore = <String, dynamic>{};
      enqueuedPayloads = <Map<String, dynamic>>[];

      fakeQueue = OperationQueue(
        sessionUid: () => 'user-almoxarife-1',
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
        execute: (action, payload) async =>
            {'movementId': 'mock-id-1', 'quantityUnits': 50000},
        autoSync: false,
      );

      OperationQueue.instance = fakeQueue;
    });

    test('Movimentacao serializa e desserializa metadados financeiros e rateio de frete/despesas', () {
      final now = DateTime.now();
      final mov = Movimentacao(
        id: 'mov-rateio-001',
        materialId: 'mat-cimento-01',
        type: MovimentacaoType.entrada,
        quantity: 50.0,
        date: now,
        responsavelId: 'user-almoxarife',
        observacao: 'Compra com frete rateado',
        nfNumber: 'NF-12345',
        fornecedor: 'Votorantim',
        valorItensCentavos: 150000, // R$ 1.500,00
        freteCentavos: 10000, // R$ 100,00
        despesasCentavos: 5000, // R$ 50,00
        descontoCentavos: 2000, // R$ 20,00
        custoTotalCentavos: 163000, // R$ 1.630,00
        custoUnitarioCentavos: 3260, // R$ 32,60
      );

      final json = mov.toJson();
      expect(json['id'], 'mov-rateio-001');
      expect(json['type'], 'entrada');
      expect(json['quantity'], 50.0);
      expect(json['valorItensCentavos'], 150000);
      expect(json['freteCentavos'], 10000);
      expect(json['despesasCentavos'], 5000);
      expect(json['descontoCentavos'], 2000);
      expect(json['custoTotalCentavos'], 163000);
      expect(json['custoUnitarioCentavos'], 3260);

      final restored = Movimentacao.fromJson(json);
      expect(restored.id, mov.id);
      expect(restored.materialId, mov.materialId);
      expect(restored.valorItensCentavos, 150000);
      expect(restored.freteCentavos, 10000);
      expect(restored.despesasCentavos, 5000);
      expect(restored.descontoCentavos, 2000);
      expect(restored.custoTotalCentavos, 163000);
      expect(restored.custoUnitarioCentavos, 3260);
    });

    test('Movimentacao mantém retrocompatibilidade total com registros sem rateio financeiro', () {
      final legacyJson = {
        'id': 'mov-antiga-01',
        'materialId': 'mat-tijolo-01',
        'type': 'entrada',
        'quantity': 100.0,
        'date': DateTime.now().toIso8601String(),
        'responsavelId': 'user-legado',
        'observacao': 'Entrada física antiga',
      };

      final restored = Movimentacao.fromJson(legacyJson);
      expect(restored.id, 'mov-antiga-01');
      expect(restored.valorItensCentavos, isNull);
      expect(restored.freteCentavos, isNull);
      expect(restored.despesasCentavos, isNull);
      expect(restored.descontoCentavos, isNull);
      expect(restored.custoTotalCentavos, isNull);
      expect(restored.custoUnitarioCentavos, isNull);
    });

    testWidgets('Matrix Row 1: Recebimento com Rateio Completo enfileira stockCommand e calcula Custo Total e Unitário',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final material = mat.Material(
        id: 'mat-1',
        construtoraId: 'const-1',
        name: 'Cimento CP II',
        unit: 'Saco',
        currentQuantity: 0.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            almoxarifadoRepositoryProvider.overrideWithValue(AlmoxarifadoRepository()),
          ],
          child: MaterialApp(
            home: MovimentacaoScreen(
              construtoraId: 'const-1',
              material: material,
              type: MovimentacaoType.entrada,
            ),
          ),
        ),
      );

      // Preenche quantidade 50
      await tester.enterText(find.byType(TextFormField).first, '50');
      await tester.pump();

      // Preenche campos de rateio
      await tester.enterText(find.byKey(const Key('valor-itens-field')), '1500,00');
      await tester.enterText(find.byKey(const Key('frete-field')), '100,00');
      await tester.enterText(find.byKey(const Key('despesas-field')), '50,00');
      await tester.enterText(find.byKey(const Key('desconto-field')), '20,00');
      await tester.pump();

      // Verifica cálculo da prévia em tempo real:
      // Total: 1500 + 100 + 50 - 20 = 1630,00
      // Unitário: 1630 / 50 = 32,60
      expect(find.byKey(const Key('rateio-preview-card')), findsOneWidget);
      expect(find.text('R\$ 1.630,00'), findsOneWidget);
      expect(find.text('R\$ 32,60 / Saco'), findsOneWidget);

      // Submissão
      await tester.ensureVisible(find.text('Confirmar Entrada'));
      await tester.tap(find.text('Confirmar Entrada'));
      await tester.pump();

      expect(enqueuedPayloads.length, 1);
      final call = enqueuedPayloads.first;
      expect(call['type'], 'entrada');
      expect(call['quantity'], 50.0);
      expect(call['valorItensCentavos'], 150000);
      expect(call['freteCentavos'], 10000);
      expect(call['despesasCentavos'], 5000);
      expect(call['descontoCentavos'], 2000);
      expect(call['custoTotalCentavos'], 163000);
      expect(call['custoUnitarioCentavos'], 3260);
    });

    testWidgets('Matrix Row 2: Recebimento com Apenas Frete Rateado calcula valores proporcionais',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final material = mat.Material(
        id: 'mat-2',
        construtoraId: 'const-1',
        name: 'Piso Cerâmico',
        unit: 'm²',
        currentQuantity: 0.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            almoxarifadoRepositoryProvider.overrideWithValue(AlmoxarifadoRepository()),
          ],
          child: MaterialApp(
            home: MovimentacaoScreen(
              construtoraId: 'const-1',
              material: material,
              type: MovimentacaoType.entrada,
            ),
          ),
        ),
      );

      // Quantidade: 100
      await tester.enterText(find.byType(TextFormField).first, '100');
      await tester.pump();

      // Valor itens: 2000,00; Frete: 250,00
      await tester.enterText(find.byKey(const Key('valor-itens-field')), '2000,00');
      await tester.enterText(find.byKey(const Key('frete-field')), '250,00');
      await tester.pump();

      // Total: 2250,00. Unitário: 22,50 / m²
      expect(find.byKey(const Key('rateio-preview-card')), findsOneWidget);
      expect(find.text('R\$ 2.250,00'), findsOneWidget);
      expect(find.text('R\$ 22,50 / m²'), findsOneWidget);

      await tester.ensureVisible(find.text('Confirmar Entrada'));
      await tester.tap(find.text('Confirmar Entrada'));
      await tester.pump();

      expect(enqueuedPayloads.length, 1);
      final call = enqueuedPayloads.first;
      expect(call['valorItensCentavos'], 200000);
      expect(call['freteCentavos'], 25000);
      expect(call['despesasCentavos'], 0);
      expect(call['descontoCentavos'], 0);
      expect(call['custoTotalCentavos'], 225000);
      expect(call['custoUnitarioCentavos'], 2250);
    });

    testWidgets('Matrix Row 3: Desconto Maior que Custo Bruto exibe alerta e impede submissão',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final material = mat.Material(
        id: 'mat-1',
        construtoraId: 'const-1',
        name: 'Cimento CP II',
        unit: 'Saco',
        currentQuantity: 0.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MovimentacaoScreen(
              construtoraId: 'const-1',
              material: material,
              type: MovimentacaoType.entrada,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, '10');
      await tester.enterText(find.byKey(const Key('valor-itens-field')), '100,00');
      await tester.enterText(find.byKey(const Key('desconto-field')), '150,00');
      await tester.pump();

      // Alerta na prévia
      expect(find.text('Desconto não pode exceder o valor total'), findsOneWidget);

      // Tenta submeter
      await tester.ensureVisible(find.text('Confirmar Entrada'));
      await tester.tap(find.text('Confirmar Entrada'));
      await tester.pump();

      // Validação do campo bloqueia submissão
      expect(find.text('Desconto não pode exceder o valor total'), findsWidgets);
      expect(enqueuedPayloads, isEmpty);
    });

    testWidgets('Matrix Row 4: Valor Monetário Negativo é bloqueado pelo validador',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final material = mat.Material(
        id: 'mat-1',
        construtoraId: 'const-1',
        name: 'Cimento CP II',
        unit: 'Saco',
        currentQuantity: 0.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MovimentacaoScreen(
              construtoraId: 'const-1',
              material: material,
              type: MovimentacaoType.entrada,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, '10');
      await tester.enterText(find.byKey(const Key('frete-field')), '-50,00');
      await tester.pump();

      await tester.ensureVisible(find.text('Confirmar Entrada'));
      await tester.tap(find.text('Confirmar Entrada'));
      await tester.pump();

      expect(find.text('Informe um valor monetário válido'), findsOneWidget);
      expect(enqueuedPayloads, isEmpty);
    });

    testWidgets('Matrix Row 5: Entrada Simples sem Informação Financeira enfileira sem campos nulos/zerados de custos',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final material = mat.Material(
        id: 'mat-1',
        construtoraId: 'const-1',
        name: 'Areia Média',
        unit: 'm³',
        currentQuantity: 10.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            almoxarifadoRepositoryProvider.overrideWithValue(AlmoxarifadoRepository()),
          ],
          child: MaterialApp(
            home: MovimentacaoScreen(
              construtoraId: 'const-1',
              material: material,
              type: MovimentacaoType.entrada,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, '30');
      await tester.pump();

      expect(find.byKey(const Key('rateio-preview-card')), findsNothing);

      await tester.ensureVisible(find.text('Confirmar Entrada'));
      await tester.tap(find.text('Confirmar Entrada'));
      await tester.pump();

      expect(enqueuedPayloads.length, 1);
      final call = enqueuedPayloads.first;
      expect(call['quantity'], 30.0);
      expect(call['valorItensCentavos'], isNull);
      expect(call['freteCentavos'], isNull);
      expect(call['despesasCentavos'], isNull);
      expect(call['descontoCentavos'], isNull);
      expect(call['custoTotalCentavos'], isNull);
      expect(call['custoUnitarioCentavos'], isNull);
    });

    testWidgets('Matrix Row 6: Exibição de Rateio no Histórico de Estoque apresenta badge e detalhamento',
        (WidgetTester tester) async {
      final material = mat.Material(
        id: 'mat-cimento',
        construtoraId: 'const-1',
        name: 'Cimento CP II',
        unit: 'Saco',
        currentQuantity: 50.0,
        quantityUnits: 50000,
      );

      final mockMovements = [
        {
          'id': 'mov-1',
          'type': 'entrada',
          'commandType': 'entrada',
          'quantity': 50.0,
          'date': DateTime.now().toIso8601String(),
          'responsavelId': 'user-1',
          'nfNumber': 'NF-888',
          'fornecedor': 'Cimentos SA',
          'valorItensCentavos': 150000,
          'freteCentavos': 10000,
          'despesasCentavos': 5000,
          'descontoCentavos': 2000,
          'custoTotalCentavos': 163000,
          'custoUnitarioCentavos': 3260,
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: StockHistoryScreen(
              c: 'const-1',
              material: material,
              canManage: true,
              mockMovements: mockMovements,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Badge de custo unitário
      expect(find.text('R\$ 32,60/Saco'), findsOneWidget);

      // Linha discriminada de rateio
      expect(
        find.textContaining('Itens: R\$ 1.500,00 | Frete: R\$ 100,00 | Desp: R\$ 50,00 | Desc: R\$ 20,00'),
        findsOneWidget,
      );
      expect(find.textContaining('NF: NF-888'), findsOneWidget);
      expect(find.textContaining('Fornecedor: Cimentos SA'), findsOneWidget);
    });

    testWidgets('Matrix Row 7: Movimentação Histórica Antiga sem Custos renderiza sem falhas',
        (WidgetTester tester) async {
      final material = mat.Material(
        id: 'mat-cimento',
        construtoraId: 'const-1',
        name: 'Cimento CP II',
        unit: 'Saco',
        currentQuantity: 50.0,
        quantityUnits: 50000,
      );

      final mockMovements = [
        {
          'id': 'mov-legado',
          'type': 'entrada',
          'commandType': 'entrada',
          'quantity': 25.0,
          'date': DateTime.now().toIso8601String(),
          'responsavelId': 'user-1',
          'observacao': 'Entrada física antiga sem custos',
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: StockHistoryScreen(
              c: 'const-1',
              material: material,
              canManage: true,
              mockMovements: mockMovements,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('entrada · 25.0 Saco'), findsOneWidget);
      expect(find.text('Entrada física antiga sem custos'), findsOneWidget);
      // Não exibe badges de rateio
      expect(find.textContaining('Frete:'), findsNothing);
    });
  });
}
