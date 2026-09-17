---
title: 'Story 3.3 — Estoque: Saída via Requisição por Lote'
type: 'feature'
created: '2026-09-17'
status: 'done'
baseline_commit: 'b3b92767c9ccb91aa13c871c91c58496fad46f42'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
  - '{project-root}/docs/task.md'
  - '{project-root}/docs/user_flows.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A saída de materiais do almoxarifado central possuía apenas campos de texto livre não-reativos para ID de obra e ID de lote, sem seleção estruturada de obras e seus respectivos lotes, sem marcação explícita de apropriação direta ao lote e sem identificação do solicitante da requisição, dificultando o rastreio do consumo físico de materiais nas unidades produtivas.

**Approach:** Aprimorar o modelo de movimentação para suportar `apropriacaoLote` e `solicitante`, enriquecer o formulário de saída na `MovimentacaoScreen` com seleção dinâmica de obra e lotes correspondentes vinculados à construtora, alternância de requisição com apropriação obrigatória por lote, validação de saldo de estoque disponível e exibição detalhada dos destinos no histórico de movimentações (`StockHistoryScreen`).

## Boundaries & Constraints

**Always:**
- Manter o saldo central em `construtoras/{cId}/materiais/{mId}` controlado exclusivamente pela Cloud Function transacional `stockCommand`.
- Enfileirar saídas via `OperationQueue.instance.enqueue('stockCommand', ...)` com UUID v4 único e idempotência preservada.
- Para saídas (`type: 'saida'`), a obra de destino (`obraId`) é estritamente obrigatória.
- Se a saída for marcada com apropriação por lote (`apropriacaoLote: true`), o lote de destino (`loteId`) torna-se obrigatório.
- Quantidade deve ser finita, estritamente positiva, com no máximo 3 casas decimais (`quantityScale: 1000`) e menor ou igual ao saldo disponível atual no estoque.
- Manter retrocompatibilidade com documentos de movimentação legados sem quebrar campos nulos.

**Never:**
- Não permitir alteração direta do saldo no cliente Firestore sem o aceite idempotente do servidor.
- Não permitir seleção de lotes desconectados da obra de destino selecionada.
- Não exibir campos de Nota Fiscal, Fornecedor ou Evidência de recebimento de compra durante o fluxo de saída.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Saída com Apropriação por Lote | Quantidade `10`, Obra `Obra Alphaville`, Lote `Lote 12`, Apropriação marcada, Solicitante `Mestre Carlos` | Enfileira `stockCommand` com `type: 'saida'`, `obraId`, `loteId`, `apropriacaoLote: true`, `solicitante`; saldo atualiza no servidor | SnackBar de confirmação pendente e retorno de rota |
| Saída Geral para a Obra | Quantidade `5`, Obra `Obra Alphaville`, sem seleção de lote e apropriação desmarcada | Enfileira `stockCommand` com `type: 'saida'`, `obraId`, `loteId: null`, `apropriacaoLote: false` | SnackBar de confirmação |
| Apropriação Marcada sem Lote | Apropriação ativada, mas nenhum lote selecionado | Formulário bloqueia envio com erro "Selecione o lote para apropriação" | Validação síncrona de campo |
| Quantidade Superior ao Estoque | Estoque atual `20`, quantidade digitada `25` | Validador acusa "Estoque insuficiente" e bloqueia submissão | Validação síncrona |
| Quantidade com mais de 3 decimais | Quantidade digitada `4.1234` | Validador acusa "Use até 3 casas decimais" | Validação com decimalUnits |
| Histórico de Movimentações | Lista de saídas carregada no `StockHistoryScreen` | Exibe destino com Obra, Lote, Solicitante e badge de Apropriação por Lote | N/A |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/almoxarifado/domain/movimentacao.dart` -- Adicionar campos `apropriacaoLote` e `solicitante` ao modelo `Movimentacao`.
- `app/lib/src/features/almoxarifado/domain/movimentacao.g.dart` -- Regenerar serializador JSON para os novos campos.
- `app/lib/src/features/almoxarifado/data/almoxarifado_repository.dart` -- Repassar `apropriacaoLote` e `solicitante` no payload de `stockCommand`.
- `app/lib/src/features/almoxarifado/presentation/movimentacao_screen.dart` -- Implementar seleção reativa de obra (`construtoraObrasProvider`), carregamento dinâmico de lotes da obra (`obraLotesProvider`), switch de apropriação por lote e campo de solicitante.
- `app/lib/src/features/almoxarifado/presentation/stock_history_screen.dart` -- Exibir obra, lote, solicitante e indicador de apropriação de lote nos itens de histórico.
- `app/test/stock_saida_test.dart` -- Nova suíte de testes unitários e de widget cobrindo saídas por lote, validações de apropriação e histórico.
- `app/test/stock_recebimento_test.dart` -- Assegurar compatibilidade contínua dos testes da Story 3.2.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/almoxarifado/domain/movimentacao.dart` -- Estender `Movimentacao` com `apropriacaoLote` (bool?) e `solicitante` (String?).
- [x] `app/lib/src/features/almoxarifado/domain/movimentacao.g.dart` -- Atualizar serializador JSON com os novos atributos.
- [x] `app/lib/src/features/almoxarifado/data/almoxarifado_repository.dart` -- Repassar `apropriacaoLote` e `solicitante` no `OperationQueue.instance.enqueue('stockCommand', ...)`.
- [x] `app/lib/src/features/almoxarifado/presentation/movimentacao_screen.dart` -- Reestruturar seção de saída com seletores reativos de Obra e Lote, switch de apropriação, validações contextuais e campo de solicitante.
- [x] `app/lib/src/features/almoxarifado/presentation/stock_history_screen.dart` -- Renderizar detalhes de saída (obra, lote, solicitante e tag de apropriação) nos cards do histórico.
- [x] `app/test/stock_saida_test.dart` -- Criar testes unitários do modelo, testes de enfileiramento e testes de widget do fluxo de saída de materiais por lote.
- [x] `_bmad-output/implementation-artifacts/sprint-status.yaml` -- Atualizar status da Story 3.3 para in-progress / done conforme o avanço.

