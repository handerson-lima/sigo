# Review — Acurácia brownfield do PRD SIGO Obras

- **Alvo:** `prd.md` e `addendum.md` (PRD SIGO Obras, 2026-09-24)
- **Tipo:** fact-check de afirmações sobre o sistema existente
- **Data:** 2026-09-24
- **Fontes cotejadas:** `_bmad-output/planning-artifacts/epics.md`; `docs/*.md` (`task.md`, `implementation_plan.md`, `user_flows.md`, `data_model.md`, `politica.md`, `decisoes.md`, `presentation_summary.md`, `implantacao-c0-c6.md`, `validacao-c0-c6.md`); `_bmad-output/specs/*/SPEC.md`; `_bmad-output/implementation-artifacts/sprint-status.yaml`; `_bmad-output/implementation-artifacts/spec-*.md` (spot-check); além do código (`app/lib/src/core/contracts.dart`, `functions/src/index.ts`, `functions/package.json`, `firestore.rules`).
- **Legenda de veredito:** `ACURADO` · `INACURADO` · `NÃO SUPORTADO/AMBÍGUO`
- **Legenda de severidade:** critical · high · medium · low

---

## Resumo executivo

O PRD é em geral bem ancorado nos artefatos: acerta o estado de produção (não autorizado), o aceite C0–C6 em desenvolvimento, os limites de anexo (10 MB / 2 MiB), os cinco perfis, a nomenclatura `obraAdmin`, os nomes de Functions e os caminhos Firestore. Os problemas concentram-se em **superdeclaração de "implementado/validado"** para módulos do Epic 5 e para a navegação/hierarquia, em **duas versões técnicas trocadas no addendum** e no **vocabulário de módulos**. Há também divergências em artefatos de origem (docs vs specs/sprint-status) que o PRD resolve silenciosamente a favor da leitura mais otimista.

| ID | Severidade | Veredito | Local | Tema |
|----|-----------|----------|-------|------|
| F01 | high | NÃO SUPORTADO/AMBÍGUO | §6.1 | Epic 5 (Fornecedores, Compras/NF, Qualidade, Visão 360) declarado implementado+validado |
| F02 | high | INACURADO | §6.1, §4.3, UJ-9 | Drill-down 5 níveis (Lote→Setor→Equipe) declarado pronto |
| F03 | high | NÃO SUPORTADO | §6.1 | "Alinhamento Epics 8–10 à Hierarquia (raiz Loteamento)" declarado em escopo |
| F04 | medium | INACURADO | addendum §12 | "runtime Node 22 (Functions)" — real é Node 20 |
| F05 | medium | INACURADO | addendum §12 | "firebase-tools 12.19.0" — real é 15.30.1 |
| F06 | medium | INACURADO | §3 Glossary | `financeiro` listado como módulo canônico; aliases incompletos |
| F07 | medium | NÃO SUPORTADO | §3 Glossary | "Loteamento substitui Obra como raiz de atribuição de vínculos" |
| F08 | medium | AMBÍGUO | §4.2, §6.1, UJ-5 | Onboarding declarado implementado; spec frontmatter `in-progress` |
| F09 | low | AMBÍGUO | §9 OQ-2, §4.4 | Atribuição do limite de logo (2 MiB × 5 MB) |
| F10 | low | INACURADO | FR-14 | "senha … nunca é persistida" — é gravada no doc de notificação |
| F11 | medium | INACURADO | addendum §2 AD-4 | Conjunto de módulos aceitos subdeclarado vs `firestore.rules` |
| F12 | low | AMBÍGUO | §0/§9 | `docs/task.md` x specs/sprint-status: quais módulos são "entregues" |
| F13 | low | AMBÍGUO | §9 OQ-6, §0 | Política 0-2 "aprovada" em docs, mas `sprint-status` a mantém `in-progress` |

---

## Achados detalhados

