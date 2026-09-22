---
title: 'Fechar status das Épicas 8 e 10'
type: 'chore'
created: '2026-09-22'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** As Épicas 8 e 10 estão com `epic-8`/`epic-10: in-progress` em `sprint-status.yaml`, mas todas as stories estão `done` (8-1/8-2/8-3 com `epic-8-retrospective: done`; 10-1/10-2/10-3 com `epic-10-retrospective: optional`) — o acompanhamento não reflete o estado real.

**Approach:** Alterar somente `_bmad-output/implementation-artifacts/sprint-status.yaml`: promover `epic-8` e `epic-10` para `done` e atualizar `last_updated`, preservando comentários, estrutura, chaves de stories e `action_items` — mesmo padrão do fechamento da Épica 9 (commit `55fabb8`). Decisão registrada: `epic-10-retrospective` permanece `optional` (retro não é executada nesta tarefa; o pedido é fechar status).

</frozen-after-approval>

## Implementation Notes

- Arquivo alterado: `_bmad-output/implementation-artifacts/sprint-status.yaml` — apenas 3 linhas: `epic-8: in-progress → done`, `epic-10: in-progress → done` e `last_updated: 09-22-2026 16:11 → 09-22-2026 16:35`.
- Comentários, estrutura, chaves de stories e `action_items` preservados sem alteração (inclui os 3 itens abertos da retro do Épica 8 e os 3 da retro do Épica 9).
- `epic-10-retrospective` mantido como `optional` — decisão registrada no Intent: retro não executada nesta tarefa.
- Nenhuma surpresa durante a implementação; mudança dentro do planejado (sem replanejamento).
- `story_key` vazio (não é story de épica) → `sync-sprint-status.md` não aplicável.
- Verificação pós-implementação: `ruby -ryaml` parse OK; diff exatamente 3 linhas (`last_updated`, `epic-8`, `epic-10`); `action_items` = 21 preservados; baseline HEAD `959d669`.
- Camadas de review oneshot: ativa `blind-hunter`; puladas `edge-case-hunter` e `verification-gap` (rota dispatch).

## Review Triage Log

- `status` não avançou para `done` — **false**: etapa Finalize Spec do step-oneshot roda após a classificação e define `status: 'done'`.
- Commit não executado — **false**: etapa Commit do step-oneshot ocorre após Finalize; executada em seguida.
- `baseline_commit` ausente — **false**: rota oneshot não exige o campo (step-03 não se aplica); template não o inclui; 10+ specs irmãos também não têm; baseline `959d669` recuperável do histórico.
- Intent confunde chaves de story com chaves de retro — **false**: o parêntese apresenta estados complementares (stories `done` + estado das retros); abreviações `8-1`… reconhecíveis; sem erro factual.
- "mesmo padrão do fechamento da Épica 9 (55fabb8)" incorreto — **false**: o padrão citado é o flip de status preservando estrutura, exatamente o que 55fabb8 fez nas linhas `epic-9`; o arquivo de retro foi artefato concorrente da run de retro, não parte do padrão de fechamento de status.
- Épica 10 fechada sem arquivo de retro nem `action_item` do adiamento — **false**: `epic-10-retrospective: optional` é a convenção estabelecida (épicas 3 e 6 fechadas `done` com retro `optional`, sem arquivo); decisão registrada no Intent do spec.
- Retro keys divergem (`done`/`done`/`optional`) sem comentário no YAML — **false**: mesma convenção; o valor `optional` no próprio YAML comunica a exceção, como nas épicas 3 e 6.
- `review_loop_iteration` não avançou / camadas e Triage Log não registrados — **false**: camadas anunciadas no chat; Triage Log adicionado no Finalize; `review_loop_iteration` incrementa apenas em loopbacks do step-04 (rota dispatch).
- `context: []` vazio — **false**: campo opcional no template; caminho do `sprint-status.yaml` já está no corpo do Intent.
- Expressão "`story_key` vazio" sem campo no frontmatter — **false**: refere-se à variável de runtime do workflow (step-01), indefinida/nula para specs que não são stories de épica.
- Sem verificação de parse YAML / diff — **low, patch aplicado**: `ruby -ryaml` parse OK; diff confere exatamente 3 linhas pretendidas; 21 `action_items` preservados.

