import 'dart:io';

void main() {
  final path = '_bmad-output/implementation-artifacts/sprint-status.yaml';
  final file = File(path);
  if (file.existsSync()) {
    var content = file.readAsStringSync();
    content = content.replaceFirst(
      '  13-2-rotas-declarativas-e-drill-down-inicial: in-progress',
      '  13-2-rotas-declarativas-e-drill-down-inicial: review'
    );
    file.writeAsStringSync(content);
  }
}
