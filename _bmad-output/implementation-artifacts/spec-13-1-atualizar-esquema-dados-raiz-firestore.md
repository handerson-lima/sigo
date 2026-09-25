---
title: 'Story 13.1 - Atualizar esquema de dados raiz no Firestore (Loteamentos a Equipes)'
type: 'feature'
created: '2026-09-25'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '34e0c9fe2c500a7a5660195c6379393cd9e8299a'
context: ['_bmad-output/implementation-artifacts/epic-13-context.md', '_bmad-output/planning-artifacts/architecture/architecture-obras-2026-09-24/ARCHITECTURE-SPINE.md', '_bmad-output/specs/spec-navegacao-loteamento-etapa/SPEC.md', '_bmad-output/specs/spec-navegacao-loteamento-etapa/hierarquia-etapas.md']
---

<!-- Target: 900–1300 tokens. Above 1600 = high risk of context rot.
     Never over-specify "how" — use boundaries + examples instead.
     Cohesive cross-layer stories (DB+BE+UI) stay in ONE file.
     IMPORTANT: Remove all HTML comments when filling this template. -->

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O esquema atual do Firestore usa subcollections aninhadas sob `construtoras/{c}/loteamentos/{l}/quadras/{q}/lotes/{lt}/setores/{s}/equipes/{e}` e nomenclatura legada ("Obras", "Setores"). Conforme AD-1 da arquitetura, devemos migrar para coleções top-level flat (`loteamentos`, `quadras`, `lotes`, `etapas`, `equipes`) com chaves estrangeiras para permitir consultas eficientes, evitar limites de profundidade do Firestore, e adotar a terminologia unificada do domínio.

**Approach:** Refatorar o esquema de dados para 5 coleções top-level no Firestore com foreign keys (construtoraId, loteamentoId, quadraId, loteId, etapaId). Renomear "Setor" → "Etapa" com as 5 etapas fixas por Lote (Muro, Cinza/1ª, Cinza/2ª, Cinza/3ª, Branca/Acabamento). Atualizar models, repositories, providers e security rules. Deletar/isolando dados legados de Obras/Setores em dev. Sem scripts de migração.

## Boundaries & Constraints

**Always:**
- Coleções na raiz do Firestore (top-level) conforme AD-1: `loteamentos`, `quadras`, `lotes`, `etapas`, `equipes`
- Cada documento contém chaves estrangeiras completas para navegar a hierarquia sem subcollections
- Terminologia unificada exclusivamente: `Loteamento`, `Quadra`, `Lote`, `Etapa`, `Equipe`. Abolir `Obra` e `Setor`
- IDs: UUIDv4 ou document IDs do Firestore
- Dados legados de Obras/Setores apagados/isolados em dev
- Security rules: read se `member(construtoraId)`, write se `admin(construtoraId)` em todas as 5 coleções

**Never:**
- Não criar subcollections aninhadas (ex: `construtoras/{cid}/loteamentos`)
- Não manter referências a "Obra" ou "Setor" no esquema de dados, models ou rules
- Não criar scripts de migração de dados — iniciar do zero em dev

**Decisions:**
- Escopo: camada de dados (Firestore schema, models, repositories, providers, security rules)
- Hierarquia relacional: Construtora → Loteamento → Quadra → Lote → Etapa → Equipe (1:N cada nível)
- Etapas fixas por Lote com ordem predefinida (conforme hierarquia-etapas.md)

</frozen-after-approval>

## Open Questions

1. **Localização dos models** — O códigobase atual usa `app/lib/src/features/{feature}/domain/{model}.dart`. O spec propõe `app/lib/src/core/models/`. Qual padrão seguir?
   - Opção A: Feature-specific domains (padrão atual) — `features/loteamentos/domain/loteamento.dart`, `features/etapas/domain/etapa.dart`, etc.
   - Opção B: Core models compartilhados — `core/models/loteamento.dart`, `core/models/etapa.dart`, etc.
   - Consequência A: Consistência com código existente, mas dispersa modelos relacionados. Consequência B: Centraliza domínio, mas quebra padrão atual.
   - **Resolução:** Opção A — models em `features/{feature}/domain/` (`features/etapas/domain/etapa.dart` etc.), mantendo o padrão existente.

