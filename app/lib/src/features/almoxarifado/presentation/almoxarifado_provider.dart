import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/almoxarifado_repository.dart';
import '../domain/material.dart' as mat;

final construtoraMateriaisProvider = StreamProvider.autoDispose.family<List<mat.Material>, String>((ref, construtoraId) {
  final repo = ref.watch(almoxarifadoRepositoryProvider);
  return repo.watchMateriais(construtoraId);
});
