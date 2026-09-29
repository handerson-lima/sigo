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
      'aprova rascunho com lotes ambíguos após confirmação',
      (tester) async {
        final repository = _ApprovingRepository();
        final router = GoRouter(
          initialLocation: '/revisao',
          routes: [
            GoRoute(
              path: '/revisao',
              builder: (_, _) => const LoteamentoCanvasScreen(
                construtoraId: 'const-1',
                draftId: 'draft-1',
              ),
            ),
            GoRoute(
              path: '/construtoras/:id/loteamentos',
              builder: (_, _) =>
                  const Scaffold(body: Text('Lista de loteamentos')),
            ),
          ],
        );
        final mockData = {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'properties': {'tipo': 'lote', 'status': 'ambiguo', 'nome': ''},
            },
            {
              'type': 'Feature',
              'properties': {
                'tipo': 'lote',
                'status': 'resolvido',
                'nome': 'L 1',
              },
            },
          ],
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              loteamentosImportRepositoryProvider.overrideWithValue(
                repository,
              ),
              canvasDraftStreamProvider.overrideWith(
                (ref, id) => Stream.value(mockData),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('1 Pendências'), findsOneWidget);

        final buttonFinder = find.widgetWithText(
          FilledButton,
          'Aprovar Definitivamente',
        );
        final button = tester.widget<FilledButton>(buttonFinder);
        expect(
          button.onPressed,
          isNotNull,
          reason: 'Ambiguidade não deve mais bloquear a aprovação',
        );

        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();

        expect(find.textContaining('1 lote'), findsOneWidget);
        expect(repository.approvedDraftId, isNull);

        await tester.tap(find.widgetWithText(FilledButton, 'Aprovar'));
        await tester.pumpAndSettle();

        expect(repository.approvedDraftId, 'draft-1');
        expect(
          router.routeInformationProvider.value.uri.path,
          '/construtoras/const-1/loteamentos',
        );
      },
    );

    testWidgets('cancelar a confirmação não aprova o rascunho', (
      tester,
    ) async {
      final repository = _ApprovingRepository();
      final mockData = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {'tipo': 'lote', 'status': 'ambiguo', 'nome': ''},
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
          child: const MaterialApp(
            home: LoteamentoCanvasScreen(
              construtoraId: 'const-1',
              draftId: 'draft-1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(FilledButton, 'Aprovar Definitivamente'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(repository.approvedDraftId, isNull);
    });

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

    testWidgets('pede confirmação para lote resolvido sem nome e aprova', (
      tester,
    ) async {
      final repository = _ApprovingRepository();
      final router = GoRouter(
        initialLocation: '/revisao',
        routes: [
          GoRoute(
            path: '/revisao',
            builder: (_, _) => const LoteamentoCanvasScreen(
              construtoraId: 'const-1',
              draftId: 'draft-1',
            ),
          ),
          GoRoute(
            path: '/construtoras/:id/loteamentos',
            builder: (_, _) =>
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
              'nome': '',
              'quadra': '',
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

      expect(find.text('0 Pendências'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Aprovar Definitivamente'),
      );
      expect(button.onPressed, isNotNull);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Aprovar Definitivamente'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('1 lote'), findsOneWidget);
      expect(repository.approvedDraftId, isNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Aprovar'));
      await tester.pumpAndSettle();
      expect(repository.approvedDraftId, 'draft-1');
    });

    testWidgets('confirma lote ambíguo mesmo com nome tentativo', (
      tester,
    ) async {
      final repository = _ApprovingRepository();
      final mockData = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {
              'tipo': 'lote',
              'status': 'ambiguo',
              'nome': 'ESTRADA CARROÇÁVEL',
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
          child: const MaterialApp(
            home: LoteamentoCanvasScreen(
              construtoraId: 'const-1',
              draftId: 'draft-1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(FilledButton, 'Aprovar Definitivamente'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('1 lote'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(repository.approvedDraftId, isNull);
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

    testWidgets('aprova e navega para a lista', (tester) async {
      final repository = _ApprovingRepository();
      final router = GoRouter(
        initialLocation: '/revisao',
        routes: [
          GoRoute(
            path: '/revisao',
            builder: (_, _) => const LoteamentoCanvasScreen(
              construtoraId: 'const-1',
              draftId: 'draft-1',
            ),
          ),
          GoRoute(
            path: '/construtoras/:id/loteamentos',
            builder: (_, _) =>
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
      expect(find.text('Rascunho aprovado.'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/construtoras/const-1/loteamentos',
      );
    });
  });
}