2. **Estrutura do modelo Etapa** — As 5 etapas são fixas por Lote. Como modelar?
   - Opção A: Enum `EtapaTipo { muro, cinza1, cinza2, cinza3, branca }` + campo `ordem` — type-safe, validação em compile-time
   - Opção B: String `nome` + int `ordem` — flexível, mas permite valores inválidos em runtime
   - Consequência A: Mais seguro, exige migração se etapas mudarem. Consequência B: Mais simples, validação só em runtime.
   - **Resolução:** Opção A — enum `EtapaTipo { muro, cinza1, cinza2, cinza3, branca }` com extensão de `label` e `ordem` (1..5), fonte única para `buildDefaultEtapas`.

3. **Destino dos arquivos legados (setores/)** — A feature `setores/` existe com models, repository, routes, screens. Como tratar?
   - Opção A: Renomear pasta `setores/` → `etapas/` e refatorar conteúdo — preserva histórico git, transição gradual
   - Opção B: Deletar `setores/` e criar `etapas/` do zero — limpo, mas perde histórico
   - Consequência A: Git history preservado, mas refatoração mais complexa. Consequência B: Mais limpo, histórico perdido.
   - **Resolução:** Opção A — pasta `setores/` renomeada para `etapas/` (git detecta rename), conteúdo refatorado para a nova terminologia.

## Code Map

- `firestore.rules` (linhas 47-66) — Rules atuais para subcollections `loteamentos`/`quadras`/`lotes`/`setores`/`equipes` sob `construtoras/{c}`. Substituir por rules para top-level collections.
- `app/lib/src/features/loteamentos/domain/loteamento.dart` — Model atual com `id`, `construtoraId`, `name`, `createdAt`. Adicionar `updatedAt`.
- `app/lib/src/features/loteamentos/data/loteamento_repository.dart` — Usa subcollection `construtoras/$construtoraId/loteamentos`. Migrar para top-level `loteamentos` com query por `construtoraId`.
- `app/lib/src/features/quadras/domain/quadra.dart` — Model atual com `id`, `construtoraId`, `loteamentoId`, `name`, `createdAt`. Adicionar `updatedAt`.
- `app/lib/src/features/quadras/data/quadra_repository.dart` — Usa subcollection `construtoras/$c/loteamentos/$l/quadras`. Migrar para top-level `quadras` com query por `construtoraId` + `loteamentoId`.
- `app/lib/src/features/lotes/domain/lote.dart` — Model atual com `phase`, `status`, `responsavelId`. **Substituir** por modelo alinhado à nova hierarquia (remover phase/status, adicionar `updatedAt`).
- `app/lib/src/features/lotes/data/lote_repository.dart` — Usa subcollection `.../lotes`. Migrar para top-level `lotes` com query por `construtoraId` + `loteamentoId` + `quadraId`.
- `app/lib/src/features/setores/domain/setor.dart` — **Renomear para Etapa**. Model atual: `id`, `construtoraId`, `loteamentoId`, `quadraId`, `loteId`, `name`, `responsavelId`, `createdAt`. Novo: adicionar `ordem`, remover `responsavelId` (vai para Equipe), nomes fixos das 5 etapas.
- `app/lib/src/features/setores/data/setor_repository.dart` — **Renomear para etapa_repository.dart**. Migrar de subcollection `.../setores` para top-level `etapas` com query por `construtoraId` + `loteamentoId` + `quadraId` + `loteId`.
- `app/lib/src/features/equipes/domain/equipe.dart` — Model atual com `setorId`. **Alterar para `etapaId`**. Adicionar `updatedAt`.
- `app/lib/src/features/equipes/data/equipe_repository.dart` — Usa subcollection `.../setores/{setorId}/equipes`. Migrar para top-level `equipes` com query por `construtoraId` + `loteamentoId` + `quadraId` + `loteId` + `etapaId`.
- `app/test/loteamento_quadra_lote_providers_test.dart` — Testes dos providers atuais. Atualizar para novos paths de coleção e Record params.
- `app/test/loteamento_quadra_lote_navigation_test.dart` — Testes de navegação. Verificar se paths de rota mudam.

