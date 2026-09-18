---
title: 'Story 5.1 — Módulo EPI: Catálogo, Eventos de Entrega e Termos de Responsabilidade'
type: 'feature'
created: '2026-09-18'
status: 'done'
baseline_commit: '3520b6b0509e37da6496ba2e38b6c4eb8eace950'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-epic-5/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-4-1-rh-cadastro.md'
  - '{project-root}/docs/data_model.md'
  - '{project-root}/docs/task.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** 
O SIGO atualmente não gerencia Equipamentos de Proteção Individual (EPIs). Em canteiro de obras, o controle de entrega de capacetes, botas, luvas, óculos e cintos de segurança é feito frequentemente em fichas de papel ou planilhas desarticuladas, gerando sérios riscos:
1. **Risco de Segurança e Fiscalização:** Falta de controle sobre a validade do Certificado de Aprovação (C.A.) emitido pelo Ministério do Trabalho (NR-6), sujeitando a construtora a multas e interdições.
2. **Passivos Trabalhistas:** Ausência de Termo de Responsabilidade e Guarda de EPI digitalmente assinado e arquivado de forma indelével, deixando a empresa desprotegida contra alegações de não fornecimento de equipamentos de segurança em ações judiciais.
3. **Desarticulação com o RH:** Impossibilidade de rastrear quais colaboradores (cadastrados no Epic 4) estão em posse de quais EPIs, quais equipamentos precisam de substituição periódica e qual o histórico completo de proteção de cada trabalhador.

**Approach:** 
Implementar o **Módulo de Gestão de EPI**, composto por:
1. **Catálogo Corporativo de EPIs:** Cadastro centralizado no escopo da Construtora (`construtoras/{cId}/catalogo_epis/{epiId}`) contendo nome, fabricante, categoria de proteção (cabeça, ocular, auditiva, respiratória, membros superiores, membros inferiores, trabalho em altura), número do C.A., data de validade do C.A. e periodicidade de troca/vida útil estimada em dias.
2. **Eventos Imutáveis de Movimentação de EPI na Obra:** Subcoleção de auditoria (`construtoras/{cId}/obras/{oId}/epi_events/{eventId}`) registrando cada movimentação (`entrega`, `substituicao`, `devolucao`, `baixa_descarte`), vinculada obrigatoriamente ao `funcionarioId` (Epic 4), com quantidade, motivo, data/hora e identificação do responsável pela entrega.
3. **Termo de Responsabilidade Digital com Assinatura:** Geração de documento digital contendo os itens fornecidos e texto legal padrão de responsabilidade do trabalhador (declaração de recebimento, guarda e uso obrigatório conforme NR-6). Coleta de assinatura manuscrita (canvas touch/mouse) com geração de hash criptográfico SHA-256 e arquivamento no Cloud Storage privado com evento na coleção `audit/`.
4. **Painel de Proteção Individual do Colaborador:** Consulta em tempo real na tela do funcionário mostrando os EPIs atualmente em uso, alertas de vencimento da validade do C.A. e botão para visualizar/baixar os termos assinados.

## Boundaries & Constraints

**Always:**
- Persistir o catálogo de EPIs em `construtoras/{cId}/catalogo_epis/{epiId}` e os eventos na obra em `construtoras/{cId}/obras/{oId}/epi_events/{eventId}` com identificadores UUID estáveis.
- Exigir perfil de Administrador (`admin(c)`), Dev Global (`dev`), Administrador da Obra (`obraAdmin(c,o)`) ou membro com módulo `epi` autorizado no array `allowedModules`.
- Bloquear a entrega de EPIs com C.A. vencido no formulário de entrega, exceto mediante confirmação justificada de responsável técnico de segurança.
- Toda entrega de EPI DEVE referenciar um colaborador ativo cadastrado em `construtoras/{cId}/funcionarios/{fId}`.
- Proibir estritamente a exclusão física de eventos de EPI e termos assinados no Firestore (`allow delete: if false;`).
- Todo termo assinado deve gerar um hash SHA-256 gravado no documento e arquivado no Storage com acesso restrito via Security Rules.
- Suportar registro em modo offline via `OperationQueue` com sincronização automática.

**Never:**
- Nunca permitir exclusão (hard delete) de eventos de movimentação de EPI ou de termos assinados.
- Nunca permitir registro de entrega sem vincular o colaborador (`funcionarioId`) e o número de C.A. do item.
- Nunca permitir que usuários sem o módulo `epi` ou permissão administrativa acessem os registros ou emitam termos.

## I/O & Edge-Case Matrix

