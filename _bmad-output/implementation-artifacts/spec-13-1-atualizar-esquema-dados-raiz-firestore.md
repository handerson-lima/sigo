---
title: 'Story 13.1 - Atualizar esquema de dados raiz no Firestore (Loteamentos a Equipes)'
type: 'feature'
created: '2026-09-25'
status: 'in-progress'
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

2. **Estrutura do modelo Etapa** — As 5 etapas são fixas por Lote. Como modelar?
   - Opção A: Enum `EtapaTipo { muro, cinza1, cinza2, cinza3, branca }` + campo `ordem` — type-safe, validação em compile-time
   - Opção B: String `nome` + int `ordem` — flexível, mas permite valores inválidos em runtime
   - Consequência A: Mais seguro, exige migração se etapas mudarem. Consequência B: Mais simples, validação só em runtime.

3. **Destino dos arquivos legados (setores/)** — A feature `setores/` existe com models, repository, routes, screens. Como tratar?
   - Opção A: Renomear pasta `setores/` → `etapas/` e refatorar conteúdo — preserva histórico git, transição gradual
   - Opção B: Deletar `setores/` e criar `etapas/` do zero — limpo, mas perde histórico
   - Consequência A: Git history preservado, mas refatoração mais complexa. Consequência B: Mais limpo, histórico perdido.

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
- [ ] `firestore.rules` — Substituir rules de subcollections (linhas 47-66) por 5 blocos `match /loteamentos/{id}`, `/quadras/{id}`, `/lotes/{id}`, `/etapas/{id}`, `/equipes/{id}` com `allow read: if member(resource.data.construtoraId); allow write: if admin(resource.data.construtoraId);`
- [ ] `app/lib/src/features/loteamentos/domain/loteamento.dart` — Adicionar campo `updatedAt` (DateTime). Gerar `loteamento.g.dart` (`build_runner`).
- [ ] `app/lib/src/features/loteamentos/data/loteamento_repository.dart` — Alterar `_loteamentosRef` para `_firestore.collection('loteamentos').where('construtoraId', isEqualTo: construtoraId)`. Manter `StreamProvider.family` com `LoteamentoParams = ({String construtoraId})`.
- [ ] `app/lib/src/features/quadras/domain/quadra.dart` — Adicionar `updatedAt`. Gerar `.g.dart`.
- [ ] `app/lib/src/features/quadras/data/quadra_repository.dart` — Alterar para top-level `quadras` com `where('construtoraId', ...) + where('loteamentoId', ...)`. `QuadraParams = ({String construtoraId, String loteamentoId})`.
- [ ] `app/lib/src/features/lotes/domain/lote.dart` — **Refatorar**: remover `phase`, `status`, `responsavelId`. Manter `id`, `construtoraId`, `loteamentoId`, `quadraId`, `name`, `createdAt`, `updatedAt`. Gerar `.g.dart`.
- [ ] `app/lib/src/features/lotes/data/lote_repository.dart` — Top-level `lotes` com query por 3 chaves. `LoteParams = ({String construtoraId, String loteamentoId, String quadraId})`.
- [ ] `app/lib/src/features/etapas/domain/etapa.dart` — **Novo arquivo** (renomear de setor.dart). Campos: `id`, `construtoraId`, `loteamentoId`, `quadraId`, `loteId`, `nome` (String), `ordem` (int), `createdAt`, `updatedAt`. Enum `EtapaTipo` opcional (ver Open Question 2). Gerar `.g.dart`.
- [ ] `app/lib/src/features/etapas/data/etapa_repository.dart` — **Novo** (renomear de setor_repository.dart). Top-level `etapas` com query por 4 chaves. `EtapaParams = ({String construtoraId, String loteamentoId, String quadraId, String loteId})`. Incluir método `createDefaultEtapas(loteId)` que cria as 5 etapas fixas com ordem correta.
- [ ] `app/lib/src/features/equipes/domain/equipe.dart` — Alterar `setorId` → `etapaId`. Adicionar `updatedAt`. Gerar `.g.dart`.
- [ ] `app/lib/src/features/equipes/data/equipe_repository.dart` — Top-level `equipes` com query por 5 chaves. `EquipeParams = ({String construtoraId, String loteamentoId, String quadraId, String loteId, String etapaId})`.
- [ ] `app/lib/src/features/setores/` — **Renomear pasta para `etapas/`** (ver Open Question 3). Atualizar imports em todo código.
- [ ] `app/test/loteamento_quadra_lote_providers_test.dart` — Atualizar fakes/mocks para novos paths de coleção top-level e Record params.
- [ ] `app/test/` — Adicionar testes unitários para `EtapaRepository.createDefaultEtapas()` e validação de ordem das etapas.

**Acceptance Criteria:**
- Given ambiente de dev limpo, when rules e models deployados, then 5 coleções top-level (`loteamentos`, `quadras`, `lotes`, `etapas`, `equipes`) existem e aceitam escritas com foreign keys corretas
- Given Loteamento criado, when consulto quadras com `loteamentoId`, then retorna apenas quadras desse loteamento
- Given Lote criado, when chamo `createDefaultEtapas(loteId)`, then 5 etapas (Muro ordem=1, Cinza/1ª ordem=2, Cinza/2ª ordem=3, Cinza/3ª ordem=4, Branca/Acabamento ordem=5) são criadas na ordem correta
- Given Etapa criada, when consulto equipes com `etapaId`, then retorna equipes alocadas a essa etapa
- Given usuário não-membro da construtora, when tenta ler qualquer coleção, then acesso negado (permission-denied)
- Given membro (não admin) da construtora, when tenta escrever em qualquer coleção, then acesso negado (permission-denied)

## Implementation Notes

## Spec Change Log

## Review Triage Log

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

**Commands:**
- `flutter analyze` — expected: Sem erros nos novos/atualizados models, repositories, providers
- `flutter test` — expected: Testes de providers e repositories passam (incluindo novos testes de Etapa)
- `flutter pub run build_runner build --delete-conflicting-outputs` — expected: Geração de `.g.dart` bem-sucedida
- Verificar no Firebase Console: coleções `loteamentos`, `quadras`, `lotes`, `etapas`, `equipes` na raiz com documentos de teste

**Manual checks (if no CLI):**
- Criar Loteamento → verificar documento em `loteamentos/` com `construtoraId`
- Criar Quadra → verificar documento em `quadras/` com `construtoraId` + `loteamentoId`
- Criar Lote → verificar documento em `lotes/` com 3 foreign keys
- Criar Lote → chamar `createDefaultEtapas()` → verificar 5 docs em `etapas/` com `ordem` 1-5
- Criar Equipe → verificar documento em `equipes/` com 5 foreign keys
- Tentar ler como não-membro → confirmar permission-denied
- Tentar escrever como membro não-admin → confirmar permission-denied