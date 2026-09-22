---
title: '0-2 definir politica'
type: 'chore'
created: '09-22-2026'
status: 'in-review'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '2eb09d70b0f95a6eaba7c23b9842fbaa7fef2d83'
context: [/Users/usuario/obras/_bmad-output/implementation-artifacts/epic-0-context.md, /Users/usuario/obras/docs/decisoes.md]
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** As decisões D1–D7 estão registradas em `docs/decisoes.md` (0-1), mas não existe um documento de política de acesso e privilégios que as operationalize para quem implementa C1, regras e UI — o Epic 0 continua sem referência autoritativa de escopo de autorização além da matriz literal no plano de correção.

**Approach:** Redigir um documento de política de acesso e privilégios ancorado exclusivamente em D1–D7 e nas fontes já aprovadas (plano de correção §3/§6, implementation_plan §4, data_model §2), sem reabrir o histórico congelado nem inventar evidência para as Pendências.

## Boundaries & Constraints

**Always:**
- Ancorar cada cláusula da política em D1–D7 ou em seção explícita das fontes vigentes de 15/09/2026 (`@90e550d`), com citação de caminho e seção
- Preservar `docs/decisoes.md` intacto (D1–D7 e Pendências de 0-1); 0-2 não edita decisões aprovadas
- Manter Pendências visíveis como `pendente-evidência` (devs legítimos, regras de produção, volume legado) — nunca marcar como definidas
- Reforçar: dev global confirmado; servidor autoritativo para `globalRole`; módulos fail-closed; exceções dev/admin-construtora ao vínculo individual de obra; produção fora do escopo desta aprovação
- Texto em pt-br, UTF-8, alinhado ao vocabulário de papéis do plano §3 (Dev confiável, Admin/proprietário, Admin da obra, Membro comum, Sem autorização)

**Never:**
- Não alterar D1–D7, o cabeçalho de 0-1 nem `docs/archive/`
- Não alterar `firestore.rules`, `storage.rules`, `functions/`, `app/` nem executar deploy/migração
- Não inferir devs legítimos, regras publicadas ou volumes sem evidência
- Não duplicar a matriz literal de 0-4 / plano §3 como se fosse nova decisão
- Não autorizar implantação em produção

**Decisões humanas 22/09/2026:**
- DESTINO=A: criar `docs/politica.md` novo (separar registro 0-1 de política 0-2)
- ESCOPO-POLÍTICA=A: só acesso e privilégios (custo/evidências/retenção ficam na evolução futura)
- COLETA=A: formalizar as 3 Pendências como bloqueios de evidência na política; inventário real continua em 0-3/C0

</frozen-after-approval>

## Code Map

- `docs/decisoes.md` -- somente leitura; D1–D7 + Pendências de 0-1; 0-2 não edita
- `docs/plano-de-correcao-2026-09-15.md` -- fonte: §1 decisões/limites, §3 matriz aprovada, §6 escopo da aprovação
- `docs/implementation_plan.md` -- fonte: §4 autorização proposta (tabela de perfis), §6 critérios
- `docs/data_model.md` -- fonte: §2 autorização/dev global, `globalRole` só servidor, `isActive`/`modules`
- `docs/task.md` -- registrar Aceite 0-2 + Change Log (padrão do Aceite 0-1 em :95-101)
- `docs/politica.md` -- **criar** (se DESTINO=A) ou seção em `decisoes.md` (se B); entregável principal
- `_bmad-output/implementation-artifacts/epic-0-context.md` -- contexto do épico, leitura apenas
- `_bmad-output/implementation-artifacts/spec-0-1-registrar-decisoes.md` -- continuidade 0-1 done; frozen não reabrir
- `firestore.rules` / `storage.rules` / `functions/src/index.ts` / `app/lib/src/common_widgets/access_guard.dart` / `app/lib/src/features/authentication/data/user_repository.dart` -- **não alterar**; citar apenas como estado atual se necessário na política
- `docs/archive/2026-09-15-planejamento-anterior/` -- imutável, consulta apenas

## Tasks & Acceptance

**Execution:**
- [x] `docs/politica.md` (ou seção em `docs/decisoes.md` conforme DESTINO) -- redigir política de acesso e privilégios em pt-br com seções: escopo, papéis e escopos (5 perfis do plano §3), regras de privilégio (dev global, servidor autoritativo, módulos fail-closed, exceções de vínculo), pendências de evidência, limite de produção -- entrega o "definir" do 0-2 sem duplicar 0-4
- [x] `docs/politica.md` -- em cada seção, citar base em D# e/ou `arquivo seção` das fontes 15/09 -- rastreabilidade exigida pelo padrão 0-1
- [x] `docs/task.md` -- adicionar `## Aceite 0-2` com decisão binária + motivo de 1 linha e linha no Change Log -- espelha rastreio do Aceite 0-1

**Acceptance Criteria:**
- Given as fontes vigentes e D1–D7, when a política é criada, then toda cláusula de acesso/privilégio remete a D# ou a seção citada das fontes, sem decisão nova
- Given as Pendências de `docs/decisoes.md`, when a política é revisada, then devs legítimos, regras de produção e volume legado aparecem como pendente-evidência (ou referência conforme COLETA), nunca como resolvidos
- Given os Boundaries, when o changeset é conferido, then `decisoes.md` D1–D7, archive, rules, functions e `app/` permanecem intactos; nenhum deploy/migração

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Verification

**Commands:**
- `grep -E "D[1-7]|pendente-evidência" docs/politica.md | head -20` -- expected: citações D#/pendências presentes
- `git diff --name-only -- docs/archive firestore.rules storage.rules functions app` -- expected: vazio
- `test -f docs/politica.md || grep -q "## Política" docs/decisoes.md` -- expected: entregável existe (conforme DESTINO)