## Tasks & Acceptance

**Execution:**
- [x] `firestore.rules` — Substituir rules de subcollections (linhas 47-66) por 5 blocos `match /loteamentos/{id}`, `/quadras/{id}`, `/lotes/{id}`, `/etapas/{id}`, `/equipes/{id}` com `allow read: if member(resource.data.construtoraId); allow write: if admin(resource.data.construtoraId);`
- [x] `app/lib/src/features/loteamentos/domain/loteamento.dart` — Adicionar campo `updatedAt` (DateTime). Gerar `loteamento.g.dart` (`build_runner`).
- [x] `app/lib/src/features/loteamentos/data/loteamento_repository.dart` — Alterar `_loteamentosRef` para `_firestore.collection('loteamentos').where('construtoraId', isEqualTo: construtoraId)`. Manter `StreamProvider.family` com `LoteamentoParams = ({String construtoraId})`.
- [x] `app/lib/src/features/quadras/domain/quadra.dart` — Adicionar `updatedAt`. Gerar `.g.dart`.
- [x] `app/lib/src/features/quadras/data/quadra_repository.dart` — Alterar para top-level `quadras` com `where('construtoraId', ...) + where('loteamentoId', ...)`. `QuadraParams = ({String construtoraId, String loteamentoId})`.
- [x] `app/lib/src/features/lotes/domain/lote.dart` — **Refatorar**: remover `phase`, `status`, `responsavelId`. Manter `id`, `construtoraId`, `loteamentoId`, `quadraId`, `name`, `createdAt`, `updatedAt`. Gerar `.g.dart`.
- [x] `app/lib/src/features/lotes/data/lote_repository.dart` — Top-level `lotes` com query por 3 chaves. `LoteParams = ({String construtoraId, String loteamentoId, String quadraId})`.
- [x] `app/lib/src/features/etapas/domain/etapa.dart` — **Novo arquivo** (renomear de setor.dart). Campos: `id`, `construtoraId`, `loteamentoId`, `quadraId`, `loteId`, `nome` (String), `ordem` (int), `createdAt`, `updatedAt`. Enum `EtapaTipo` opcional (ver Open Question 2). Gerar `.g.dart`.
- [x] `app/lib/src/features/etapas/data/etapa_repository.dart` — **Novo** (renomear de setor_repository.dart). Top-level `etapas` com query por 4 chaves. `EtapaParams = ({String construtoraId, String loteamentoId, String quadraId, String loteId})`. Incluir método `createDefaultEtapas(loteId)` que cria as 5 etapas fixas com ordem correta.
- [x] `app/lib/src/features/equipes/domain/equipe.dart` — Alterar `setorId` → `etapaId`. Adicionar `updatedAt`. Gerar `.g.dart`.
- [x] `app/lib/src/features/equipes/data/equipe_repository.dart` — Top-level `equipes` com query por 5 chaves. `EquipeParams = ({String construtoraId, String loteamentoId, String quadraId, String loteId, String etapaId})`.
- [x] `app/lib/src/features/setores/` — **Renomear pasta para `etapas/`** (ver Open Question 3). Atualizar imports em todo código.
- [x] `app/test/loteamento_quadra_lote_providers_test.dart` — Atualizar fakes/mocks para novos paths de coleção top-level e Record params.
- [x] `app/test/` — Adicionar testes unitários para `EtapaRepository.createDefaultEtapas()` e validação de ordem das etapas.

**Acceptance Criteria:**
- Given ambiente de dev limpo, when rules e models deployados, then 5 coleções top-level (`loteamentos`, `quadras`, `lotes`, `etapas`, `equipes`) existem e aceitam escritas com foreign keys corretas
- Given Loteamento criado, when consulto quadras com `loteamentoId`, then retorna apenas quadras desse loteamento
- Given Lote criado, when chamo `createDefaultEtapas(loteId)`, then 5 etapas (Muro ordem=1, Cinza/1ª ordem=2, Cinza/2ª ordem=3, Cinza/3ª ordem=4, Branca/Acabamento ordem=5) são criadas na ordem correta
- Given Etapa criada, when consulto equipes com `etapaId`, then retorna equipes alocadas a essa etapa
- Given usuário não-membro da construtora, when tenta ler qualquer coleção, then acesso negado (permission-denied)
- Given membro (não admin) da construtora, when tenta escrever em qualquer coleção, then acesso negado (permission-denied)

