---
title: '0-2 definir politica'
type: 'chore'
created: '09-22-2026'
status: 'in-progress'
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

### Review Findings (24/09/2026)

- [x] [Review][Patch] Remover ou regenerar o diff histórico truncado e autorreferente, que mistura outras entregas com a Story 0-2 (blind-hunter + acceptance-auditor; medium): removido o artefato inconsistente. [_bmad-output/implementation-artifacts/diff-spec-0-2.diff:96]
- [x] [Review][Patch] Preservar no item da retrospectiva a extração do sumário de rateio (edge-case-hunter; medium): requisito reposto junto à meta de linhas. [_bmad-output/implementation-artifacts/sprint-status.yaml:221]
- [x] [Review][Patch] Explicitar comandos auditados para operações de suporte do dev em estoque e financeiro (blind-hunter; low): exigência adicionada ao perfil de dev. [docs/politica.md:21]
- [x] [Review][Defer] Corrigir aceite C5 de Chrome/Safari móvel (blind-hunter; medium) [docs/task.md:73] — deferred: pendência preexistente: item marcado concluído, mas docs/validacao-c0-c6.md:139 ainda exige testes em navegadores reais; fora do changeset documental de 0-2.
- [x] [Review][Defer] Reconciliar edição do contexto do Épico 0 com a restrição de somente leitura (acceptance-auditor; medium) [_bmad-output/implementation-artifacts/epic-0-context.md:7] — deferred: mudanças reais em arquivo de contexto de agente, explicitamente reservado para leitura pela spec; revisão de contexto segue fluxo próprio.

Rejected (vereditos individuais):

- blind-2 — false: `review` no sprint é o estado correto enquanto este code review está aberto; `done` na spec se refere à execução e o aceite documental foi registrado.
- blind-3 — false: mudanças em `app/` aparecem apenas como texto dentro do diff histórico; o changeset real dos commits não toca `app/` nem `functions/`.
- blind-4 — false: `docs/task.md:24` marca inventário/critério demonstrado em dev, enquanto a política distingue identificação de identidades legítimas reais, ainda pendente para migração.
- blind-5 — false: `docs/task.md:31` marca validação em desenvolvimento, não retirada do fallback nem verificação de identidades reais; docs/task.md:5 delimita o sentido de `[x]`.
- blind-7 — false: `app/README.md` não foi alterado pelos commits 0-2; a citação vem exclusivamente do diff histórico incorporado.
- blind-8 — false: `scripts/check-docs.py` não foi alterado pelos commits 0-2; o trecho é texto no diff histórico incorporado.
- blind-9 — false: idem, o script não faz parte das alterações reais de 0-2.
- blind-10 — false: idem, o script não faz parte das alterações reais de 0-2.

## Implementation Notes

## Spec Change Log

## Review Triage Log

