---
title: 'Estabilizar gestão de vínculos dos épicos 8–10'
type: 'chore'
created: '2026-09-22'
status: 'done'
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
- **`sprint-status.yaml`**: `action` do `epic-4-retro-item-1-modularizar-chamada-form` atualizado (progresso parcial; tela 585 > meta 500 → item **mantido `open`**); `last_updated` bumpado; item `epic-10-retro-item-28` anotando fechamento parcial 19–21 (review). Story 0-2 **não** foi promovida a `done` por este spec (valor atual `review`, alterado pelo commit paralelo `3435106`, fora do footprint intencional).
- **CI (`.github/workflows/ci.yml`)**: 3 jobs independentes (`app`, `functions`, `doc-check`), triggers push/PR em `main`, Flutter pinado em `3.47.2` stable, Node 20, só `flutter analyze` + `flutter test` + `npm test` (sem emuladores/rules). Workflow YAML parseado com sucesso.
- **`scripts/check-docs.py`**: vetos `aguardam aprovação`/`permanecem abertos` em `task.md`, `não autorizados` em `deferred-work.md`, coerência básica (`validacao-c0-c6.md` contém ACEITO; `task.md` referencia a validação). Verificado nos 3 sentidos: estado reconciliado → exit 0; frase vetada reintroduzida em `task.md` → exit 1; em `deferred-work.md` → exit 1; arquivos restaurados → exit 0.
- **Gap 19 (seam deliberado)**: `MembrosRepository` não tinha seam injetável (diferente de `ObraMembersRepository`, citado como padrão no finding 19/9.2). Para testar o `setCargo` **real** (offline/payload/permission-denied) sem Firebase emulado, campos `_firestore`/`_functions` ficaram nullable e foram adicionados `checkConnectivity`/`callSetCargo` opcionais — mesmo molde exato de `ObraMembersRepository`. Comportamento do pré-check offline preservado (plugin indisponível → tenta a chamada); `watch*`/`concederAcesso`/`approveAccessRequest` usam `!` (o provider sempre injeta instâncias reais). Unificação de seams/erros continua deferida em `epic-10-dedup-erros-rotulos-tests`.
- **Gaps 20–21**: wiring do sheet (botão Trocar cargo + `trustedDevProvider` override + prefill do vínculo + opção Proprietário + snackbar `Cargo atualizado.`) e prefill via overflow (`base102` ganhou parâmetro opcional `vinculo` — 1 linha; asserta papel Admin + chips diário/lotes pré-marcados vindo do `ObraMember` real). +5 testes (110 → 115 na suite de membros; 423 no total).
- Fora do footprint intencional, não tocados por este spec: `docs/decisoes.md` (D1–D7), `epics.md` (AC 9.2/10.3 segue em `epic-10-spec-reconcile-epics`), `chamada_form_screen.dart` (585 linhas, sem mudança), seções adiadas legítimas de `deferred-work`. (`docs/politica.md` e artefatos 0-2 mudaram no commit paralelo `3435106`, após o baseline `9592f86`.)

## Spec Change Log

- 2026-09-22 — Implementação completa das 9 tasks; gap 19 exigiu seam mínimo em `membros_repository.dart` (fora do Code Map, registrado acima); findings 22–24 adiados conforme previsto pela própria task.

## Review Triage Log

Rodada 1 (`review_loop_iteration: 0`) — camadas: blind-hunter, edge-case-hunter, verification-gap.

