# Trabalho diferido — SIGO

Atualizado em 2026-09-24.

## Deferred from: code review (2026-09-23) — story 3-infraestrutura-segura-para-gestao-de-logos

- Handler `processLogo` nunca executado por teste algum (`functions/src/index.ts:332-356`) — deferred: o repo não tem harness que execute handlers de trigger Storage (`test:emulators` não inclui o emulador de functions); criar esse harness excede o escopo desta mudança.

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

- source_spec: `_bmad-output/implementation-artifacts/spec-estabilizar-vinculos-epicos-8-10.md`
  summary: "`_temConectividade` em `MembrosRepository.setCargo` sem `.timeout` pode pendurar o diálogo se a platform channel de connectivity nunca completar"
  evidence: mesma classe do finding 9.2 já adiado para `setMembership` (maybe-false); comportamento pré-existente preservado na extração para `_temConectividade`; settles com teste forçando channel pendurada ou evidência de que a channel sempre completa/erro
- source_spec: `_bmad-output/implementation-artifacts/spec-corrigir-firestore-indexes-json.md`
  summary: Adicionar validação de firestore.indexes.json (chaves de topo únicas) ao CI
  evidence: Bug de chave duplicada passou silenciosamente; parsers aceitam chave duplicada mantendo só a última — nenhuma checagem existe no repo.
- source_spec: `_bmad-output/implementation-artifacts/spec-corrigir-firestore-indexes-json.md`
  summary: Reconciliar firestore.indexes.json com produção (firebase firestore:indexes / deploy) e decidir sobre fieldOverrides de userId
  evidence: Índices provavelmente não existem em produção; fieldOverrides pré-existentes podem desabilitar índices single-field COLLECTION/DESCENDING de userId; deploy é ação externa irreversível.
- source_spec: `_bmad-output/implementation-artifacts/spec-corrigir-firestore-indexes-json.md`
  summary: Declarar índices ausentes para chamadas (construtoraId+date), movimentacoes (obraId, obraId+loteId) e fornecedores (status+razaoSocial)
  evidence: Queries em chamada_repository.dart, custos_360_repository.dart e fornecedores_repository.dart sem entrada correspondente no arquivo; gap pré-existente, não causado por esta correção.
- source_spec: `_bmad-output/implementation-artifacts/spec-corrigir-firestore-indexes-json.md`
  summary: Melhorias auxiliares: firebase.test.json declarar índices, teste que valide o arquivo, filtro server-side em users_list_screen
  evidence: Config/testes/otimizações pré-existentes fora do escopo da correção da chave duplicada.

- source_spec: `spec-hardening-credenciais-seed.md`
  summary: Ampliar cobertura de nomes de credencial ignorados/verificados (credentials.json, google-services.json, chaves de PEM/JKS etc.)
  evidence: Padrões atuais cobrem serviceAccountKey/service-account/firebase-adminsdk/extensões .pem/.key/.cert/.p12/.env; nomes extras não estavam no intent e algum (google-services.json) é legitimamente commitável em Flutter.

- source_spec: `spec-hardening-credenciais-seed.md`
  summary: Varredura de conteúdo e histórico git (gitleaks/trufflehog) para além de nomes de arquivos rastreados
  evidence: A CI atual só examina nomes no HEAD; chave colada em código ou já presente em commit antigo passaria; fora do escopo do hardening de seed.

- source_spec: `spec-hardening-credenciais-seed.md`
  summary: Contrapartida local da checagem (script em package.json, pre-commit) e DX (seed:cloud, runbook de exportação da env)
  evidence: Padrões duplicados entre .gitignore e ci.yml podem divergir; desenvolvedor só descobre no push; inventory.cjs ainda sugere caminho ./service-account.json na árvore.

- source_spec: `spec-hardening-credenciais-seed.md`
  summary: Testes automatizados de regressão para os caminhos de falha do seed em modo cloud
  evidence: Harness node --test existe em functions; hoje a proteção contra reintrodução do fallback é só code review.

## Deferred from: code review of spec-0-2-definir-politica.md (2026-09-24)

- source_spec: `_bmad-output/implementation-artifacts/spec-0-2-definir-politica.md`
  summary: Corrigir aceite C5 de Chrome/Safari móvel marcado concluído em docs/task.md:73.
  evidence: docs/validacao-c0-c6.md:139 ainda lista testes de Safari móvel e Chrome Android; divergência anterior à Story 0-2, fora do changeset documental.
