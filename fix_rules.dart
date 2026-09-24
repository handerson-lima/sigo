import 'dart:io';

void main() async {
  final rulesFile = File('firestore.rules');
  var content = await rulesFile.readAsString();

  final injectionPoint = '   match /construtora_members/{uid} { allow read: if signed() && (request.auth.uid == uid || admin(c)); allow write: if dev(); }';
  
  final toInject = '''   match /construtora_members/{uid} { allow read: if signed() && (request.auth.uid == uid || admin(c)); allow write: if dev(); }
   match /loteamentos/{loteamentoId} {
     allow read: if member(c);
     allow write: if admin(c);
     match /quadras/{quadraId} {
       allow read: if member(c);
       allow write: if admin(c);
       match /lotes/{loteId} {
         allow read: if member(c);
         allow write: if admin(c);
         match /setores/{setorId} {
           allow read: if member(c);
           allow write: if admin(c);
           match /equipes/{equipeId} {
             allow read: if member(c);
             allow write: if admin(c);
           }
         }
       }
     }
   }''';

  content = content.replaceFirst(injectionPoint, toInject);
  await rulesFile.writeAsString(content);
}
