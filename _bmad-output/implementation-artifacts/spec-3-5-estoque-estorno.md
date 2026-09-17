---
title: 'Story 3.5 — Estoque: Estorno por Movimentação Inversa'
type: 'feature'
created: '2026-09-17'
status: 'done'
baseline_commit: 'c09af8e6dbe1123e04df3ee177daf75f04e7e703'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
  - '{project-root}/docs/task.md'
  - '{project-root}/docs/user_flows.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Movimentações de estoque confirmadas (`entrada`, `saida`, `ajuste`) nunca podem ser alteradas ou excluídas fisicamente no SIGO, necessitando de neutralização operacional via estorno auditado. Atualmente, a ação de estorno na UI não apresenta o resumo da movimentação original nem o saldo resultante previsto, não impede estornos de entrada que resultariam em saldo negativo no cliente, não identifica com clareza visual transações estornadas e estornos no histórico, e a estimativa de saldo com pendências offline ignora estornos na fila de sincronização.

**Approach:** Aprimorar o fluxo de estorno em `StockHistoryScreen` passando a movimentação original para `_CorrectionDialog`, exibindo dados de origem (tipo, quantidade, data/responsável/documento) e cálculo de saldo previsto pós-estorno, bloqueando estornos de entrada cujo impacto negativo exceda o saldo atual; exibir badges claros `[Estorno Auditado]` e `[Estornado]` no histórico; registrar no payload enfileirado (`stockCommand`) os metadados de reversão (`reversalId`, `reversalDelta`) e considerar estornos pendentes no saldo estimado em `AlmoxarifadoListScreen`.

## Boundaries & Constraints

**Always:**
- Estorno de estoque (`type: 'estorno'`) é restrito exclusivamente a administradores (`canManage` / `a.admin == true`).
- Apenas movimentações dos tipos `entrada`, `saida` ou `ajuste` que ainda não possuam `reversedBy` podem ser estornadas.
- Exigir motivo detalhado (`reason`) com comprimento mínimo de 5 caracteres.
- Exigir evidência documental ou referência comprobatória não-vazia (`evidence`).
- O estorno gera uma nova movimentação inversa sem apagar nem modificar diretamente a original, referenciando-a por `reversalId`.
- Na transação do backend, a movimentação original recebe `reversedBy: movementId`, impedindo reversão duplicada.
- Se o estorno resultar em saldo negativo (`saldoAtual + deltaInverso < 0`), a operação deve ser prevenida na UI e rejeitada pelo backend (`failed-precondition`).
- Enfileirar via `OperationQueue.instance.enqueue('stockCommand', ...)` com `operationId` UUID v4 estável, `reversalId`, motivo, evidência e `reversalDelta`.
- Refletir o `reversalDelta` de estornos pendentes na estimativa de saldo de `AlmoxarifadoListScreen`.

**Never:**
- Nunca permitir exclusão física ou mutação direta de registros de movimentações no Firestore.
- Nunca permitir estorno sem motivo válido (>= 5 caracteres) ou sem evidência.
- Nunca permitir estorno de movimentações que já foram estornadas (`reversedBy != null`) ou de abertura de saldo (`type == 'abertura'`).
- Nunca permitir que usuários comuns sem privilégio de administrador executem ou submetam estornos.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Estorno de Saída (Devolve Material ao Estoque) | Movimentação original: Saída de `10 Saco`. Saldo atual: `20 Saco`. Motivo: `Requisição de saída cancelada`, Evidência: `Memorando-042` | Diálogo exibe resumo da saída original de `10 Saco` e saldo previsto `30 Saco`. Enfileira `stockCommand` com `type: 'estorno'`, `reversalId`, `reversalDelta: 10`, `quantity: '0'` | SnackBar de confirmação pendente |
| Estorno de Entrada (Retira Material do Estoque) | Movimentação original: Entrada de `15 Saco`. Saldo atual: `35 Saco`. Motivo: `NF duplicada lançada incorretamente`, Evidência: `Can-NF-991` | Diálogo exibe resumo da entrada original e saldo previsto `20 Saco`. Enfileira `stockCommand` com `type: 'estorno'`, `reversalDelta: -15` | SnackBar de confirmação pendente |
| Estorno de Entrada com Saldo Insuficiente | Movimentação original: Entrada de `50 Saco`. Saldo atual: `10 Saco` (material já consumido). | Diálogo detecta que saldo ficaria `-40 Saco`, exibe alerta vermelho e bloqueia botão Registrar com "Saldo insuficiente para estornar esta entrada (saldo atual: 10 Saco)" | Bloqueio síncrono na UI |
| Motivo Muito Curto | Usuário digita motivo `Erro` (< 5 caracteres) | Validador bloqueia envio com "Descreva o motivo (mínimo 5 caracteres)" | Validação síncrona no diálogo |
| Evidência Vazia | Campo evidência deixado em branco | Validador bloqueia envio com "Informe a referência da evidência ou documento" | Validação síncrona no diálogo |
| Movimentação já estornada | Movimentação com `reversedBy != null` | Exibe badge `[Estornado]`, texto em estilo atenuado/riscado e botão 'Estornar' desabilitado/oculto | N/A |
| Visualização de Estorno no Histórico | Movimentação com `commandType: 'estorno'` | Exibe badge destacado `[Estorno Auditado]`, variação inversa com sinal, motivo, evidência e referência `Ref: [reversalId]` | N/A |
| Estimativa com Estornos Pendentes | Saldo confirmado: `50`. Estorno pendente de entrada de `15` na fila offline | Lista do almoxarifado exibe saldo estimado `35 Saco` considerando `reversalDelta` do estorno | N/A |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/almoxarifado/presentation/stock_history_screen.dart` -- Enriquecer `_CorrectionDialog` para suportar `originalMovement`, exibindo resumo do movimento a estornar (tipo original, quantidade original, detalhes), saldo atual e saldo previsto pós-estorno; bloqueio preventivo de saldo negativo no estorno de entrada; badge visual `[Estorno Auditado]` e badge `[Estornado]`; inclusão de `reversalDelta` no payload da fila.
- `app/lib/src/features/almoxarifado/presentation/almoxarifado_list_screen.dart` -- Atualizar cálculo de estimativa com pendências offline para considerar comandos com `d['type'] == 'estorno'`, aplicando `reversalDelta`.
- `app/test/stock_estorno_test.dart` -- Nova suíte abrangente de testes cobrindo a matriz I/O (estorno de saída, estorno de entrada, estorno com saldo insuficiente, validação de campos, badges de histórico e cálculo de pendências offline).

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/almoxarifado/presentation/stock_history_screen.dart` -- Implementar suporte a `originalMovement` no diálogo de estorno com exibição de detalhes, cálculo de saldo previsto e bloqueio de saldo negativo.
- [x] `app/lib/src/features/almoxarifado/presentation/stock_history_screen.dart` -- Formatar badges `[Estorno Auditado]` e `[Estornado]` na listagem de movimentações com indicação de referência e estilo visual claro.
- [x] `app/lib/src/features/almoxarifado/presentation/almoxarifado_list_screen.dart` -- Incorporar `reversalDelta` de estornos pendentes no cálculo do saldo estimado do Almoxarifado.
- [x] `app/test/stock_estorno_test.dart` -- Criar testes unitários e de widget para todos os cenários da Matriz I/O e casos de borda de estorno.

