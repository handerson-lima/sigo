/// Utilitário e validador canônico de documentos fiscais brasileiros (CNPJ e CPF).
///
/// Implementa o algoritmo oficial do Módulo 11 da Receita Federal, rejeitando
/// sequências de dígitos repetidos conhecidas e garantindo sanitização estrita.
class FornecedorValidator {
  FornecedorValidator._();

  /// Remove qualquer caractere não-numérico da string.
  static String apenasDigitos(String? valor) {
    if (valor == null) return '';
    return valor.replaceAll(RegExp(r'\D'), '');
  }

  /// Valida se o documento é um CPF válido (11 dígitos, cálculo do Módulo 11).
  static bool validarCpf(String? cpf) {
    final digitos = apenasDigitos(cpf);
    if (digitos.length != 11) return false;

    // Rejeita sequências de 11 dígitos idênticos (ex.: 000.000.000-00, 111.111.111-11, etc.)
    if (RegExp(r'^(\d)\1{10}$').hasMatch(digitos)) return false;

    // Cálculo do 1º Dígito Verificador (pesos de 10 a 2)
    int soma1 = 0;
    for (int i = 0; i < 9; i++) {
      soma1 += int.parse(digitos[i]) * (10 - i);
    }
    int resto1 = soma1 % 11;
    int dv1 = resto1 < 2 ? 0 : 11 - resto1;
    if (int.parse(digitos[9]) != dv1) return false;

    // Cálculo do 2º Dígito Verificador (pesos de 11 a 2)
    int soma2 = 0;
    for (int i = 0; i < 10; i++) {
      soma2 += int.parse(digitos[i]) * (11 - i);
    }
    int resto2 = soma2 % 11;
    int dv2 = resto2 < 2 ? 0 : 11 - resto2;
    if (int.parse(digitos[10]) != dv2) return false;

    return true;
  }

  /// Valida se o documento é um CNPJ válido (14 dígitos, cálculo do Módulo 11).
  static bool validarCnpj(String? cnpj) {
    final digitos = apenasDigitos(cnpj);
    if (digitos.length != 14) return false;

    // Rejeita sequências de 14 dígitos idênticos (ex.: 00.000.000/0000-00, 11.111.111/1111-11, etc.)
    if (RegExp(r'^(\d)\1{13}$').hasMatch(digitos)) return false;

    // Pesos oficiais da Receita Federal
    const pesos1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    const pesos2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

    // Cálculo do 1º Dígito Verificador
    int soma1 = 0;
    for (int i = 0; i < 12; i++) {
      soma1 += int.parse(digitos[i]) * pesos1[i];
    }
    int resto1 = soma1 % 11;
    int dv1 = resto1 < 2 ? 0 : 11 - resto1;
    if (int.parse(digitos[12]) != dv1) return false;

    // Cálculo do 2º Dígito Verificador
    int soma2 = 0;
    for (int i = 0; i < 13; i++) {
      soma2 += int.parse(digitos[i]) * pesos2[i];
    }
    int resto2 = soma2 % 11;
    int dv2 = resto2 < 2 ? 0 : 11 - resto2;
    if (int.parse(digitos[13]) != dv2) return false;

    return true;
  }

  /// Valida documento conforme o tipo ou quantidade de dígitos (11 para CPF, 14 para CNPJ).
  static bool validarDocumento(String? doc, {bool isPessoaJuridica = true}) {
    if (isPessoaJuridica) {
      return validarCnpj(doc);
    } else {
      return validarCpf(doc);
    }
  }

  /// Aplica máscara de exibição para CPF (000.000.000-00) ou CNPJ (00.000.000/0000-00).
  static String formatarDocumento(String? doc) {
    final digitos = apenasDigitos(doc);
    if (digitos.length == 11) {
      return '${digitos.substring(0, 3)}.${digitos.substring(3, 6)}.${digitos.substring(6, 9)}-${digitos.substring(9, 11)}';
    } else if (digitos.length == 14) {
      return '${digitos.substring(0, 2)}.${digitos.substring(2, 5)}.${digitos.substring(5, 8)}/${digitos.substring(8, 12)}-${digitos.substring(12, 14)}';
    }
    return doc ?? '';
  }

  /// Aplica máscara simples de telefone ou celular brasileiro.
  static String formatarTelefone(String? tel) {
    final digitos = apenasDigitos(tel);
    if (digitos.length == 10) {
      return '(${digitos.substring(0, 2)}) ${digitos.substring(2, 6)}-${digitos.substring(6, 10)}';
    } else if (digitos.length == 11) {
      return '(${digitos.substring(0, 2)}) ${digitos.substring(2, 7)}-${digitos.substring(7, 11)}';
    }
    return tel ?? '';
  }

  /// Formata CEP (00000-000).
  static String formatarCep(String? cep) {
    final digitos = apenasDigitos(cep);
    if (digitos.length == 8) {
      return '${digitos.substring(0, 5)}-${digitos.substring(5, 8)}';
    }
    return cep ?? '';
  }
}
