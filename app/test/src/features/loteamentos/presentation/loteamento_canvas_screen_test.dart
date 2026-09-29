import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:app/src/features/loteamentos/data/loteamentos_import_repository.dart';
import 'package:app/src/features/loteamentos/presentation/loteamento_canvas_screen.dart';
import 'package:app/src/features/loteamentos/presentation/widgets/geojson_canvas_widget.dart';

class _FakeFirebaseStorage extends Fake implements FirebaseStorage {}

class _ApprovingRepository extends LoteamentosImportRepository {
  _ApprovingRepository()
    : super(FakeFirebaseFirestore(), _FakeFirebaseStorage());

  String? approvedDraftId;

  @override
  Future<void> approveDraft(String draftId) async {
    approvedDraftId = draftId;
  }
}

void main() {
  group('LoteamentoCanvasScreen', () {
    testWidgets('renderiza o loading enquanto aguarda o provider', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canvasDraftStreamProvider.overrideWith((ref, id) {
              return const Stream.empty(); // Fica aguardando
            }),
          ],
          child: const MaterialApp(
            home: LoteamentoCanvasScreen(
              construtoraId: 'const-1',
              draftId: 'test-123',
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renderiza GeojsonCanvasWidget quando o dado e recebido', (
      tester,
    ) async {
      final mockData = {'type': 'FeatureCollection', 'features': []};

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canvasDraftStreamProvider.overrideWith((ref, id) {
              return Stream.value(mockData);
            }),
          ],
          child: const MaterialApp(
            home: LoteamentoCanvasScreen(
              construtoraId: 'const-1',
              draftId: 'test-123',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(GeojsonCanvasWidget), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Aprovar Definitivamente'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('renderiza erro se o stream falhar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canvasDraftStreamProvider.overrideWith((ref, id) {
              return Stream.error(Exception('Falha no banco'));
            }),
          ],
          child: const MaterialApp(
            home: LoteamentoCanvasScreen(
              construtoraId: 'const-1',
              draftId: 'test-123',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Falha no banco'), findsOneWidget);
    });
    testWidgets(
      'Aprovar button is disabled when there are ambiguous features',
      (tester) async {
        final mockData = {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'properties': {'status': 'ambiguo'},
            },
            {
              'type': 'Feature',
              'properties': {'status': 'resolvido'},
            },
          ],
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              canvasDraftStreamProvider.overrideWith((ref, id) {
                return Stream.value(mockData);
              }),
            ],
            child: const MaterialApp(
              home: LoteamentoCanvasScreen(
                construtoraId: 'const-1',
                draftId: 'test-123',
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('1 Pendências'), findsOneWidget);

        final buttonFinder = find.widgetWithText(
          FilledButton,
          'Aprovar Definitivamente',
        );
        expect(buttonFinder, findsOneWidget);
        final button = tester.widget<FilledButton>(buttonFinder);
        expect(
          button.onPressed,
          isNull,
          reason: 'O botão deve estar desabilitado',
        );
      },
    );

    testWidgets(
      'Aprovar button is enabled when there are no ambiguous features',
      (tester) async {
        final mockData = {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'properties': {
                'tipo': 'lote',
                'status': 'resolvido',
                'nome': 'Lote 1',
                'quadra': 'Quadra 1',
              },
            },
          ],
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              canvasDraftStreamProvider.overrideWith((ref, id) {
                return Stream.value(mockData);
              }),
            ],
            child: const MaterialApp(
              home: LoteamentoCanvasScreen(
                construtoraId: 'const-1',
                draftId: 'test-123',
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('0 Pendências'), findsOneWidget);

        final buttonFinder = find.widgetWithText(
          FilledButton,
          'Aprovar Definitivamente',
        );
        expect(buttonFinder, findsOneWidget);
        final button = tester.widget<FilledButton>(buttonFinder);
        expect(
          button.onPressed,
          isNotNull,
          reason: 'O botão deve estar habilitado',
        );
      },
    );

    testWidgets('permite aprovação sem campos auxiliares quando não há pendências', (
      tester,
    ) async {
      final mockData = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {
              'tipo': 'lote',
              'status': 'resolvido',
              'nome': '',
              'quadra': '',
            },
          },
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canvasDraftStreamProvider.overrideWith(
              (ref, id) => Stream.value(mockData),
            ),
          ],
          child: const MaterialApp(
            home: LoteamentoCanvasScreen(
              construtoraId: 'const-1',
              draftId: 'test-123',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Aprovar Definitivamente'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('bloqueia aprovação sem lote', (
      tester,
    ) async {
      for (final properties in [
        {'tipo': 'quadra', 'nome': ''},
        {'tipo': 'rua', 'nome': 'Rua 1'},
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              canvasDraftStreamProvider.overrideWith(
                (ref, id) => Stream.value({
                  'features': [
                    {'properties': properties},
                  ],
                }),
              ),
            ],
            child: const MaterialApp(
              home: LoteamentoCanvasScreen(
                construtoraId: 'const-1',
                draftId: 'test-123',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Aprovar Definitivamente'),
        );
        expect(button.onPressed, isNull);
      }
    });

    testWidgets('bloqueia aprovação de rascunho apenas com quadras', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canvasDraftStreamProvider.overrideWith(
              (ref, id) => Stream.value({
                'features': [
                  {
                    'properties': {'tipo': 'quadra', 'nome': 'Q 1'},
                  },
                ],
              }),
            ),
          ],
          child: const MaterialApp(
            home: LoteamentoCanvasScreen(
              construtoraId: 'const-1',
              draftId: 'test-123',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Aprovar Definitivamente'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('aprova, informa a consolidação e navega para a lista', (
      tester,
    ) async {
      final repository = _ApprovingRepository();
      final router = GoRouter(
        initialLocation: '/revisao',
        routes: [
          GoRoute(
            path: '/revisao',
            builder: (_, __) => const LoteamentoCanvasScreen(
              construtoraId: 'const-1',
              draftId: 'draft-1',
            ),
          ),
          GoRoute(
            path: '/construtoras/:id/loteamentos',
            builder: (_, __) =>
                const Scaffold(body: Text('Lista de loteamentos')),
          ),
        ],
      );
      final mockData = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {
              'tipo': 'lote',
              'status': 'resolvido',
              'nome': 'L 1',
              'quadra': 'Q 1',
            },
          },
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loteamentosImportRepositoryProvider.overrideWithValue(repository),
            canvasDraftStreamProvider.overrideWith(
              (ref, id) => Stream.value(mockData),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(FilledButton, 'Aprovar Definitivamente'),
      );
      await tester.pump();

      expect(repository.approvedDraftId, 'draft-1');
      expect(
        find.text(
          'Consolidação iniciada. O loteamento aparecerá na lista ao concluir.',
        ),
        findsOneWidget,
      );
      expect(
        router.routeInformationProvider.value.uri.path,
        '/construtoras/const-1/loteamentos',
      );
    });
  });
}
