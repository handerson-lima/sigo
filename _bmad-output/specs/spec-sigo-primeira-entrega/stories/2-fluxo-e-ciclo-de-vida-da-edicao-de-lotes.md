---
title: 'Fluxo e Ciclo de Vida da Edição de Lotes'
type: 'feature'
created: '2026-09-23'
status: 'in-review'
review_loop_iteration: 0
followup_review_recommended: false
baseline_revision: 'e80fe1e5befb6e65072c557973b3b891ea46f549'
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** A criação/edição de lotes (AddLoteScreen e provedores associados) atualmente considera o dado salvo assim que o repositório resolve a escrita (que no Firestore pode ser apenas no cache local), e não gerencia falhas de comunicação ou respostas incertas, levando a confirmações falsas.

**Approach:** Atualizar o `lote_repository.dart` para expor uma forma de obter um "recibo real" do servidor (ex: aguardar `hasPendingWrites == false`) e atualizar o `add_lote_screen.dart` para gerenciar estados claros (não enviado, timeout/incerto, salvo) sem limpar o formulário se o resultado for incerto.

## Boundaries & Constraints

**Always:** Manter a persistência local ativa e gerenciar os timeouts na camada de controle/UI; se a resposta não chegar em tempo hábil (ex: 15s), avisar o usuário que o estado é incerto, mas manter os dados no formulário/sessão. Fixar o UUID do Lote na primeira tentativa e reusá-lo em caso de repetição.

**Never:** Não introduzir transação, rollback ou fila offline personalizada. Não inferir sucesso apenas a partir da leitura imediata de cache local do Firestore. Não descartar a digitação do usuário se o envio der timeout.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Envio de Lote Offline | Rede desconectada, timeout disparado | Mostra aviso de resultado incerto, mantém UUID e dados | Snackbar de timeout |
| Envio Lote Online | Conectado, Firestore responde rápido | Mostra sucesso, limpa/fecha o form, avisa sucesso | N/A |

</intent-contract>

## Code Map

- `app/lib/src/features/lotes/data/lote_repository.dart` -- RELEVANCE: Implementar método auxiliar ou alterar `createLote` para aguardar a confirmação remota (via snapshots `!metadata.hasPendingWrites`).
- `app/lib/src/features/lotes/presentation/add_lote_screen.dart` -- RELEVANCE: Adicionar timer/timeout no `_submit`, impedir repetição do UUID no retry, tratar timeout e feedback visual.

## Tasks & Acceptance

**Execution:**
- `app/lib/src/features/lotes/data/lote_repository.dart` -- Atualizar `createLote` para retornar o resultado de forma que possamos aguardar o sincronismo real (por exemplo, monitorando os snapshots do documento recém criado até que a propriedade `metadata.hasPendingWrites` seja falsa) ou criar um método específico de sync. -- Garante que a UI consiga aguardar o "recibo real".
- `app/lib/src/features/lotes/presentation/add_lote_screen.dart` -- Mover a geração do Uuid para o estado do formulário (`_loteId` persistente) e usar `.timeout(...)` na chamada ao repositório. Em caso de timeout ou erro, não dar pop no formulário, mostrando Snackbar. -- Cumpre AD-5, mantendo o UUID fixo e nunca perdendo o progresso do usuário.

**Acceptance Criteria:**
- Given um lote preenchido na AddLoteScreen, when o botão de criar for pressionado sem rede e o tempo expirar, then o formulário permanece aberto com aviso de erro/timeout.
- Given uma tentativa de repetição do envio de lote que falhou/deu timeout antes, when o usuário clica novamente, then o mesmo UUID é enviado ao repositório.

## Design Notes

A checagem de recibo real pode ser feita aguardando a sincronização:
```dart
await _lotesRef(...).doc(lote.id).set(lote);
await _lotesRef(...).doc(lote.id).snapshots().firstWhere((snap) => !snap.metadata.hasPendingWrites).timeout(const Duration(seconds: 15));
```

## Verification

**Commands:**
- `cd app && flutter analyze` -- expected: Sem erros de lint após modificar repositório e UI.

## Auto Run Result

Status: blocked
Blocking condition: no subagents
