import 'dart:io';

void main() {
  var path = 'lib/src/features/construtoras/presentation/widgets/membros_filtros_header.dart';
  var file = File(path);
  if (file.existsSync()) {
    var content = file.readAsStringSync();
    content = content.replaceFirst(
      'Não foi possível carregar as obras.',
      'Não foi possível carregar os loteamentos.'
    );
    file.writeAsStringSync(content);
  }
  
  path = 'lib/src/features/construtoras/presentation/widgets/obra_vinculo_row.dart';
  file = File(path);
  if (file.existsSync()) {
    var content = file.readAsStringSync();
    content = content.replaceAll(
      'Nenhuma obra vinculada — Atribuir',
      'Nenhum loteamento vinculado — Atribuir'
    );
    file.writeAsStringSync(content);
  }
}