- source_spec: `_bmad-output/implementation-artifacts/spec-0-2-definir-politica.md`
  summary: Reconciliar edição de epic-0-context.md com restrição de somente leitura no Code Map da Story 0-2.
  evidence: commits da história alteraram objetivo e adicionaram seções ao contexto do épico; por ser arquivo de contexto de agente, requer fluxo próprio.

- source_spec: `_bmad-output/implementation-artifacts/spec-epic-4-retro-item-1-modularizar-chamada-form.md`
  summary: Fixar snapshot consistente ou bloquear edições durante salvamento da chamada (high) — RESOLVIDO por `spec-corrigir-concorrencia-salvamento-chamada.md` (single-flight + snapshot antes do await + guards).
  evidence: Implementado e coberto por 8 testes de regressão em `chamada_form_screen_test.dart`; 47 testes RH verdes.

## Deferred from: review of spec-corrigir-concorrencia-salvamento-chamada.md (2026-09-24)

- source_spec: `_bmad-output/implementation-artifacts/spec-corrigir-concorrencia-salvamento-chamada.md`
  summary: Unicidade data/obra e atomicidade check→save no repositório de chamadas (transação/precondição Firestore).
  evidence: medium real e pré-existente; `saveChamada` grava UUID novo sem constraint; TOCTOU entre `findCrossObraApontamentos` e `saveChamada`.

- source_spec: `_bmad-output/implementation-artifacts/spec-corrigir-concorrencia-salvamento-chamada.md`
  summary: Retificação sem precondição de versão + `SetOptions(merge: true)` pode sofrer lost update entre editores.
  evidence: medium real e pré-existente em `chamada_repository.dart:141-143` + `versaoAuditoria + 1` no cliente.

- source_spec: `_bmad-output/implementation-artifacts/spec-corrigir-concorrencia-salvamento-chamada.md`
  summary: Race na troca de equipe — `_syncWorkersList` roda com `_defaultLotId` stale enquanto `getDefaultLot` ainda pendura; workers não re-sincronizam quando o lote chega.
  evidence: medium real e pré-existente (`chamada_form_screen.dart` wrapper `onTeamChanged` + `_onTeamChanged` async); assentaria com teste de troca de equipe com `getDefaultLot` atrasado.

- source_spec: `_bmad-output/implementation-artifacts/spec-corrigir-concorrencia-salvamento-chamada.md`
  summary: Trocar equipe na tela de retificação esvazia `_workers` permanentemente (`_syncWorkersList` retorna cedo quando `_existingChamada != null`).
  evidence: medium real e pré-existente; assentaria com teste de retificação + `onTeamChanged`.

- source_spec: `_bmad-output/implementation-artifacts/spec-corrigir-concorrencia-salvamento-chamada.md`
  summary: Sync de workers por comprimento de lista (sem merge por `workerId`) — troca 1-a-1 não refresca; mudança de contagem apaga marcações/rateio.
  evidence: medium real e pré-existente em `_syncWorkersList`.

- source_spec: `_bmad-output/implementation-artifacts/spec-corrigir-concorrencia-salvamento-chamada.md`
  summary: `_loadInitialData` sem try/catch — `getChamada` quebrando vira unhandled async e `_initialized` nunca seta; `chamadaId` inexistente cai em modo nova sem aviso.
  evidence: maybe-false unverified medium; assentaria com repo que lança em `getChamada` + asserção de UI de erro/retry; pré-existente.

- source_spec: `_bmad-output/implementation-artifacts/spec-corrigir-concorrencia-salvamento-chamada.md`
  summary: SnackBar "Ver Chamada" usa `context.pushReplacement` sem `context.mounted` — snackBar pode sobreviver à rota.
  evidence: maybe-false unverified medium; assentaria com teste de tap na ação após navegar para longe; pré-existente.

- source_spec: `_bmad-output/implementation-artifacts/spec-corrigir-concorrencia-salvamento-chamada.md`
  summary: `onWorkerChanged` sem guarda de bounds e view recebe `_workers` viva — index obsoleto derrubaria RangeError em vez de no-op.
  evidence: maybe-false unverified medium; assentaria com caminho reproduzível em que a lista encolhe entre build e callback; lista viva pré-existente.

