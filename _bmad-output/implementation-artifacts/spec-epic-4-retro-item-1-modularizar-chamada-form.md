---
title: 'Epic 4 retro item 1 — Extrair sumário de rateio da chamada'
type: 'refactor'
created: '2026-09-24'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problema:** O item `epic-4-retro-item-1-modularizar-chamada-form` permanece aberto: `app/lib/src/features/rh/presentation/chamada_form_screen.dart` possui 585 linhas e ainda concentra a composição do sumário de rateio. A meta é ter no máximo 500 linhas após formatação normal.

**Abordagem:** Extrair o sumário de rateio e a composição visual complementar em widgets da apresentação de RH. Preservar aparência, contadores, custos em centavos, resumo por lote, filtros, atualização de trabalhadores, validações, salvamento e retificação. Encerrar o item de retrospectiva somente após comprovar a extração e o limite de linhas.

</frozen-after-approval>

## Implementation Notes

- Investigação: não há lacunas de intenção nem operações irreversíveis. Refatoração local pequena; rota `oneshot`.
- A barra e o diálogo já existem em `app/lib/src/features/rh/presentation/widgets/chamada_sticky_bottom_bar.dart` e `resumo_custos_chamada_dialog.dart`. Reutilizá-los; retirar da tela a derivação de contadores e a composição do custo estimado usando `CustoMaoDeObraService.computeChamadaCosts`.
- Extrair um `ChamadaRateioSummary` em `app/lib/src/features/rh/presentation/widgets/chamada_rateio_summary.dart`, com trabalhadores, funcionários, data, chamada existente, flags e callback de salvamento. Um `ChamadaFormView` em `app/lib/src/features/rh/presentation/widgets/chamada_form_view.dart` compõe o layout atual, filtros/banner, lista/vazio e sumário. Somente dados e callbacks tipados; não introduzir providers ou persistência nesses widgets.
- A tela mantém carregamento Riverpod/streams, estado, sincronização dos trabalhadores, validação, memorização do lote, cross-obra e salvamento/auditoria. Preservar a ordem dos callbacks de equipe e a distinção atual entre validade do botão e validação com lotes válidos. Não modificar serviços ou regras de domínio.
- Verificação: formatar os arquivos Dart alterados, conferir contagem física <=500, executar `flutter analyze` e `flutter test test/rh_chamada_test.dart test/rh_custos_apropriacao_test.dart test/rh_invariantes_auditoria_test.dart` em `app/`. Usar cobertura existente; testes adicionais só se necessários para risco comportamental real da fronteira extraída.
- Atualizar somente o item correspondente em `_bmad-output/implementation-artifacts/sprint-status.yaml`, registrando contagem e evidência final após verificações.
- Implementação: criados `ChamadaRateioSummary` (derivação de custos/contagens) e `ChamadaFormView` (composição visual). Tela principal com 491 linhas após `dart format`, redução de 94 linhas. Callbacks e regras de persistência preservados.
- Verificação inicial: as três suítes de RH passaram, 39 testes. `flutter analyze` reportou 13 imports não utilizados nos arquivos de roteamento preexistentes `dev_routes.dart` e `app_router.dart`; nenhum diagnóstico nos arquivos alterados. Não foram acrescentados testes que espelhem esta extração mecânica e reversível; cobertura comportamental existente foi executada.
- Verificação final: `dart analyze` dos três arquivos Dart alterados passou sem problemas; `git diff --check` passou. Revisão independente Blind Hunter concluída, única camada configurada na rota. Item da retrospectiva atualizado para `done`, com contagem de 491 linhas e evidência dos testes.

## Review Triage Log

- **low — rejeitado:** falta teste direto de integração dos widgets extraídos. Busca em `app/test/` confirma ausência; os 39 testes validam os componentes existentes e regras, não a tela integrada. Diff confirma transposição dos mesmos callbacks e argumentos, sem novo comportamento. Montar um harness adicional para esta extração mecânica/reversível excede uma correção simples, sem defeito comportamental demonstrado.
- **low — patch:** acompanhamento ainda descrevia 585 linhas e sumário pendente durante a revisão. Finalização atualizou o item exato em `sprint-status.yaml` para 491 linhas, extração concluída e `done`.
- **false — rejeitado:** datas divergentes no novo componente. Único chamador passa `_selectedDate` e o getter `_formattedDate`, que deriva diretamente dela no mesmo build síncrono; não há caminho real com divergência. Possíveis futuros chamadores não demonstram um defeito atual.
- **low — rejeitado:** busca linear de funcionário por cartão. Existe, mas é idêntica ao código anterior e limitada aos cartões construídos pelo `ListView.builder`; não há lentidão demonstrada no uso normal. Índice adicional é otimização além de uma correção simples e não é necessário para esta extração.
- **high — defer:** edição durante salvamento pode produzir data/trabalhadores diferentes dos validados antes do await da consulta cross-obra. Conferidos `_saveChamada`, `_pickDate`, callbacks de filtros e `isSaving` restrito à barra; sequência já existia no diff-base. Registrado em `deferred-work.md` para correção comportamental própria; não introduzido pela refatoração.