### F01 — Epic 5 (Fornecedores, Compras/NF, Qualidade, Visão 360) declarado implementado e validado
- **Local PRD:** `prd.md` §6.1 ("In Scope") e §1 ("a validação de qualidade por lote, fornecedores, compras com nota fiscal e a visão consolidada de custos por lote"); §6.2 só exclui "custo médio".
- **Afirmação:** "os módulos abaixo têm código implementado e validado em desenvolvimento" incluindo Validação/qualidade, Fornecedores, Compras/NF/parcelas e Visão 360.
- **Contra-evidência:**
  - `docs/task.md:89-95` (2026-09-22) lista **ainda futuros**: "Compras/NF multi-itens, fornecedores, rateio e parcelas"; "Custo médio, snapshots e apropriação financeira por lote"; "Qualidade, cronograma, checklists e evidências por etapa"; "Documentos e visão 360 de lotes".
  - `docs/implementation_plan.md:7` põe "qualidade, compras integradas e visão completa de custos" no backlog.
  - `docs/presentation_summary.md:25` — "Compras com notas fiscais e parcelas, custo médio e apropriação por lote, RH e presença, EPI, qualidade e visão 360. Ainda não devem ser apresentados como recursos entregues."
  - `docs/validacao-c0-c6.md:140` — "Módulos: RH, EPI, Qualidade | Fora do escopo desta rodada."
- **A favor do PRD (conflito real):** `spec-5-1`..`spec-5-6` têm frontmatter `status: 'done'`; `epic-5-retro-2026-09-21.md` conclui `verdict: accepted`; `sprint-status.yaml:93-100` marca `epic-5: done`.
- **Veredito:** NÃO SUPORTADO/AMBÍGUO — a afirmação de "validado" é forte demais: o único documento de validação com evidência de testes (`validacao-c0-c6.md`) exclui explicitamente Qualidade/EPI/RH, e a fonte de escopo (`task.md`) ainda as trata como futuras. O PRD deveria registrar a divergência em §9 em vez de afirmar entrega.
- **Severidade:** high.

### F02 — Drill-down de cinco níveis declarado pronto
- **Local PRD:** `prd.md` §6.1 ("Hierarquia Estrutural com drill-down Loteamento → Quadra → Lote → Setor → Equipe e deep linking"), §4.3 (FR-17/FR-95/FR-96) e UJ-9.
- **Contra-evidência:** `sprint-status.yaml:128-131` — `epic-11: in-progress`; `11-1 … done`, `11-2-navegação-lote-setor-equipe: in-progress`. `spec-11-2-navegacao-lote-setor-equipe.md` frontmatter `status: 'in-progress'` (`review_loop_iteration: 1`).
- **Veredito:** INACURADO — apenas Loteamento→Quadra→Lote (11.1) está `done`; o nível Lote→Setor→Equipe (11.2) segue em progresso. A capacidade completa não está validada.
- **Severidade:** high.

### F03 — "Alinhamento dos vínculos (Epics 8–10) à Hierarquia Estrutural, com raiz em Loteamento"
- **Local PRD:** `prd.md` §6.1 (quarto item de In Scope).
- **Contra-evidência:** `addendum.md:136` lista como **action item aberto**: "Alinhar os vínculos (Epics 8–10) à Hierarquia Estrutural canônica … migração dos vínculos por obra mapeada como OQ-1". `epics.md` (Epic 8/9/10) mantém `construtoras/{cId}/obras/{oId}/members` e "N obras"; `docs/data_model.md:17` confirma `hierarquia_members` convivendo com `obras/{o}/members`; `spec-estabilizar-vinculos-epicos-8-10.md` trata de vínculos por obra.
- **Veredito:** NÃO SUPORTADO — é trabalho pendente (OQ-1), não capacidade implementada. Apresentar como In Scope realizado contamina a leitura do MVP.
- **Severidade:** high.

