---
title: 'Estabilizar gestão de vínculos dos épicos 8–10'
type: 'chore'
created: '2026-09-22'
status: 'in-review'
route: 'dispatch'
review_loop_iteration: 0
context: []
baseline_commit: '9592f86'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Docs de backlog/adiamento ainda dizem que C0–C6 “aguardam aprovação” e listam como futuras entregas já validadas; o action item da retro do épico 4 (extração de componentes da chamada de RH) está `open` apesar de extração parcial concluída; não há CI nem README real do app, e gaps de verificação 10.x seguem abertos.

**Approach:** Reconciliar a narrativa dos docs com `docs/validacao-c0-c6.md` (ACEITO em dev) e o sprint status; atualizar o action item da retro 4 para progresso parcial **sem** fechar o item (tela ainda 585 > 500 linhas); criar CI mínimo (analyze/test/npm test) + doc-check leve + README do app; fechar parcialmente os gaps de verificação 10.x (findings 19–24, subconjunto prioritário) e adiar o restante em `deferred-work.md`.

## Boundaries & Constraints

**Always:** Produtos em pt-br; CI só `flutter analyze` + `flutter test` + `functions npm test` (sem emuladores); manter `epic-4-retro-item-1` **open** enquanto `chamada_form_screen.dart` > 500 linhas; não promover Story 0-2 a `done`; não alterar histórico imutável de decisões (D1–D7); não fechar itens de retro inteiros sem evidência total; regressão limitada a subconjunto prioritário dos findings 19–24 + doc-checks.

**Never:** Deploy/publicação; job de emulador/rules no Actions; inventar aprovação de produção; fechar `epic-4-retro-item-1` com tela ≥500; apagar seções ainda verdadeiras de `deferred-work` (ex.: produção não autorizada); grande reescrita de `membros_test.dart` além dos gaps 10.x.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Doc-check roda no CI | `task.md` afirma C0–C6 “aguardam aprovação” | Script falha (exit ≠ 0) | Corrigir narrativa no repositório |
| Doc-check OK | `task.md` coerente com `validacao-c0-c6.md`/`sprint-status` | Exit 0 | N/A |
| Retro 4 status | Tela 585 linhas, widgets parciais extraídos | Item permanece `open` com action atualizado (progresso parcial) | Nunca `done` sem ≤500 |
| Gap 10.x teste novo | `flutter test` na suíte afetada | Testes passam; analyzer limpo | Falha → corrigir teste/código antes do merge |
| CI baseline | PR/push em `main` | Jobs analyze/test/npm test verdes | Se vermelho, bloquear |

</frozen-after-approval>

## Code Map

- `docs/task.md:5` -- frase “C0–C6 aguardam aprovação e permanecem abertos” a reconciliar
- `docs/task.md:16,20-81` -- checkboxes C0–C6 ainda `- [ ]`; narrativa vs `validacao-c0-c6.md:6` ACEITO
- `docs/task.md:83-91` -- “Evolução futura” inclui RH/EPI já entregues (Epic 4/5) -- ajustar sem apagar o que ainda é futuro (produção, etc.)
- `_bmad-output/implementation-artifacts/deferred-work.md:5-7` -- “Correções aguardando aprovação” / “Ainda não autorizados” contradiz `sprint-status.yaml` `correction_plan: approved_by_user`
- `docs/validacao-c0-c6.md` -- fonte ACEITO (dev) para reconciliar
- `_bmad-output/implementation-artifacts/sprint-status.yaml:219-225` -- `epic-4-retro-item-1-modularizar-chamada-form` `status: open` -- atualizar action, manter open
- `app/lib/src/features/rh/presentation/chamada_form_screen.dart` -- 585 linhas; meta retro ≤500; **não** fechar item
- `app/lib/src/features/rh/presentation/widgets/` -- `chamada_invariantes_banner.dart`, `chamada_filtros_header.dart`, `chamada_sticky_bottom_bar.dart` já extraídos (evidência parcial)
- `.github/` -- só `agents/`; **criar** `.github/workflows/ci.yml`
- `app/README.md:1-17` -- template Flutter gen -- **substituir** por docs SIGO
- `docs/implantacao-c0-c6.md:8-12` -- comandos locais a espelhar no README e no CI
- `functions/package.json` -- `engines.node: 20`; scripts `test`, `test:emulators`, `test:rules` (CI usa só `test`)
- `app/pubspec.yaml` / Flutter **3.47.2** stable -- pin no workflow
- `_bmad-output/implementation-artifacts/epic-10-retro-2026-09-22.md:108-113,151` -- findings 19–24 e item `epic-10-tests-fechar-gaps-10x`
- `_bmad-output/planning-artifacts/epics.md` -- AC 9.2/10.3 (atalho Ativar) -- **fora** deste escopo de código (permanece em `epic-10-spec-reconcile-epics`)
- `app/test/features/construtoras/membros_test.dart` -- base existente p/ gaps 10.x (Fake repo, wiring)

