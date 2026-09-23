---
title: 'Corrigir chave indexes duplicada em firestore.indexes.json'
type: 'bugfix'
created: '2026-09-22'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `firestore.indexes.json` contém a chave `"indexes"` duas vezes (linhas 2 e 54). Parsers JSON descartam silenciosamente o primeiro array, então os índices compostos de `construtora_members` e `members` (isActive+userId, COLLECTION_GROUP) — usados por `construtora_repository.dart` e `obra_repository.dart` — são perdidos e provavelmente não existem em produção.

**Approach:** Mesclar os dois arrays `"indexes"` em um único array (unindo os índices de `construtora_members`, `members`, `access_requests` e `notifications`), mantendo `fieldOverrides` intacto, garantindo JSON válido com uma única ocorrência de cada chave de topo.

</frozen-after-approval>

## Implementation Notes

- Mesclados os dois arrays `"indexes"` em um único array de 5 entradas (`construtora_members` CG, `members` CG, `access_requests` ×2, `notifications`), preservando `fieldOverrides` (2 entradas) intacto.
- Verificado com `python3 json.load`: chaves de topo únicas (`indexes`, `fieldOverrides`), 5 índices, 2 overrides — nenhum índice do parser antigo se perdeu.
- Normalizada a formatação (todas as entradas multi-linha) e a ordem de `fieldOverrides` para coincidir com a de `indexes`.
- Arquivo alterado: `firestore.indexes.json`.

## Review Triage Log

- CI não valida `firestore.indexes.json` — **defer** (medium): bug pré-existente, não causado por esta mudança; validação de chaves duplicadas preveniria recorrência.
- Spec untracked / Implementation Notes vazia — **patch**: notas preenchidas; spec será commitada.
- `fieldOverrides` de `userId` substitui config COLLECTION/DESCENDING — **defer** (medium): pré-existente desde o commit `c456de9`; requer decisão sobre export do console.
- Deploy/reconciliação com produção (`firebase firestore:indexes`) — **defer** (medium): ação externa irreversível fora do footprint; usuário deve rodar deploy/preview manualmente.
- Índices ausentes para `chamadas` (construtoraId+date) — **defer** (medium): gap pré-existente, não causado pela mudança.
- Índices ausentes para `movimentacoes` (obraId, obraId+loteId) — **defer** (medium): gap pré-existente; erro engolido em `custos_360_repository.dart`.
- Índice composto ausente para fornecedores (status+razaoSocial) — **defer** (medium): gap pré-existente.
- Índice `notifications` (read+createdAt) sem query correspondente — **false**: declarado intencionalmente pela spec de onboarding (`spec-onboarding-solicitacao-acesso.md`).
- Falta documentação consulta→índice — **rejected low**: comentário agregaria mais que uma correção simples e raramente afetaria uso normal.
- `firebase.test.json` não declara `firestore.indexes` — **defer** (low): config pré-existente de testes.
- Teste de integração não detectaria índice errado/ausente — **defer** (low): melhoria de teste futura.
- Ordem dos campos `isActive, userId` vs ordem dos filtros — **false**: consulta é equality-only; ordem é inofensiva hoje.
- Formatação inconsistente das entradas — **patch**: normalizada na reescrita.
- `users_list_screen.dart` filtra `isActive` no cliente — **defer** (low): otimização de leitura pré-existente, fora do escopo.

