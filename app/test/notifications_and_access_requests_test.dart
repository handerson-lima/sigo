import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app/src/features/notifications/data/notifications_repository.dart';

void main() {
  group('SigoNotification and Access Requests Unit Tests', () {
    test('SigoNotification.fromFirestore parses attributes correctly', () {
      final now = DateTime.now();
      final data = {
        'title': 'Conta criada: Carlos Silva',
        'body': 'A conta de Carlos Silva (carlos@exemplo.com) foi criada como Operário. Senha provisória: Mudar@1234. Compartilhe com o funcionário e oriente-o a alterar no primeiro acesso.',
        'read': false,
        'createdAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 7))),
      };

      final notif = SigoNotification.fromFirestore(data, 'notif_123');

      expect(notif.id, equals('notif_123'));
      expect(notif.title, equals('Conta criada: Carlos Silva'));
      expect(notif.read, isFalse);
      expect(notif.createdAt, isNotNull);
      expect(notif.expiresAt, isNotNull);

      // Validação da regex de extração de senha provisória efêmera
      final match = RegExp(r'Senha provisória:\s*([^\s\.]+)').firstMatch(notif.body);
      expect(match, isNotNull);
      expect(match!.group(1), equals('Mudar@1234'));
    });

    test('SigoNotification handles missing optional fields with safe defaults', () {
      final data = <String, dynamic>{};
      final notif = SigoNotification.fromFirestore(data, 'empty_doc');

      expect(notif.id, equals('empty_doc'));
      expect(notif.title, equals('Notificação'));
      expect(notif.body, equals(''));
      expect(notif.read, isFalse);
      expect(notif.createdAt, isNull);
      expect(notif.expiresAt, isNull);
    });
  });
}
