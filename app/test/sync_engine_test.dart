import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/sync/operation_queue.dart';
import 'package:app/src/sync/sync_engine.dart';

class _FakeQueue extends OperationQueue {
  _FakeQueue({
    required super.sessionUid,
    required super.store,
    required super.upload,
    required super.execute,
  });

  int syncCallCount = 0;
  Completer<void>? pendingSyncCompleter;

  @override
  Future<void> sync({
    String? onlyKey,
    String? construtoraId,
    String? obraId,
  }) async {
    syncCallCount++;
    if (pendingSyncCompleter != null) {
      await pendingSyncCompleter!.future;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<List<ConnectivityResult>> connectivityController;
  late _FakeQueue fakeQueue;

  setUp(() {
    connectivityController = StreamController<List<ConnectivityResult>>.broadcast();
    fakeQueue = _FakeQueue(
      sessionUid: () => 'alice',
      store: (action, input) async => 'null',
      upload: (a, b, u) async {},
      execute: (a, p) async {},
    );
  });

  tearDown(() {
    connectivityController.close();
  });

  group('Story 2.8 — Sync Engine', () {
    test('Inicializa com status idle quando conectividade inicial é online', () async {
      final engine = SyncEngine(
        queue: fakeQueue,
        connectivityStream: connectivityController.stream,
        checkConnectivity: () async => [ConnectivityResult.wifi],
        periodicInterval: const Duration(seconds: 10),
        autoStart: true,
        observeLifecycle: false,
      );

      // Aguarda checagem inicial
      await Future<void>.delayed(Duration.zero);

      expect(engine.isOnline, isTrue);
      expect(engine.status, SyncEngineStatus.idle);
      engine.dispose();
    });

    test('Inicializa com status offline quando conectividade inicial é none', () async {
      final engine = SyncEngine(
        queue: fakeQueue,
        connectivityStream: connectivityController.stream,
        checkConnectivity: () async => [ConnectivityResult.none],
        periodicInterval: const Duration(seconds: 10),
        autoStart: true,
        observeLifecycle: false,
      );

      await Future<void>.delayed(Duration.zero);

      expect(engine.isOnline, isFalse);
      expect(engine.status, SyncEngineStatus.offline);
      engine.dispose();
    });

    test('Transição de offline para online engatilha syncNow imediatamente', () async {
      final engine = SyncEngine(
        queue: fakeQueue,
        connectivityStream: connectivityController.stream,
        checkConnectivity: () async => [ConnectivityResult.none],
        periodicInterval: const Duration(seconds: 10),
        autoStart: true,
        observeLifecycle: false,
      );

      await Future<void>.delayed(Duration.zero);
      expect(engine.status, SyncEngineStatus.offline);
      expect(fakeQueue.syncCallCount, 0);

      // Conexão restabelecida
      connectivityController.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);

      expect(engine.isOnline, isTrue);
      expect(fakeQueue.syncCallCount, 1);
      engine.dispose();
    });

    test('Quando offline, chamadas a syncNow são suspensas', () async {
      final engine = SyncEngine(
        queue: fakeQueue,
        connectivityStream: connectivityController.stream,
        checkConnectivity: () async => [ConnectivityResult.none],
        periodicInterval: const Duration(seconds: 10),
        autoStart: true,
        observeLifecycle: false,
      );

      await Future<void>.delayed(Duration.zero);
      expect(engine.isOnline, isFalse);

      await engine.syncNow();
      expect(fakeQueue.syncCallCount, 0);
      expect(engine.status, SyncEngineStatus.offline);
      engine.dispose();
    });

    test('AppLifecycleState.resumed engatilha sincronização imediata se online', () async {
      final engine = SyncEngine(
        queue: fakeQueue,
        connectivityStream: connectivityController.stream,
        checkConnectivity: () async => [ConnectivityResult.wifi],
        periodicInterval: const Duration(seconds: 10),
        autoStart: true,
        observeLifecycle: false,
      );

      await Future<void>.delayed(Duration.zero);
      fakeQueue.syncCallCount = 0; // zera contagem da inicialização

      engine.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(fakeQueue.syncCallCount, 1);
      engine.dispose();
    });

    test('pause() suspende o motor e resume() retoma e dispara sync', () async {
      final engine = SyncEngine(
        queue: fakeQueue,
        connectivityStream: connectivityController.stream,
        checkConnectivity: () async => [ConnectivityResult.wifi],
        periodicInterval: const Duration(seconds: 10),
        autoStart: true,
        observeLifecycle: false,
      );

      await Future<void>.delayed(Duration.zero);
      fakeQueue.syncCallCount = 0;

      engine.pause();
      expect(engine.isPaused, isTrue);
      expect(engine.status, SyncEngineStatus.paused);

      // Em pausa, syncNow não é executado
      await engine.syncNow();
      expect(fakeQueue.syncCallCount, 0);

      // Ao retomar, reconecta e sincroniza
      engine.resume();
      expect(engine.isPaused, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(fakeQueue.syncCallCount, 1);

      engine.dispose();
    });

    test('Transição para status syncing durante execução do syncNow', () async {
      fakeQueue.pendingSyncCompleter = Completer<void>();

      final engine = SyncEngine(
        queue: fakeQueue,
        connectivityStream: connectivityController.stream,
        checkConnectivity: () async => [ConnectivityResult.wifi],
        periodicInterval: const Duration(seconds: 10),
        autoStart: false,
        observeLifecycle: false,
      );

      final syncFuture = engine.syncNow();
      await Future<void>.delayed(Duration.zero);

      expect(engine.status, SyncEngineStatus.syncing);

      fakeQueue.pendingSyncCompleter!.complete();
      await syncFuture;

      expect(engine.status, SyncEngineStatus.idle);
      engine.dispose();
    });

    test('Provedores Riverpod instanciam syncEngineProvider e syncStatusProvider', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final engine = container.read(syncEngineProvider);
      expect(engine, isNotNull);
      expect(engine.statusListenable, isNotNull);
    });
  });
}
