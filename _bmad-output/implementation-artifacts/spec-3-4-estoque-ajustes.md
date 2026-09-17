---
title: 'Story 3.4 — Estoque: Ajustes Auditados'
type: 'feature'
created: '2026-09-17'
status: 'done'
baseline_commit: '2618d2e1464e3b76614b74a74ab1abe8975b70da'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
  - '{project-root}/docs/task.md'
  - '{project-root}/docs/user_flows.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Ajustes de inventário de estoque (correções de saldo decorrentes de contagem física, perdas, quebras ou sobras) não possuíam validação rigorosa de decimais e limites na UI, ignoravam pendências de ajuste no cálculo de saldo estimado do almoxarifado, e exibiam rótulos genéricos no histórico sem evidenciar a natureza auditada da correção administrativa.

**Approach:** Aprimorar o fluxo de ajuste de estoque em `StockHistoryScreen` e `AlmoxarifadoListScreen` com validações rigorosas (motivo com no mínimo 5 caracteres, evidência/documento obrigatório, variação não-nula com até 3 casas decimais, bloqueio de variação negativa superior ao saldo atual), exibição do saldo resultante previsto no diálogo, consideração de ajustes pendentes na estimativa de estoque local e rotulagem expressiva de `[Ajuste Auditado]` no histórico de movimentações.

## Boundaries & Constraints

**Always:**
- Ajuste de estoque (`type: 'ajuste'`) é restrito exclusivamente a administradores (`canManage` / `a.admin == true`).
- Exigir motivo detalhado (`reason`) com comprimento mínimo de 5 caracteres.
- Exigir evidência documental ou referência comprobatória não-vazia (`evidence`).
- Variação deve ser um número finito diferente de zero, com no máximo 3 casas decimais (`quantityScale: 1000`).
- O saldo resultante pós-ajuste (`saldoAtual + variacao`) não pode ser negativo.
- Enfileirar via `OperationQueue.instance.enqueue('stockCommand', ...)` com `operationId` estável (UUID v4) e idempotência assegurada.
- Refletir o delta de ajustes pendentes (`type: 'ajuste'`) no cálculo de saldo estimado de `AlmoxarifadoListScreen`.

**Never:**
- Não permitir ajuste sem motivo ou sem evidência.
- Não permitir que usuários comuns sem privilégio de administrador executem ou submetam ajustes.
- Não efetuar alterações diretas no saldo do Firestore pelo cliente sem transação auditada da Cloud Function `stockCommand`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Ajuste Positivo (Sobra de Inventário) | Saldo `50`, Variação `+5.5`, Motivo `Sobra identificada na contagem semanal`, Evidência `Laudo-INV-2026-09` | Enfileira `stockCommand` com `type: 'ajuste'`, `quantity: '5.5'`, `reason` e `evidence`; saldo previsto `55.5` | SnackBar de confirmação pendente |
| Ajuste Negativo (Avaria / Perda) | Saldo `30`, Variação `-10`, Motivo `Sacos furados na chuva`, Evidência `Foto-DOC-8821` | Enfileira `stockCommand` com `type: 'ajuste'`, `quantity: '-10'`, `reason` e `evidence`; saldo previsto `20` | SnackBar de confirmação pendente |
| Motivo Muito Curto | Usuário digita motivo `Erro` (< 5 caracteres) | Validador bloqueia envio com "Descreva o motivo (mínimo 5 caracteres)" | Validação síncrona no diálogo |
| Evidência Vazia | Campo evidência deixado em branco | Validador bloqueia envio com "Informe a referência da evidência ou documento" | Validação síncrona no diálogo |
| Ajuste Negativo Maior que Saldo | Saldo `10`, Variação digitada `-15` | Validador bloqueia com "Ajuste negativo excede o saldo atual (10)" | Validação síncrona preventiva |
| Variação Zero ou Inválida | Usuário digita `0` ou `abc` | Validador bloqueia com "Informe uma variação diferente de zero" | Validação síncrona |
| Mais de 3 Casas Decimais | Usuário digita `2.1234` | Validador bloqueia com "Use até 3 casas decimais" | Validação com decimalUnits |
| Histórico de Movimentações | Movimentação com `commandType: 'ajuste'` | Card exibe badge destacado `[Ajuste Auditado]`, variação com sinal, motivo e evidência | N/A |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/almoxarifado/presentation/stock_history_screen.dart` -- Validação completa no diálogo de ajuste (motivo >= 5 chars, evidência obrigatória, delta válido, cálculo de saldo previsto), e formatação contextual de `[Ajuste Auditado]` no histórico.
- `app/lib/src/features/almoxarifado/presentation/almoxarifado_list_screen.dart` -- Incluir comandos de `type == 'ajuste'` no cálculo de saldo estimado de materiais com pendências offline.
- `app/test/stock_ajuste_test.dart` -- Nova suíte de testes unitários e de widget cobrindo regras de validação de ajustes, cálculo de saldo estimado e exibição no histórico.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/almoxarifado/presentation/stock_history_screen.dart` -- Aprimorar diálogo `correction` para `ajuste` com validação de escala decimal, limite de saldo negativo, motivo mínimo de 5 caracteres e evidência obrigatória.
- [x] `app/lib/src/features/almoxarifado/presentation/stock_history_screen.dart` -- Renderizar badge `[Ajuste Auditado]`, variação com sinal (+/-), motivo e evidência na listagem do histórico.
- [x] `app/lib/src/features/almoxarifado/presentation/almoxarifado_list_screen.dart` -- Incluir `type == 'ajuste'` na soma de deltas do saldo estimado com pendências.
- [x] `app/test/stock_ajuste_test.dart` -- Criar suíte de testes automatizados para validação do diálogo de ajuste e cálculo de saldo estimado.
- [x] `_bmad-output/implementation-artifacts/sprint-status.yaml` -- Atualizar status da Story 3.4.