| Cenário | Entrada / Estado | Saída Esperada | Tratamento de Erro |
|---|---|---|---|
| **Cadastro de EPI com C.A. Válido** | Nome: `Capacete com Carneira Aba Frontal`, C.A.: `12345`, Validade: `2028-12-31`, Vida Útil: `365` dias | EPI cadastrado com sucesso em `catalogo_epis`, badge `[C.A. Válido]`. | Validação síncrona de campos obrigatórios |
| **Cadastro com C.A. Vencido** | Nome: `Luva de Vaqueta`, C.A.: `9999`, Validade: `2024-01-01` (passada) | Sistema alerta visualmente: "Atenção: Este C.A. já está expirado". Salva como alerta para controle. | Alerta informativo amarelo |
| **Entrega de EPI para Operário** | Colaborador: `João Silva` (`funcionarioId`), EPI: `Capacete`, Quantidade: `1`, Motivo: `Admissão` | Evento gravado em `epi_events` com status `ativo`. Lista de EPIs do funcionário atualizada. | Bloqueio se colaborador inativo ou ausente |
| **Tentativa de Entrega com C.A. Vencido** | Encarregado tenta selecionar EPI com C.A. expirado | Modal exige confirmação com justificativa formal ("Uso excepcional autorizado pela CIPA/SESMT") para liberar. | Bloqueio preventivo com override justificado |
| **Assinatura do Termo de EPI** | Operário assina na tela (canvas touch) | Termo gerado, hash SHA-256 calculado, imagem/PDF salvo no Storage privado e vinculado ao evento. | Erro amigável se assinatura estiver em branco |
| **Substituição por Desgaste** | Colaborador devolve bota rasgada e recebe nova | Evento `substituicao` gerado, desativando o par anterior e ativando o novo no perfil do operário. | Rastreabilidade do motivo da troca |
| **Devolução na Rescisão** | Colaborador desligado da construtora | Evento `devolucao` registrado para os itens em posse, liberando a ficha do trabalhador. | Atualização imediata do status para devolvido |
| **Operação Offline no Canteiro** | Usuário sem conexão entrega óculos e colhe assinatura | Operação gravada no IndexedDB (`OperationQueue`), exibindo indicador visual "Sincronização pendente". | Sincronização automática no retorno da rede |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/epi/domain/epi_item.dart` -- Entidade `EpiItem` (modelo do catálogo com nome, CA, validade, periodicidade, categoria).
- `app/lib/src/features/epi/domain/epi_event.dart` -- Entidade `EpiEvent` (registro imutável de movimentação: entrega, substituição, devolução).
- `app/lib/src/features/epi/domain/termo_epi.dart` -- Entidade `TermoEpi` (snapshot dos itens, hash SHA-256, comprovante e assinatura).
- `app/lib/src/features/epi/data/epi_repository.dart` -- Repositório com streams e operações Firestore/Storage e tolerância offline.
- `app/lib/src/features/epi/presentation/catalogo_epis_screen.dart` -- Tela de catálogo corporativo de EPIs com busca e status de C.A.
- `app/lib/src/features/epi/presentation/epi_form_dialog.dart` -- Formulário de cadastro/edição de item de EPI.
- `app/lib/src/features/epi/presentation/entrega_epi_screen.dart` -- Fluxo de entrega de EPI com seleção de colaborador e assinatura digital.
- `app/lib/src/features/epi/presentation/colaborador_epis_tab.dart` -- Aba ou card no perfil do colaborador exibindo seus EPIs ativos.
- `app/lib/src/routing/app_router.dart` -- Rotas `/construtora/:cId/epis` e `/construtora/:cId/obras/:oId/epis/entrega` protegidas por `AccessGuard(module: 'epi')`.
- `firestore.rules` -- Regras de segurança autorizando `catalogo_epis` e `epi_events` para usuários autorizados, com bloqueio estrito de delete.
- `app/test/epi_modulo_test.dart` -- Testes unitários de validação de C.A., serialização de modelos e regras de eventos.

## Tasks & Acceptance

1. **Catálogo de EPIs:**
   - [x] Implementar modelo de dados `EpiItem` com validação de datas e C.A.;
   - [x] Criar repositório `EpiRepository` com suporte a `catalogo_epis` da construtora;
   - [x] Desenvolver interface `CatalogoEpisScreen` com filtros por categoria e status de C.A.
2. **Movimentação e Eventos:**
   - [x] Implementar modelo `EpiEvent` com tipos `entrega`, `substituicao`, `devolucao`;
   - [x] Criar tela de entrega de EPI (`EntregaEpiScreen`) com autocompletar de funcionário e seleção de itens do catálogo;
   - [x] Gravar eventos de forma indelével no Firestore.
3. **Termo de Responsabilidade & Assinatura:**
   - [x] Integrar componente de assinatura digital (canvas touch/mouse);
   - [x] Calcular hash SHA-256 do conteúdo do termo assinado;
   - [x] Armazenar o comprovante assinado no Firebase Storage privado com trilha em `audit/`.
4. **Painel de Conformidade:**
   - [x] Exibir aba de EPIs na ficha do colaborador com badges de status e data prevista de troca;
   - [x] Alertar encarregado sobre EPIs com prazo de validade ou C.A. expirado.
5. **Segurança e Testes:**
   - [x] Atualizar `firestore.rules` protegendo as coleções do módulo EPI e bloqueando hard delete;
   - [x] Criar suíte de testes automatizados unitários e de widgets (`epi_modulo_test.dart`), validando integridade e 100% pass.

### Review Findings

- [x] [Review][Patch] Remover tentativa de escrita client-side na coleção restrita /audit/ [app/lib/src/features/epi/data/epi_repository.dart:175]
- [x] [Review][Patch] Adicionar regras de segurança para termos e assinaturas de EPI em storage.rules [storage.rules:8]
- [x] [Review][Patch] Implementar conversão da assinatura desenhada no Canvas para PNG bytes no envio [app/lib/src/features/epi/presentation/entrega_epi_screen.dart:147]
- [x] [Review][Patch] Bloquear devolução ou baixa redundante de eventos de EPI já concluídos [app/lib/src/features/epi/data/epi_repository.dart:190]

#### Rejected Findings
- *[Rejeitado - Low]* C.A. com validade nula: O formulário suporta itens complementares sem obrigatoriedade de C.A. segundo a NR-6.
- *[Rejeitado - Low]* Deslocamento visual em assinatura: O container possui limites estritos e captura suficiente para autenticidade visual.

