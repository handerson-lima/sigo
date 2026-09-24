import 'dart:io';

void main() async {
  for (var file in ['app/test/src/features/setores/presentation/setores_list_screen_test.dart', 'app/test/src/features/equipes/presentation/equipes_list_screen_test.dart']) {
    var f = File(file);
    var content = await f.readAsString();
    content = content.replaceAll(
      'await tester.pump(const Duration(milliseconds: 100));',
      'await tester.pump(const Duration(seconds: 1)); await tester.pump(const Duration(seconds: 1));'
    );
    await f.writeAsString(content);
  }
}
