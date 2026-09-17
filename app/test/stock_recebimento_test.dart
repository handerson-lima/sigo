import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/src/features/almoxarifado/domain/material.dart' as mat;
import 'package:app/src/features/almoxarifado/domain/movimentacao.dart';
import 'package:app/src/features/almoxarifado/presentation/movimentacao_screen.dart';
import 'package:app/src/sync/operation_queue.dart';

void main() {
  group('Story 3.2 — Estoque: Recebimento no Almoxarifado Central', () {
    test('Movimentacao serializa e desserializa metadados de recebimento (NF, Fornecedor, Evidência)', () {
      final now = DateTime.now();
      final mov = Movimentacao(
        id: 'mov-rec-001',
        materialId: 'mat-cimento-01',
        type: MovimentacaoType.entrada,
        quantity: 50.0,
        date: now,
        responsavelId: 'user-almoxarife',
        observacao: 'Recebimento de carga de cimento',
        nfNumber: 'NF-998877',
        fornecedor: 'Cimentos Brasil SA',
        evidence: 'https://storage.googleapis.com/sigo/nf-998877.pdf',
      );

      final json = mov.toJson();
      expect(json['id'], 'mov-rec-001');
      expect(json['type'], 'entrada');
      expect(json['quantity'], 50.0);
      expect(json['nfNumber'], 'NF-998877');
      expect(json['fornecedor'], 'Cimentos Brasil SA');
      expect(json['evidence'], 'https://storage.googleapis.com/sigo/nf-998877.pdf');

      final restored = Movimentacao.fromJson(json);
      expect(restored.id, mov.id);
      expect(restored.materialId, mov.materialId);
      expect(restored.type, MovimentacaoType.entrada);
      expect(restored.quantity, 50.0);
      expect(restored.nfNumber, 'NF-998877');
      expect(restored.fornecedor, 'Cimentos Brasil SA');
      expect(restored.evidence, 'https://storage.googleapis.com/sigo/nf-998877.pdf');
    });

    test('Movimentacao mantém retrocompatibilidade com payloads sem novos metadados', () {
      final legacyJson = {
        'id': 'mov-legacy-001',
        'materialId': 'mat-areia-01',
        'type': 'entrada',
        'quantity': 10.0,
        'date': DateTime.now().toIso8601String(),
        'responsavelId': 'user-antigo',
        'observacao': 'Entrada antiga sem NF',
      };

      final restored = Movimentacao.fromJson(legacyJson);
      expect(restored.id, 'mov-legacy-001');
      expect(restored.nfNumber, isNull);
      expect(restored.fornecedor, isNull);
      expect(restored.evidence, isNull);
    });

    test('Enfileiramento de stockCommand preserva metadados no OperationQueue', () async {
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
          return {'movementId': 'hash-rec-001', 'quantityUnits': 50000};
        },
        autoSync: false,
      );

      await queue.enqueue('stockCommand', {
        'operationId': 'op-rec-001',
        'construtoraId': 'c1',
        'materialId': 'mat-01',
        'type': 'entrada',
        'quantity': '50.0',
        'nfNumber': 'NF-54321',
        'fornecedor': 'Distribuidora Central Ltda',
        'evidence': 'https://sigo.app/uploads/nf54321.jpg',
        'observacao': 'Recebimento conferido pelo almoxarife',
      });

      expect(await queue.pendingCount, 1);
      await queue.sync();

      expect(executedCalls.length, 1);
      final call = executedCalls.first;
      expect(call['action'], 'stockCommand');
      expect(call['payload']['nfNumber'], 'NF-54321');
      expect(call['payload']['fornecedor'], 'Distribuidora Central Ltda');
      expect(call['payload']['evidence'], 'https://sigo.app/uploads/nf54321.jpg');
      expect(call['payload']['type'], 'entrada');
    });

    testWidgets('MovimentacaoScreen exibe campos de recebimento (NF, Fornecedor, Evidência) para Entrada', (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testMaterial = mat.Material(
        id: 'mat-cimento',
        construtoraId: 'c1',
        name: 'Cimento CP-II',
        unit: 'saco',
        currentQuantity: 100.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MovimentacaoScreen(
              construtoraId: 'c1',
              material: testMaterial,
              type: MovimentacaoType.entrada,
            ),
          ),
        ),
      );

      expect(find.text('Entrada de Material'), findsOneWidget);
      expect(find.text('Número da Nota Fiscal (NF)'), findsOneWidget);
      expect(find.text('Fornecedor'), findsOneWidget);
      expect(find.text('Evidência / Comprovante (URL ou Referência)'), findsOneWidget);
      expect(find.text('Confirmar Entrada'), findsOneWidget);

      // Na entrada, campo de obra de destino não deve ser exibido
      expect(find.text('ID da Obra de Destino'), findsNothing);
    });

    testWidgets('MovimentacaoScreen não exibe campos de NF para Saída de Material', (tester) async {
      final testMaterial = mat.Material(
        id: 'mat-cimento',
        construtoraId: 'c1',
        name: 'Cimento CP-II',
        unit: 'saco',
        currentQuantity: 100.0,
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

      expect(find.text('Saída de Material'), findsOneWidget);
      expect(find.text('ID da Obra de Destino'), findsOneWidget);
      expect(find.text('Confirmar Saída'), findsOneWidget);

      // Na saída, campos exclusivos de entrada/recebimento não devem ser exibidos
      expect(find.text('Número da Nota Fiscal (NF)'), findsNothing);
      expect(find.text('Fornecedor'), findsNothing);
    });
  });
}
