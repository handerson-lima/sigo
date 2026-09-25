import 'dart:io';

void main() {
  final path = 'test/features/construtoras/membros_test.dart';
  final file = File(path);
  if (file.existsSync()) {
    var content = file.readAsStringSync();
    
    // 8.2 filtros e busca (widget) 8.2 Por obra com erro em obras mostra mensagem
    content = content.replaceAll('Erro ao carregar obras', 'Erro ao carregar loteamentos');
    
    // 8.3 detalhe do membro 8.3 formatarJoinedAt e rotuloPapelObra / status em pt-br
    content = content.replaceAll('Admin da obra', 'Admin do loteamento');
    
    // 8.3 sem obras mostra microcopy estática sem CTA
    content = content.replaceAll('Nenhuma obra vinculada hoje', 'Nenhum loteamento vinculado hoje');
    
    file.writeAsStringSync(content);
  }
}
