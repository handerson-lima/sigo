import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/custos_360_repository.dart';
import '../../domain/custo_lote_consolidado.dart';

final resumoCustosObraStreamProvider = StreamProvider.family<
    ResumoCustosObra,
    ({String construtoraId, String obraId})>((ref, arg) {
  final repo = ref.watch(custos360RepositoryProvider);
  return repo.watchResumoObra(arg.construtoraId, arg.obraId);
});

final loteCustoConsolidadoProvider = Provider.family<
    CustoLoteConsolidado?,
    ({String construtoraId, String obraId, String loteId})>((ref, arg) {
  final resumoAsync = ref.watch(
    resumoCustosObraStreamProvider(
      (construtoraId: arg.construtoraId, obraId: arg.obraId),
    ),
  );

  return resumoAsync.when(
    data: (resumo) {
      try {
        return resumo.lotesCustos.firstWhere((l) => l.loteId == arg.loteId);
      } catch (_) {
        return null;
      }
    },
    loading: () => null,
    error: (err, stack) => null,
  );
});

final extratoLoteFutureProvider = FutureProvider.family<
    List<ExtratoItemCusto>,
    ({String construtoraId, String obraId, String loteId})>((ref, arg) {
  final repo = ref.watch(custos360RepositoryProvider);
  return repo.buscarExtratoLote(
    construtoraId: arg.construtoraId,
    obraId: arg.obraId,
    loteId: arg.loteId,
  );
});

class Custos360Controller {
  final Custos360Repository _repository;

  Custos360Controller(this._repository);

  Future<bool> atualizarOrcamentoLote({
    required String construtoraId,
    required String obraId,
    required String loteId,
    required int orcamentoPrevistoCents,
  }) async {
    try {
      await _repository.atualizarOrcamentoLote(
        construtoraId: construtoraId,
        obraId: obraId,
        loteId: loteId,
        orcamentoPrevistoCents: orcamentoPrevistoCents,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

final custos360ControllerProvider = Provider<Custos360Controller>((ref) {
  final repo = ref.watch(custos360RepositoryProvider);
  return Custos360Controller(repo);
});
