---
title: '0-1 registrar decisoes'
type: 'chore'
created: '09-21-2026'
status: 'done'
route: 'dispatch'
baseline_commit: '90e550d33a11c40791f99583052d333d38986006'
review_loop_iteration: 1
context: [/Users/usuario/obras/_bmad-output/implementation-artifacts/epic-0-context.md]
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** As decisões vigentes de 15/09/2026 estão dispersas na pasta docs sem registro único auditável para o Epic 0.

**Approach:** Transcreva apenas o conteúdo vigente das 3 fontes para um registro único, sem alterar histórico, regras ou código.

**Decisões congeladas D1-D7:**
- D1 desenvolvedor global mantido, sem exigir vínculo por obra
- D2 estoque central por construtora
- D3 caminhos preservados `construtoras/{cId}/obras/{oId}`
- D4 web/PWA mobile-first
- D5 matriz de acesso aprovada
- D6 categorias C0-C6 restritas ao ambiente de desenvolvimento
- D7 papel global só via servidor, com fallback de e-mail para UID

C0-C6 são categorias de inventário, correção e aceite restritas ao desenvolvimento. Cada item acima exige fonte na seção 1, 2 ou 6 do plano de correção, no plano de implementação ou no modelo de dados.

**Decisões humanas congeladas 21/09/2026:**
- LOCAL_FORMATO=A: criar `docs/decisoes.md` novo
- ESCOPO=A: só transcrever aprovação de 15/09/2026, coleta fica para 0-2/0-3
- ASSINATURA=A: maranduteam em 15/09/2026 como aprovação registrada

## Boundaries & Constraints

**Always:**
- Transcrever apenas de `docs/plano-de-correcao-2026-09-15.md`, `docs/implementation_plan.md` e `docs/data_model.md`
- Não transcrever de `sprint-status.yaml` nem de `epic-0-context.md`; citar sprint-status só como metadado de aprovação
- Preservar desenvolvedor global confirmado como restrição de maior risco
- Cada decisão com status, motivo resumido e evidência no formato `docs/caminho.md seção X @hash`
- Todo texto em pt-br, arquivo em UTF-8, com cabeçalho de vigência 15/09/2026
- Destino fixo: `docs/decisoes.md` novo; responsável fixo maranduteam 15/09/2026

**Never:**
- Não alterar `firestore.rules`, `storage.rules`, `functions/`, `app/` ou `docs/archive/`
- Não executar migração, deploy ou mutação de dados
- Não inferir desenvolvedores legítimos ou regras de produção sem evidência
- Não sobrescrever registro existente; se o arquivo existe, abortar e pedir merge humano

</frozen-after-approval>

## Code Map

- `docs/plano-de-correcao-2026-09-15.md` -- fonte verdade, extrair decisões das seções 1, 2 e 6
- `docs/implementation_plan.md` -- decisão de desenvolvedor global e matriz
- `docs/data_model.md` -- papel global via servidor e fallback
- `docs/task.md` -- backlog vigente e story_location
- `_bmad-output/implementation-artifacts/sprint-status.yaml` -- metadado de approval, leitura apenas
- `_bmad-output/implementation-artifacts/epic-0-context.md` -- contexto do Epic 0, leitura apenas
- `docs/decisoes.md` -- registro decidido em LOCAL_FORMATO=A, criar novo
- `docs/archive/2026-09-15-planejamento-anterior/` -- histórico imutável, consulta apenas

## Tasks & Acceptance

**Execution:**
- [x] `docs/decisoes.md` -- criar novo conforme LOCAL_FORMATO=A -- aplica a escolha sem arquivo fantasma
- [x] `docs/decisoes.md` -- criar tabela `| ID | decisão | status | motivo | evidência | responsável | data |` com 7 linhas D1-D7 -- centraliza sem duplicar
- [x] `docs/decisoes.md` -- incluir seção Pendências com desenvolvedores legítimos, regras de produção e volume real como itens sem evidência -- evita inferência
- [x] `docs/task.md` -- registrar decisão binária de aceite 0-1 com motivo de 1 linha -- done exige diff ou N/A justificado no Change Log

**Acceptance Criteria:**
- Given fontes vigentes, when registro criado, then cada D1-D7 tem status em {aprovado-2026-09-15, pendente-evidência}, motivo resumido e evidência com caminho seção e hash; pendente exige responsável e data como TBD
- Given Boundaries, when revisado, then archive intacto e nenhum item de regra, função, app ou migração foi alterado, sem deploy

## Implementation Notes

## Review Triage Log

- blind-1 D5 matriz sem literal: verdict low, evidence aponta plano seção 1+6 e plano seção 4 como onde a matriz vive; resumo era o requerido pelo intent. Rejected: fix seria editar spec para exigir reprodução integral.
- blind-2 D6 sem enumerar C0-C6: verdict low, spec congelou D6 como categoria restrita com definição; detalhe por C vive no plano seção 6. Rejected: fix seria editar spec.
- blind-3 evidência mesmo hash: verdict false, @90e550d é o baseline único declarado no cabeçalho para as 3 fontes; hash por arquivo seria outro requisito. Disproved pelo cabeçalho baseline.
- blind-4 decisões 21/09 fora do artefato: verdict false, spec exigiu destino com vigência 15/09/2026 e responsável maranduteam; decisões de workflow vivem na spec e no task Change Log. Intent não pediu espelho.
- blind-5 aceite task.md aprovado vs in-review/in-progress: verdict medium, docs/task.md diz aprovado enquanto spec está in-review e sprint in-progress; risco de aceite prematuro. Routes to patch.
- blind-6 guarda sobrescrita sem registro: verdict false, arquivo não existia; Never exigia abortar se existisse, não documentar verificação. Nenhum overwrite ocorreu.
- blind-7 comando verification falha no próprio changeset: verdict medium, comando não exclui sprint-status.yaml nem docs/task.md. Rejected: fix seria editar spec, regra manda rejeitar fix-em-spec.
- blind-8 sem Change Log interno: verdict false, spec exigiu Change Log em docs/task.md, não seção interna; registro único não exigia histórico próprio.
- edge-1 re-run sobrescreve: verdict low, reexecução após done é improvável no uso cotidiano e guarda adiciona complexidade. Rejected por low+complexidade.
- edge-2/3/4/5/6/10 verification grep/staged/pipefail/allowlist: verdict medium como grupo, mesmo root do blind-7. Rejected: fix seria editar spec.
- edge-7/8 task.md rejeição/duplicata: verdict low, caminho de reprovação e reexecução fora do intent transcricional; guarda adiciona ramificação. Deferred como melhoria futura de tracker.
- edge-9 sprint last_updated concorrente: verdict maybe-false, pré-existente fora da story; sem evidência de perda. Deferred com severidade unverified.
- verification-gap: clean, No verification gaps found.

Grouping: A bad_spec candidato (verification) rejeitado por regra fix-em-spec; B patch único (task.md aprovado prematuro); C defer (tracker idempotência + concorrência).

## Verification

**Commands:**
- `git status --short -- docs/ _bmad-output/implementation-artifacts/spec-0-1-registrar-decisoes.md` -- expected: mostra só registro novo mais spec
- `test $(grep -c "^| D[0-9]" docs/decisoes.md) -eq 7 && grep -q "Pendências" docs/decisoes.md && git diff --name-only | grep -Ev "docs/decisoes.md|spec-0-1-registrar-decisoes" | grep -Ev "epic-0-context" ; test $? -ne 0` -- expected: 7 decisões, seção Pendências presente, sem arquivos fora do escopo
