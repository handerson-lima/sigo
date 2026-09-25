import 'package:app/src/features/construtoras/data/construtora_repository.dart';
import 'package:app/src/features/construtoras/domain/construtora.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Construtora _c(String id, {bool? isActive}) => Construtora(
  id: id,
  name: 'Construtora $id',
  createdAt: DateTime(2026, 1, 1),
  isActive: isActive ?? true,
);

void main() {
  group('12.2 filtro de construtoras visíveis', () {
    test('lista com vínculo em construtora inativa é descartada', () {
      final visiveis = filtrarConstrutorasAtivas([
        _c('ativa'),
        _c('inativa', isActive: false),
      ]);
      expect(visiveis.map((c) => c.id), ['ativa']);
    });

    test('lista com vínculo ativo permanece visível', () {
      final visiveis = filtrarConstrutorasAtivas([_c('ativa')]);
      expect(visiveis.map((c) => c.id), ['ativa']);
    });

    test('doc inacessível (permission-denied) equivale a sem acesso', () {
      expect(filtrarConstrutorasAtivas([null]), isEmpty);
      expect(filtrarConstrutorasAtivas([null, _c('ativa')]), hasLength(1));
    });

    test('doc sem isActive é tratado como ativo (legado)', () {
      final legado = Construtora.fromJson({'id': 'legacy', 'name': 'Legado'});
      expect(legado.isActive, isTrue);
      expect(filtrarConstrutorasAtivas([legado]).map((c) => c.id), ['legacy']);
    });

    test('permission-denied é inacessível; outros erros não', () {
      expect(
        construtoraInacessivel(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        isTrue,
      );
      expect(
        construtoraInacessivel(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        isFalse,
      );
      expect(construtoraInacessivel(Exception('boom')), isFalse);
    });
  });
}
