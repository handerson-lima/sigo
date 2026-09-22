# Trabalho diferido — SIGO

Atualizado em 2026-09-22.

## Correções C0–C6 — status

O [plano de correções](../../docs/plano-de-correcao-2026-09-15.md) foi **aprovado pelo usuário** (`sprint-status.yaml`: `correction_plan: approved_by_user`). Os pacotes C0–C6 foram **validados com resultado ACEITO em desenvolvimento** ([validação](../../docs/validacao-c0-c6.md)); a implantação em produção **segue pendente** de autorização (`production_deployment: not_authorized_by_this_plan`) e é apresentada separadamente. Manter os privilégios globais de dev é uma decisão já confirmada pelo usuário.

## Expansão depois da estabilização

- Compras/NF, fornecedores, parcelas e integração com estoque.
- Custo médio, rateios e apropriação por lote.
- RH, equipes, presença e política de custos.
- EPI, assinaturas e evidências.
- Qualidade, cronograma, documentos e visão 360.

Requisitos anteriores permanecem [arquivados](../../docs/archive/2026-09-15-planejamento-anterior/README.md), sujeitos a refinamento para a hierarquia construtora/obra e o papel dev preservado.

## Review Story 1.8 — findings adiados

- source_spec: `spec-1-8-recalculo-modulos.md`
  summary: Flash momentâneo na troca de obra durante rebuild do provider
  evidence: Race condition entre streams; AccessGuard cobre no nível de rota

- source_spec: `spec-1-8-recalculo-modulos.md`
  summary: financeiro inconsistente entre caminhos obraId/null no AccessGuard
  evidence: Comportamento pré-existente não causado por esta story

- source_spec: `spec-1-8-recalculo-modulos.md`
  summary: null obraDoc tratado como ativo no currentPermissionsProvider
  evidence: Fallback intencional para obras sem documento; AccessGuard cobre

- source_spec: `spec-1-8-recalculo-modulos.md`
  summary: dupla normalização normalizeModule em sidebar e dashboard
  evidence: Idempotente hoje; risco teórico se mapping crescer

- source_spec: `spec-1-8-recalculo-modulos.md`
  summary: ObraSwitcher sem tratamento de erro em stream
  evidence: Degradção silenciosa aceitável; widget oculto em caso de erro

- source_spec: `spec-1-8-recalculo-modulos.md`
  summary: _resolveRoute catch silencioso no GoRouterState
  evidence: Fallback intencional; ObraSwitcher não renderizado fora de contexto de obra

- source_spec: `spec-1-8-recalculo-modulos.md`
  summary: sidebar isActive sem teste de widget
  evidence: Guarda UI-only; rota protegida por AccessGuard

- source_spec: `spec-1-8-recalculo-modulos.md`
  summary: dashboard isActive sem teste de widget
  evidence: Guarda UI-only; rota protegida por AccessGuard

## Deferred from: code review of spec-1-8-recalculo-modulos.md (2026-09-16)

- ObraSwitcher sem feedback de loading/erro; hint generico; ids duplicados; overflow — UI polish pre-existente, fora dos ACs
- Financeiro inconsistente entre caminho obraId/null — pre-existente, nao causado por esta story
- Normalizacao sem trim/lowercase; campos nao-lista — spec exige so aliases exatos
- Flash/skeleton em sidebar/dashboard durante loading — rota protegida por AccessGuard com spinner; UI-only
- obraDoc nulo tratado como ativo — fallback intencional documentado; AccessGuard cobre

## Implantação

Nenhuma migração, publicação ou alteração de dados de produção foi executada nesta atualização documental. Preparar resultado concreto, simulação e recuperação antes de solicitar implantação.

## Deferred from: review of spec-0-1-registrar-decisoes.md (2026-09-21)

- source_spec: `/Users/usuario/obras/_bmad-output/implementation-artifacts/spec-0-1-registrar-decisoes.md`
  summary: Template de reprovação e guarda anti-duplicata para Aceite em docs/task.md
  evidence: edge findings mostram reexecução anexando headings duplicados e sem template de reprovação; low, fora do intent transcricional
- source_spec: `/Users/usuario/obras/_bmad-output/implementation-artifacts/spec-0-1-registrar-decisoes.md`
  summary: Checagem de concorrência em last_updated do sprint-status.yaml
  evidence: maybe-false unverified medium; sem evidência de perda, mas escrita sem merge check; o que assentaria: ler timestamp base antes de escrever e retry em mismatch

- source_spec: `_bmad-output/implementation-artifacts/spec-8-3-detalhe-do-membro.md`
  summary: Sheet de detalhe pode ficar em loading infinito se streams de obras não emitirem offline sem cache (sem timeout no bloco)
  evidence: maybe-false; `contagemObrasMetaProvider.carregando` sem emissão mantém spinner; settles com teste de stream não-emitting + expect de erro/timeout ou evidência do comportamento Firestore offline em `cachedList`

- source_spec: `_bmad-output/implementation-artifacts/spec-9-2-atribuir-admin-erros-e-offline.md`
  summary: checkConnectivity sem timeout pode pendurar setMembership se a platform channel não responder
  evidence: maybe-false unverified medium; spinner preso no diálogo se checkConnectivity nunca completar; o que assentaria: teste forçando platform channel pendurada ou evidência de que a channel sempre completa/erro

## Deferred from: retro epic-10 — gaps de verificação restantes (2026-09-22)

Findings 19–21 fechados em `spec-estabilizar-vinculos-epicos-8-10` (setCargo real, wiring Trocar cargo, prefill via overflow). Resto adiado (regressão limitada ao subconjunto prioritário).

- source_spec: `_bmad-output/implementation-artifacts/epic-10-retro-2026-09-22.md`
  summary: "Finding 22 — invalidação de providers nunca assertada (zero testes observam rebuild pós-mutação; apagar qualquer bloco `ref.invalidate` fica verde)"
  evidence: fechar exige harness de observação de rebuild pós-mutação; fora do subconjunto prioritário 19–21 desta rodada

- source_spec: `_bmad-output/implementation-artifacts/epic-10-retro-2026-09-22.md`
  summary: "Finding 23 — N+1 e progresso não testados com 2 obras confirmadas (happy path de CF é `nObras: 1`; diálogo `Desativando...` sem teste)"
  evidence: regressão N→1 passaria; ligado a `epic-10-fix-desativar-partial-invalidation` (findings 9, 15) que ainda está open

- source_spec: `_bmad-output/implementation-artifacts/epic-10-retro-2026-09-22.md`
  summary: "Finding 24 — a11y dos surfaces novos sem asserção (Esc/foco/≥48dp/`Editar vínculo`/textScale 1.3 nos dialogs 10.x e no overflow)"
  evidence: pares do finding 12; parte coberta por `epic-10-fix-a11y-overflow` (open); asserções de teste ficam para depois do fix de alvos ≥48dp