- source_spec: `_bmad-output/implementation-artifacts/spec-corrigir-concorrencia-salvamento-chamada.md`
  summary: Demais findings low adiados: isFormValid sem `lotesValidosDaObra`; data duplicada só advisory sem teste; `_syncWorkersList` muta em build; conflito mostra `obraId` cru; `saveDefaultLot` sem tratamento de erro; sem teste de write lento/wiring do sticky bar; exceção crua no snackbar; uid fallback `unknown`; sem `PopScope`; `findChamadaByDate` da fixture sempre null; date picker 2020–2035.
  evidence: todos pré-existente ou gap de cobertura fora do intent de concorrência; ver Review Triage Log da spec.

- source_spec: `_bmad-output/implementation-artifacts/spec-11-1-navegacao-loteamento-quadra-lote.md`
  summary: As Boundaries do spec descrevem a hierarquia em plural (`/construtoras/:cId/...`) enquanto o app usa o singular (`/construtora/:cId`).
  evidence: divergência real de documentação; o singular é a convenção de todo o app (`ConstrutoraPaths.detail`) e a navegação funciona; pré-existente, não introduzido pela 11.1.

- source_spec: `_bmad-output/implementation-artifacts/spec-11-1-navegacao-loteamento-quadra-lote.md`
  summary: Ramos `error`/`loading` das listagens de loteamentos, quadras e lotes não têm testes.
  evidence: lacuna de cobertura real (só vazio/dados/rebuild são exercitados); sem defeito demonstrado no comportamento atual.

- source_spec: `_bmad-output/implementation-artifacts/spec-11-1-navegacao-loteamento-quadra-lote.md`
  summary: `watchLoteamentosProvider`/`watchQuadrasProvider`/`watchLotesProvider` são `StreamProvider.family` sem `autoDispose`, mantendo subscriptions do Firestore por toda a sessão.
  evidence: padrão já usado por setores/equipes; `autoDispose` reintroduziria o `AsyncLoading` que a história quer evitar; decisão de ciclo de vida de provider a revisitar.

## Deferred from: code review of spec-11-1-navegacao-loteamento-quadra-lote (2026-09-24)

- `StreamProvider.family` sem `autoDispose` acumula subscriptions do Firestore. source_spec: `_bmad-output/implementation-artifacts/spec-11-1-navegacao-loteamento-quadra-lote.md`; location: `app/lib/src/features/loteamentos/data/loteamento_repository.dart:36`. Evidence: padrão pré-existente de setores/equipes; `autoDispose` reintroduziria o `AsyncLoading` que a história quer evitar; decisão de ciclo de vida de provider a revisitar.

## Deferred from: code review of spec-11-3-corrige-navegacao-hierarquia (2026-09-24)

- `LoteHierarchySelector`: ids retidos (loteamento/quadra) ausentes após refresh geram dropdowns vazios. source_spec: `_bmad-output/implementation-artifacts/spec-11-3-corrige-navegacao-hierarquia.md`; location: `app/lib/src/features/lotes/presentation/widgets/lote_hierarchy_selector.dart`. Evidence: borda pré-existente de dados; o `_valorSeguro` só protege `initialValue`, não o gate do nível seguinte.

- `chamada_form_screen`: editar uma chamada não repõe loteamento/quadra do lote padrão salvo (só `_defaultLotId`). source_spec: `_bmad-output/implementation-artifacts/spec-11-3-corrige-navegacao-hierarquia.md`; location: `app/lib/src/features/rh/presentation/chamada_form_screen.dart`. Evidence: o caminho antigo (`dummy_loteamento`/`dummy_quadra`) já retornava vazio em produção; repor exigiria resolver o pai do lote.

- source_spec: `_bmad-output/implementation-artifacts/spec-11-3-corrige-navegacao-hierarquia.md`
  summary: Criar telas/ações de criação para Loteamento e Quadra (e Setor/Equipe) na hierarquia; hoje só Lote tem `AddLoteScreen` roteada.
  evidence: `LoteamentoRepository.createLoteamento` e `QuadraRepository.createQuadra` existem, mas nenhum formulário/rota os usa; as listagens novas ficam sem CTA de criação nesses níveis (spec-11-3 só entregou vazio + CTA de Lote por não haver formulário).
