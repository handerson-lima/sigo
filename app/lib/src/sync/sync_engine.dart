import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'operation_queue.dart';

enum SyncEngineStatus { idle, syncing, offline, paused, error }

class SyncEngine with WidgetsBindingObserver {
  static bool get isRunningTests {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  SyncEngine({
    OperationQueue? queue,
    Stream<List<ConnectivityResult>>? connectivityStream,
    Future<List<ConnectivityResult>> Function()? checkConnectivity,
    this.periodicInterval = const Duration(seconds: 15),
    bool? autoStart,
    this.observeLifecycle = true,
  }) : _queue = queue ?? OperationQueue.instance,
       _connectivityStream =
           connectivityStream ?? Connectivity().onConnectivityChanged,
       _checkConnectivity =
           checkConnectivity ?? Connectivity().checkConnectivity {
    if (observeLifecycle) {
      WidgetsBinding.instance.addObserver(this);
    }
    final shouldStart = autoStart ?? !isRunningTests;
    if (shouldStart) {
      start();
    }
  }

  static final instance = SyncEngine();

  final OperationQueue _queue;
  final Stream<List<ConnectivityResult>> _connectivityStream;
  final Future<List<ConnectivityResult>> Function() _checkConnectivity;
  final Duration periodicInterval;
  final bool observeLifecycle;

  final ValueNotifier<SyncEngineStatus> _statusNotifier =
      ValueNotifier<SyncEngineStatus>(SyncEngineStatus.idle);
  final StreamController<SyncEngineStatus> _statusStreamController =
      StreamController<SyncEngineStatus>.broadcast();

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isOnline = true;
  bool _isPaused = false;
  bool _isDisposed = false;
  String? _lastError;

  ValueListenable<SyncEngineStatus> get statusListenable => _statusNotifier;
  SyncEngineStatus get status => _statusNotifier.value;
  Stream<SyncEngineStatus> get statusStream => _statusStreamController.stream;
  bool get isOnline => _isOnline;
  bool get isPaused => _isPaused;
  String? get lastError => _lastError ?? _queue.lastError;

  void _updateStatus(SyncEngineStatus newStatus) {
    if (_isDisposed || _statusNotifier.value == newStatus) return;
    _statusNotifier.value = newStatus;
    _statusStreamController.add(newStatus);
  }

  void start() {
    if (_isDisposed) return;
    _isPaused = false;

    // Inicializa verificação de conectividade
    unawaited(_checkInitialConnectivity());

    // Ouve alterações de conectividade
    _connectivitySub ??= _connectivityStream.listen(_onConnectivityChanged);

    // Inicia timer periódico de heartbeat
    _timer?.cancel();
    _timer = Timer.periodic(periodicInterval, (_) {
      if (_isOnline && !_isPaused && status != SyncEngineStatus.syncing) {
        unawaited(syncNow());
      }
    });
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await _checkConnectivity();
      _onConnectivityChanged(results);
    } catch (_) {
      _isOnline = true;
      _updateStatus(SyncEngineStatus.idle);
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (_isDisposed) return;
    final wasOnline = _isOnline;
    final nowOnline = results.any((r) => r != ConnectivityResult.none);
    _isOnline = nowOnline;

    if (!nowOnline) {
      _updateStatus(SyncEngineStatus.offline);
    } else {
      if (!wasOnline) {
        // Acabou de voltar a ficar online: dispara sync imediatamente
        _updateStatus(SyncEngineStatus.idle);
        if (!_isPaused) {
          unawaited(syncNow());
        }
      } else if (status == SyncEngineStatus.offline) {
        _updateStatus(SyncEngineStatus.idle);
      }
    }
  }

  Future<void> syncNow({
    String? onlyKey,
    String? construtoraId,
    String? obraId,
  }) async {
    if (_isDisposed ||
        _isPaused ||
        !_isOnline ||
        status == SyncEngineStatus.syncing) {
      return;
    }

    _updateStatus(SyncEngineStatus.syncing);
    try {
      await _queue.sync(
        onlyKey: onlyKey,
        construtoraId: construtoraId,
        obraId: obraId,
      );
      _lastError = _queue.lastError;
      if (!_isOnline) {
        _updateStatus(SyncEngineStatus.offline);
      } else if (_isPaused) {
        _updateStatus(SyncEngineStatus.paused);
      } else if (_lastError != null) {
        _updateStatus(SyncEngineStatus.error);
      } else {
        _updateStatus(SyncEngineStatus.idle);
      }
    } catch (e) {
      _lastError = e.toString();
      _updateStatus(SyncEngineStatus.error);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isOnline && !_isPaused) {
      unawaited(syncNow());
    }
  }

  void pause() {
    if (_isDisposed) return;
    _isPaused = true;
    _timer?.cancel();
    _timer = null;
    _updateStatus(SyncEngineStatus.paused);
  }

  void resume() {
    if (_isDisposed) return;
    _isPaused = false;
    start();
    if (_isOnline) {
      unawaited(syncNow());
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _timer?.cancel();
    _timer = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
    if (observeLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _statusStreamController.close();
    _statusNotifier.dispose();
  }
}

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine.instance;
  ref.onDispose(engine.dispose);
  return engine;
});

final syncStatusProvider = StreamProvider<SyncEngineStatus>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine.statusStream;
});
