import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/epi/domain/epi_item.dart';
import 'package:app/src/features/epi/domain/epi_event.dart';
import 'package:app/src/features/epi/domain/termo_epi.dart';

void main() {
  group('EpiItem Domain Tests', () {
    test('Identifica C.A. válido e vencido corretamente', () {
      final now = DateTime.now();
      final epiValido = EpiItem(
        id: 'epi-1',
        construtoraId: 'c1',
        nome: 'Capacete Aba Frontal',
        fabricante: 'MSA',
        categoria: 'cabeca',
        caNumero: '12345',
        caValidade: now.add(const Duration(days: 100)),
        vidaUtilDias: 180,
      );

      expect(epiValido.isCaVencido, isFalse);
      expect(epiValido.isCaProximoVencimento(30), isFalse);
      expect(epiValido.categoriaFormatada, 'Proteção da Cabeça');

      final epiVencido = EpiItem(
        id: 'epi-2',
        construtoraId: 'c1',
        nome: 'Luva de Vaqueta',
        fabricante: 'Danny',
        categoria: 'maos_bracos',
        caNumero: '9999',
        caValidade: now.subtract(const Duration(days: 10)),
      );

      expect(epiVencido.isCaVencido, isTrue);
      expect(epiVencido.isCaProximoVencimento(30), isFalse);
      expect(epiVencido.categoriaFormatada, 'Proteção dos Membros Superiores');

      final epiVencendo = EpiItem(
        id: 'epi-3',
        construtoraId: 'c1',
        nome: 'Óculos de Proteção',
        fabricante: '3M',
        categoria: 'ocular',
        caNumero: '45678',
        caValidade: now.add(const Duration(days: 15)),
      );

      expect(epiVencendo.isCaVencido, isFalse);
      expect(epiVencendo.isCaProximoVencimento(30), isTrue);
      expect(epiVencendo.diasParaVencer, inInclusiveRange(14, 16));
    });

    test('Serialização toMap e fromMap preserva integridade', () {
      final validade = DateTime(2028, 5, 20);
      final item = EpiItem(
        id: 'epi-10',
        construtoraId: 'c1',
        nome: 'Botina com Bico de Aço',
        fabricante: 'Marluvas',
        categoria: 'pes_pernas',
        caNumero: '34567',
        caValidade: validade,
        vidaUtilDias: 240,
        unidade: 'par',
        descricao: 'Solado bidensidade antiderrapante',
      );

      final map = item.toMap();
      expect(map['nome'], 'Botina com Bico de Aço');
      expect(map['caNumero'], '34567');
      expect(map['unidade'], 'par');
      expect(map['vidaUtilDias'], 240);

      final reconstructed = EpiItem.fromMap(map, 'epi-10');
      expect(reconstructed.id, 'epi-10');
      expect(reconstructed.nome, item.nome);
      expect(reconstructed.fabricante, item.fabricante);
      expect(reconstructed.categoria, item.categoria);
      expect(reconstructed.caNumero, item.caNumero);
      expect(reconstructed.caValidade.year, 2028);
      expect(reconstructed.caValidade.month, 5);
      expect(reconstructed.caValidade.day, 20);
    });
  });

  group('EpiEvent Domain Tests', () {
    test('Criação e tipos de eventos de entrega e devolução', () {
      final now = DateTime.now();
      final eventoEntrega = EpiEvent(
        id: 'ev-1',
        construtoraId: 'c1',
        obraId: 'o1',
        funcionarioId: 'func-100',
        funcionarioNome: 'João Silva',
        epiId: 'epi-1',
        epiNome: 'Capacete de Segurança',
        caNumero: '12345',
        tipoEvento: 'entrega',
        quantidade: 1,
        motivo: 'Admissão',
        dataEvento: now,
        responsavelUid: 'user-admin',
        responsavelNome: 'Mestre Carlos',
        dataTrocaPrevista: now.add(const Duration(days: 180)),
        status: 'ativo',
      );

      expect(eventoEntrega.isEntrega, isTrue);
      expect(eventoEntrega.isDevolvidoOuBaixado, isFalse);
      expect(eventoEntrega.isTrocaVencida, isFalse);
      expect(eventoEntrega.tipoEventoFormatado, 'Entrega Inicial');

      final eventoDevolucao = EpiEvent(
        id: 'ev-2',
        construtoraId: 'c1',
        obraId: 'o1',
        funcionarioId: 'func-100',
        funcionarioNome: 'João Silva',
        epiId: 'epi-1',
        epiNome: 'Capacete de Segurança',
        caNumero: '12345',
        tipoEvento: 'devolucao',
        quantidade: 1,
        motivo: 'Desligamento',
        dataEvento: now,
        responsavelUid: 'user-admin',
        responsavelNome: 'Mestre Carlos',
        status: 'devolvido',
      );

      expect(eventoDevolucao.isEntrega, isFalse);
      expect(eventoDevolucao.isDevolvidoOuBaixado, isTrue);
      expect(eventoDevolucao.tipoEventoFormatado, 'Devolução');
    });

    test('Identifica troca periódica vencida', () {
      final now = DateTime.now();
      final eventoVencido = EpiEvent(
        id: 'ev-3',
        construtoraId: 'c1',
        obraId: 'o1',
        funcionarioId: 'func-100',
        funcionarioNome: 'João Silva',
        epiId: 'epi-1',
        epiNome: 'Respirador Semi-Facial',
        caNumero: '5555',
        tipoEvento: 'entrega',
        dataEvento: now.subtract(const Duration(days: 90)),
        responsavelUid: 'user-admin',
        responsavelNome: 'Mestre Carlos',
        dataTrocaPrevista: now.subtract(const Duration(days: 5)),
        status: 'ativo',
      );

      expect(eventoVencido.isTrocaVencida, isTrue);

      // Se foi devolvido ou baixado, não deve acusar troca pendente
      final eventoBaixado = eventoVencido.copyWith(status: 'baixado');
      expect(eventoBaixado.isTrocaVencida, isFalse);
    });
  });

  group('TermoEpi Domain Tests', () {
    test('Geração determinística de hash SHA-256 e integridade', () {
      final dataAssinatura = DateTime(2026, 9, 18, 10, 30);
      final itens = [
        {'epiNome': 'Capacete', 'caNumero': '12345', 'quantidade': 1},
        {'epiNome': 'Botina', 'caNumero': '67890', 'quantidade': 1},
      ];

      final termo1 = TermoEpi(
        id: 'termo-1',
        construtoraId: 'c1',
        obraId: 'o1',
        funcionarioId: 'func-1',
        funcionarioNome: 'Sebastião Souza',
        funcionarioCpf: '123.456.789-00',
        itens: itens,
        dataAssinatura: dataAssinatura,
        responsavelUid: 'resp-1',
      );

      final hashOriginal = termo1.hashSha256;
      expect(hashOriginal, isNotEmpty);
      expect(hashOriginal.length, 64); // SHA-256 hex possui 64 chars

      // Mesmo payload deve gerar hash idêntico
      final hashRepetido = TermoEpi.gerarHash(
        funcionarioCpf: '123.456.789-00',
        dataAssinatura: dataAssinatura,
        itens: itens,
        texto: termo1.textoLegal,
      );
      expect(hashRepetido, equals(hashOriginal));

      // Qualquer alteração nos itens ou CPF deve alterar o hash
      final hashAdulterado = TermoEpi.gerarHash(
        funcionarioCpf: '999.999.999-99',
        dataAssinatura: dataAssinatura,
        itens: itens,
        texto: termo1.textoLegal,
      );
      expect(hashAdulterado, isNot(equals(hashOriginal)));
    });

    test('Serialização toMap e fromMap de TermoEpi', () {
      final termo = TermoEpi(
        id: 't-100',
        construtoraId: 'c1',
        obraId: 'o1',
        funcionarioId: 'func-2',
        funcionarioNome: 'Antônio Ferreira',
        funcionarioCpf: '222.333.444-55',
        itens: [
          {'epiNome': 'Protetor Auditivo', 'caNumero': '1111', 'quantidade': 2}
        ],
        tipoConfirmacao: 'assinatura_canvas',
        assinaturaStoragePath: 'construtoras/c1/obras/o1/epis/func-2/ass.png',
        dataAssinatura: DateTime(2026, 9, 18),
        responsavelUid: 'admin-1',
      );

      final map = termo.toMap();
      expect(map['funcionarioNome'], 'Antônio Ferreira');
      expect(map['tipoConfirmacao'], 'assinatura_canvas');
      expect(map['assinaturaStoragePath'], contains('ass.png'));

      final reconstructed = TermoEpi.fromMap(map, 't-100');
      expect(reconstructed.id, 't-100');
      expect(reconstructed.funcionarioCpf, termo.funcionarioCpf);
      expect(reconstructed.itens.first['epiNome'], 'Protetor Auditivo');
      expect(reconstructed.hashSha256, termo.hashSha256);
    });
  });
}
