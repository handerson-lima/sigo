import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/common_widgets/sigo_top_bar.dart';
import 'package:app/src/features/authentication/data/auth_repository.dart';
import 'package:app/src/sync/operation_queue.dart';
import 'package:app/src/sync/sync_engine.dart';
import 'package:app/src/sync/sync_indicator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Story 2.12 — Indicador de Sincronização (SyncIndicator)', () {
    testWidgets(
      'renderiza estado Sincronizado quando online e sem pendencias',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncSummaryProvider.overrideWithValue(
                const SyncSummary(
                  isOnline: true,
                  engineStatus: SyncEngineStatus.idle,
                  pendingCount: 0,
                  failedCount: 0,
                  alertCount: 0,
                ),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: Center(child: SyncIndicator())),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('sync-indicator')), findsOneWidget);
        expect(find.byKey(const Key('sync-indicator-label')), findsOneWidget);
        expect(find.text('Sincronizado'), findsOneWidget);
        expect(find.byIcon(Icons.cloud_done), findsOneWidget);
        expect(find.byKey(const Key('sync-indicator-badge')), findsNothing);
      },
    );

    testWidgets('renderiza estado Sincronizando quando em transmissao ativa', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncSummaryProvider.overrideWithValue(
              const SyncSummary(
                isOnline: true,
                engineStatus: SyncEngineStatus.syncing,
                pendingCount: 3,
                failedCount: 0,
                alertCount: 0,
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Center(child: SyncIndicator())),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('sync-indicator')), findsOneWidget);
      expect(find.text('Sincronizando...'), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('sync-indicator')),
          matching: find.byType(RotationTransition),
        ),
        findsOneWidget,
      );
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets(
      'renderiza estado Offline com contador de alteracoes pendentes preservadas',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncSummaryProvider.overrideWithValue(
                const SyncSummary(
                  isOnline: false,
                  engineStatus: SyncEngineStatus.offline,
                  pendingCount: 2,
                  failedCount: 0,
                  alertCount: 0,
                ),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: Center(child: SyncIndicator())),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('sync-indicator')), findsOneWidget);
        expect(find.text('Offline (2)'), findsOneWidget);
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
        expect(find.byKey(const Key('sync-indicator-badge')), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
      },
    );

    testWidgets('renderiza estado Offline puro quando sem pendencias locais', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncSummaryProvider.overrideWithValue(
              const SyncSummary(
                isOnline: false,
                engineStatus: SyncEngineStatus.offline,
                pendingCount: 0,
                failedCount: 0,
                alertCount: 0,
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Center(child: SyncIndicator())),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Offline'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.byKey(const Key('sync-indicator-badge')), findsNothing);
    });

    testWidgets(
      'renderiza estado Falha quando ha operacoes com erro ou falha no motor',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncSummaryProvider.overrideWithValue(
                const SyncSummary(
                  isOnline: true,
                  engineStatus: SyncEngineStatus.error,
                  pendingCount: 0,
                  failedCount: 1,
                  alertCount: 0,
                  lastError: 'Falha de conexao temporaria',
                ),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: Center(child: SyncIndicator())),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Falha'), findsOneWidget);
        expect(find.byIcon(Icons.sync_problem), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
      },
    );

    testWidgets(
      'renderiza estado Atencao quando ha conflito ou autorizacao rejeitada',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncSummaryProvider.overrideWithValue(
                const SyncSummary(
                  isOnline: true,
                  engineStatus: SyncEngineStatus.idle,
                  pendingCount: 1,
                  failedCount: 0,
                  alertCount: 1,
                  lastError: 'Acesso recusado',
                ),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: Center(child: SyncIndicator())),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Atenção'), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
      },
    );

    testWidgets(
      'toque no SyncIndicator abre o dialogo de status e aciona sincronizacao manual',
      (tester) async {
        final testEngine = SyncEngine(
          queue: OperationQueue.instance,
          connectivityStream: const Stream.empty(),
          checkConnectivity: () async => [ConnectivityResult.wifi],
          periodicInterval: const Duration(days: 1),
          autoStart: false,
          observeLifecycle: false,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncEngineProvider.overrideWithValue(testEngine),
              syncSummaryProvider.overrideWithValue(
                const SyncSummary(
                  isOnline: true,
                  engineStatus: SyncEngineStatus.idle,
                  pendingCount: 3,
                  failedCount: 0,
                  alertCount: 0,
                ),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SyncIndicator(construtoraId: 'c1', obraId: 'o1'),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Clica no indicador para abrir o diálogo
        await tester.tap(find.byKey(const Key('sync-indicator')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('sync-status-dialog')), findsOneWidget);
        expect(find.text('Tudo Sincronizado'), findsOneWidget);
        expect(find.text('Operações locais pendentes'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.byKey(const Key('sync-now-button')), findsOneWidget);
        expect(find.byKey(const Key('view-queue-button')), findsOneWidget);

        // Clica no botão de sincronizar agora
        await tester.tap(find.byKey(const Key('sync-now-button')));
        await tester.pumpAndSettle();

        // Diálogo deve fechar após acionar
        expect(find.byKey(const Key('sync-status-dialog')), findsNothing);
      },
    );

    testWidgets(
      'SigoTopBar embute SyncIndicator automaticamente em suas actions',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateChangesProvider.overrideWith(
                (ref) => Stream.value(null),
              ),
              syncSummaryProvider.overrideWithValue(
                const SyncSummary(
                  isOnline: true,
                  engineStatus: SyncEngineStatus.idle,
                  pendingCount: 0,
                  failedCount: 0,
                  alertCount: 0,
                ),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(appBar: SigoTopBar(title: 'Teste TopBar')),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('sync-indicator')), findsOneWidget);
        expect(find.text('Sincronizado'), findsOneWidget);
        expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      },
    );
  });
}
