import 'dart:io';

void main() {
  final path = 'test/custos_360_presentation_test.dart';
  final file = File(path);
  if (file.existsSync()) {
    var content = file.readAsStringSync();
    content = content.replaceAll('Custo Total Realizado da Obra', 'Custo Total Realizado do Loteamento');
    file.writeAsStringSync(content);
  }
}