## Implementation Notes

- A camada de produção já estava implementada no commit `14594cc`; nesta passagem corrigiram-se os 27 issues de `flutter analyze` (todos em testes/fixtures quebrados pelo refactor dos models) e completou-se o escopo pendente.
- Renomeação `Setor` → `Etapa` propagada ao `SigoBreadcrumbs` (segmento de path `setores` → `etapas`, rótulos `Etapa`/`Etapas`).
- `EtapaRepository.createDefaultEtapas` delega para `EtapaRepository.buildDefaultEtapas` (estático/testável), construído a partir de `EtapaTipo.values`, eliminando nomes/ordens duplicados.
- 5 repositórios migrados para coleções top-level com query por foreign keys; `features/setores/` removida e substituída por `features/etapas/`.
- Cobertura de testes: `etapa_repository_test.dart` deixou de usar fake tautológico e passou a exercitar `EtapaTipo` (5 etapas, labels e ordens fixas) e `buildDefaultEtapas` (nomes, ordens crescentes, FKs e timestamps); testes de navegação/etapas atualizados.
- Risco conhecido (fora do escopo desta story, endereçado pela retro-item 39): `etapa.g.dart` serializa datas como ISO string (`DateTime.parse`/`toIso8601String`), enquanto os demais 4 models usam codec Timestamp/String/int. Autoconsistente dentro da 13.1, mas divergente do restante da hierarquia.
- **Correções do review (2026-09-25):** `firestore.rules` estava com um `}` a mais (101/102) e `match /construtoras/{c}` fechava cedo, jogando `/commands`… `/obras` para fora do escopo — corrigido o aninhamento e movidos os 5 blocos top-level para irmãos de `/construtoras` (agora 101/101). Os 5 blocos passaram a usar `create` com `request.resource`, `update` ancorado em `resource.data.construtoraId` + FK congelada, e `delete` com `resource.data`. Adicionados índices compostos de `etapas`/`equipes` em `firestore.indexes.json`. Recriado `app/test/src/features/etapas/presentation/etapas_list_screen_test.dart`.

## Spec Change Log

- `EtapaRepository.createDefaultEtapas` usa named params `{construtoraId, loteamentoId, quadraId, loteId}` (em vez do `(loteId)` implícito), alinhando com o padrão de repository do restante da camada.

## Review Triage Log

Revisão em 2026-09-25 pelas camadas `blind-hunter`, `edge-case-hunter` e `verification-gap`. Nenhum achado roteado como `intent_gap`/`bad_spec`; **5 patches** aplicados e **5 defers** registrados. Duplicatas entre camadas consolidadas numa linha.

