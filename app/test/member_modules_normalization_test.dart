import 'package:app/src/core/contracts.dart';
import 'package:app/src/features/obras/domain/obra_member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'allowedModules normaliza modulos legados e falha fechado se vazio',
    () {
      // Teste com allowedModules legados (rdo -> diario)
      final rawData = {
        'userId': 'u1',
        'isActive': true,
        'isAdmin': false,
        'allowedModules': ['rdo'],
        'joinedAt': DateTime(2025).toIso8601String(),
      };
      final modules = normalizeRawModules(
        rawData['modules'],
        rawData['allowedModules'],
      );
      final member = ObraMember.fromJson({...rawData, 'modules': modules});

      expect(member.modules, contains('diario'));
      expect(member.modules, isNot(contains('rdo')));

      // Teste com allowedModules vazio falha fechado (sem permissões)
      final emptyData = {
        'userId': 'u2',
        'isActive': true,
        'isAdmin': false,
        'allowedModules': [],
        'joinedAt': DateTime(2025).toIso8601String(),
      };
      final emptyModules = normalizeRawModules(
        emptyData['modules'],
        emptyData['allowedModules'],
      );
      final emptyMember = ObraMember.fromJson({
        ...emptyData,
        'modules': emptyModules,
      });

      expect(emptyMember.modules, isEmpty);
    },
  );

  test('normalizeRawModules cobre fallback e filtragem', () {
    expect(normalizeRawModules(['rdo']), contains('diario'));
    expect(normalizeRawModules([], ['diario']), contains('diario'));
    expect(normalizeRawModules([], []), isEmpty);
    expect(normalizeRawModules('diario', ['lotes']), equals(['lotes']));
    expect(
      normalizeRawModules([null, 123, 'lotes']),
      equals(['lotes']),
    );
    expect(normalizeRawModules(null, null), isEmpty);
  });
}
