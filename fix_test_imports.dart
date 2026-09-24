import 'dart:io';

void main() async {
  final sTest = File('app/test/src/features/setores/presentation/setores_list_screen_test.dart');
  var sText = await sTest.readAsString();
  sText = sText.replaceAll("package:obras/src/", "../../../../lib/src/");
  await sTest.writeAsString(sText);

  final eTest = File('app/test/src/features/equipes/presentation/equipes_list_screen_test.dart');
  var eText = await eTest.readAsString();
  eText = eText.replaceAll("package:obras/src/", "../../../../lib/src/");
  await eTest.writeAsString(eText);
}
