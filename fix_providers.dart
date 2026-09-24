import 'dart:io';

void main() async {
  // Setor Repo
  final srFile = File('app/lib/src/features/setores/data/setor_repository.dart');
  var srContent = await srFile.readAsString();
  if (!srContent.contains('watchSetoresProvider')) {
    srContent += '''
final watchSetoresProvider = StreamProvider.family<List<Setor>, Map<String, String>>((ref, params) {
  final repo = ref.watch(setorRepositoryProvider);
  return repo.watchSetores(
    params['construtoraId']!,
    params['loteamentoId']!,
    params['quadraId']!,
    params['loteId']!,
  );
});
''';
    await srFile.writeAsString(srContent);
  }

  // Equipe Repo
  final erFile = File('app/lib/src/features/equipes/data/equipe_repository.dart');
  var erContent = await erFile.readAsString();
  if (!erContent.contains('watchEquipesProvider')) {
    erContent += '''
final watchEquipesProvider = StreamProvider.family<List<Equipe>, Map<String, String>>((ref, params) {
  final repo = ref.watch(equipeRepositoryProvider);
  return repo.watchEquipes(
    params['construtoraId']!,
    params['loteamentoId']!,
    params['quadraId']!,
    params['loteId']!,
    params['setorId']!,
  );
});
''';
    await erFile.writeAsString(erContent);
  }
}
