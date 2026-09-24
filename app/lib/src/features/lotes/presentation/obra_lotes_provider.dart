import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../obras/presentation/current_permissions_provider.dart';
import '../data/lote_repository.dart';
import '../domain/lote.dart';

final obraLotesProvider = StreamProvider.autoDispose.family<List<Lote>, ObraScope>((ref, scope) {
  final repo = ref.watch(loteRepositoryProvider);
  return repo.watchLotes(scope.construtoraId, 'dummy', 'dummy');
});
