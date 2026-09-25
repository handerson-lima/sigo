import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/src/core/contracts.dart';
import 'package:app/src/features/almoxarifado/domain/material.dart' as mat;
import 'package:app/src/features/almoxarifado/domain/movimentacao.dart';
import 'package:app/src/features/almoxarifado/presentation/add_material_screen.dart';
import 'package:app/src/features/almoxarifado/presentation/almoxarifado_list_screen.dart';
import 'package:app/src/features/almoxarifado/presentation/almoxarifado_provider.dart';
import 'package:app/src/features/almoxarifado/presentation/movimentacao_screen.dart';
import 'package:app/src/features/almoxarifado/presentation/stock_history_screen.dart';
import 'package:app/src/features/almoxarifado/data/almoxarifado_repository.dart';
import 'package:app/src/features/obras/domain/obra.dart';
import 'package:app/src/features/obras/presentation/construtora_obras_provider.dart';
import 'package:app/src/features/loteamentos/data/loteamento_repository.dart';
import 'package:app/src/features/loteamentos/domain/loteamento.dart';
import 'package:app/src/features/lotes/data/lote_repository.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/quadras/data/quadra_repository.dart';
import 'package:app/src/features/quadras/domain/quadra.dart';
import 'package:app/src/sync/operation_queue.dart';

class FakeAlmoxarifadoRepository extends AlmoxarifadoRepository {
  mat.Material? lastCreatedMaterial;

  @override
  Future<void> createMaterial(mat.Material material) async {
    lastCreatedMaterial = material;
  }
}

class FakeOperationQueue extends OperationQueue {
  final List<Map<String, dynamic>> enqueuedPayloads;
  final Map<String, dynamic> memoryStore;

  FakeOperationQueue({
    required this.enqueuedPayloads,
    required this.memoryStore,
  }) : super(
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
         execute: (action, payload) async => {
           'movementId': 'mock-id-37',
           'quantityUnits': 50000,
         },
         autoSync: false,
       );

  @override
  Stream<List<Map<String, dynamic>>> watch({
    String? construtoraId,
    String? obraId,
    String? action,
  }) async* {
    yield memoryStore.values.cast<Map<String, dynamic>>().toList();
  }
}

