import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../obras/presentation/current_permissions_provider.dart';
import '../data/diario_repository.dart';
import '../domain/diario.dart';

final obraDiariosProvider = StreamProvider.autoDispose.family<List<DiarioObra>, ObraScope>((ref, scope) {
  final repo = ref.watch(diarioRepositoryProvider);
  return repo.watchDiarios(scope.construtoraId, scope.obraId);
});
