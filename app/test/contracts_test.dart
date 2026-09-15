import 'package:app/src/core/contracts.dart';
import 'package:app/src/features/financeiro/domain/despesa.dart';
import 'package:app/src/features/obras/domain/obra_member.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> expense(dynamic payment) => {
  'id': 'd',
  'construtoraId': 'c',
  'descricao': 'teste',
  'valor': 1.005,
  'dataVencimento': '2026-09-15',
  'dataPagamento': payment,
  'status': 'pendente',
  'categoria': 'teste',
  'responsavelId': 'u',
  'createdAt': '2026-09-01T12:00:00Z',
};
void main() {
  test('legacy money rounds half away from zero using decimal text', () {
    expect(decimalUnits(1.005, 2, round: true), 101);
    expect(decimalUnits('-1.005', 2, round: true), -101);
    expect(() => decimalUnits(double.nan, 2), throwsFormatException);
    expect(() => decimalUnits('0.0001', 3), throwsFormatException);
  });
  test('payment dates accept null, ISO and Timestamp', () {
    for (final date in [
      null,
      '2026-09-15T12:00:00Z',
      Timestamp.fromDate(DateTime.utc(2026, 9, 15, 12)),
    ]) {
      final d = Despesa.fromJson(expense(date));
      expect(d.valorEmCentavos, 101);
      expect(
        d.dataPagamento?.toUtc(),
        date == null ? null : DateTime.utc(2026, 9, 15, 12),
      );
      expect(d.toJson()['dataVencimento'], '2026-09-15');
    }
  });
  test('integer cents take precedence and survive safe integer limit', () {
    final data = expense(null)..['valorEmCentavos'] = 9007199254740991;
    final d = Despesa.fromJson(data);
    expect(d.valorEmCentavos, 9007199254740991);
    expect(d.toJson()['valorEmCentavos'], 9007199254740991);
  });
  test('invalid amounts reject instead of silently zero', () {
    for (final value in [0, -1, 'bad', double.infinity]) {
      expect(
        () => Despesa.fromJson(expense(null)..['valor'] = value),
        throwsFormatException,
      );
    }
  });
  test('missing active flag fails closed and module aliases normalize', () {
    expect(
      ObraMember.fromJson({'userId': 'u', 'joinedAt': '2026-09-15'}).isActive,
      false,
    );
    expect(normalizeModule('rdo'), 'diario');
    expect(normalizeModule('almoxarifado'), 'estoque');
  });
}