| # | Achado (escopo deduplicado) | Veredito | Rota | Evidência |
|---|---|---|---|---|
| 1 | `firestore.rules` estruturalmente inválido: `match /construtoras/{c}` fecha na linha 47 e o fechamento antigo permanece (linha 220); 101 `{` vs 102 `}`; `/commands`, `/funcionarios`, `/equipes` (RH), `/catalogo_epis`… `/obras` saem do escopo e usam `c`/`o` indefinidos. | high | patch | Contagem de chaves: baseline `34e0c9f` 101/101; árvore atual 101/102. Leitura de `firestore.rules:41-72,121-237`. Relatado pelas 3 camadas. |
| 2 | Nos 5 blocos novos, `allow write: if admin(request.resource.data.construtoraId)` cobre `delete`; em delete `request.resource` é nulo → admin nunca exclui (antes `write: if admin(c)` permitia). | medium | patch | `firestore.rules:49-72`; semântica de `request.resource` em delete. Consumidor atual não existe, mas é regressão de autorização introduzida pela mudança. |
| 3 | `allow write` valida só o valor de entrada: em `update` não congela `construtoraId`, permitindo admin de X reapropriar doc de Y (cross-tenant). | medium | patch | `firestore.rules:49-72`; regra antiga era ancorada no path `admin(c)`, que impedia o cross-tenant. |
| 4 | Índices compostos ausentes para `watchEtapas` (4 igualdades + `orderBy('ordem')`) e `watchEquipes` (5 igualdades + `orderBy('name')`) → `FAILED_PRECONDITION` em runtime. | high | patch | `etapa_repository.dart:28-37`, `equipe_repository.dart:41-56`; `firestore.indexes.json` não tem entradas para as 5 coleções, embora o projeto declare índices equivalentes para `access_requests`/`notifications`. |
| 5 | Regressão de cobertura: `setores_list_screen_test.dart` foi deletado e não há `etapas_list_screen_test.dart`; estados vazio/erro/retry de `EtapasListScreen` ficam sem teste. | medium | patch | Deleção no diff + ausência do arquivo; epic-13 exige "cobertura unitária/widget para repositories, models, rotas e breadcrumbs". |
| 6 | `createDefaultEtapas` nunca é chamado no fluxo de criação de Lote (`AddLoteScreen`), então Lote criado pela UI nasce sem as 5 etapas. | medium | defer | `createDefaultEtapas` só aparece em `etapa_repository.dart` e fakes; AC 13.1 é condicional ("when chamo"); ramificação/criação de etapas é escopo da Story 13.3 (epic-13-context). |
| 7 | `etapa_repository_test.dart` testa `buildDefaultEtapas` (pura) e não o `batch.commit()` de `createDefaultEtapas`, apesar do texto da task. | low | defer | Sem mock/harness de Firestore em Dart (`pubspec` não tem mockito/firebase-mock); a extração de `buildDefaultEtapas` é a costura testável possível hoje. |
| 8 | Nenhum teste executa os repositórios reais (`collection('loteamentos'|...)` + `where`), portanto o isolamento multi-tenant por FK não é verificado. | medium | defer | `loteamento_quadra_lote_providers_test.dart` e testes de tela só usam fakes/overrides; não há emulador Firestore para Dart no repo (só suíte de rules em Node). |
| 9 | Rules top-level sem casos no emulador: `functions/test/security-rules.test.cjs` só cobre caminhos aninhados e `npm run test:rules` não roda no CI. | medium | defer | `functions/test/security-rules.test.cjs`; `.github/workflows/ci.yml` roda `npm test` (`unit.cjs`) e `flutter analyze/test`, não `test:rules`. |
| 10 | Guard `request.resource.data.id == <pathId>` supostamente removido das novas coleções. | false | reject | Esse guard nunca existiu para loteamentos/quadras/lotes/setores/equipes (as rules antigas eram só `allow write: if admin(c)`); permanece em `/construtoras`, `/funcionarios`, `/equipes` (RH). |
| 11 | Sem migração/backfill dos dados legados de Obras/Setores. | false | reject | Intent congelado determina explicitamente "Não criar scripts de migração de dados — iniciar do zero em dev". |
| 12 | `updatedAt` obrigatório com `DateTime.parse(json['updatedAt'] as String)` quebra docs pré-existentes. | false | reject | Ambiente de dev parte do zero (sem legado); codec `DateTime.parse` já era o padrão de Lote/Loteamento/Quadra antes da mudança. |
| 13 | `Etapa` serializa datas como ISO string enquanto `Equipe` usa Timestamp. | low | defer | `etapa.g.dart` segue o estilo de `lote.g.dart`/`quadra.g.dart`; unificação de codec é a retro-item 39 (já aberta). Registrado em Implementation Notes. |
| 14 | `createEtapa`/`createEquipe` adicionados e nunca chamados (APIs mortas). | false | reject | São pontos de extensão do repositório para 13.3/13.4; não há defeito funcional. |
| 15 | Inconsistência `nome` (Etapa) vs `name` (demais). | false | reject | O spec define explicitamente o campo `nome` para Etapa. |
| 16 | Colisão de nome `Equipe` (features/equipes vs features/rh) e dois `match /equipes` nas rules. | false | reject | O overlap de rules é efeito colateral do achado #1 (some ao corrigir braces: o `/equipes` de RH volta a ser aninhado). As duas classes Dart são pré-existentes (já registradas nos findings da 11.2). |
| 17 | URLs `/setores` sem redirect, hierarquia de Etapa não surfada na UI e rótulos "Setores" remanescentes (`sigo_sidebar.dart:237`, `obra_dashboard_screen.dart:146`). | medium | defer | Rotas declarativas/UI são o escopo explícito da Story 13.2 (epic-13-context); o intent congelado da 13.1 é camada de dados. |
| 18 | Arquivos novos sem newline final; `import 'package:intl/intl.dart'` após import relativo. | low | reject | Cosmético; não afeta usuário/dev no uso cotidiano e não é erro de `flutter analyze`. |

