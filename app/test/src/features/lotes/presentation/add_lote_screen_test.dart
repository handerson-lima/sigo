import 'dart:async';

import 'package:app/src/features/lotes/data/lote_repository.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/lotes/presentation/add_lote_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class FakeLoteRepository implements LoteRepository {
  final List<Lote> savedLotes = [];
  final List<List<Lote>> savedMassBatches = [];
  final List<String> attemptedIndividualIds = [];
  int individualAttempts = 0;
  bool hangFirstIndividualAttempt = false;

  @override
  Future<void> createLoteComEtapas(Lote lote) async {
    individualAttempts++;
    attemptedIndividualIds.add(lote.id);
    if (hangFirstIndividualAttempt && individualAttempts == 1) {
      return Completer<void>().future;
    }
    savedLotes.add(lote);
  }

  @override
  Future<void> createLotesEmMassa(List<Lote> lotes) async {
    savedMassBatches.add(lotes);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget buildRouterTestApp(FakeLoteRepository fakeRepo) {
  final router = GoRouter(
    initialLocation: '/lotes/novo',
    routes: [
      GoRoute(
        path: '/lotes',
        builder: (context, state) => const Scaffold(body: Text('Tela Lotes')),
        routes: [
          GoRoute(
            path: 'novo',
            builder: (context, state) => const AddLoteScreen(
              construtoraId: 'c1',
              loteamentoId: 'lt1',
              quadraId: 'qd1',
            ),
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [loteRepositoryProvider.overrideWithValue(fakeRepo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets(
    'Modo Individual calcula área automaticamente em pt-br, respeita sobrescrita manual e recalcula ao limpar',
    (tester) async {
      final fakeRepo = FakeLoteRepository();
      await tester.pumpWidget(buildRouterTestApp(fakeRepo));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('lote-individual-name')),
        'Lote 31',
      );
      await tester.enterText(
        find.byKey(const Key('lote-individual-frente')),
        '10,5',
      );
      await tester.enterText(
        find.byKey(const Key('lote-individual-profundidade')),
        '20',
      );
      await tester.pump();

      final areaField = tester.widget<TextFormField>(
        find.byKey(const Key('lote-individual-area-terreno')),
      );
      expect(areaField.controller?.text, '210');

      await tester.enterText(
        find.byKey(const Key('lote-individual-area-terreno')),
        '215,5',
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('lote-individual-frente')),
        '12',
      );
      await tester.pump();
      expect(areaField.controller?.text, '215,5');

      await tester.enterText(
        find.byKey(const Key('lote-individual-area-terreno')),
        '',
      );
      await tester.enterText(
        find.byKey(const Key('lote-individual-profundidade')),
        '25',
      );
      await tester.pump();
      expect(areaField.controller?.text, '300');

      await tester.tap(find.text('Criar Lote'));
      await tester.pumpAndSettle();

      expect(fakeRepo.savedLotes.length, 1);
      final saved = fakeRepo.savedLotes.first;
      expect(saved.name, 'Lote 31');
      expect(saved.frenteM, 12.0);
      expect(saved.profundidadeM, 25.0);
      expect(saved.areaTerrenoM2, 300.0);
      expect(saved.taxaOcupacaoPercent, isNull);
      expect(saved.toJson().containsKey('geometry'), isFalse);
      expect(find.text('Tela Lotes'), findsOneWidget);
    },
  );

  testWidgets(
    'Modo Individual salva dados técnicos opcionais do ExpansionTile e preserva mesmo UUID após timeout',
    (tester) async {
      final fakeRepo = FakeLoteRepository()..hangFirstIndividualAttempt = true;
      await tester.pumpWidget(buildRouterTestApp(fakeRepo));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('lote-individual-name')),
        'Lote 07',
      );
      await tester.enterText(
        find.byKey(const Key('lote-individual-logradouro')),
        'Rua Sandoval Wanderley, s/n',
      );
      await tester.enterText(
        find.byKey(const Key('lote-individual-frente')),
        '10',
      );
      await tester.enterText(
        find.byKey(const Key('lote-individual-profundidade')),
        '20',
      );
      await tester.enterText(
        find.byKey(const Key('lote-individual-area-construida')),
        '49,96',
      );

      final techTile = find.byKey(const Key('lote-dados-tecnicos-tile'));
      await tester.ensureVisible(techTile);
      await tester.tap(techTile);
      await tester.pumpAndSettle();

      final taxaOcupacao = find.byKey(const Key('lote-taxa-ocupacao'));
      await tester.ensureVisible(taxaOcupacao);
      await tester.enterText(taxaOcupacao, '24,98');

      final recuoFrontal = find.byKey(const Key('lote-recuo-frontal'));
      await tester.ensureVisible(recuoFrontal);
      await tester.enterText(recuoFrontal, '5,05');

      final dataProjeto = find.byKey(const Key('lote-data-projeto'));
      await tester.ensureVisible(dataProjeto);
      await tester.enterText(dataProjeto, 'outubro/26');

      final submitBtn = find.widgetWithText(ElevatedButton, 'Criar Lote');
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pump();
      await tester.pump(const Duration(seconds: 16));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(
          'A criação está demorando além do esperado. Os dados continuam sendo sincronizados em segundo plano.',
        ),
        findsOneWidget,
      );
      expect(fakeRepo.savedLotes, isEmpty);
      expect(fakeRepo.attemptedIndividualIds.length, 1);

      ScaffoldMessenger.of(tester.element(submitBtn)).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(fakeRepo.attemptedIndividualIds.length, 2);
      expect(
        fakeRepo.attemptedIndividualIds[0],
        fakeRepo.attemptedIndividualIds[1],
      );
      expect(fakeRepo.savedLotes.length, 1);

      final saved = fakeRepo.savedLotes.first;
      expect(saved.logradouro, 'Rua Sandoval Wanderley, s/n');
      expect(saved.areaConstruidaM2, 49.96);
      expect(saved.taxaOcupacaoPercent, 24.98);
      expect(saved.recuoFrontalM, 5.05);
      expect(saved.dataProjeto, 'outubro/26');
    },
  );

  testWidgets(
    'Modo Em Massa gera prévia editável, ajusta exceção e salva via createLotesEmMassa',
    (tester) async {
      final fakeRepo = FakeLoteRepository();
      await tester.pumpWidget(buildRouterTestApp(fakeRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Em Massa'));
      await tester.pumpAndSettle();

      final submitMassBtn = find.text('Criar Lotes em Massa');
      await tester.ensureVisible(submitMassBtn);
      await tester.tap(submitMassBtn);
      await tester.pump();
      expect(
        find.text('Gere a prévia dos lotes antes de salvar.'),
        findsOneWidget,
      );
      expect(fakeRepo.savedMassBatches, isEmpty);

      for (final entry in <Key, String>{
        const Key('mass-gen-quantidade'): '4',
        const Key('mass-gen-prefixo'): 'Lote ',
        const Key('mass-gen-numero-inicial'): '10',
        const Key('mass-gen-logradouro'): 'Rua A',
        const Key('mass-gen-frente'): '10',
        const Key('mass-gen-profundidade'): '20',
      }.entries) {
        final finder = find.byKey(entry.key);
        await tester.ensureVisible(finder);
        await tester.enterText(finder, entry.value);
      }

      final previewBtn = find.byKey(const Key('mass-gen-preview-btn'));
      await tester.ensureVisible(previewBtn);
      await tester.tap(previewBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mass-preview-item-0')), findsOneWidget);
      expect(find.byKey(const Key('mass-preview-item-3')), findsOneWidget);
      expect(find.text('Lote 10'), findsOneWidget);
      expect(find.text('Lote 13'), findsOneWidget);

      final lote11Frente = find.byKey(const Key('mass-preview-frente-1'));
      await tester.ensureVisible(lote11Frente);
      await tester.enterText(lote11Frente, '12,5');
      await tester.pump();

      final lote11Area = tester.widget<TextFormField>(
        find.byKey(const Key('mass-preview-area-terreno-1')),
      );
      expect(lote11Area.controller?.text, '250');

      await tester.ensureVisible(submitMassBtn);
      await tester.tap(submitMassBtn);
      await tester.pumpAndSettle();

      expect(fakeRepo.savedMassBatches.length, 1);
      final batch = fakeRepo.savedMassBatches.first;
      expect(batch.length, 4);
      expect(batch.map((l) => l.name).toList(), [
        'Lote 10',
        'Lote 11',
        'Lote 12',
        'Lote 13',
      ]);
      expect(batch.map((l) => l.id).toSet().length, 4);

      expect(batch[0].frenteM, 10.0);
      expect(batch[0].areaTerrenoM2, 200.0);
      expect(batch[1].frenteM, 12.5);
      expect(batch[1].profundidadeM, 20.0);
      expect(batch[1].areaTerrenoM2, 250.0);
      expect(batch[2].frenteM, 10.0);
      expect(batch[2].areaTerrenoM2, 200.0);
      expect(batch[3].frenteM, 10.0);
      expect(batch[3].areaTerrenoM2, 200.0);
      for (final lote in batch) {
        expect(lote.logradouro, 'Rua A');
        expect(lote.toJson().containsKey('geometry'), isFalse);
      }
      expect(find.text('Tela Lotes'), findsOneWidget);
    },
  );
}