## Tasks & Acceptance

**Execution:**
- [x] `docs/task.md` -- reescrever intro C0–C6 (aprovado/validado em dev, produção separada); reconciliar checkboxes/inventário com `validacao-c0-c6.md`; ajustar "Evolução futura" (RH/EPI já entregues) -- narrativa coerente
- [x] `_bmad-output/implementation-artifacts/deferred-work.md` -- seção aprovação: plano aprovado, validação ACEITO em dev, produção segue pendente; não apagar findings adiados legítimos
- [x] `_bmad-output/implementation-artifacts/sprint-status.yaml` -- action item retro-4: anotar extração parcial (banner/filtros/sticky feitos; meta ≤500 pendente); **manter** `status: open`; bump `last_updated`
- [x] `.github/workflows/ci.yml` -- **criar**: checkout; Flutter 3.47.2 + `flutter analyze`/`flutter test` em `app/`; setup Node 20 + `npm ci && npm test` em `functions/`; job `doc-check` roda script; triggers push/PR `main`
- [x] `scripts/check-docs.py` (ou shell equivalente) -- **criar**: falha se `docs/task.md` contiver “aguardam aprovação”/“permanecem abertos” no bloco C0–C6 ou se `deferred-work.md` afirmar C0–C6 “não autorizados”; coerência básica com `validacao-c0-c6.md`
- [x] `app/README.md` -- substituir template: o que é SIGO/app, pré-requisitos, comandos (`flutter analyze`, `flutter test`, ponteiro p/ `docs/implantacao-c0-c6.md` e emuladores)
- [x] `app/test/...` -- fechar **subconjunto prioritário** dos gaps 10.x: **(19)** teste `setCargo` real (offline/permission-denied), **(20)** wiring “Trocar cargo”, **(21)** prefill via overflow -- restante (22–24) → `deferred-work.md` se não couber
- [x] `_bmad-output/implementation-artifacts/deferred-work.md` -- append findings 10.x não fechados (22–24 e o que restar) no formato findings adiados
- [x] `_bmad-output/implementation-artifacts/spec-estabilizar-vinculos-epicos-8-10.md` -- Implementation Notes ao longo do work

**Acceptance Criteria:**
- Given `docs/task.md`/`deferred-work.md` revisados, when someone lê o bloco C0–C6, then não há afirmação de “aguardam aprovação”/“não autorizados” e a validação ACEITO em dev + produção pendente está clara
- Given `chamada_form_screen.dart` com 585 linhas, when olho `sprint-status.yaml`, then `epic-4-retro-item-1` permanece `open` com action que reflete progresso parcial
- Given repositório com `.github/workflows/ci.yml`, when há push/PR em `main`, then jobs de analyze, test, npm test e doc-check executam
- Given doc-check no CI, when `task.md` volta a contradizer a validação, then o job falha
- Given novos testes 10.x prioritários, when `cd app && flutter test`, then suíte passa e `flutter analyze` limpo
- Given `app/README.md`, when um dev novo lê, then encontra comandos reais do projeto (não template Flutter)

## Implementation Notes

