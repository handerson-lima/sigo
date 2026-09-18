---
id: SPEC-5-2-modulo-validacao
companions:
  - ../implementation-artifacts/spec-5-2-modulo-validacao.md
sources:
  - ../planning-artifacts/architecture/architecture-epic-5/ARCHITECTURE-SPINE.md
  - ../implementation-artifacts/epic-5-context.md
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate.

# Story 5.2 — Módulo Validação: Templates de Inspeção e Checklists de Lote com Evidências Fotográficas

## Why

O controle de qualidade física nos canteiros de obras do SIGO atualmente depende de registros manuais, planilhas dispersas ou fotos desorganizadas em aplicativos de mensagens, sem amarração formal por lote ou unidade construtiva. Esse cenário causa três problemas críticos:
1. **Critérios Inconsistentes:** A falta de padrões corporativos versionados faz com que equipes diferentes avaliem disciplinas técnicas (fundação, estrutura, alvenaria, instalações, acabamento) sob critérios divergentes.
2. **Vícios Construtivos e Falta de Prova Material:** Não-conformidades identificadas sem registro georreferenciado e fotográfico dificultam a exigência de retrabalho junto a empreiteiros e encarregados.
3. **Ausência de Trilha de Auditoria:** Lotes são dados como "prontos" sem comprovação de vistoria formal, expondo a construtora a custos de assistência técnica pós-entrega e riscos de garantia.

## Capabilities

- **CAP-1**
  - **intent:** Gerenciar templates corporativos de inspeção de qualidade por disciplina com controle de versionamento.
  - **success:** A construtora cadastra e versiona templates (`construtoras/{cId}/validacao_templates/{tId}`) contendo título, disciplina técnica (ex.: Estrutura, Alvenaria, Elétrica, Pintura), itens de checagem obrigatórios e flag de foto requerida, com versionamento incremental automático (`version: 1, 2, ...`).

- **CAP-2**
  - **intent:** Executar vistorias de checklist por lote na obra com fixação imutável da versão do template aplicado.
  - **success:** O engenheiro/técnico abre uma nova vistoria vinculada a um lote (`construtoras/{cId}/obras/{oId}/lotes/{lId}/validacoes/{vId}`), seleciona o template ativo e preenche a conformidade de cada item (`conforme`, `nao_conforme`, `nao_se_aplica`), fixando o `templateVersion` utilizado para garantir integridade histórica.

- **CAP-3**
  - **intent:** Exigir e registrar evidências fotográficas com carimbo auditável (data/hora, lote, inspetor) para itens não-conformes.
  - **success:** Sempre que um item for assinalado como `nao_conforme`, a interface exige obrigatoriamente a anexação de foto comprobatória com notas descritivas e carimbo de evidência, armazenando a imagem no Storage privado (`construtoras/{cId}/obras/{oId}/validacao/{lId}/{vId}/...`).

- **CAP-4**
  - **intent:** Controlar o ciclo de vida e status de qualidade do lote (pendente, aprovado, reprovado, reaberto).
  - **success:** O lote exibe visualmente o status consolidado de suas vistorias. Uma vistoria com todos os itens conformes recebe status `aprovado`; havendo itens não-conformes, recebe status `reprovado`, permitindo posterior correção e reabertura/reinspeção (`reaberto`).

## Constraints

- **Imutabilidade de Vistorias Finalizadas:** Registros de validação concluídos não podem sofrer exclusão física (`allow delete: if false;`).
- **Fixação de Critério:** A alteração futura de um template corporativo gera uma nova versão (`version + 1`) e nunca modifica os itens ou critérios de uma vistoria já executada.
- **Evidência Obrigatória em Não-Conformidade:** O sistema impede a conclusão de vistoria reprovada sem que todos os itens com não-conformidade possuam ao menos uma imagem/foto de evidência e justificativa registrada.
- **Armazenamento Seguro:** As evidências fotográficas residem no Firebase Storage sob regras que restringem leitura e escrita apenas a membros autorizados da respectiva obra e construtora.
- **Autorização e RBAC:** Acesso protegido para usuários com permissão no módulo `validacao`, gestores da obra (`obraAdmin`), administradores corporativos (`admin`) ou `dev_roles`.
- **Resiliência Offline:** O preenchimento da vistoria em canteiro de obras suporta operação desconectada, sincronizando os dados e fotos quando houver reconexão.

## Non-goals

- Emissão de laudo pericial oficial com certificação digital ICP-Brasil A3 (o módulo foca em controle operacional e auditoria interna do SIGO).
- Bloqueio financeiro automático de medição de empreiteiros atrelado à vistoria nesta fatia (a integração entre qualidade e medições será conectada na Story 5.6 e expansões futuras).

## Success signal

- Templates de vistoria cadastrados e versionados na construtora, vistorias executadas e vinculadas aos lotes da obra, upload e vínculo de fotos comprobatórias para itens com não-conformidade, máquina de status (`aprovado`/`reprovado`) funcionando deterministicamente, 100% dos testes unitários e de integração passando e zero warnings no `flutter analyze`.
