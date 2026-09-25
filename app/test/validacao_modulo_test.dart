import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/features/validacao/domain/validacao_template.dart';
import 'package:app/src/features/validacao/domain/validacao_vistoria.dart';

void main() {
  group('ValidacaoTemplate Domain Tests', () {
    test('Criação de template com versionamento inicial 1 e itens', () {
      final now = DateTime(2026, 9, 18, 10, 0);
      const item1 = ChecklistTemplateItem(
        id: 'item_1',
        titulo: 'Prumo e alinhamento das paredes',
        descricao: 'Verificação com régua de nível',
        obrigatorio: true,
        requerFotoSeReprovado: true,
      );
      const item2 = ChecklistTemplateItem(
        id: 'item_2',
        titulo: 'Amarração com telas soldadas',
        descricao: 'Fixação nos pilares',
        obrigatorio: true,
        requerFotoSeReprovado: true,
      );

      final template = ValidacaoTemplate(
        id: 'tpl_alvenaria_01',
        construtoraId: 'c1',
        titulo: 'Checklist de Alvenaria e Vedações',
        disciplina: 'alvenaria',
        version: 1,
        ativo: true,
        createdAt: now,
        updatedAt: now,
        itens: [item1, item2],
      );

      expect(template.id, 'tpl_alvenaria_01');
      expect(template.version, 1);
      expect(template.ativo, isTrue);
      expect(template.disciplinaFormatada, 'Alvenaria e Vedações');
      expect(template.itens.length, 2);
    });

    test('Incremento de versão em atualização de template (version + 1)', () {
      final now = DateTime(2026, 9, 18, 10, 0);
      final tplV1 = ValidacaoTemplate(
        id: 'tpl_1',
        construtoraId: 'c1',
        titulo: 'Instalações Hidráulicas',
        disciplina: 'hidraulica',
        version: 1,
        ativo: true,
        createdAt: now,
        updatedAt: now,
        itens: const [
          ChecklistTemplateItem(
            id: 'it_1',
            titulo: 'Teste de estanqueidade',
            descricao: 'Pressurização por 24h',
          ),
        ],
      );

      final tplV2 = tplV1.copyWith(
        version: tplV1.version + 1,
        updatedAt: DateTime(2026, 9, 18, 12, 0),
        itens: [
          ...tplV1.itens,
          const ChecklistTemplateItem(
            id: 'it_2',
            titulo: 'Fixação de tubos de queda',
            descricao: 'Abraçadeiras a cada 1.5m',
          ),
        ],
      );

      expect(tplV2.version, 2);
      expect(tplV2.itens.length, 2);
      expect(tplV1.version, 1); // Preservação da versão original
    });

    test(
      'Serialização toMap e fromMap do ValidacaoTemplate preserva integridade',
      () {
        final now = DateTime(2026, 9, 18, 8, 30);
        final template = ValidacaoTemplate(
          id: 'tpl_eletrica_01',
          construtoraId: 'c1',
          titulo: 'Checklist Elétrico',
          disciplina: 'eletrica',
          version: 3,
          ativo: true,
          createdAt: now,
          updatedAt: now,
          itens: const [
            ChecklistTemplateItem(
              id: 'el_1',
              titulo: 'Passagem de fiação nos conduítes',
              descricao: 'Sem emendas internas',
              obrigatorio: true,
              requerFotoSeReprovado: true,
            ),
          ],
        );

        final map = template.toMap();
        expect(map['id'], 'tpl_eletrica_01');
        expect(map['disciplina'], 'eletrica');
        expect(map['version'], 3);
        expect(map['itens'], isA<List>());

        final reconstructed = ValidacaoTemplate.fromMap(map, 'tpl_eletrica_01');
        expect(reconstructed.id, 'tpl_eletrica_01');
        expect(reconstructed.titulo, 'Checklist Elétrico');
        expect(reconstructed.disciplinaFormatada, 'Instalações Elétricas');
        expect(reconstructed.version, 3);
        expect(
          reconstructed.itens.first.titulo,
          'Passagem de fiação nos conduítes',
        );
      },
    );
  });

  group('ValidacaoVistoria Domain Tests', () {
    test('Aprovação total quando todos os itens são conformes ou N/A', () {
      final now = DateTime(2026, 9, 18, 9, 0);
      final vistoria = ValidacaoVistoria(
        id: 'vistoria_1',
        construtoraId: 'c1',
        obraId: 'o1',
        loteId: 'lote_10',
        templateId: 'tpl_alvenaria_01',
        templateTitulo: 'Alvenaria',
        disciplina: 'alvenaria',
        templateVersion: 1,
        status: ValidacaoStatus.pendente,
        inspetorUid: 'eng_1',
        inspetorNome: 'Engenheiro Carlos',
        dataVistoria: now,
        itensRespondidos: const [
          ItemRespondido(
            itemId: 'it_1',
            titulo: 'Prumo',
            status: ItemConformidadeStatus.conforme,
          ),
          ItemRespondido(
            itemId: 'it_2',
            titulo: 'Impermeabilização de baldrame',
            status: ItemConformidadeStatus.nao_se_aplica,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      expect(vistoria.hasNaoConforme, isFalse);
      expect(vistoria.validarParaConclusao(), isEmpty);
      expect(vistoria.calcularStatusFinal(), ValidacaoStatus.aprovado);
      expect(vistoria.totalConformes, 1);
      expect(vistoria.totalNaoSeAplica, 1);
      expect(vistoria.totalNaoConformes, 0);
    });

    test('Bloqueio de conclusão se item Não Conforme não possuir observação ou foto', () {
      final now = DateTime(2026, 9, 18, 9, 0);
      final vistoriaSemFoto = ValidacaoVistoria(
        id: 'vistoria_2',
        construtoraId: 'c1',
        obraId: 'o1',
        loteId: 'lote_12',
        templateId: 'tpl_1',
        templateTitulo: 'Estrutura',
        disciplina: 'estrutura',
        templateVersion: 1,
        status: ValidacaoStatus.pendente,
        inspetorUid: 'eng_1',
        inspetorNome: 'Eng. Roberto',
        dataVistoria: now,
        itensRespondidos: const [
          ItemRespondido(
            itemId: 'it_1',
            titulo: 'Desforma de pilares',
            status: ItemConformidadeStatus.nao_conforme,
            observacao: null, // Sem observação
            fotos: [], // Sem fotos
            obrigatorio: true,
            requerFotoSeReprovado: true,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final erros = vistoriaSemFoto.validarParaConclusao();
      expect(erros.length, 2);
      expect(
        erros.any((e) => e.contains('exige descrição de observação')),
        isTrue,
      );
      expect(
        erros.any((e) => e.contains('exige pelo menos 1 foto de evidência')),
        isTrue,
      );
    });

    test('Finalização como REPROVADO quando item Não Conforme possui observação e foto anexada', () {
      final now = DateTime(2026, 9, 18, 9, 0);
      final vistoriaComEvidencia = ValidacaoVistoria(
        id: 'vistoria_3',
        construtoraId: 'c1',
        obraId: 'o1',
        loteId: 'lote_12',
        templateId: 'tpl_1',
        templateTitulo: 'Estrutura',
        disciplina: 'estrutura',
        templateVersion: 1,
        status: ValidacaoStatus.pendente,
        inspetorUid: 'eng_1',
        inspetorNome: 'Eng. Roberto',
        dataVistoria: now,
        itensRespondidos: const [
          ItemRespondido(
            itemId: 'it_1',
            titulo: 'Desforma de pilares',
            status: ItemConformidadeStatus.nao_conforme,
            observacao: 'Fissura estrutural identificada na base do pilar P4.',
            fotos: ['https://storage.googleapis.com/sigo/foto_pilar_01.jpg'],
            obrigatorio: true,
            requerFotoSeReprovado: true,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      expect(vistoriaComEvidencia.validarParaConclusao(), isEmpty);
      expect(vistoriaComEvidencia.hasNaoConforme, isTrue);
      expect(
        vistoriaComEvidencia.calcularStatusFinal(),
        ValidacaoStatus.reprovado,
      );
    });

    test('Transição para REABERTO ao solicitar reavaliação de lote após retrabalho', () {
      final now = DateTime(2026, 9, 18, 9, 0);
      final vistoriaReprovada = ValidacaoVistoria(
        id: 'vistoria_4',
        construtoraId: 'c1',
        obraId: 'o1',
        loteId: 'lote_12',
        templateId: 'tpl_1',
        templateTitulo: 'Estrutura',
        disciplina: 'estrutura',
        templateVersion: 1,
        status: ValidacaoStatus.reprovado,
        inspetorUid: 'eng_1',
        inspetorNome: 'Eng. Roberto',
        dataVistoria: now,
        createdAt: now,
        updatedAt: now,
      );

      final vistoriaReaberta = vistoriaReprovada.copyWith(
        status: ValidacaoStatus.reaberto,
        updatedAt: DateTime(2026, 9, 18, 14, 0),
      );

      expect(vistoriaReaberta.isReaberto, isTrue);
      expect(vistoriaReaberta.status.label, 'Reaberto');
    });

    test('Serialização toMap e fromMap de ValidacaoVistoria preserva integridade histórica', () {
      final now = DateTime(2026, 9, 18, 9, 0);
      final vistoria = ValidacaoVistoria(
        id: 'vistoria_5',
        construtoraId: 'c1',
        obraId: 'o1',
        loteId: 'lote_5',
        templateId: 'tpl_acabamento_01',
        templateTitulo: 'Pintura Interna',
        disciplina: 'pintura',
        templateVersion: 2,
        status: ValidacaoStatus.aprovado,
        inspetorUid: 'uid_tec',
        inspetorNome: 'Técnico Valdir',
        dataVistoria: now,
        dataFinalizacao: now.add(const Duration(hours: 1)),
        observacoesGerais: 'Serviço executado dentro dos padrões exigidos.',
        itensRespondidos: const [
          ItemRespondido(
            itemId: 'item_tintas',
            titulo: 'Homogeneidade da demão',
            status: ItemConformidadeStatus.conforme,
            observacao: 'Duas demãos de acrílico semi-brilho aplicadas',
            fotos: ['https://storage.googleapis.com/sigo/foto_parede.jpg'],
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final map = vistoria.toMap();
      expect(map['id'], 'vistoria_5');
      expect(map['loteId'], 'lote_5');
      expect(map['templateVersion'], 2);
      expect(map['status'], 'aprovado');

      final reconstructed = ValidacaoVistoria.fromMap(map, 'vistoria_5');
      expect(reconstructed.id, 'vistoria_5');
      expect(reconstructed.templateTitulo, 'Pintura Interna');
      expect(reconstructed.templateVersion, 2);
      expect(reconstructed.status, ValidacaoStatus.aprovado);
      expect(reconstructed.itensRespondidos.length, 1);
      expect(
        reconstructed.itensRespondidos.first.fotos.first,
        'https://storage.googleapis.com/sigo/foto_parede.jpg',
      );
    });
  });
}
