---
title: 'Story 13.3 - Ramificação Específica de Etapas por Lote'
type: 'feature'
created: '2026-09-25'
status: 'in-review'
baseline_commit: '9668da9'
route: 'dispatch'
context: ['_bmad-output/implementation-artifacts/epic-13-context.md', '_bmad-output/specs/spec-navegacao-loteamento-etapa/hierarquia-etapas.md']
review_loop_iteration: 1
---

# Story 13.3 - Ramificação Específica de Etapas por Lote

## Intent
Garantir que toda inicialização de lote siga uma hierarquia fixa de etapas (Muro, Cinza/1ª, Cinza/2ª, Cinza/3ª, Branca/Acabamento), tanto para novos lotes (automaticamente) quanto para lotes legados (manualmente, por admins).

## Context & Scope
- **O que fazer:** Criar as 5 etapas padrão atomicamente junto com a criação do Lote, ou via botão para Lotes antigos.
- **Limites:** Usar ids determinísticos (`${loteId}_${tipo.name}`) para evitar duplicidade; usar uma única transação/WriteBatch para criar o Lote e as Etapas.

## Architecture & Code Map
- `app/lib/src/features/lotes/data/lote_repository.dart` -> Modificar `createLote` (ou criar `createLoteComEtapas`) para usar batch e garantir atomicidade.
- `app/lib/src/features/etapas/data/etapa_repository.dart` -> `createDefaultEtapas` deve usar IDs determinísticos e aceitar um batch externo opcional.
- `app/lib/src/features/lotes/presentation/add_lote_screen.dart` -> Chamar a função atômica e remover retry que causa duplicatas.
- `app/lib/src/features/etapas/presentation/etapas_list_screen.dart` -> Usar `currentPermissionsProvider` para ler a permissão `isAdmin`. Tratar erro e loading adequadamente.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/etapas/data/etapa_repository.dart` -- Atualizar `createDefaultEtapas` para usar IDs determinísticos (`${loteId}_${tipo.name}`) e opcionalmente receber um `WriteBatch` para ser executado de forma atômica com a criação do Lote.
- [x] `app/lib/src/features/lotes/data/lote_repository.dart` -- Implementar criação de Lote atômica junto com etapas (ex: `createLoteComEtapas`), coordenando com `EtapaRepository`.
- [x] `app/lib/src/features/lotes/presentation/add_lote_screen.dart` -- Atualizar `_submit` para invocar a nova função atômica. Tratar retry corretamente. 
- [x] `app/lib/src/features/etapas/presentation/etapas_list_screen.dart` -- Derivar admin de `currentPermissionsProvider`. Em `_inicializarEtapas`, adicionar `.timeout()`, tratar exceções (não vazar erro puro) e melhorar UX do loading (usar Row com "Inicializando...").
- [x] `app/test/obras_lotes_crud_test.dart` -- Adicionar override de `etapaRepositoryProvider`.
- [x] `app/test/src/features/etapas/presentation/etapas_list_screen_test.dart` -- Adicionar testes para os estados e chamada de inicialização.

**Acceptance Criteria:**
- Given um Admin, when criar lote, then lote e 5 etapas são criados atomicamente.
- Given lote criado, the etapas têm id determinístico.

## Spec Change Log
- **Review Loop 1 (bad_spec)**: 
  - *Finding*: `createLote` e `createDefaultEtapas` não eram atômicos (spec prescrevia dois awaits separados). IDs das etapas eram aleatórios.
  - *Amended*: Foi especificado uso de IDs determinísticos e execução atômica via `WriteBatch` abrangendo Lote e Etapas.
  - *KEEP*: Manter a UX do botão manual para lotes legados (`ConsumerStatefulWidget` com estado de loading) e captura genérica de erros no SnackBar, porém sem vazar detalhes técnicos (`$e`).

## Review Triage Log
- **high** — createLote e createDefaultEtapas não são atômicos, ferindo a boundary. (Group A, bad_spec)
- **high** — createDefaultEtapas usa IDs aleatórios e permite duplicatas no retry. (Group B, bad_spec)
- **medium** — _inicializarEtapas sem timeout. (Group C, patch)
- **medium** — isAdmin implementado duplicado usando construtoraPermissionProvider em vez de currentPermissionsProvider. (Group D, bad_spec)
- **high** — Testes faltando para createDefaultEtapas e erro no teste existente. (Group E, patch)
- **low** — SnackBar vaza erro. (Group F, patch)
- **low** — UX do spinner pobre na inicialização de lotes legados. (Group G, patch)
- **low** — Formatação da linha do baseRoute. (Group H, patch)
- **high** — Escalada de privilégio client-side no `user_repository.dart` para e-mails contendo "dev". (Group I, patch)
- **medium** — `patch_etapas_test.py` commitado acidentalmente. (Group J, patch)
- **high** — `createDefaultEtapas` usa `set` sem merge, apagando etapas existentes. (Group K, patch)
- **high** — Faltam testes para a coordenação atômica de lotes e etapas. (Group L, patch)
- **medium** — `etapas_list_screen.dart` usa provider divergente da spec. (Group M, patch)
- **low** — Vazamento genérico de erro em telas legadas. (Group N, defer)
- **medium** — `user_repository.dart` logando dados sensíveis em produção. (Group I, patch)
- **high** — `sigo_top_bar.dart` navega para rota incorreta `/obra/$newLoteamentoId`. (Group O, patch)
- **medium** — `createDefaultEtapas` tem contrato ambíguo para `WriteBatch`. (Group K, patch)
- **low** — `createLote` é código morto em `LoteRepository`. (Group P, patch)
- **medium** — `construtora_routes.dart` retorna `SizedBox.shrink()`. (Group Q, patch)
- **low** — Timeout de 15s duplicado e mensagem contraditória. (Group R, patch)
- **low** — Diff com formatação dart format massiva. (Group S, defer)
- **low** — Supressões de lint injustificadas mantidas. (Group T, patch)