- Frontmatter `context:` veio vazio (`[]`); todos os arquivos do Code Map foram carregados na íntegra antes de qualquer edição.
- **`docs/task.md`**: intro reescrita apontando ACEITO em dev + produção separada; checkboxes C0–C6 marcados `[x]` conforme `validacao-c0-c6.md` (exceto C6 "apresentar implantação de produção separadamente", que permanece `[ ]`); inventário "aceite funcional" marcado; em "Evolução futura", RH/EPI movidos para a linha "já entregues (Epics 4/5)" sem apagar os itens ainda futuros; entrada de Change Log 2026-09-22 adicionada.
- **`deferred-work.md`**: seção "Correções aguardando aprovação" renomeada/reescrita como "status" (plano `approved_by_user`, validação ACEITO em dev, produção `not_authorized_by_this_plan`); findings legítimos anteriores (1.8, spec-0-1, 8.3, 9.2) preservados; seção "Implantação" intacta; findings 22–24 da retro 10 anexados no formato `source_spec/summary/evidence`.
- **`sprint-status.yaml`**: só o `action` do `epic-4-retro-item-1-modularizar-chamada-form` foi alterado (progresso parcial: banner/filtros/sticky extraídos; tela 585 > meta 500 → item **mantido `open`**); `last_updated` bumpado para `09-22-2026 18:22`; nenhuma story promovida (0-2 segue `in-progress`).
- **CI (`.github/workflows/ci.yml`)**: 3 jobs independentes (`app`, `functions`, `doc-check`), triggers push/PR em `main`, Flutter pinado em `3.47.2` stable, Node 20, só `flutter analyze` + `flutter test` + `npm test` (sem emuladores/rules). Workflow YAML parseado com sucesso.
- **`scripts/check-docs.py`**: vetos `aguardam aprovação`/`permanecem abertos` em `task.md`, `não autorizados` em `deferred-work.md`, coerência básica (`validacao-c0-c6.md` contém ACEITO; `task.md` referencia a validação). Verificado nos 3 sentidos: estado reconciliado → exit 0; frase vetada reintroduzida em `task.md` → exit 1; em `deferred-work.md` → exit 1; arquivos restaurados → exit 0.
- **Gap 19 (seam deliberado)**: `MembrosRepository` não tinha seam injetável (diferente de `ObraMembersRepository`, citado como padrão no finding 19/9.2). Para testar o `setCargo` **real** (offline/payload/permission-denied) sem Firebase emulado, campos `_firestore`/`_functions` ficaram nullable e foram adicionados `checkConnectivity`/`callSetCargo` opcionais — mesmo molde exato de `ObraMembersRepository`. Comportamento do pré-check offline preservado (plugin indisponível → tenta a chamada); `watch*`/`concederAcesso`/`approveAccessRequest` usam `!` (o provider sempre injeta instâncias reais). Unificação de seams/erros continua deferida em `epic-10-dedup-erros-rotulos-tests`.
- **Gaps 20–21**: wiring do sheet (botão Trocar cargo + `trustedDevProvider` override + prefill do vínculo + opção Proprietário + snackbar `Cargo atualizado.`) e prefill via overflow (`base102` ganhou parâmetro opcional `vinculo` — 1 linha; asserta papel Admin + chips diário/lotes pré-marcados vindo do `ObraMember` real). +5 testes (110 → 115 na suite de membros; 423 no total).
- Fora do footprint, não tocados: `docs/decisoes.md` (D1–D7), `docs/politica.md`, story 0-2, `epics.md` (AC 9.2/10.3 segue em `epic-10-spec-reconcile-epics`), `chamada_form_screen.dart` (585 linhas, sem mudança), seções adiadas legítimas de `deferred-work`.

## Spec Change Log

- 2026-09-22 — Implementação completa das 9 tasks; gap 19 exigiu seam mínimo em `membros_repository.dart` (fora do Code Map, registrado acima); findings 22–24 adiados conforme previsto pela própria task.

## Review Triage Log

- Sem rodada de review adicional — `route: dispatch`, `review_loop_iteration: 0` (spec seguiu direto para implementação).

## Verification

**Commands:**
- `cd app && flutter analyze` -- ✅ `No issues found!` (exit 0)
- `cd app && flutter test` -- ✅ `423 All tests passed!` (baseline + 5 novos 10.x; membros_test 115/115)
- `cd functions && npm ci && npm test` -- ✅ tsc build + 9/9 unit tests pass (exit 0)
- `python3 scripts/check-docs.py` -- ✅ exit 0 no estado reconciliado; exit 1 ao reintroduzir “aguardam aprovação”/“permanecem abertos” em `task.md`; exit 1 ao reintroduzir “não autorizados” em `deferred-work.md`
- `git diff --stat` -- ✅ apenas arquivos do footprint do spec (+ `membros_repository.dart` justificado no Implementation Notes)

**Manual checks (if no CLI):**
- ✅ `sprint-status.yaml`: item retro-4 ainda `status: open` com action de progresso parcial; `last_updated` bumpado; YAML parse OK (ruby -ryaml)
- ✅ Workflow YAML parse válido (`jobs: app, functions, doc-check`)
- ✅ `chamada_form_screen.dart` = 585 linhas (item retro-4 permanece open)
- ✅ Story `0-2-definir-politica` permanece `in-progress` (não promovida a `done`)
- ✅ `grep` de frases vetadas em `task.md`/`deferred-work.md`: nenhuma ocorrência
