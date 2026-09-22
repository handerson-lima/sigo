Conduct a review of CONTENT.
Look for what's missing, not only what's wrong.
Compute your finding floor N from the diff file's size: N = min(floor(sqrt(kB) + 1), 10), where kB is the file's size in kilobytes. State the arithmetic in one line, then find at least N issues to fix or improve.
Output a Markdown list of findings only — no severity, priority, or ranking.
If the content is empty, stop and say so.
If you have zero findings, re-check and keep thinking; do not stop with an empty list.

CONTENT: the unified diff inlined below — it is the content under review.

diff --git a/_bmad-output/implementation-artifacts/epic-0-context.md b/_bmad-output/implementation-artifacts/epic-0-context.md
index 43dcbab..dd1ec53 100644
--- a/_bmad-output/implementation-artifacts/epic-0-context.md
+++ b/_bmad-output/implementation-artifacts/epic-0-context.md
@@ -4,7 +4,7 @@
 
 ## Goal
 
-Estabelecer a base de governança do SIGO antes da execução: registrar decisões vigentes, definir política, aprovar termos e mapear matriz de acesso. Sem arquivo formal de epics em planning-artifacts; objetivo inferido de sprint-status.yaml e docs/task.md. Lacuna: sem PRD/arquitetura dedicados ao Epic 0.
+Estabelecer a base de governança do SIGO antes da estabilização C0–C6 e das demais epics: registrar as decisões vigentes de forma centralizada e auditável, definir a política de acesso e privilégios, obter as aprovações formais dos termos e consolidar a matriz de acesso que orienta Rules, Functions e UI. Sem este epic, a execução técnica carece de referência autoritativa de escopo e autorização; a matriz e as políticas aqui firmadas alimentam diretamente o pacote de segurança (C1) e a autorização de vínculos dos epics seguintes. Nota de lacuna: o arquivo de epics formalizado cobre apenas Epics 8–10; Goal e Stories deste epic derivam do sprint status, do backlog vigente (docs/task.md) e do registro de decisões — sem PRD ou spine de arquitetura dedicados ao Epic 0.
 
 ## Stories
 
@@ -12,3 +12,30 @@ Estabelecer a base de governança do SIGO antes da execução: registrar decisõ
 - Story 0.2: definir-politica
 - Story 0.3: aprovar-termos
 - Story 0.4: matriz-acesso