**Acceptance Criteria:**
- Given um almoxarife na tela de saída de material, when seleciona uma obra e ativa apropriação por lote sem escolher o lote, then o formulário bloqueia a submissão exigindo a escolha do lote.
- Given uma saída com obra e lote selecionados e apropriação ativa, when o formulário é submetido, then o comando `stockCommand` é enfileirado com `type: 'saida'`, `obraId`, `loteId`, `apropriacaoLote: true` e `solicitante`.
- Given o histórico de movimentações, when uma saída com lote ou obra é listada, then as informações de destino e apropriação são exibidas claramente.
- Given uma quantidade superior ao estoque disponível, when informada na saída, then a submissão é bloqueada com "Estoque insuficiente".
- Given a suíte de testes (`flutter test`), then todos os testes passam sem falhas.

## Implementation Notes

- **Domínio & Serialização:** `Movimentacao` expandido com `apropriacaoLote` (bool?) e `solicitante` (String?), com serialização JSON completa e compatibilidade com dados legados sem novos campos.
- **Transacional & Fila:** `AlmoxarifadoRepository.registrarMovimentacao` repassa `apropriacaoLote` e `solicitante` no payload de `stockCommand` para o `OperationQueue`.
- **Formulário Reativo:** `MovimentacaoScreen` foi reestruturado para saída: consome `construtoraObrasProvider` para seleção de Obra, desencadeia `obraLotesProvider` para seleção de Lote da obra escolhida, inclui switch de apropriação direta ao lote com validação estrita e campo de solicitante. Layout otimizado e responsivo.
- **Histórico:** `StockHistoryScreen` enriquece cada movimentação exibindo Obra, Lote, badge `[Apropriação Lote]` e Solicitante.
- **Verificações:**
  - `flutter test`: 131/131 testes passaram com sucesso (incluindo testes de widget de saída e recebimento).
  - `flutter analyze`: 0 issues.
  - `functions test`: 8/8 passaram (`npm test`).
  - DTD `hot_reload`: recarga a quente executada com sucesso no app web ativo.

## Spec Change Log

- 2026-09-17: Criação da especificação, implementação completa de saída por lote, suíte de 6 testes em `stock_saida_test.dart` e validação sem regressões.

## Review Triage Log

- 2026-09-17: Blind Hunter & Edge Case Hunter — Validação de troca de obra e limpeza de lote anterior. Veredito: false (onChanged redefine _selectedLoteId = null e _loteController.clear()).
- 2026-09-17: Edge Case Hunter — Tentativa de apropriação de lote sem seleção de lote de destino. Veredito: false (validador síncrono no Dropdown/TextFormField e guarda explícita no _submit barram envio com erro 'Selecione o lote para apropriação').
- 2026-09-17: Verification Gap — Cobertura completa dos cenários da matriz de I/O de saída. Veredito: false (todos os cenários cobertos em `test/stock_saida_test.dart` e 131 testes passaram).

## Verification

**Commands:**
- `flutter test` -- expected: Todos os testes de unidade e widget executam e passam com sucesso (exit code 0).
- `flutter analyze` -- expected: Nenhum problema ou aviso no código estático (exit code 0).
- `cd ../functions && npm test` -- expected: Testes de unidade e contratos transacionais executam com sucesso (exit code 0).
