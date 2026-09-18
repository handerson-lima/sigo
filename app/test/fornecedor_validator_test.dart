import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/fornecedores/domain/fornecedor_validator.dart';

void main() {
  group('FornecedorValidator - CPF', () {
    test('Valida CPFs válidos conhecidos', () {
      // Casos matematicamente válidos
      expect(FornecedorValidator.validarCpf('52998224725'), isTrue);
      expect(FornecedorValidator.validarCpf('529.982.247-25'), isTrue);
      expect(FornecedorValidator.validarCpf('12345678909'), isTrue);
      expect(FornecedorValidator.validarCpf('123.456.789-09'), isTrue);
    });

    test('Rejeita CPFs com tamanho incorreto', () {
      expect(FornecedorValidator.validarCpf('1234567890'), isFalse);
      expect(FornecedorValidator.validarCpf('123456789012'), isFalse);
      expect(FornecedorValidator.validarCpf(''), isFalse);
      expect(FornecedorValidator.validarCpf(null), isFalse);
    });

    test('Rejeita CPFs com todos os dígitos iguais', () {
      expect(FornecedorValidator.validarCpf('00000000000'), isFalse);
      expect(FornecedorValidator.validarCpf('111.111.111-11'), isFalse);
      expect(FornecedorValidator.validarCpf('22222222222'), isFalse);
      expect(FornecedorValidator.validarCpf('99999999999'), isFalse);
    });

    test('Rejeita CPFs com dígitos verificadores incorretos', () {
      expect(FornecedorValidator.validarCpf('52998224726'), isFalse);
      expect(FornecedorValidator.validarCpf('12345678908'), isFalse);
      expect(FornecedorValidator.validarCpf('12345678919'), isFalse);
    });
  });

  group('FornecedorValidator - CNPJ', () {
    test('Valida CNPJs válidos conhecidos', () {
      // Casos matematicamente válidos
      expect(FornecedorValidator.validarCnpj('11222333000181'), isTrue);
      expect(FornecedorValidator.validarCnpj('11.222.333/0001-81'), isTrue);
      expect(FornecedorValidator.validarCnpj('00000000000191'), isTrue); // Banco do Brasil
      expect(FornecedorValidator.validarCnpj('00.000.000/0001-91'), isTrue);
    });

    test('Rejeita CNPJs com tamanho incorreto', () {
      expect(FornecedorValidator.validarCnpj('1122233300018'), isFalse);
      expect(FornecedorValidator.validarCnpj('112223330001811'), isFalse);
      expect(FornecedorValidator.validarCnpj(''), isFalse);
      expect(FornecedorValidator.validarCnpj(null), isFalse);
    });

    test('Rejeita CNPJs com todos os dígitos iguais', () {
      expect(FornecedorValidator.validarCnpj('00000000000000'), isFalse);
      expect(FornecedorValidator.validarCnpj('11.111.111/1111-11'), isFalse);
      expect(FornecedorValidator.validarCnpj('99999999999999'), isFalse);
    });

    test('Rejeita CNPJs com dígitos verificadores incorretos', () {
      expect(FornecedorValidator.validarCnpj('11222333000182'), isFalse);
      expect(FornecedorValidator.validarCnpj('00000000000192'), isFalse);
    });
  });

  group('FornecedorValidator - Formatação e Sanitização', () {
    test('apenasDigitos remove caracteres especiais', () {
      expect(FornecedorValidator.apenasDigitos('12.345.678/0001-90'), '12345678000190');
      expect(FornecedorValidator.apenasDigitos('(11) 98765-4321'), '11987654321');
      expect(FornecedorValidator.apenasDigitos(null), '');
    });

    test('formatarDocumento aplica máscara correta para CPF e CNPJ', () {
      expect(FornecedorValidator.formatarDocumento('52998224725'), '529.982.247-25');
      expect(FornecedorValidator.formatarDocumento('11222333000181'), '11.222.333/0001-81');
    });

    test('formatarTelefone aplica máscara correta', () {
      expect(FornecedorValidator.formatarTelefone('1140041234'), '(11) 4004-1234');
      expect(FornecedorValidator.formatarTelefone('11987654321'), '(11) 98765-4321');
    });

    test('formatarCep aplica máscara correta', () {
      expect(FornecedorValidator.formatarCep('01310100'), '01310-100');
    });
  });
}