+
+## Requirements & Constraints
+
+- As decisões aprovadas (D1–D7) ficam centralizadas num único registro vigente, sem duplicar nem alterar histórico; o arquivo de planejamento anterior permanece imutável e só de consulta.
+- Todo registro de decisão exige: status, motivo, evidência rastreável até o baseline de referência, responsável e data. Pendências sem evidência ficam explícitas como tais — nunca inferir conclusão por presença de código ou tela.
+- Restrição de maior risco: desenvolvedor global é confirmado e preservado, sem exigir vínculo por obra para administração global; identidades de devs legítimos não podem ser inferidas e autoatribuições de `globalRole=dev` não são confiáveis.
+- A matriz de acesso define papéis (dev confiável, admin/proprietário da construtora, admin da obra, membro comum, sem autorização) com escopos explícitos sobre usuários/vínculos, dados de obra, estoque, financeiro e arquivos; permissão de obra regular exige vínculo ativo na construtora e na obra, com dev e admin/proprietário da construtora como exceções.
+- Escopo da aprovação vigente: implementação e validação de C0–C6 e da matriz em ambiente de desenvolvimento, preservando dev global, estoque central e dados existentes. Implantação em produção não é autorizada por este plano e deve ser apresentada separadamente, com simulação, impactos, devs verificados e plano de recuperação.
+- Termos/aprovações devem espelhar o estado real do sprint status: atualização de planejamento solicitada, dev global preservado confirmado, plano de correção aprovado, produção não autorizada.
+- Pendências abertas que o epic deve manter visíveis (sem inventário não há conclusão): identidade dos desenvolvedores legítimos, regras de produção publicadas, volume real de dados legados.
+- Aceite da Story 0.1 já registrado (transcrição das fontes vigentes de 15/09/2026 aprovada em 21/09/2026); demais stories permanecem em backlog.
+
+## Technical Decisions
+
+- Autorização é server-authoritative: campos e papéis globais nunca são gravados nem alterados pelo cliente comum; papel global só via servidor, com migração segura do fallback legado de e-mail para UID.
+- Gate de dev confiável (`trustedDev`/`dev_roles`) é a única exceção para operações privilegiadas (ex.: alterar `owner`); a guarda deve ser única e uniforme entre Rules, Functions e UI.
+- Perfis consistentes via `isActive`, `modules`, `isAdmin` e `isOwner`; claims antigas não prevalecem sobre vínculo revogado; módulos fail-closed (vazio = sem acesso), com normalização de nomes legados.
+- Escrita de autorização/vínculos somente por Functions auditadas no servidor; auditoria de ator, alvo e resultado fica no servidor, sem UI nesta etapa.
+- C0–C6 são categorias de inventário, correção e aceite restritas ao desenvolvimento; estabilização e segurança são dependências explícitas de qualquer expansão de módulos.
+- Inventário/migração antes de publicar: versionamento de schema, simulação e verificação prévia de conta de recuperação antes de qualquer migração de privilégios.
+
+## Cross-Story Dependencies
+
+- Story 0.1 (done) é a base documental: 0.2, 0.3 e 0.4 consolidam sobre as decisões já registradas, sem reabrir o histórico.
+- A matriz de acesso (0.4) é pré-condição de referência para o pacote C1 (autorização) e para as guards de rota/vínculo dos epics de gestão de membros.
+- Aprovações do epic (0.3) limitam o alcance dos demais epics: execução em dev autorizada, produção bloqueada até aprovação separada.
+- Pendências de evidência (devs legítimos, regras publicadas, dados legados) bloqueiam etapas dependentes de migração/produção fora deste epic.
diff --git a/_bmad-output/implementation-artifacts/spec-0-2-definir-politica.md b/_bmad-output/implementation-artifacts/spec-0-2-definir-politica.md
new file mode 100644
index 0000000..6addad5
--- /dev/null
+++ b/_bmad-output/implementation-artifacts/spec-0-2-definir-politica.md
@@ -0,0 +1,79 @@
+---
+title: '0-2 definir politica'
+type: 'chore'
+created: '09-22-2026'
+status: 'in-review'
+route: 'dispatch'
+review_loop_iteration: 0
+baseline_commit: '2eb09d70b0f95a6eaba7c23b9842fbaa7fef2d83'
+context: [/Users/usuario/obras/_bmad-output/implementation-artifacts/epic-0-context.md, /Users/usuario/obras/docs/decisoes.md]
+---
+
+<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">
+
+## Intent
+
+**Problem:** As decisões D1–D7 estão registradas em `docs/decisoes.md` (0-1), mas não existe um documento de política de acesso e privilégios que as operationalize para quem implementa C1, regras e UI — o Epic 0 continua sem referência autoritativa de escopo de autorização além da matriz literal no plano de correção.
+
+**Approach:** Redigir um documento de política de acesso e privilégios ancorado exclusivamente em D1–D7 e nas fontes já aprovadas (plano de correção §3/§6, implementation_plan §4, data_model §2), sem reabrir o histórico congelado nem inventar evidência para as Pendências.
+
+## Boundaries & Constraints
+
+**Always:**
+- Ancorar cada cláusula da política em D1–D7 ou em seção explícita das fontes vigentes de 15/09/2026 (`@90e550d`), com citação de caminho e seção
+- Preservar `docs/decisoes.md` intacto (D1–D7 e Pendências de 0-1); 0-2 não edita decisões aprovadas
+- Manter Pendências visíveis como `pendente-evidência` (devs legítimos, regras de produção, volume legado) — nunca marcar como definidas
+- Reforçar: dev global confirmado; servidor autoritativo para `globalRole`; módulos fail-closed; exceções dev/admin-construtora ao vínculo individual de obra; produção fora do escopo desta aprovação
+- Texto em pt-br, UTF-8, alinhado ao vocabulário de papéis do plano §3 (Dev confiável, Admin/proprietário, Admin da obra, Membro comum, Sem autorização)
+
+**Never:**
+- Não alterar D1–D7, o cabeçalho de 0-1 nem `docs/archive/`
+- Não alterar `firestore.rules`, `storage.rules`, `functions/`, `app/` nem executar deploy/migração
+- Não inferir devs legítimos, regras publicadas ou volumes sem evidência
+- Não duplicar a matriz literal de 0-4 / plano §3 como se fosse nova decisão
+- Não autorizar implantação em produção
+
+**Decisões humanas 22/09/2026:**
+- DESTINO=A: criar `docs/politica.md` novo (separar registro 0-1 de política 0-2)
+- ESCOPO-POLÍTICA=A: só acesso e privilégios (custo/evidências/retenção ficam na evolução futura)
+- COLETA=A: formalizar as 3 Pendências como bloqueios de evidência na política; inventário real continua em 0-3/C0
+
+</frozen-after-approval>
+
+## Code Map
+
+- `docs/decisoes.md` -- somente leitura; D1–D7 + Pendências de 0-1; 0-2 não edita
+- `docs/plano-de-correcao-2026-09-15.md` -- fonte: §1 decisões/limites, §3 matriz aprovada, §6 escopo da aprovação
+- `docs/implementation_plan.md` -- fonte: §4 autorização proposta (tabela de perfis), §6 critérios
+- `docs/data_model.md` -- fonte: §2 autorização/dev global, `globalRole` só servidor, `isActive`/`modules`
+- `docs/task.md` -- registrar Aceite 0-2 + Change Log (padrão do Aceite 0-1 em :95-101)
+- `docs/politica.md` -- **criar** (se DESTINO=A) ou seção em `decisoes.md` (se B); entregável principal
+- `_bmad-output/implementation-artifacts/epic-0-context.md` -- contexto do épico, leitura apenas
+- `_bmad-output/implementation-artifacts/spec-0-1-registrar-decisoes.md` -- continuidade 0-1 done; frozen não reabrir
+- `firestore.rules` / `storage.rules` / `functions/src/index.ts` / `app/lib/src/common_widgets/access_guard.dart` / `app/lib/src/features/authentication/data/user_repository.dart` -- **não alterar**; citar apenas como estado atual se necessário na política
+- `docs/archive/2026-09-15-planejamento-anterior/` -- imutável, consulta apenas
+
+## Tasks & Acceptance
+
+**Execution:**
+- [x] `docs/politica.md` (ou seção em `docs/decisoes.md` conforme DESTINO) -- redigir política de acesso e privilégios em pt-br com seções: escopo, papéis e escopos (5 perfis do plano §3), regras de privilégio (dev global, servidor autoritativo, módulos fail-closed, exceções de vínculo), pendências de evidência, limite de produção -- entrega o "definir" do 0-2 sem duplicar 0-4
+- [x] `docs/politica.md` -- em cada seção, citar base em D# e/ou `arquivo seção` das fontes 15/09 -- rastreabilidade exigida pelo padrão 0-1
+- [x] `docs/task.md` -- adicionar `## Aceite 0-2` com decisão binária + motivo de 1 linha e linha no Change Log -- espelha rastreio do Aceite 0-1
+
+**Acceptance Criteria:**
+- Given as fontes vigentes e D1–D7, when a política é criada, then toda cláusula de acesso/privilégio remete a D# ou a seção citada das fontes, sem decisão nova
+- Given as Pendências de `docs/decisoes.md`, when a política é revisada, then devs legítimos, regras de produção e volume legado aparecem como pendente-evidência (ou referência conforme COLETA), nunca como resolvidos
+- Given os Boundaries, when o changeset é conferido, then `decisoes.md` D1–D7, archive, rules, functions e `app/` permanecem intactos; nenhum deploy/migração
+
+## Implementation Notes
+
+## Spec Change Log
+
+## Review Triage Log
+
+## Verification
+
+**Commands:**
+- `grep -E "D[1-7]|pendente-evidência" docs/politica.md | head -20` -- expected: citações D#/pendências presentes
+- `git diff --name-only -- docs/archive firestore.rules storage.rules functions app` -- expected: vazio
+- `test -f docs/politica.md || grep -q "## Política" docs/decisoes.md` -- expected: entregável existe (conforme DESTINO)
diff --git a/_bmad-output/implementation-artifacts/sprint-status.yaml b/_bmad-output/implementation-artifacts/sprint-status.yaml
index efac61b..4ac13a6 100644
--- a/_bmad-output/implementation-artifacts/sprint-status.yaml
+++ b/_bmad-output/implementation-artifacts/sprint-status.yaml
@@ -5,7 +5,7 @@
 # IDs históricos preservados; docs/stories não existe no workspace atual.
 
 generated: 09-14-2026 16:15