## Design Notes

**Padrão de Repository com Record params:** Seguir padrão existente em `loteamento_repository.dart` e `quadra_repository.dart` usando `StreamProvider.family` com typedef de Record para evitar loops de `AsyncLoading`. Exemplo:
```dart
typedef LoteParams = ({String construtoraId, String loteamentoId, String quadraId});
final watchLotesProvider = StreamProvider.family<List<Lote>, LoteParams>((ref, params) { ... });
```

**Criação das 5 etapas padrão:** O `EtapaRepository` deve expor `Future<void> createDefaultEtapas({required String construtoraId, required String loteamentoId, required String quadraId, required String loteId})` que cria em batch as 5 etapas com nomes e ordens fixas. Isso garante que todo Lote tenha a estrutura completa de etapas imediatamente após criação.

**Security Rules top-level:** Como as collections são top-level, as rules devem validar `resource.data.construtoraId` (para read) e `request.resource.data.construtoraId` (para write) comparando com a construtora do usuário via `member()`/`admin()`. Exemplo:
```
match /loteamentos/{id} {
  allow read: if member(resource.data.construtoraId);
  allow write: if admin(request.resource.data.construtoraId);
}
```

## Verification

**Executado em 2026-09-25 (working tree sobre `14594cc`, baseline `34e0c9f`; patches do review reaplicados):**

**Commands:**
- `flutter analyze` (workdir `app/`) — RESULTADO: `No issues found! (ran in 5.8s)`, exit 0. Antes: 27 issues.
- `flutter test` (workdir `app/`) — RESULTADO: `00:48 +503: All tests passed!`, exit 0.
- `dart run build_runner build --delete-conflicting-outputs` (workdir `app/`) — RESULTADO: `Built with build_runner/aot in 15s; wrote 0 outputs` (`.g.dart` em dia). Nota: o flag `--delete-conflicting-outputs` foi removido pelo build_runner e é ignorado.
- `firestore.rules` — RESULTADO: balanceado `{`=101 / `}`=101 (antes do patch: 101/102, inválido).
- `firestore.indexes.json` — RESULTADO: JSON válido (`json.load`), com índices novos de `etapas` e `equipes`.
- Verificar no Firebase Console — NÃO EXECUTADO: sem emulador/instância de Firestore disponível localmente. ACs de rules e de criação de docs ficam comprovadas por leitura de código (`firestore.rules:49-72`, repositórios), não por teste automatizado.

**Manual checks (if no CLI):**
- [ ] Criar Loteamento → verificar documento em `loteamentos/` com `construtoraId` (pendente de ambiente)
- [ ] Criar Quadra → verificar documento em `quadras/` com `construtoraId` + `loteamentoId` (pendente de ambiente)
- [ ] Criar Lote → verificar documento em `lotes/` com 3 foreign keys (pendente de ambiente)
- [x] Criar Lote → chamar `createDefaultEtapas()` → 5 etapas com `ordem` 1-5 — coberto por `app/test/etapa_repository_test.dart` (passando)
- [ ] Criar Equipe → verificar documento em `equipes/` com 5 foreign keys (pendente de ambiente)
- [ ] Tentar ler como não-membro → confirmar permission-denied (pendente de emulador de rules)
- [ ] Tentar escrever como membro não-admin → confirmar permission-denied (pendente de emulador de rules)

**Matriz de testes:** a story não define I/O & Edge-Case Matrix no bloco congelado — auditoria não aplicável.