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

  group('Currency conversion and formatting', () {
    test('parseCurrencyToCents parses formatted BRL, decimals and ints', () {
      expect(parseCurrencyToCents('R\$ 1.500,75'), 150075);
      expect(parseCurrencyToCents('1500.75'), 150075);
      expect(parseCurrencyToCents('1500,75'), 150075);
      expect(parseCurrencyToCents('R\$ 35,00'), 3500);
      expect(parseCurrencyToCents('35'), 3500);
      expect(parseCurrencyToCents('0,50'), 50);
      expect(parseCurrencyToCents('-35,00'), -3500);
    });

    test('parseCurrencyToCents throws on invalid inputs', () {
      expect(() => parseCurrencyToCents(null), throwsFormatException);
      expect(() => parseCurrencyToCents(''), throwsFormatException);
      expect(() => parseCurrencyToCents('abc'), throwsFormatException);
      expect(() => parseCurrencyToCents(double.nan), throwsFormatException);
    });

    test('formatCents formats cents to currency string', () {
      expect(formatCents(150075), 'R\$ 1.500,75');
      expect(formatCents(3500), 'R\$ 35,00');
      expect(formatCents(0), 'R\$ 0,00');
      expect(formatCents(-3500), '-R\$ 35,00');
    });
  });

  group('Quantity units parsing and scale formatting', () {
    test('parseQuantityUnits supports pt-BR comma and en-US dot', () {
      expect(parseQuantityUnits('1,5'), 1500);
      expect(parseQuantityUnits('1,250'), 1250);
      expect(parseQuantityUnits('2.5'), 2500);
      expect(parseQuantityUnits('0.75'), 750);
      expect(parseQuantityUnits('1.250,5'), 1250500);
      expect(parseQuantityUnits(10), 10000);
      expect(parseQuantityUnits(2.5), 2500);
    });

    test('parseQuantityUnits rejects more than 3 decimal places', () {
      expect(
        () => parseQuantityUnits('1,1234'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Use até 3 casas decimais',
          ),
        ),
      );
      expect(
        () => parseQuantityUnits('0.0001'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Use até 3 casas decimais',
          ),
        ),
      );
    });

    test('parseQuantityUnits validates negative and invalid numbers', () {
      expect(() => parseQuantityUnits('-5'), throwsFormatException);
      expect(() => parseQuantityUnits('abc'), throwsFormatException);
      expect(() => parseQuantityUnits(null), throwsFormatException);
      expect(() => parseQuantityUnits(''), throwsFormatException);
      // When allowNegative is true
      expect(parseQuantityUnits('-5', allowNegative: true), -5000);
      expect(parseQuantityUnits('+2,5', allowNegative: true), 2500);
    });

    test('formatQuantityWithScale strips trailing zeros and formats comma', () {
      expect(formatQuantityWithScale(50.0), '50');
      expect(formatQuantityWithScale(52.5), '52,5');
      expect(formatQuantityWithScale(1.25), '1,25');
      expect(formatQuantityWithScale(1.250), '1,25');
      expect(formatQuantityWithScale(0.0), '0');
      expect(formatQuantityWithScale(0.001), '0,001');
      expect(formatQuantityWithScale(12.5, useComma: false), '12.5');
    });

    test('formatQuantityUnits converts integer units to formatted string', () {
      expect(formatQuantityUnits(50000), '50');
      expect(formatQuantityUnits(52500), '52,5');
      expect(formatQuantityUnits(1250), '1,25');
      expect(formatQuantityUnits(1), '0,001');
    });
  });
}