-last_updated: 09-22-2026 17:23
+last_updated: 09-22-2026 17:45
 project: obras
 project_key: SIGO
 tracking_system: file-system
@@ -34,7 +34,7 @@ observed_baseline:
 development_status:
   epic-0: in-progress
   0-1-registrar-decisoes: done
-  0-2-definir-politica: backlog
+  0-2-definir-politica: in-progress
   0-3-aprovar-termos: backlog
   0-4-matriz-acesso: backlog
   epic-0-retrospective: optional
diff --git a/docs/politica.md b/docs/politica.md
new file mode 100644
index 0000000..57fadee
--- /dev/null
+++ b/docs/politica.md
@@ -0,0 +1,65 @@
+# Política de acesso e privilégios — Epic 0
+
+Vigência das fontes: 15/09/2026 @90e550d (`90e550d33a11c40791f99583052d333d38986006`)
+Registro de decisões: [decisoes.md](decisoes.md) — leitura apenas; D1–D7 e Pendências de 0-1 permanecem intactos
+Story: 0-2 definir-politica | Destino: `docs/politica.md` novo (decisão humana DESTINO=A, 22/09/2026)
+
+Esta política operationaliza D1–D7 para quem implementa C1, regras e UI. Toda cláusula abaixo é referência a decisão ou seção já aprovada; nenhuma cláusula cria decisão nova e o histórico congelado (`docs/archive/`) não é reaberto. Texto em pt-br, alinhado ao vocabulário de papéis do plano §3.
+
+## 1. Escopo
+
+Cobre somente **acesso e privilégios**: papéis, escopos, regras de privilégio, pendências de evidência e limite de produção (decisão humana ESCOPO-POLÍTICA=A, 22/09/2026). Custo, evidências e retenção de dados ficam fora desta política e permanecem na evolução futura (`docs/task.md`, seção "Evolução futura — fora de C0–C6").
+
+A política orienta a implementação de C1 (autorização), a coerência entre Rules, Functions e UI, e as guards de rota/vínculo. A matriz literal detalhada permanece em `docs/plano-de-correcao-2026-09-15.md` seção 3 e será consolidada pela Story 0-4; aqui ela é referenciada, não duplicada como se fosse decisão nova.
+
+**Base:** D5, D6, D7 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 e seção 6 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d; `docs/data_model.md` seção 2 @90e550d.
+
+## 2. Papéis e escopos
+
+Cinco perfis, com vocabulário conforme `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d (D5). Escopos abaixo são resumos rastreáveis; a matriz literal é a do plano §3:
+
+1. **Dev confiável** — administração global, inclusive papéis via servidor; acesso global de suporte em dados de obra, estoque, financeiro e arquivos conforme operação autorizada. Não exige vínculo individual de obra.
+   *Base:* D1 e D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 1 e seção 3 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d.
+2. **Admin/proprietário ativo da construtora** — perfis mínimos e vínculos da própria construtora; nunca concede dev; todas as obras da construtora; administra estoque, financeiro e arquivos no próprio escopo. Dispensa membership em cada obra da própria construtora.
+   *Base:* D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d; `docs/data_model.md` seção 2 @90e550d.
+3. **Admin ativo da obra** — gestão restrita aos vínculos da obra, sem elevar privilégios de construtora; sem acesso automático ao financeiro central; estoque central somente com permissão explícita; arquivos da obra autorizada.
+   *Base:* D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d.
+4. **Membro comum (ativo)** — próprio perfil e próprios vínculos; módulos explicitamente permitidos no escopo correspondente; estoque central exige módulo central `estoque`; financeiro sem acesso nesta rodada; arquivos conforme módulo e obra.
+   *Base:* D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d; `docs/data_model.md` seção 2 @90e550d.
+5. **Sem autorização** — nenhum acesso operacional; dados de obra, estoque, financeiro e arquivos negados.
+   *Base:* D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d.
+
+**Base (seção):** D1 e D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d; `docs/data_model.md` seção 2 @90e550d.
+
+## 3. Regras de privilégio
+
+- **Dev global confirmado.** O desenvolvedor global é mantido e preservado, sem exigir vínculo por obra para administração global; a proteção da concessão desse papel é parte da correção. Autoatribuições de `globalRole=dev` não são confiáveis e identidades de devs legítimos não são inferidas.
+  *Base:* D1 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 1 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d; `docs/data_model.md` seção 2 @90e550d.
+- **Servidor autoritativo para `globalRole`.** O papel global só é escrito e alterado por fluxo administrativo confiável no servidor (Functions auditadas); o cliente comum não cria, altera nem apaga autorização própria e edita apenas campos pessoais permitidos. A migração do fallback legado de e-mail para UID preserva e testa o acesso dos devs legítimos antes da retirada do fallback; claims antigas não reativam vínculo revogado.
+  *Base:* D7 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 1 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d; `docs/data_model.md` seção 2 @90e550d.
+- **Módulos fail-closed.** Perfis consistem via `isActive`, `modules`, `isAdmin` e `isOwner`. Campos ou `modules` ausentes, ilegíveis ou vazios não concedem acesso implicitamente (vazio = sem acesso); nomes legados de módulo serão normalizados com mapeamento no inventário, sem concessão geral silenciosa.
+  *Base:* D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d; `docs/data_model.md` seção 2 @90e550d.
+- **Exceções ao vínculo individual de obra.** A permissão de obra regular exige vínculo ativo na construtora e na obra. **Dev confiável** e **admin/proprietário da construtora** são exceções explícitas a esse vínculo individual; a guarda deve ser única e uniforme entre Rules, Functions e UI.
+  *Base:* D1 e D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d.
+
+**Base (seção):** D1, D5, D7 — [decisoes.md](decisoes.md).
+
+## 4. Pendências de evidência
+
+Bloqueios de evidência formalizados nesta política (decisão humana COLETA=A, 22/09/2026). O inventário real continua em 0-3/C0; aqui os itens ficam visíveis como bloqueios e **nunca aparecem como resolvidos ou definidos**:
+
+| bloqueio | status | efeito |
+|---|---|---|
+| identidade dos desenvolvedores legítimos | `pendente-evidência` | bloqueia migração do fallback de e-mail e etapas dependentes de privilégio |
+| regras de produção atualmente publicadas | `pendente-evidência` | bloqueia qualquer afirmação sobre regras vigentes em produção |
+| volume real e dados legados (quantidades, saldos, anexos) | `pendente-evidência` | bloqueia conclusão sobre migração e volume legado |
+
+Status e motivação espelham a seção Pendências de [decisoes.md](decisoes.md) (0-1); sem inventário não há conclusão. Nenhum destes itens pode ser marcado como definido por presença de código ou tela.
+
+**Base:** Pendências — [decisoes.md](decisoes.md) seção Pendências; `docs/plano-de-correcao-2026-09-15.md` seção 1 @90e550d; `docs/data_model.md` seção 4 @90e550d.
+
+## 5. Limite de produção
+
+Esta política e a aprovação vigente autorizam implementação e validação de C0–C6 e da matriz **em ambiente de desenvolvimento**, mantendo dev global, estoque central e dados existentes. C0–C6 são categorias de inventário, correção e aceite restritas ao desenvolvimento. **Implantação em produção não é autorizada por este escopo** e deve ser apresentada separadamente, com simulação, impactos, devs verificados e plano de recuperação.
+
+**Base:** D6 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 6 @90e550d; `docs/implementation_plan.md` seção 5 @90e550d; `docs/data_model.md` seção 4 @90e550d.
diff --git a/docs/task.md b/docs/task.md
index 3a03a7d..1f916b0 100644
--- a/docs/task.md
+++ b/docs/task.md
@@ -96,6 +96,11 @@ Os critérios detalhados antigos permanecem no [arquivo histórico](archive/2026
 
 - Aceite 0-1: aprovado em 21/09/2026 — D1-D7 transcritos das 3 fontes vigentes de 15/09/2026 para docs/decisoes.md.
 
+## Aceite 0-2
+
+- Aceite 0-2: aprovado em 22/09/2026 — política de acesso e privilégios criada em docs/politica.md, ancorada em D1-D7 e nas fontes de 15/09/2026, sem decisão nova.
+
 ## Change Log
 
 - 2026-09-21: 0-1 aprovado (aceite final humano); diff: docs/decisoes.md novo (7 decisões + Pendências).
+- 2026-09-22: 0-2 aprovado; diff: docs/politica.md novo (escopo, 5 perfis, regras de privilégio, 3 pendências como bloqueio, limite de produção) + docs/task.md Aceite 0-2.


Do not invoke any skill, and do not spawn subagents of your own — you are the reviewer. Return your findings as text in your final message; do not route them through any findings-reporting tool the host may offer.