**Acceptance Criteria:**
- Given um administrador no histórico de um material, when clica em "Ajustar quantidade", then o diálogo exibe campos para variação, motivo (mínimo 5 caracteres) e evidência documental.
- Given uma variação negativa que deixaria o saldo negativo, when o administrador tenta confirmar, then o validador bloqueia o envio com mensagem contextual.
- Given um ajuste válido submetido, then o comando `stockCommand` é enfileirado com `type: 'ajuste'`, quantidade, motivo e evidência.
- Given itens com pendência de ajuste na fila offline, when listados no `AlmoxarifadoListScreen`, then o saldo estimado reflete corretamente o delta do ajuste.
- Given a suíte de testes (`flutter test`), then todos os testes passam com sucesso.

## Implementation Notes
- Diálogo de ajuste implementado via `_CorrectionDialog` com controle de ciclo de vida próprio dos TextEditingControllers, evitando erros de dispose durante animação de saída.
- Validação síncrona preventiva no formulário: motivo >= 5 chars, evidência não-vazia, número finito diferente de zero com até 3 casas decimais, bloqueio de variação negativa superior ao saldo atual, cálculo de saldo previsto dinâmico.
- Sanitização de input antes do enfileiramento no `OperationQueue`: remoção de prefixos `+` para estrita conformidade com o contrato regex `/^-?\d+(\.\d+)?$/` do backend Cloud Functions.
- `StockHistoryScreen` exibe badge destacado `[Ajuste Auditado]`, variação com sinal e exibição explícita de motivo e evidência. Suporte a injeção opcional de `mockMovements` e `queue` para testes unitários/widgets isolados.
- `AlmoxarifadoListScreen` atualizado para somar deltas de `type == 'ajuste'` no saldo estimado com pendências.
- Suíte `stock_ajuste_test.dart` com 10 testes cobrindo todas as linhas da matriz I/O, critérios de aceitação e limites de permissão.

## Spec Change Log

## Review Triage Log

- 2026-09-17: Blind Hunter — Validação de ciclo de vida e descarte de controladores de texto do diálogo. Veredito: false (encapsulado em `_CorrectionDialogState` gerenciando o ciclo de vida e garantindo descarte seguro após a rota de diálogo ser desmontada).
- 2026-09-17: Edge Case Hunter — Sanitização de prefixo de sinal '+' para conformidade com regex do backend (`contracts.ts`). Veredito: false (sanitização preventiva implementada: `replaceAll('+', '')` antes do enfileiramento na fila offline).
- 2026-09-17: Edge Case Hunter — Proteção contra saldo negativo em ajustes debitados. Veredito: false (validação síncrona preventiva no diálogo com mensagem contextual `Ajuste negativo excede o saldo atual (...)`).
- 2026-09-17: Verification Gap — Cobertura completa da matriz de I/O e restrições de permissão. Veredito: false (todos os cenários cobertos em `test/stock_ajuste_test.dart`, 141/141 testes Flutter e 8/8 testes de functions passaram).

## Verification

**Commands:**
- `flutter test` -- expected: Todos os testes de unidade e widget executam e passam com sucesso (exit code 0).
- `flutter analyze` -- expected: Nenhum problema ou aviso no código estático (exit code 0).
- `cd ../functions && npm test` -- expected: Testes de unidade e contratos transacionais executam com sucesso (exit code 0).
