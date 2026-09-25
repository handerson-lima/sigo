import 'dart:io';

void main() {
  final files = [
    'test/features/construtoras/membros_test.dart',
    'test/custos_360_presentation_test.dart',
  ];
  
  for (final path in files) {
    final file = File(path);
    if (file.existsSync()) {
      var content = file.readAsStringSync();
      content = content.replaceAll('Atribuir à obra', 'Atribuir ao loteamento');
      content = content.replaceAll('Nenhuma obra vinculada', 'Nenhum loteamento vinculado');
      content = content.replaceAll('Remover da obra', 'Remover do loteamento');
      content = content.replaceAll('erro ao carregar obras', 'erro ao carregar loteamentos');
      content = content.replaceAll('carregando obras', 'carregando loteamentos');
      content = content.replaceAll('Obras vinculadas', 'Loteamentos vinculados');
      content = content.replaceAll('Obras afetadas:', 'Loteamentos afetados:');
      content = content.replaceAll('Não foi possível carregar as obras.', 'Não foi possível carregar os loteamentos.');
      
      // also the domain specific
      content = content.replaceAll('Admin da obra', 'Admin do loteamento');
      content = content.replaceAll('Operário da obra', 'Operário do loteamento');
      content = content.replaceAll('Mestre de obras', 'Mestre de loteamento');
      
      file.writeAsStringSync(content);
    }
  }
}
