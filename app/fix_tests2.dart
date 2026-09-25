import 'dart:io';

void main() {
  final files = [
    'test/features/construtoras/membros_test.dart',
  ];
  
  for (final path in files) {
    final file = File(path);
    if (file.existsSync()) {
      var content = file.readAsStringSync();
      content = content.replaceAll('1 obra', '1 loteamento');
      content = content.replaceAll('2 obras', '2 loteamentos');
      content = content.replaceAll('N obras', 'N loteamentos');
      
      file.writeAsStringSync(content);
    }
  }
}