### F04 — Runtime das Functions: "Node 22" (addendum) vs Node 20 (real)
- **Local PRD:** `addendum.md:150` — "runtime Node 22 (Functions)".
- **Contra-evidência:** `functions/package.json:20` — `"node": "20"`. `docs/implantacao-c0-c6.md:7` — "Functions declara runtime Node 20"; `:26` "runtime Node 20". A fonte que o addendum cita (`implantacao-c0-c6.md`) diz **Node 20**, não 22.
- **Veredito:** INACURADO.
- **Severidade:** medium (número de versão citado explicitamente e com fonte atribuída errada).

### F05 — "firebase-tools 12.19.0"
- **Local PRD:** `addendum.md:150` — "`firebase-tools` 12.19.0".
- **Contra-evidência:** `docs/implantacao-c0-c6.md:13` diz que o preparador da PWA exige **`functions/node_modules/firebase` 12.19.0** — o **SDK JS `firebase`**, não o CLI `firebase-tools`. O `firebase-tools` declarado no projeto é **15.30.1** (`_bmad-output/implementation-artifacts/verification-gap-prompt.md:147`; `architecture-design-system-2026-09-23/.memlog.md:15`).
- **Veredito:** INACURADO — pacote e versão trocados.
- **Severidade:** medium.

### F06 — Lista de módulos do Glossário inclui `financeiro` como canônico e omite aliases
- **Local PRD:** `prd.md:146` (Glossary — "Módulo … (`diario`, `lotes`, `estoque`, `rh`, `epi`, `validacao`, `adm`, `financeiro`, `compras`). Aliases legados (`rdo`→`diario`, `almoxarifado`→`estoque`) são normalizados.") e FR-33/FR-38.
- **Contra-evidência:** `app/lib/src/core/contracts.dart:3-10` — a normalização canônica é `rdo→diario`, `almoxarifado→estoque`, `recursos_humanos→rh`, `qualidade→validacao`, **`financeiro→adm`**. Logo, `financeiro` é **alias legado** de `adm`, não módulo canônico; os aliases `qualidade` e `recursos_humanos` não são mencionados no PRD. `firestore.rules:19` confirma `adm(c)` aceitando `'adm'` **ou** `'financeiro'`.
- **Veredito:** INACURADO/AMBÍGUO — o vocabulário de módulos (item sensível a autorização) está impreciso e incompleto.
- **Severidade:** medium.

### F07 — "Loteamento substitui o contexto genérico de 'Obra' … como raiz de atribuição de vínculos"
- **Local PRD:** `prd.md:148` (Glossary — Loteamento) e `prd.md:153` (Obra "consolidado na raiz").
- **Contra-evidência:** a atribuição de vínculos segue por construtora (`construtora_members`) e por obra/nó (`construtoras/{cId}/obras/{oId}/members`, `hierarquia_members`) — `docs/data_model.md:11,17`; Epics 8–10 em `epics.md` operam "N obras". O próprio PRD admite migração pendente em §9 OQ-1 e o addendum em §11.
- **Veredito:** NÃO SUPORTADO (presente do indicativo forte demais) — o modelo canônico é alvo em migração, não o estado atual. O texto ressalva "durante a migração" logo depois, o que reduz a gravidade.
- **Severidade:** medium.

### F08 — Onboarding/Solicitação de Acesso declarado implementado
- **Local PRD:** `prd.md` §4.2 (FR-12..FR-16), §6.1 ("Onboarding com solicitação de acesso e aprovação pelo Dev"), UJ-5.
- **Evidência a favor:** `functions/src/index.ts:55-82` intercepta `auth/user-not-found` e cria `access_requests`; `:110` exporta `approveAccessRequest`; `firestore.rules:218-225` cobre `access_requests` e `notifications`.
- **Evidência contrária:** `spec-onboarding-solicitacao-acesso.md` frontmatter `status: 'in-progress'` e checklist `[ ]` não marcado (linhas 61-68); `sprint-status.yaml` não lista a story.
- **Veredito:** AMBÍGUO — backend/rules presentes, mas o artefato de spec que governa a entrega está `in-progress`. O PRD afirma como concluído sem registrar a pendência.
- **Severidade:** medium.