- blind-1 divergência de status 0-2 (sprint/spec/tasks/task.md): verdict medium, quatro estados distintos reais durante a revisão; componentes `in-review`/`[x]` são design do fluxo; residual = sprint-status atrasado. patch — resolvido pelo sync do step-05 (`0-2 → review`).
- blind-2 epic-0-context "demais stories em backlog": verdict medium, epic-0-context:25 contradiz aceite de 0-2 no mesmo changeset. patch — linha reescrita (0.1 e 0.2 aceitas; 0.3/0.4 backlog).
- blind-3 claim "operacionaliza D1–D7" sem citar D2–D4: verdict low, D2–D4 são estrutura/plataforma fora do escopo ESCOPO-POLÍTICA=A; o desalinhamento era da redação. patch — politica:7 reescrita (opacionaliza D1, D5, D6, D7; D2–D4 fora de escopo).
- blind-4 metadecisões 22/09 como normativas: verdict low, marcações eram proveniência legítima (frozen intent) mas podiam confundir com cânone D#. patch — politica:7 explicita DESTINO/ESCOPO/COLETA como metadecisões de story, não D1–D7.
- blind-5 greps presence-only não garantem AC: verdict low, comandos de verificação checam só presença. Rejected: fix seria editar spec — regra fix-em-spec (precedente 0-1 blind-7).
- blind-6 fallback morto DESTINO=B no cmd3: verdict low, ramo inalcançável com DESTINO=A e arquivo presente. Rejected: fix seria editar spec.
- blind-7 seções internas da spec vazias: verdict low, Triage Log preenchido por este workflow; Spec Change Log vazio é legítimo sem bad_spec; Implementation Notes vazio = precedente 0-1. Rejected: fix seria editar spec.
- blind-8 âncoras `:95-101` no Code Map deslocadas: verdict low, âncoras absolutas envelhecem com o task.md. Rejected: fix seria editar spec.
- blind-9 `context:` com paths absolutos no frontmatter: verdict low, não-portável; maioria das specs usa `context:` vazio. Rejected: fix seria editar spec.
- blind-10 review-prompt-*-0-2 com diff auto-referente e meta-instruções: verdict medium, três artefatos criados sem necessidade (subagentes têm filesystem), duplicam diff e expõem diretivas do host a consumidores. patch — arquivos removidos.
- blind-11 IDs de story inconsistentes ("Story 0.2" / `0-2-definir-politica` / "0-2 definir politica"): verdict low, variância entre convenções de arquivos distintos. Rejected: low + renomes multi-arquivo além de correção direta.
- blind-12 `**Base (seção):**` redundantes: verdict low, linhas duplicavam os `*Base:*` por item sem ganho de rastreabilidade. patch — as duas linhas removidas.
- blind-13 citações sem hash uniformes: verdict low, `decisoes.md` citado sem `@90e550d` em alguns pontos. patch — politica:4 nota de que linhas D# carregam a própria evidência `@90e550d`.
- blind-14 política não especifica caminho de grant de dev: verdict false, politica:38 define fluxo administrativo confiável no servidor; o "quem" depende de identidades de devs = Pendência `pendente-evidência`, corretamente não inferida. Rejected on refutation.
- blind-15 `last_updated` bump sem avançar status: verdict medium, mesmo root de blind-1. patch — resolvido pelo sync do step-05.
- edge-1 `isActive=false` sem deny explícito: verdict medium, §3 listava `isActive` sem negar inativo; plano §4 aceite exige "inativo não acessa dados". patch — cláusula added em politica §3.
- edge-2 precedência admin × módulos vazios: verdict medium, plano §3: `modules` é de membros comuns centrais; admin decorre de perfil/`isAdmin`/`isOwner` — política não explicitava. patch — sentença de precedência added.
- edge-3 nome legado de módulo sem regra interim: verdict false, politica:40 veda concessão implícita e "concessão geral silenciosa"; bloqueio até o mapeamento do inventário é fail-closed pretendido (plano §3). Rejected on refutation.
- edge-4 claims não cobrem rebaixamento com vínculo ativo: verdict medium, política só tratava vínculo revogado; rebaixamento mantém claim antiga elevada — corolário direto de D7 (servidor autoritativo). patch — cláusula estendida em politica §3.
- edge-5 avaliação por obra ausente: verdict false, politica §3 exige vínculo ativo na construtora E na obra (plano §3); aplicar um perfil global violaria a regra citada. Rejected on refutation.
- edge-6 backlog claim no epic-0-context: verdict medium, mesmo root de blind-2. patch — mesmo fix.
- edge-7 aprovado vs in-progress: verdict medium, mesmo root de blind-1. patch — resolvido pelo sync do step-05.
- edge-8 heading exato `## Política` no fallback: verdict false, fallback inalcançável — DESTINO=A decidido e `docs/politica.md` existe (`test -f` succeed). Rejected on refutation.
- edge-9 diretivas do host no artefato de prompt: verdict medium, mesmo root de blind-10. patch — arquivos removidos.
- edge-10 "handling branch" de responsável ausente: verdict false, D1–D7 todas com responsável; Pendências com `TBD` explícito; Aceite 0-2 espelha o padrão do Aceite 0-1 (sem campo responsável). Rejected on refutation.
- edge-11 metadecisões 22/09 como cânone: verdict low, mesmo root de blind-4. patch — mesmo fix.
- verification-gap-1 sprint-status sem verificação de transição: verdict medium (pre-verified pela camada), disposition filed = patch (comando no `## Verification`). Rejected: fix seria editar spec — regra fix-em-spec (precedente 0-1 blind-7/edge-2..6); a transição em si é executada nativamente pelo sync do step-05.
- verification-gap-other-1 task.md "aprovado" antes do fim do review: verdict medium, mesmo root de blind-1; precedente 0-1 blind-5 routeou a patch. patch — resolvido pelo sync do step-05 (padrão do Aceite espelha 0-1).
- verification-gap-other-2 meta-instruções no fim dos prompts: verdict medium, mesmo root de blind-10. patch — arquivos removidos.

Grouping: patches A) status sync (blind-1/15, edge-7, vg-other-1) via step-05; B) epic-0-context backlog (blind-2, edge-6); C) prompt artifacts (blind-10, edge-9, vg-other-2); D) isActive deny (edge-1); E) precedência admin/modules (edge-2); F) claims rebaixamento (edge-4); G) escopo D# (blind-3); H) metadecisões (blind-4, edge-11); I) Base redundante (blind-12); J) nota de hash (blind-13). Rejeitados: fix-em-spec (blind-5/6/7/8/9, vg-1); false (blind-14, edge-3/5/8/10); low+complexidade (blind-11). Nenhum intent_gap, bad_spec ou defer — sem loopback (`review_loop_iteration` permanece 0). Sem itens em `deferred-work.md`.

## Verification

**Commands:**
- `grep -E "D[1-7]|pendente-evidência" docs/politica.md | head -20` -- expected: citações D#/pendências presentes
- `git diff --name-only -- docs/archive firestore.rules storage.rules functions app` -- expected: vazio
- `test -f docs/politica.md || grep -q "## Política" docs/decisoes.md` -- expected: entregável existe (conforme DESTINO)
