import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_repository.dart';
import '../data/fornecedores_repository.dart';
import '../domain/fornecedor.dart';

final fornecedoresControllerProvider =
    AsyncNotifierProvider<FornecedoresController, void>(
        FornecedoresController.new);

class FornecedoresController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Initial state is idle (AsyncData(null))
  }

  Future<bool> salvarFornecedor(Fornecedor fornecedor) async {
    state = const AsyncLoading();
    final auth = ref.read(authRepositoryProvider);
    final repo = ref.read(fornecedoresRepositoryProvider);

    state = await AsyncValue.guard(() async {
      final uid = auth.currentUser?.uid;
      final itemComUid = fornecedor.copyWith(
        criadoPorUid: fornecedor.criadoPorUid ?? uid,
        atualizadoPorUid: uid,
      );
      await repo.salvarFornecedor(itemComUid);
    });

    return !state.hasError;
  }

  Future<bool> toggleStatus({
    required String construtoraId,
    required String fornecedorId,
    required bool ativo,
  }) async {
    state = const AsyncLoading();
    final auth = ref.read(authRepositoryProvider);
    final repo = ref.read(fornecedoresRepositoryProvider);

    state = await AsyncValue.guard(() async {
      final uid = auth.currentUser?.uid;
      await repo.toggleStatus(
        construtoraId,
        fornecedorId,
        ativo,
        atualizadoPorUid: uid,
      );
    });

    return !state.hasError;
  }
}
