import 'dart:io';

void main() {
  final path = 'lib/src/features/construtoras/presentation/widgets/atribuir_obra_dialog.dart';
  final file = File(path);
  if (file.existsSync()) {
    var content = file.readAsStringSync();
    content = content.replaceFirst(
      'DropdownButtonFormField<String>(',
      'DropdownButtonFormField<String>(\n                isExpanded: true,'
    );
    file.writeAsStringSync(content);
  }
}