void main() {
  group('Story 3.7 — Estoque: Monetário em Centavos e Escalas de Estoque (I/O Matrix)', () {
    late Map<String, dynamic> memoryStore;
    late List<Map<String, dynamic>> enqueuedPayloads;
    late FakeOperationQueue fakeQueue;

    setUp(() {
      memoryStore = <String, dynamic>{};
      enqueuedPayloads = <Map<String, dynamic>>[];

      fakeQueue = FakeOperationQueue(
        enqueuedPayloads: enqueuedPayloads,
        memoryStore: memoryStore,
      );

      OperationQueue.instance = fakeQueue;
    });

    // Matrix Row 1: Input de Quantidade com Vírgula Brasileira
    testWidgets(
      'Matrix Row 1: Input de Quantidade com Vírgula Brasileira converte para escala 1000 e passa validação',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        expect(parseQuantityUnits('1,5', scale: 1000), 1500);
        expect(parseQuantityUnits('1,250', scale: 1000), 1250);
        expect(formatQuantityWithScale(1.5), '1,5');
        expect(formatQuantityWithScale(1.25), '1,25');

        final material = mat.Material(
          id: 'mat-cimento',
          construtoraId: 'c1',
          name: 'Cimento CP II',
          unit: 'Saco',
          currentQuantity: 100.0,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              almoxarifadoRepositoryProvider.overrideWithValue(
                AlmoxarifadoRepository(),
              ),
            ],
            child: MaterialApp(
              home: MovimentacaoScreen(
                construtoraId: 'c1',
                material: material,
                type: MovimentacaoType.entrada,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).first, '1,5');
        await tester.pump();

        await tester.ensureVisible(find.text('Confirmar Entrada'));
        await tester.tap(find.text('Confirmar Entrada'));
        await tester.pumpAndSettle();

        expect(enqueuedPayloads.length, 1);
        expect(enqueuedPayloads.first['quantity'], 1.5);
        expect(enqueuedPayloads.first['quantityUnits'], 1500);
        expect(enqueuedPayloads.first['deltaUnits'], 1500);
      },
    );

    // Matrix Row 2: Input de Quantidade com Ponto Decimal
    testWidgets(
      'Matrix Row 2: Input de Quantidade com Ponto Decimal converte para escala 1000 e passa validação',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        expect(parseQuantityUnits('2.5', scale: 1000), 2500);

        final material = mat.Material(
          id: 'mat-cimento-2',
          construtoraId: 'c1',
          name: 'Cimento CP II',
          unit: 'Saco',
          currentQuantity: 100.0,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              almoxarifadoRepositoryProvider.overrideWithValue(
                AlmoxarifadoRepository(),
              ),
            ],
            child: MaterialApp(
              home: MovimentacaoScreen(
                construtoraId: 'c1',
                material: material,
                type: MovimentacaoType.entrada,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).first, '2.5');
        await tester.pump();

        await tester.ensureVisible(find.text('Confirmar Entrada'));
        await tester.tap(find.text('Confirmar Entrada'));
        await tester.pumpAndSettle();

        expect(enqueuedPayloads.length, 1);
        expect(enqueuedPayloads.first['quantity'], 2.5);
        expect(enqueuedPayloads.first['quantityUnits'], 2500);
      },
    );

    // Matrix Row 3: Quantidade com Mais de 3 Casas Decimais
    testWidgets(
      'Matrix Row 3: Quantidade com mais de 3 casas decimais bloqueia com "Use até 3 casas decimais"',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final material = mat.Material(
          id: 'mat-cimento',
          construtoraId: 'c1',
          name: 'Cimento CP II',
          unit: 'Saco',
          currentQuantity: 100.0,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              almoxarifadoRepositoryProvider.overrideWithValue(
                AlmoxarifadoRepository(),
              ),
            ],
            child: MaterialApp(
              home: MovimentacaoScreen(
                construtoraId: 'c1',
                material: material,
                type: MovimentacaoType.entrada,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).first, '1,1234');
        await tester.pump();

        await tester.ensureVisible(find.text('Confirmar Entrada'));
        await tester.tap(find.text('Confirmar Entrada'));
        await tester.pump();

        expect(find.text('Use até 3 casas decimais'), findsOneWidget);
        expect(enqueuedPayloads, isEmpty);

        await tester.enterText(find.byType(TextFormField).first, '0.0001');
        await tester.pump();
        await tester.tap(find.text('Confirmar Entrada'));
        await tester.pump();

        expect(find.text('Use até 3 casas decimais'), findsOneWidget);
        expect(enqueuedPayloads, isEmpty);
      },
    );

    // Matrix Row 4: Quantidade Negativa ou Não-Finitas
    testWidgets(
      'Matrix Row 4: Quantidade Negativa ou Não-Finitas é bloqueada na validação',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final material = mat.Material(
          id: 'mat-cimento',
          construtoraId: 'c1',
          name: 'Cimento CP II',
          unit: 'Saco',
          currentQuantity: 100.0,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              almoxarifadoRepositoryProvider.overrideWithValue(
                AlmoxarifadoRepository(),
              ),
            ],
            child: MaterialApp(
              home: MovimentacaoScreen(
                construtoraId: 'c1',
                material: material,
                type: MovimentacaoType.entrada,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).first, '-5');
        await tester.pump();

        await tester.ensureVisible(find.text('Confirmar Entrada'));
        await tester.tap(find.text('Confirmar Entrada'));
        await tester.pump();

        expect(find.text('Valor inválido'), findsOneWidget);
        expect(enqueuedPayloads, isEmpty);

        await tester.enterText(find.byType(TextFormField).first, 'abc');
        await tester.pump();
        await tester.tap(find.text('Confirmar Entrada'));
        await tester.pump();

        expect(find.text('Valor inválido'), findsOneWidget);
        expect(enqueuedPayloads, isEmpty);
      },
    );

    // Matrix Row 5: Serialização de Movimentação Nova com Escala
    test('Matrix Row 5: Serialização de Movimentação Nova com Escala serializa quantityUnits e quantity', () {
      final now = DateTime.now();
      final mov = Movimentacao(
        id: 'mov-escala-1',
        materialId: 'mat-1',
        type: MovimentacaoType.entrada,
        date: now,
        responsavelId: 'user-1',
        quantityUnits: 3000,
        quantityScale: 1000,
      );

      final json = mov.toJson();
      expect(json['quantityUnits'], 3000);
      expect(json['quantityScale'], 1000);
      expect(json['quantity'], 3.0);
      expect(mov.effectiveQuantity, 3.0);
    });

    // Matrix Row 6: Leitura de Movimentação Histórica Legada
    test('Matrix Row 6: Leitura de Movimentação Histórica Legada tem fallback sem erros de nulo', () {
      final legacyJson = {
        'id': 'mov-legada-1',
        'materialId': 'mat-1',
        'type': 'entrada',
        'quantity': 12.5,
        'date': DateTime.now().toIso8601String(),
        'responsavelId': 'user-legado',
      };

      final mov = Movimentacao.fromJson(legacyJson);
      expect(mov.effectiveQuantity, 12.5);
      expect(mov.displayQuantity, '12.5');
      expect(mov.quantityUnits, isNull);
    });

    // Matrix Row 7: Cadastro de Novo Material no Catálogo
    testWidgets(
      'Matrix Row 7: Cadastro de Novo Material cria com quantityUnits: 0, scale: 1000 e SnackBar',
      (WidgetTester tester) async {
        final fakeRepo = FakeAlmoxarifadoRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              almoxarifadoRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(
              home: AddMaterialScreen(construtoraId: 'c1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'Areia Média');
        await tester.enterText(fields.at(1), 'm³');
        await tester.pump();

        await tester.tap(find.text('Cadastrar'));
        await tester.pump();

        expect(fakeRepo.lastCreatedMaterial, isNotNull);
        final matCreated = fakeRepo.lastCreatedMaterial!;
        expect(matCreated.name, 'Areia Média');
        expect(matCreated.unit, 'm³');
        expect(matCreated.currentQuantity, 0.0);
        expect(matCreated.quantityUnits, 0);
        expect(matCreated.quantityScale, 1000);
        expect(matCreated.schemaVersion, 2);

        final json = matCreated.toJson();
        expect(json['quantityUnits'], 0);
        expect(json['quantityScale'], 1000);
        expect(json['schemaVersion'], 2);

        expect(find.text('Material cadastrado com sucesso!'), findsOneWidget);
      },
    );

    // Matrix Row 8: Reconciliação de Abertura de Saldo Legado
    testWidgets(
      'Matrix Row 8: Reconciliação de Abertura de Saldo Legado pré-preenche com saldo e valida paridade',
      (WidgetTester tester) async {
        final legacyMaterial = mat.Material(
          id: 'mat-legado-25',
          construtoraId: 'c1',
          name: 'Tijolo 6 furos',
          unit: 'Milheiro',
          currentQuantity: 25.5,
          quantityUnits: null, // Sem escala, saldo legado
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: StockHistoryScreen(
                c: 'c1',
                material: legacyMaterial,
                canManage: true,
                mockMovements: const [],
                queue: fakeQueue,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final aberturaBtn = find.widgetWithText(
          TextButton,
          'Conferir saldo inicial',
        );
        expect(aberturaBtn, findsOneWidget);
        await tester.tap(aberturaBtn);
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(AlertDialog, 'Conferir saldo inicial'),
          findsOneWidget,
        );

        // Pré-preenchido com 25.5
        final qtyInput = find.widgetWithText(TextFormField, 'Saldo conferido');
        expect(qtyInput, findsOneWidget);
        expect(tester.widget<TextFormField>(qtyInput).controller!.text, '25.5');

        final reasonField = find.widgetWithText(
          TextFormField,
          'Motivo da correção',
        );
        final evidenceField = find.widgetWithText(
          TextFormField,
          'Referência da evidência ou documento',
        );

        await tester.enterText(
          reasonField,
          'Reconciliação inicial de inventário físico',
        );
        await tester.enterText(evidenceField, 'Inventário-2026-09');

        // Tenta submeter com valor divergente (ex: 26.0)
        await tester.enterText(qtyInput, '26.0');
        await tester.pump();

        await tester.tap(find.widgetWithText(FilledButton, 'Registrar'));
        await tester.pump();

        // Bloqueia com erro de divergência
        expect(
          find.text('Valor diverge do saldo legado (25,5)'),
          findsOneWidget,
        );
        expect(enqueuedPayloads, isEmpty);

        // Restaura para 25.5 exato
        await tester.enterText(qtyInput, '25.5');
        await tester.pump();

        await tester.tap(find.widgetWithText(FilledButton, 'Registrar'));
        await tester.pumpAndSettle();

        expect(enqueuedPayloads.length, 1);
        final payload = enqueuedPayloads.first;
        expect(payload['type'], 'abertura');
        expect(payload['materialId'], 'mat-legado-25');
        expect(payload['quantity'], '25.5');
        expect(payload['reason'], 'Reconciliação inicial de inventário físico');
        expect(payload['evidence'], 'Inventário-2026-09');
      },
    );

    // Matrix Row 9: Parsing e Formatação de Centavos Universal
    test('Matrix Row 9: Parsing e Formatação de Centavos Universal converte R\$ 1.500,75 e 1500.75 para 150075', () {
      expect(parseCurrencyToCents('R\$ 1.500,75'), 150075);
      expect(parseCurrencyToCents('1500.75'), 150075);
      expect(formatCents(150075), 'R\$ 1.500,75');
    });

    // Matrix Row 10: Saída de Material com Custo Apropriado
    testWidgets(
      'Matrix Row 10: Saída de Material com Custo Apropriado enfileira custoUnitario e custoTotal em centavos',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final material = mat.Material(
          id: 'mat-cimento',
          construtoraId: 'c1',
          name: 'Cimento CP II',
          unit: 'Saco',
          currentQuantity: 50.0,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              construtoraObrasProvider('c1')
                  .overrideWith((ref) => const <Obra>[]),
              watchLoteamentosProvider.overrideWith(
                (ref, arg) => Stream.value(const <Loteamento>[]),
              ),
              watchQuadrasProvider.overrideWith(
                (ref, arg) => Stream.value(const <Quadra>[]),
              ),
              watchLotesProvider.overrideWith(
                (ref, arg) => Stream.value(const <Lote>[]),
              ),
              almoxarifadoRepositoryProvider.overrideWithValue(
                AlmoxarifadoRepository(),
              ),
            ],
            child: MaterialApp(
              home: MovimentacaoScreen(
                construtoraId: 'c1',
                material: material,
                type: MovimentacaoType.saida,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Digita Quantidade 10
        await tester.enterText(find.byType(TextFormField).first, '10');

        // Preenche Loteamento de Destino
        final obraField = find.widgetWithText(
          TextFormField,
          'ID do Loteamento de Destino',
        );
        expect(obraField, findsOneWidget);
        await tester.enterText(obraField, 'obra-torre-norte');
        await tester.pumpAndSettle();

        // Preenche Custo Unitário R$ 35,00
        final custoField = find.byKey(const Key('custo-unitario-field'));
        await tester.ensureVisible(custoField);
        await tester.enterText(custoField, '35,00');
        await tester.pumpAndSettle();

        final submitBtn = find.text('Confirmar Saída');
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(enqueuedPayloads.length, 1);
        final payload = enqueuedPayloads.first;
        expect(payload['type'], 'saida');
        expect(payload['quantity'], 10.0);
        expect(payload['custoUnitarioCentavos'], 3500);
        expect(payload['custoTotalCentavos'], 35000);

        expect(
          find.text(
            'Operação pendente de confirmação. O saldo oficial muda após aceite do servidor.',
          ),
          findsOneWidget,
        );
      },
    );

    // Matrix Row 11: Exibição de Saldo no Almoxarifado sem Zeros Espúrios
    testWidgets(
      'Matrix Row 11: Exibição de Saldo no Almoxarifado sem Zeros Espúrios formata Confirmado: 50 e Estimativa: 52,5',
      (WidgetTester tester) async {
        final material = mat.Material(
          id: 'mat-saco-1',
          construtoraId: 'c1',
          name: 'Argamassa ACIII',
          unit: 'Saco',
          currentQuantity: 50.0,
          quantityUnits: 50000,
        );

        // Simula uma pendência na fila local de +2.5 sacos
        await fakeQueue.enqueue('stockCommand', {
          'operationId': 'op-pending-1',
          'construtoraId': 'c1',
          'materialId': 'mat-saco-1',
          'type': 'entrada',
          'quantity': '2.5',
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              construtoraMateriaisProvider('c1')
                  .overrideWith((ref) => Stream.value([material])),
            ],
            child: const MaterialApp(
              home: AlmoxarifadoListScreen(construtoraId: 'c1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Argamassa ACIII'), findsOneWidget);
        expect(
          find.text(
            'Confirmado: 50 Saco\nEstimativa com pendências: 52,5 Saco',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
