import 'dart:io';

void main() {
  final directories = Directory('app/lib/src/features').listSync(recursive: true);
  
  for (var entity in directories) {
    if (entity is File && entity.path.endsWith('_routes.dart') && !entity.path.contains('construtora_routes') && !entity.path.contains('dev_routes') && !entity.path.contains('auth_routes')) {
      final content = entity.readAsStringSync();
      var newContent = content.replaceAll("static const rh = '/construtora/:cId/rh';", ""); // Remove RhPaths.rh
      
      // Update the routes relative to /construtora/:cId
      // So '/construtora/:cId/obra/:oId' becomes 'obra/:oId'
      newContent = newContent.replaceAll("'/construtora/:cId/", "'");
      
      if (content != newContent) {
        entity.writeAsStringSync(newContent);
        print('Updated \${entity.path}');
      }
    }
  }
}