**Acceptance Criteria:**
- Given um administrador logado e uma movimentação confirmada de saída de 10 unidades, when clica em "Estornar" e informa motivo >= 5 chars e evidência, then o comando `stockCommand` com `type: 'estorno'` é enfileirado com `reversalId`, `reversalDelta: 10`, exibindo saldo previsto de +10 no diálogo.
- Given um administrador logado e uma movimentação confirmada de entrada de 50 unidades onde o saldo atual do material é apenas 10 unidades, when abre o diálogo de estorno, then o sistema exibe alerta de saldo insuficiente e impede a confirmação do estorno.
- Given movimentações de estorno confirmadas ou pendentes, when visualizadas no histórico e na lista do almoxarifado, then o histórico exibe `[Estorno Auditado]` e a movimentação de origem exibe `[Estornado]`, e o saldo estimado do almoxarifado reflete o delta do estorno pendente.

## Implementation Notes

- `StockHistoryScreen`: Adicionado parâmetro `originalMovement` a `_CorrectionDialog` e à chamada de `correction(...)`. O diálogo calcula `revDelta` invertendo o sinal da operação original e projeta `predictedBalance`. Se o saldo previsto for negativo (tentativa de estornar entrada sem saldo disponível suficiente), exibe alerta contextual e desabilita o botão `Registrar`.
- Enfileiramento: Payload de `stockCommand` recebe `reversalDelta` e `quantity: '0'` para operações do tipo `estorno`.
- Exibição de Histórico: Badge destacado `[Estorno Auditado]` em roxo/lilás para movimentações de estorno, e badge `[Estornado]` em cinza com texto tachado na movimentação original que foi revertida.
- `AlmoxarifadoListScreen`: Cálculo de estimativa com pendências atualizado para considerar comandos de `type == 'estorno'`, somando o `reversalDelta`.
- Testes: Criada a suíte `app/test/stock_estorno_test.dart` cobrindo 100% dos 8 cenários da Matriz I/O e casos de borda (todos aprovados). Suíte global de 148 testes do Flutter e `flutter analyze` validados com sucesso (zero warnings/errors).
- Hot reload acionado e validado com sucesso na aplicação web ativa via DTD.

## Spec Change Log

## Review Triage Log

- 2026-09-17: Blind Hunter — Validação de ciclo de vida e descarte dos controladores `_quantity`, `_reason`, `_evidence` no diálogo de correção. Veredito: false (gerenciamento de estado e dispose correto implementado em `_CorrectionDialogState`).
- 2026-09-17: Edge Case Hunter — Tentativa de estorno de entrada sem estoque suficiente gerando saldo negativo. Veredito: false (validação e bloqueio preventivo na UI exibindo alerta em destaque e desabilitando o botão `Registrar` quando `predictedBalance < 0`).
- 2026-09-17: Edge Case Hunter — Re-estorno duplicado de movimentação já revertida. Veredito: false (verificação de `isReversed` oculta botão "Estornar" e exibe tag `[Estornado]` com texto tachado).
- 2026-09-17: Edge Case Hunter — Idempotência e integridade da fila offline com metadados do estorno. Veredito: false (`operationId` UUID v4 estável, `reversalId`, `reversalDelta` e `quantity: '0'` devidamente enfileirados).
- 2026-09-17: Verification Gap — Cobertura completa de testes automatizados para todas as linhas da matriz I/O. Veredito: false (100% coberto em `test/stock_estorno_test.dart`, 148/148 testes Flutter passando e `flutter analyze` com 0 issues).

## Verification

**Commands:**
- `cd app && flutter test test/stock_estorno_test.dart` -- expected: All tests passed!
- `cd app && flutter analyze` -- expected: No issues found!