| # | Finding | Verdict | Evidência | Rota |
|---|---------|---------|-----------|------|
| 1 | BH1/EH1: `_firestore`/`_functions` nullable + `!` pode estourar null-check | `false` | Provider sempre injeta instâncias reais (`membros_repository.dart:167-171`); null só em testes com seam `callSetCargo`; mesmo molde de `ObraMembersRepository`; caminho de produção não alcança deref nulo | reject |
| 2 | BH2: `// ignore: prefer_initializing_formals` esconde design awkward | `false` | Sem outcome concreto; copia padrão já estabelecido em `obra_members_repository.dart:42` | reject |
| 3 | BH3/VG2: branch `catch` de `_temConectividade` (plugin indisponível → `return true`) sem teste | `medium` | Nenhum teste injeta `checkConnectivity` que lança; inverter `return true`→`false` não falha suíte; Implementation Notes afirmam comportamento preservado | **patch** |
| 4 | BH4: caminho real `_functions!.httpsCallable('setConstrutoraRole')` não exercitado (só seam) | `low` | Payload/exceções cobertos via seam; binding do nome exige mock/emulador (fora do Always “sem emuladores”); fix não é correção direta; dano no dia a dia improvável | reject |
| 5 | BH5/EH3: veto `"não autorizados"` em qualquer lugar de `deferred-work.md`, não só no bloco C0–C6 | `low` | Spec exige “afirmar C0–C6”; texto legítimo de produção usa “autorizada” (feminino, não vetado); falso positivo só futuro; correção direta (escopo à seção) | **patch** |
| 6 | BH6/EH5/EH7: AC “volta a contradizar” vs match exato de frases; evasão por acento/sinônimo | `medium` | AC (`:74`) promete falha ampla; script só literais do task/matrix; correção direta no script (fold/variantes), não edit de spec | **patch** |
| 7 | EH4: status “NÃO ACEITO” em `validacao-c0-c6.md` passa no check (`"aceito" in "não aceito"` → true) | `medium` | Verificado em Python; regressão de status não derruba job | **patch** |
| 8 | EH6: nota de inventário `[x]` = “código encontrado, não aceite de produção” do baseline não reestabelecida no mesmo lugar | `low` | Linha 5/16 reconstroem parcialmente; resíduo na seção Inventário; fix = uma linha | **patch** |
| 9 | VG1/BH21: `check-docs.py` sem teste automatizado (só execução manual/no job) | `medium` | Gap de regressão pré-verificado; grep/glob sem `test_*.py`; AC depende do job | **patch** |
| 10 | BH7: docstring/script promete coerência com `sprint-status` mas nunca lê o arquivo | `false` | Docstring não cita sprint-status; task `:64` exige só coerência com `validacao-c0-c6.md`; linha OK da matrix descreve estado do repo, não leitura obrigatória | reject |
| 11 | BH8: pin `3.47.2` duplicado em CI e README sem fonte única | `low` | Drift teórico; fix exige fonte única (não correção direta); bump de versão raro no dia a dia | reject |
| 12 | BH9: CI sem `permissions: contents: read` e sem `timeout-minutes` | `low` | Hardening ausente; fix = chaves YAML diretas | **patch** |
| 13 | BH10: Actions só por tag major, sem SHA | `low` | Supply-chain; fix = pin de SHA (não direto/casual); ataque no dia a dia improvável | reject |
| 14 | BH11: CI sem `dart format --set-exit-if-changed` | `low` | Boundaries: “CI só `flutter analyze` + `flutter test` + `functions npm test`” — intent exclui format gate | reject (out of scope) |
| 15 | BH12: frontmatter `context: []` vs nota “todos os arquivos carregados” | `false` | Mecanismos distintos; carregar no contexto da sessão não exige preencher `context:` | reject |
| 16 | BH13: `status: in-review` + Change Log “completa” + Triage “sem review” | `false` | Estado transitório correto do step-04; Triage reescrito nesta rodada | reject |
| 17 | BH14: item `epic-10-retro-item-28-fechar-gaps…` sem anotar fechamento parcial 19–21 | `medium` | Action ainda lista 19–24 inteiros como a fechar; risco de retrabalho | **patch** |
| 18 | BH15: teste gap-21 (prefill overflow, `membros_test.dart:2957`) sem `physicalSize`, ao contrário do gap-20 (`:3315`) | `low` | Harness inconsistente; suíte passa hoje; fix = 2 linhas | **patch** |
| 19 | BH16: `find.text('Operário').last` depende de ordem | `false` | Padrão comum p/ dropdown ambíguo; sem outcome demonstrado; teste verde | reject |
| 20 | BH17: gap-20 sem caso `isDev=false` → `Proprietário` ausente | `false` | Caso negativo já existe no mesmo dialog em `membros_test.dart:3111-3118` | reject |
| 21 | BH18: findings 23/24 “dupla escrituração” em deferred | `false` | Campo `evidence` cruza itens open related; não é registro duplicado do finding | reject |
| 22 | BH19: matrix I/O não cita “permanecem abertos” | `low` | Matrix congelada; task `:64` (não congelada) já lista as duas frases e guiou o script; fix exigiria editar spec | reject |
| 23 | BH20: “para esses módulos” ambíguo após mover RH/EPI (`task.md:93`) | `low` | Prosa ambígua; fix = reapontar explicitamente | **patch** |
| 24 | EH2: `_checkConnectividade()` sem `.timeout` pode pendurar `setCargo` | `medium` | Outcome real se platform channel não completar; comportamento pré-existente preservado na extração; mesma classe do finding 9.2 já adiado | **defer** |

**Sem** `intent_gap` e **sem** `bad_spec` — processados `patch` (auto-fix) e `defer`.

## Verification

**Commands:**
- `cd app && flutter analyze` -- ✅ `No issues found!` (exit 0)
- `cd app && flutter test` -- ✅ `424 All tests passed!` (base + testes 10.x + teste de plugin de conectividade indisponível)
- `cd functions && npm ci && npm test` -- ✅ tsc build + 9/9 unit tests pass (exit 0)
- `python3 scripts/check-docs.py` -- ✅ exit 0 no estado reconciliado
- `python3 scripts/check-docs.py --self-test` -- ✅ exit 0; negativos task/validacao/deferred todos exit 1 isoladamente
- `git diff 9592f86 --stat` -- ✅ footprint do spec (+ arquivos 0-2 do commit paralelo `3435106` entre baseline e HEAD)

**Manual checks (if no CLI):**
- ✅ `sprint-status.yaml`: item retro-4 `status: open` com action de progresso parcial; item epic-10-28 anota 19–21 fechados e 22–24 abertos
- ✅ Workflow YAML com `permissions: contents: read`, `timeout-minutes` e passo `--self-test`
- ✅ `chamada_form_screen.dart` = 585 linhas (item retro-4 permanece open)
- ✅ Story `0-2-definir-politica` **não** está `done` (constraint); valor atual `review` (commit paralelo `3435106`, não promovido a `done` por este spec)
- ✅ Frases vetadas ausentes de `task.md`/`deferred-work.md`; variantes sem acento e “aguardando aprovação” também caem no veto
- ✅ Review triage: 24 findings; sem `intent_gap`/`bad_spec`; 10 patches aplicados; 1 defer (`_temConectividade` timeout)