### F09 — Atribuição do limite de logo (2 MiB × 5 MB)
- **Local PRD:** `prd.md:312` e §9 OQ-2 (`prd.md:720`) — "2 MiB (contrato da primeira entrega) vs 5 MB (`HANDOFF.md`)".
- **Evidência:** `spec-sigo-primeira-entrega/SPEC.md:34` fixa **2 MiB**; porém, no mesmo pacote, `primeira-entrega/HANDOFF.md:15` e `EXPERIENCE.md:76` dizem **5 MB**. `architecture-design-system-2026-09-23/ARCHITECTURE-SPINE.md:125` também fixa 2 MiB. `prd-obras-2026-09-24/reconcile-ux-arch.md:27` já aponta que atribuir o 2 MiB ao "contrato da primeira entrega" é impreciso (o pacote cita 5 MB).
- **Veredito:** AMBÍGUO — os dois valores existem no mesmo pacote de origem; a atribuição de fonte está trocada. Manter como OQ é defensável, mas a nota deveria citar a inconsistência interna (SPEC 2 MiB × HANDOFF 5 MB) e que o valor canônico da spec é 2 MiB.
- **Severidade:** low.

### F10 — "senha provisória … nunca é persistida"
- **Local PRD:** `prd.md` FR-14 (`prd.md:235`) e §8 Segurança (`prd.md:710`).
- **Contra-evidência:** a spec de onboarding determina gravar a senha **dentro do documento de notificação** — `spec-onboarding-solicitacao-acesso.md:62`: `{title, body (inclui senha), read:false, createdAt, expiresAt:+7dias}`, persistido até leitura/TTL.
- **Veredito:** INACURADO — a senha é persistida (em doc de notificação) por até 7 dias; "só trafega" e "nunca persistida" não correspondem à spec.
- **Severidade:** low/medium (tema de segurança, mas transitório e de baixo alcance).

### F11 — AD-4 (addendum) subdeclara os módulos aceitos
- **Local PRD:** `addendum.md:18` — "obra aceita `diario|lotes|estoque`; construtora aceita `estoque`".
- **Contra-evidência:** `firestore.rules:14-19,135-204` — no escopo de construtora há módulos `rh`, `validacao`, `adm` (com aliases) e, por obra, `compras`, `adm`, `rh`, `almoxarifado` etc.; `app/lib/src/core/contracts.dart:3-10` normaliza `recursos_humanos→rh`, `qualidade→validacao`, `financeiro→adm`.
- **Veredito:** INACURADO/desatualizado — reproduz um AD do spine de 2026-09-21 anterior aos módulos do Epic 5. Deveria ser marcado como histórico ou atualizado.
- **Severidade:** medium.

### F12 — Conflito de fontes sobre módulos "entregues" (task.md × specs/sprint-status)
- **Local PRD:** `prd.md` §0 e §6.1.
- **Evidência:** `docs/task.md` é o `story_location` declarado do `sprint-status.yaml:12` e em 2026-09-22 ainda lista Compras/NF, fornecedores, Qualidade e Visão 360 como futuros — enquanto specs 5.x (`done`) e sprint-status (`epic-5: done`) dizem o contrário. O PRD adota a leitura otimista sem notar a contradição.
- **Veredito:** AMBÍGUO — deve ser explicitado em §9 (o próprio PRD declara essa intenção na "Nota de rigor").
- **Severidade:** low (meta), mas é a raiz de F01.

### F13 — Política 0-2: aprovada em docs, ainda `in-progress` no sprint-status
- **Local PRD:** `prd.md` §0/§9 tratam `docs/politica.md` como decisão vigente.
- **Evidência:** `docs/task.md:105` registra "Aceite 0-2: aprovado em 22/09/2026"; mas `sprint-status.yaml:37` mantém `0-2-definir-politica: in-progress` e `0-4-matriz-acesso: backlog`.
- **Veredito:** AMBÍGUO — a política está aprovada documentalmente, mas a matriz de acesso consolidada (0-4) segue backlog; o PRD não menciona essa pendência de rastreio.
- **Severidade:** low.

