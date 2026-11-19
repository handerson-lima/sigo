import 'package:app/src/features/loteamentos/data/loteamento_repository.dart';
import 'package:app/src/features/loteamentos/data/loteamentos_import_repository.dart';
import 'package:app/src/features/loteamentos/domain/loteamento.dart';
import 'package:app/src/features/loteamentos/presentation/loteamento_canvas_screen.dart';
import 'package:app/src/features/loteamentos/presentation/loteamento_draft_review_screen.dart';
import 'package:app/src/features/loteamentos/presentation/widgets/geojson_canvas_widget.dart';
import 'package:app/src/features/loteamentos/routing/loteamentos_routes.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeStorage extends Fake implements FirebaseStorage {}

void main() {
  group('generateQuadraFromLoteModel', () {
    test(
      'gera intervalo de lotes na mesma quadra copiando medidas sem duplicar o lote existente',
      () {
        final modelItem = <String, dynamic>{
          'quadra': 'Quadra 28',
          'nome': 'Lote 31',
          'frenteM': 10.0,
          'profundidadeM': 20.0,
          'areaTerrenoM2': 200.0,
          'areaConstruidaM2': 49.96,
          'logradouro': 'Rua Sandoval Wanderley, s/n',
          'taxaOcupacaoPercent': 24.98,
          'recuoFrontalM': 5.05,
          'status': 'valido',
        };

        final existing = [
          modelItem,
          {
            'quadra': 'Quadra 28',
            'nome': 'Lote 15',
            'frenteM': 12.0,
            'profundidadeM': 20.0,
            'areaTerrenoM2': 240.0,
            'status': 'valido',
          },
          // Outro lote com mesmo número em outra quadra não impede geração na Quadra 28
          {
            'quadra': 'Quadra 10',
            'nome': 'Lote 1',
            'frenteM': 8.0,
            'profundidadeM': 20.0,
            'areaTerrenoM2': 160.0,
            'status': 'valido',
          },
        ];

        final result = generateQuadraFromLoteModel(
          modelItem: modelItem,
          startNumber: 1,
          endNumber: 31,
          existingItems: existing,
        );

        // 31 números pedidos, sendo 15 e 31 já existentes na Quadra 28 -> 29 criados, 2 preservados
        expect(result.createdCount, 29);
        expect(result.skippedCount, 2);
        expect(result.items.length, existing.length + 29);

        final generatedLote1 = result.items.firstWhere(
          (i) => i['quadra'] == 'Quadra 28' && i['nome'] == 'Lote 1',
        );
        expect(generatedLote1['frenteM'], 10.0);
        expect(generatedLote1['profundidadeM'], 20.0);
        expect(generatedLote1['areaTerrenoM2'], 200.0);
        expect(generatedLote1['areaConstruidaM2'], 49.96);
        expect(generatedLote1['logradouro'], 'Rua Sandoval Wanderley, s/n');
        expect(generatedLote1['taxaOcupacaoPercent'], 24.98);
        expect(generatedLote1['recuoFrontalM'], 5.05);

        // Lote 15 original mantém suas medidas originais sem duplicação
        final lotes15 = result.items
            .where((i) => i['quadra'] == 'Quadra 28' && i['nome'] == 'Lote 15')
            .toList();
        expect(lotes15, hasLength(1));
        expect(lotes15.first['frenteM'], 12.0);
      },
    );
  });

  group('LoteamentoDraftReviewScreen', () {
    late FakeFirebaseFirestore fakeFirestore;
    late LoteamentosImportRepository repo;
    final sampleLoteamento = Loteamento(
      id: 'lot-existente-1',
      construtoraId: 'c1',
      name: 'Loteamento Existente',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repo = LoteamentosImportRepository(fakeFirestore, _FakeStorage());
    });

    Future<void> seedDraft(String draftId) async {
      await fakeFirestore.collection('loteamentos_drafts').doc(draftId).set({
        'construtoraId': 'c1',
        'targetLoteamentoId': null,
        'status': 'pendente',
        'sourceFormat': 'pdf',
        'sourceFiles': [
          {'filename': 'lote_31_q28.pdf', 'pageCount': 1, 'status': 'processado'},
        ],
        'loteamento': {
          'name': 'Loteamento Jardim Botanico',
          'bairro': 'Estivas',
          'cidade': 'Extremoz',
          'uf': 'RN',
          'proprietarioNome': 'CARNEIRO E OLIVEIRA EMPREENDIMENTOS LTDA',
          'proprietarioDocumento': '69.307.863/0001-02',
          'responsavelTecnicoNome': 'JOCSA RAMOS VARELA',
          'responsavelTecnicoRegistro': '2116022975',
        },
        'items': [
          {
            'quadra': 'Quadra 28',
            'nome': 'Lote 31',
            'frenteM': 10.0,
            'profundidadeM': 20.0,
            'areaTerrenoM2': 200.0,
            'areaConstruidaM2': 49.96,
            'logradouro': 'Rua Sandoval Wanderley, s/n',
            'status': 'valido',
          },
        ],
      });
    }

    testWidgets(
      'exibe tabela de lotes, completa quadra via lote-modelo e aprova gravando contrato tabular',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await seedDraft('draft-review-1');

        final router = GoRouter(
          initialLocation: '/construtoras/c1/loteamentos/draft/draft-review-1',
          routes: [
            GoRoute(
              path: '/construtoras/c1/loteamentos/draft/draft-review-1',
              builder: (_, _) => const LoteamentoDraftReviewScreen(
                construtoraId: 'c1',
                draftId: 'draft-review-1',
              ),
            ),
            GoRoute(
              path: '/construtoras/c1/loteamentos',
              builder: (_, _) => const Scaffold(body: Text('Lista Loteamentos')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              loteamentosImportRepositoryProvider.overrideWithValue(repo),
              watchLoteamentosProvider((construtoraId: 'c1')).overrideWith(
                (ref) => Stream.value([sampleLoteamento]),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LoteamentoCanvasScreen), findsNothing);
        expect(find.byType(GeojsonCanvasWidget), findsNothing);
        expect(find.text('Quadra 28'), findsOneWidget);
        expect(find.text('Lote 31'), findsOneWidget);
        expect(find.text('49,96'), findsOneWidget);

        // Aciona Completar Quadra via Lote-Modelo (gera 1..5 na Quadra 28)
        await tester.tap(find.text('Completar Quadra via Lote-Modelo'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Número final'),
          '5',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Gerar Lotes'));
        await tester.pumpAndSettle();

        expect(
          find.text('Lotes Extraídos (6 lotes • 1 quadra(s))'),
          findsOneWidget,
        );
        expect(find.text('Lote 1'), findsOneWidget);
        expect(find.text('Lote 5'), findsOneWidget);

        // Aprova e consolida
        await tester.tap(find.text('Aprovar e Consolidar'));
        await tester.pumpAndSettle();

        expect(find.text('Lista Loteamentos'), findsOneWidget);

        final saved = (await fakeFirestore
                .collection('loteamentos_drafts')
                .doc('draft-review-1')
                .get())
            .data()!;
        expect(saved['status'], 'aprovado');
        expect(saved['consolidationRequestId'], isA<String>());
        expect(saved['updatedAt'], isA<String>());
        expect(saved['targetLoteamentoId'], isNull);
        expect((saved['loteamento'] as Map)['name'], 'Loteamento Jardim Botanico');
        expect((saved['items'] as List).length, 6);
      },
    );

    testWidgets(
      'rota de rascunho em loteamentosRoutes não referencia LoteamentoCanvasScreen',
      (tester) async {
        final routes = loteamentosRoutes;
        final listRoute = routes.first as GoRoute;
        final draftRoute = listRoute.routes.whereType<GoRoute>().firstWhere(
          (r) => r.path == 'draft/:draftId',
        );
        expect(draftRoute.path, 'draft/:draftId');
      },
    );
  });
}
