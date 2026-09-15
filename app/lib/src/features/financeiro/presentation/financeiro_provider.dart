import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/financeiro_repository.dart';
import '../domain/despesa.dart';

final despesasConstrutoraProvider = StreamProvider.autoDispose.family<List<Despesa>, String>((ref, construtoraId) {
  return ref.watch(financeiroRepositoryProvider).watchDespesas(construtoraId);
});