---

## Itens verificados como ACURADOS (amostra)

- **Estado de produção.** §6.2/§9 ("implantação em produção não autorizada") — confere com `docs/politica.md:59`, `docs/task.md:83`, `sprint-status.yaml:21` (`production_deployment: not_authorized_by_this_plan`) e `docs/validacao-c0-c6.md:153`.
- **Aceite C0–C6 em desenvolvimento.** Addendum §7 — confere com `docs/validacao-c0-c6.md` (ACEITO; 33 testes) e `sprint-status.yaml:32`.
- **Limite de anexos.** Addendum §12 ("10 MB comprovantes; 2 MiB logo") — `spec-2-5-armazenamento-local-blobs.md:26` (10.485.760 bytes) e `spec-5-3-modulo-adm/SPEC.md:49` (10 MB); logo 2 MiB em `spec-sigo-primeira-entrega/SPEC.md:34`.
- **Cinco perfis e nomes de papel.** §3/§4.1 — `docs/politica.md:19-30` (cinco perfis); `obraAdmin` presente em `functions/src/index.ts` e `firestore.rules`; `dev_roles/{uid}.isActive` em `docs/implantacao-c0-c6.md:25` e `sprint-status.yaml:144`.
- **Nomes de Functions.** Addendum §4 (`setMembership`, `setConstrutoraRole`, `adminCreateUser`, `approveAccessRequest`, `stockCommand`) — todos exportados em `functions/src/index.ts:108,109,162,110,184`.
- **Caminhos Firestore.** Addendum §3 — conferem com `docs/data_model.md:9-21` (`construtoras/{cId}/loteamentos/.../equipes`, `hierarquia_members`, `materiais/.../movimentacoes`, `access_requests`).
- **Estados da fila offline.** §3/FR-91/Addendum §5 — `pending, syncing, synced, failed, conflict, authorization_rejected` conferem com `docs/data_model.md:79`.
- **TTL de 7 dias das notificações.** FR-13 — `spec-onboarding-solicitacao-acesso.md:26,89`.
- **Snapshot de custo de mão de obra.** FR-100/addendum §12 (`lotCostSummaries`) — presente em `app/lib/src/features/rh/data/custo_mao_de_obra_service.dart:8,156`.
- **Epics vigentes 8–11.** §0 — confere com `epics.md`.
- **Estoque central único (não por obra).** FR-47/Addendum §8 — `docs/decisoes.md` D2, `docs/user_flows.md:31`.

---

## Tabela de rastreio (afirmação → fonte)

| Afirmação do PRD | Fonte decisiva | Veredito |
|---|---|---|
| Epic 5 implementado+validado | `docs/task.md:89-95`; `docs/validacao-c0-c6.md:140` × `sprint-status.yaml:93-100` | Ambíguo |
| Drill-down 5 níveis pronto | `sprint-status.yaml:130`; `spec-11-2` frontmatter | Inacurado |
| Vínculos alinhados a Loteamento | `addendum.md:136`; `epics.md`; `data_model.md:17` | Não suportado |
| Node 22 (Functions) | `functions/package.json:20`; `implantacao-c0-c6.md:7,26` | Inacurado |
| firebase-tools 12.19.0 | `implantacao-c0-c6.md:13`; `verification-gap-prompt.md:147` | Inacurado |
| `financeiro` é módulo canônico | `contracts.dart:8`; `firestore.rules:19` | Inacurado |
| Loteamento substitui Obra | `data_model.md:11,17`; `prd.md` OQ-1 | Não suportado |
| Onboarding implementado | `spec-onboarding…` frontmatter `in-progress` | Ambíguo |
| Logo 2 MiB "contrato" | `spec-sigo-primeira-entrega/SPEC.md:34` × `HANDOFF.md:15` | Ambíguo |
| Senha nunca persistida | `spec-onboarding…:62` | Inacurado |
| AD-4 módulos | `firestore.rules:14-19` | Inacurado |
