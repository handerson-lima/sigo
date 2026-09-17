---
title: 'Story 3.2 — Estoque: Recebimento no Almoxarifado Central'
type: 'feature'
created: '2026-09-17'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
  - '{project-root}/docs/task.md'
  - '{project-root}/docs/user_flows.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O almoxarifado central possuía apenas um formulário rudimentar de entrada sem suporte a metadados essenciais de recebimento de compras (número da nota fiscal, identificação do fornecedor e anexo/foto do documento comprobatório), impossibilitando auditoria de compras e rastreabilidade de suprimentos.

**Approach:** Aprimorar o modelo de movimentação para registrar formalmente metadados de nota fiscal (`nfNumber`, `fornecedor`, `evidence`), atualizar o formulário `MovimentacaoScreen` para entrada/recebimento com campos estruturados e suporte a fotos/evidências de NF, repassar os metadados ao backend transacional (`stockCommand` via `OperationQueue`) e exibir as evidências no histórico de estoque (`StockHistoryScreen`).

## Boundaries & Constraints

**Always:**
- Manter o estoque central por construtora (`construtoras/{cId}/materiais/{mId}`), onde entradas somam ao saldo central compartilhado.
- Enfileirar comandos transacionais via `OperationQueue.instance.enqueue('stockCommand', ...)` com `operationId` estável (UUID v4) e idempotência garantida.
- Respeitar a escala de quantidades (`quantityScale: 1000`) e decimais de até 3 casas.
- Proibir entrada com quantidade nula, negativa ou não-finita.
- Permitir anexo de foto/evidência da NF com identificador estável para conformidade PWA offline.

**Never:**
- Não atualizar o saldo de estoque diretamente no cliente sem validação da Cloud Function `stockCommand`.
- Não permitir recebimento de estoque sem informação do fornecedor ou documento quando informado como compra.
- Não quebrar a retrocompatibilidade com movimentações antigas que não possuíam `evidence`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Recebimento de Material com NF | Usuário informa quantidade `50`, NF `12345`, Fornecedor `Votorantim` e anexa foto da NF | Comando enfileirado com `type: 'entrada'`, `evidence` e payload estruturado; saldo local/oficial atualiza | SnackBar de confirmação pendente |
| Quantidade Inválida ou Negativa | Usuário digita `-10` ou `0` na quantidade | Formulário bloqueia submissão com "Valor inválido" | Validação de campo síncrona |
| Quantidade com mais de 3 casas decimais | Usuário digita `10.1234` | Validador acusa "Use até 3 casas decimais" | Validação com decimalUnits |
| Recebimento sem NF opcional | Entrada rápida de material sem anexo | Permite recebimento com observação padrão de suprimento | N/A |
| Visualização no Histórico | Histórico de movimentações carregado | Card da entrada exibe badge com NF, Fornecedor e evidência | N/A |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/almoxarifado/domain/movimentacao.dart` -- Adicionar campos `evidence`, `nfNumber`, `fornecedor` ao modelo.
- `app/lib/src/features/almoxarifado/domain/movimentacao.g.dart` -- Regenerar serializadores JSON para novos campos.
- `app/lib/src/features/almoxarifado/data/almoxarifado_repository.dart` -- Enviar `evidence`, `nfNumber`, `fornecedor` no payload de `stockCommand`.
- `app/lib/src/features/almoxarifado/presentation/movimentacao_screen.dart` -- Expandir formulário de entrada com campos de NF, Fornecedor e anexo de foto/evidência.
- `app/lib/src/features/almoxarifado/presentation/stock_history_screen.dart` -- Exibir badge e detalhes de NF/evidência na lista de movimentações.
- `app/test/stock_recebimento_test.dart` -- Suíte de testes automatizados para recebimento de estoque e validações de NF.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/almoxarifado/domain/movimentacao.dart` -- Expandir modelo `Movimentacao` com `evidence`, `nfNumber`, `fornecedor`.
- [x] `app/lib/src/features/almoxarifado/domain/movimentacao.g.dart` -- Atualizar serializador JSON com os novos campos.
- [x] `app/lib/src/features/almoxarifado/data/almoxarifado_repository.dart` -- Repassar metadados de recebimento no `registrarMovimentacao`.
- [x] `app/lib/src/features/almoxarifado/presentation/movimentacao_screen.dart` -- Criar campos de NF, Fornecedor e Evidência na tela de movimentação de entrada.
- [x] `app/lib/src/features/almoxarifado/presentation/stock_history_screen.dart` -- Exibir NF, fornecedor e anexo de evidência nos itens do histórico.
- [x] `app/test/stock_recebimento_test.dart` -- Implementar testes unitários e de widget para a funcionalidade de recebimento.

**Acceptance Criteria:**
- Given um usuário no almoxarifado central, when registra entrada com quantidade, número de NF e foto do comprovante, then a operação é enfileirada no `OperationQueue` com metadados completos.
- Given o histórico de movimentações, when uma entrada com evidência é listada, then os dados da NF e evidência são renderizados de forma legível.
- Given o formulário de movimentação, when submetido com valores inválidos, then os validadores bloqueiam o envio com mensagens contextuais.
- Given a suíte de testes, when executado `flutter test`, then todos os testes passam sem falhas.

## Implementation Notes

- **Domínio & Serialização:** `Movimentacao` expandido com `evidence`, `nfNumber`, `fornecedor` e serializadores JSON atualizados com retrocompatibilidade para campos nulos.
- **Formulário de Entrada:** `MovimentacaoScreen` expandido com campos dedicados de Nota Fiscal, Fornecedor e Comprovante de Evidência quando `type == MovimentacaoType.entrada`, mantendo destino (`obraId`/`loteId`) exclusivo para saída.
- **Transacional & Idempotência:** Repositório `AlmoxarifadoRepository` e Cloud Function `stockCommand` atualizados para propagar e persistir `nfNumber`, `fornecedor` e `evidence` de forma idempotente e auditável.
- **Histórico & Rastreabilidade:** `StockHistoryScreen` enriquece a listagem de movimentações exibindo dados formatados de NF, fornecedor, evidência e status de estorno.
- **Verificações:**
  - `functions`: 8/8 testes passaram (`npm test`).
  - `app`: 125/125 testes passaram (`flutter test`).
  - `flutter analyze`: 0 issues.
  - DTD `hot_reload`: recarga a quente executada com sucesso no app web ativo.

## Spec Change Log

- 2026-09-17: Criação da especificação, implementação completa dos componentes e validação dos 125 testes.

## Review Triage Log

- 2026-09-17: Revisão inicial e suíte de testes unitários e de widget aprovada sem pendências.
