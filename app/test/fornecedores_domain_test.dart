import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/fornecedores/domain/fornecedor.dart';
import 'package:app/src/features/fornecedores/domain/fornecedor_validator.dart';

void main() {
  group('Fornecedor Domain & Serialization Tests', () {
    test('Cria e serializa fornecedor PJ completo corretamente', () {
      final now = DateTime(2026, 9, 18, 14, 0);
      final fornecedor = Fornecedor(
        id: 'forn-1',
        construtoraId: 'c1',
        tipoPessoa: TipoPessoa.juridica,
        documento: '11222333000181',
        razaoSocial: 'Votorantim Cimentos S/A',
        nomeFantasia: 'Votorantim',
        inscricaoEstadual: '123456789',
        inscricaoMunicipal: '98765',
        email: 'vendas@votorantim.com.br',
        telefone: '1140041234',
        whatsapp: '11987654321',
        nomeContato: 'Carlos Vendas',
        endereco: const EnderecoFornecedor(
          cep: '01310100',
          logradouro: 'Av. Paulista',
          numero: '1000',
          bairro: 'Bela Vista',
          cidade: 'São Paulo',
          uf: 'SP',
        ),
        categorias: ['materiais_basicos', 'acabamento'],
        dadosBancarios: const DadosBancariosFornecedor(
          chavePix: '11222333000181',
          tipoChavePix: 'cnpj',
          banco: 'Banco do Brasil',
          codigoBanco: '001',
          agencia: '1234-5',
          contaCorrente: '56789-0',
          favorecido: 'Votorantim Cimentos S/A',
        ),
        observacoes: 'Entrega em 48h',
        status: StatusFornecedor.ativo,
        criadoPorUid: 'uid-admin',
        createdAt: now,
        updatedAt: now,
      );

      expect(fornecedor.isAtivo, isTrue);
      expect(fornecedor.isPessoaJuridica, isTrue);
      expect(fornecedor.nomeExibicao, 'Votorantim');
      expect(fornecedor.documentoFormatado, '11.222.333/0001-81');
      expect(
        fornecedor.endereco?.formatado,
        'Av. Paulista, 1000 - Bela Vista - São Paulo/SP - CEP: 01310-100',
      );

      final json = fornecedor.toJson();
      expect(json['id'], 'forn-1');
      expect(json['tipoPessoa'], 'juridica');
      expect(json['documento'], '11222333000181');
      expect(json['categorias'], contains('materiais_basicos'));

      final reconstruido = Fornecedor.fromJson(json);
      expect(reconstruido.id, fornecedor.id);
      expect(reconstruido.razaoSocial, fornecedor.razaoSocial);
      expect(reconstruido.nomeFantasia, fornecedor.nomeFantasia);
      expect(reconstruido.tipoPessoa, TipoPessoa.juridica);
      expect(reconstruido.status, StatusFornecedor.ativo);
      expect(reconstruido.dadosBancarios?.chavePix, '11222333000181');
      expect(reconstruido.endereco?.cidade, 'São Paulo');
    });

    test('Cria fornecedor PF e verifica formatação de CPF', () {
      final fornecedorPf = Fornecedor(
        id: 'forn-2',
        construtoraId: 'c1',
        tipoPessoa: TipoPessoa.fisica,
        documento: '52998224725',
        razaoSocial: 'João da Silva Pintor',
        status: StatusFornecedor.ativo,
      );

      expect(fornecedorPf.isPessoaJuridica, isFalse);
      expect(fornecedorPf.nomeExibicao, 'João da Silva Pintor');
      expect(fornecedorPf.documentoFormatado, '529.982.247-25');
      expect(FornecedorValidator.validarCpf(fornecedorPf.documento), isTrue);
    });

    test('Inativação lógica (soft-disable) preserva integridade dos dados', () {
      final fornecedor = Fornecedor(
        id: 'forn-3',
        construtoraId: 'c1',
        tipoPessoa: TipoPessoa.juridica,
        documento: '11222333000181',
        razaoSocial: 'Fornecedor Antigo',
        status: StatusFornecedor.ativo,
      );

      final inativado = fornecedor.copyWith(
        status: StatusFornecedor.inativo,
        atualizadoPorUid: 'uid-admin-2',
      );

      expect(inativado.isAtivo, isFalse);
      expect(inativado.status, StatusFornecedor.inativo);
      expect(inativado.documento, fornecedor.documento);
      expect(inativado.atualizadoPorUid, 'uid-admin-2');
    });
  });
}
