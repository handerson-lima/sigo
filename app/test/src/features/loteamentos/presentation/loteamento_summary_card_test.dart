import 'package:app/src/design_system/sigo_theme.dart';
import 'package:app/src/features/etapas/domain/etapa.dart';
import 'package:app/src/features/loteamentos/domain/loteamento.dart';
import 'package:app/src/features/loteamentos/presentation/loteamento_summary_card.dart';
import 'package:app/src/features/loteamentos/presentation/loteamento_summary_provider.dart';
import 'package:app/src/features/lotes/domain/lote.dart';
import 'package:app/src/features/quadras/domain/quadra.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Loteamento _buildLoteamento({
  String id = 'lt1',
  String name = 'Vida Nova',
  String? bairro,
  String? cidade,
  String? uf,
  String? proprietarioNome,
  String? responsavelTecnicoNome,
  String? responsavelTecnicoRegistro,
}) {
  final now = DateTime(2026, 10, 1);
  return Loteamento(
    id: id,
    construtoraId: 'c1',
    name: name,
    bairro: bairro,
    cidade: cidade,
    uf: uf,
    proprietarioNome: proprietarioNome,
    responsavelTecnicoNome: responsavelTecnicoNome,
    responsavelTecnicoRegistro: responsavelTecnicoRegistro,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('LoteamentoSummaryCard', () {
    testWidgets(
      'exibe estado completo com localização, carimbo, progresso, distribuição e aciona onTap',
      (tester) async {
        var tapped = false;
        final loteamento = _buildLoteamento(
          bairro: 'Centro',
          cidade: 'Natal',
          uf: 'rn',
          proprietarioNome: 'Construtora Alpha',
          responsavelTecnicoNome: 'Eng. João',
          responsavelTecnicoRegistro: 'CREA 12345',
        );
        const summary = LoteamentoSummary(
          totalQuadras: 3,
          totalLotes: 24,
          lotesConcluidos: 10,
          lotesEmAndamento: 8,
          lotesPendentes: 6,
          progressoMedio: 42,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: SigoTheme.lightTheme,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: LoteamentoSummaryCard(
                  loteamento: loteamento,
                  summary: summary,
                  onTap: () => tapped = true,
                ),
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.map_outlined), findsOneWidget);
        expect(find.text('Vida Nova'), findsOneWidget);
        expect(find.text('Centro • Natal - RN'), findsOneWidget);
        expect(find.text('Em andamento • 42%'), findsOneWidget);

        // Faixa de carimbo
        expect(
          find.byKey(const Key('loteamento_card_carimbo_lt1')),
          findsOneWidget,
        );
        expect(find.text('Construtora Alpha'), findsOneWidget);
        expect(find.text('Eng. João (CREA 12345)'), findsOneWidget);

        // Progresso macro
        expect(
          find.text('Progresso Geral (3 quadras • 24 lotes)'),
          findsOneWidget,
        );
        expect(find.text('42%'), findsOneWidget);
        final progressBar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(progressBar.value, closeTo(0.42, 0.001));
        expect(progressBar.minHeight, 8);

        // Rodapé
        expect(
          find.text('10 concluídos • 8 em andamento • 6 pendentes'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);

        // Semântica
        expect(
          find.bySemanticsLabel(
            'Loteamento Vida Nova, Centro • Natal - RN, 42% concluído, 3 quadras e 24 lotes',
          ),
          findsOneWidget,
        );

        // Clique no card
        await tester.tap(find.text('Vida Nova'));
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'exibe estado mínimo sem localização, sem carimbo e sem métricas',
      (tester) async {
        final loteamento = _buildLoteamento(name: 'Vida Nova');

        await tester.pumpWidget(
          MaterialApp(
            theme: SigoTheme.lightTheme,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: LoteamentoSummaryCard(loteamento: loteamento),
              ),
            ),
          ),
        );

        expect(find.text('Vida Nova'), findsOneWidget);
        expect(find.text('Localização não informada'), findsOneWidget);
        expect(
          find.byKey(const Key('loteamento_card_carimbo_lt1')),
          findsNothing,
        );
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.textContaining('Progresso Geral'), findsNothing);
        expect(find.text('Ver quadras'), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      },
    );

    testWidgets(
      'exibe estado pendente quando há quadras mas 0 lotes',
      (tester) async {
        final loteamento = _buildLoteamento(name: 'Residencial Sol');
        const summary = LoteamentoSummary(
          totalQuadras: 2,
          totalLotes: 0,
          lotesConcluidos: 0,
          lotesEmAndamento: 0,
          lotesPendentes: 0,
          progressoMedio: 0,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: SigoTheme.lightTheme,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: LoteamentoSummaryCard(
                  loteamento: loteamento,
                  summary: summary,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Pendente • 0%'), findsOneWidget);
        expect(
          find.text('Progresso Geral (2 quadras • 0 lotes)'),
          findsOneWidget,
        );
        expect(find.text('0%'), findsOneWidget);
        expect(find.text('Ver quadras'), findsOneWidget);
      },
    );

    testWidgets('exibe estado 100% concluído com cor semântica de conclusão', (
      tester,
    ) async {
      final loteamento = _buildLoteamento(
        name: 'Jardim Real',
        cidade: 'Parnamirim',
        uf: 'RN',
        responsavelTecnicoNome: 'Arq. Maria',
      );
      const summary = LoteamentoSummary(
        totalQuadras: 1,
        totalLotes: 12,
        lotesConcluidos: 12,
        lotesEmAndamento: 0,
        lotesPendentes: 0,
        progressoMedio: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: SigoTheme.lightTheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: LoteamentoSummaryCard(
                loteamento: loteamento,
                summary: summary,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Jardim Real'), findsOneWidget);
      expect(find.text('Parnamirim - RN'), findsOneWidget);
      expect(find.text('Concluído • 100%'), findsOneWidget);
      expect(find.text('Arq. Maria'), findsOneWidget);
      expect(
        find.text('Progresso Geral (1 quadra • 12 lotes)'),
        findsOneWidget,
      );
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('12 concluídos'), findsOneWidget);

      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressBar.value, 1.0);
      final valueColor =
          progressBar.valueColor! as AlwaysStoppedAnimation<Color>;
      expect(valueColor.value, SigoTheme.extension.lotCompleteInk);
    });
  });

  group('computeLoteamentoSummaries', () {
    test('agrega quadras, lotes por status e progresso médio por loteamento', () {
      final now = DateTime(2026, 10, 1);
      final quadras = [
        Quadra(
          id: 'q1',
          construtoraId: 'c1',
          loteamentoId: 'lt1',
          name: 'Quadra 1',
          createdAt: now,
          updatedAt: now,
        ),
        Quadra(
          id: 'q2',
          construtoraId: 'c1',
          loteamentoId: 'lt1',
          name: 'Quadra 2',
          createdAt: now,
          updatedAt: now,
        ),
        Quadra(
          id: 'q3',
          construtoraId: 'c1',
          loteamentoId: 'lt2',
          name: 'Quadra Única',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final lotes = [
        Lote(
          id: 'l1',
          construtoraId: 'c1',
          loteamentoId: 'lt1',
          quadraId: 'q1',
          name: 'Lote 1',
          progressoPercentual: 100,
          etapasConcluidasCount: 5,
          createdAt: now,
          updatedAt: now,
        ),
        Lote(
          id: 'l2',
          construtoraId: 'c1',
          loteamentoId: 'lt1',
          quadraId: 'q1',
          name: 'Lote 2',
          progressoPercentual: 40,
          etapasConcluidasCount: 2,
          statusEtapasMap: const {
            'muro': EtapaStatus.concluida,
            'cinza1': EtapaStatus.concluida,
            'cinza2': EtapaStatus.emAndamento,
            'cinza3': EtapaStatus.pendente,
            'branca': EtapaStatus.pendente,
          },
          createdAt: now,
          updatedAt: now,
        ),
        Lote(
          id: 'l3',
          construtoraId: 'c1',
          loteamentoId: 'lt1',
          quadraId: 'q2',
          name: 'Lote 3',
          progressoPercentual: 0,
          etapasConcluidasCount: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final summaries = computeLoteamentoSummaries(
        quadras: quadras,
        lotes: lotes,
      );

      expect(summaries['lt1'], isNotNull);
      expect(summaries['lt1']!.totalQuadras, 2);
      expect(summaries['lt1']!.totalLotes, 3);
      expect(summaries['lt1']!.lotesConcluidos, 1);
      expect(summaries['lt1']!.lotesEmAndamento, 1);
      expect(summaries['lt1']!.lotesPendentes, 1);
      expect(summaries['lt1']!.progressoMedio, 47); // (100 + 40 + 0) / 3 = 46.67

      expect(summaries['lt2'], isNotNull);
      expect(summaries['lt2']!.totalQuadras, 1);
      expect(summaries['lt2']!.totalLotes, 0);
      expect(summaries['lt2']!.progressoMedio, 0);
    });
  });

  group('watchLoteamentoSummariesForTest (escopado)', () {
    test('agrega apenas loteamentos escopados mesmo com >10 IDs', () async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime(2026, 10, 1);

      for (var i = 1; i <= 12; i++) {
        final ltId = 'lt_$i';
        await firestore.collection('quadras').doc('q_$i').set(
              Quadra(
                id: 'q_$i',
                construtoraId: 'c1',
                loteamentoId: ltId,
                name: 'Q$i',
                createdAt: now,
                updatedAt: now,
              ).toJson(),
            );
        await firestore.collection('lotes').doc('l_$i').set(
              Lote(
                id: 'l_$i',
                construtoraId: 'c1',
                loteamentoId: ltId,
                quadraId: 'q_$i',
                name: 'L$i',
                progressoPercentual: 100,
                etapasConcluidasCount: 5,
                createdAt: now,
                updatedAt: now,
              ).toJson(),
            );
      }
      await firestore.collection('quadras').doc('q_fora').set(
            Quadra(
              id: 'q_fora',
              construtoraId: 'c1',
              loteamentoId: 'lt_fora',
              name: 'Q Fora',
              createdAt: now,
              updatedAt: now,
            ).toJson(),
          );

      final scoped = [for (var i = 1; i <= 12; i++) 'lt_$i'];
      final result = await watchLoteamentoSummariesForTest(
        firestore,
        'c1',
        scopedLoteamentoIds: scoped,
      ).first;

      expect(result.length, 12);
      expect(result.containsKey('lt_fora'), isFalse);
      expect(result['lt_12']?.totalLotes, 1);
      expect(result['lt_12']?.progressoMedio, 100);
    });

    test('propaga erro de consulta parcial no stream de resumos', () async {
      final firestore = _FailingSummaryFirestore(FakeFirebaseFirestore());
      await expectLater(
        watchLoteamentoSummariesForTest(
          firestore,
          'c1',
          scopedLoteamentoIds: const ['lt_1'],
        ).first,
        throwsA(isA<FirebaseException>()),
      );
    });

    test('loteamentoSummaryMapProvider retorna mapa vazio sem Firebase', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sub = container.listen(
        loteamentoSummaryMapProvider('c1'),
        (_, _) {},
      );
      addTearDown(sub.close);

      final value = await container.read(loteamentoSummaryMapProvider('c1').future);
      expect(value, isEmpty);
    });
  });
}

class _FailingSummaryFirestore implements FirebaseFirestore {
  final FakeFirebaseFirestore _delegate;

  _FailingSummaryFirestore(this._delegate);

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    if (path == 'lotes') {
      return _FailingSummaryCollection(_delegate.collection(path));
    }
    return _delegate.collection(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => _delegate.noSuchMethod(invocation);
}

class _FailingSummaryCollection
    implements CollectionReference<Map<String, dynamic>> {
  final CollectionReference<Map<String, dynamic>> _delegate;

  _FailingSummaryCollection(this._delegate);

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) =>
      _FailingSummaryQuery(
        _delegate.where(
          field,
          isEqualTo: isEqualTo,
          isNotEqualTo: isNotEqualTo,
          isLessThan: isLessThan,
          isLessThanOrEqualTo: isLessThanOrEqualTo,
          isGreaterThan: isGreaterThan,
          isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
          arrayContains: arrayContains,
          arrayContainsAny: arrayContainsAny,
          whereIn: whereIn,
          whereNotIn: whereNotIn,
          isNull: isNull,
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => _delegate.noSuchMethod(invocation);
}

class _FailingSummaryQuery implements Query<Map<String, dynamic>> {
  final Query<Map<String, dynamic>> _delegate;

  _FailingSummaryQuery(this._delegate);

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) =>
      _FailingSummaryQuery(
        _delegate.where(
          field,
          isEqualTo: isEqualTo,
          isNotEqualTo: isNotEqualTo,
          isLessThan: isLessThan,
          isLessThanOrEqualTo: isLessThanOrEqualTo,
          isGreaterThan: isGreaterThan,
          isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
          arrayContains: arrayContains,
          arrayContainsAny: arrayContainsAny,
          whereIn: whereIn,
          whereNotIn: whereNotIn,
          isNull: isNull,
        ),
      );

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    return Stream.error(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => _delegate.noSuchMethod(invocation);
}
