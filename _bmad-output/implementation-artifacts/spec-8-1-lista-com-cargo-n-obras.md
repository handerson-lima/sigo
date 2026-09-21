---
title: '8.1 Lista com Cargo · N obras'
type: 'feature'
created: '2026-09-21'
status: 'done'
route: 'dispatch'
baseline_commit: 'bd223c476c02abb3270c10b683899485203e3404'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Adm/owner da construtora não enxerga cargo e quantidade de obras por membro antes de atribuir, o que dificulta saber quem está alocado onde.

**Approach:** Evoluir a rota `/construtora/:cId/membros` para combinar `watchMembros(c)` + `watchPendingRequests(c)` + agregação cliente `watchObraMembers(c,o)` por obra ativa, exibindo pendentes no topo e ativos com subtitle `Cargo · N obras` e avatar/chip do DESIGN.md.

## Boundaries & Constraints

**Always:** Rota protegida por `AccessGuard(adminOnly:true)`; agregação no cliente sem `collectionGroup`; normalizar leitura `member→Operário`, nunca `owner` em obra; pendentes no topo (`Pendente · Cargo`), ativos abaixo (`Cargo · N obras` com singular/plural); tokens RoleChip/Avatar do DESIGN.md; microcopy pt-br; leitura com cache Firestore; a11y com anúncio nome/cargo/N/status e alvos 48dp; responsivo via SigoLayout.

**Never:** Nenhuma escrita neste epic (sem `setMembership`, sem fila offline); não alterar `firestore.rules` de escrita nem `AccessGuard`/routing; não criar `collectionGroup` novo; não tratar `owner` como papel de obra; não incluir filtros/busca (8.2) nem detalhe (8.3).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| HAPPY_PATH lista | Admin logado abre `/construtora/:cId/membros` com 1 pendente + 2 ativos (1 com 2 obras, 1 com 0) | Pendente no topo `Pendente · Operário`; ativos abaixo `Operário · 2 obras` e `Administrador · Nenhuma obra vinculada` | N/A |
| Singular/plural | Membro com 1 obra ativa | Subtitle `Operário · 1 obra` | N/A |
| Vazio | Nenhum membro nem pendente | `Nenhum membro encontrado.` | N/A |
| Erro leitura | Falha stream membros | Tela erro com mensagem + botão Retry | Retry refaz watch |
| Offline leitura | Sem conexão com cache válido | Mostra último cache; sem cache mostra `Sem conexão — tente novamente` | Sem fila/enqueue |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/construtoras/presentation/membros_screen.dart` -- tela atual a evoluir; já tem `membrosProvider`, `pendingRequestsProvider`, ordenação pendente-topo, avatar owner/admin.
- `app/lib/src/features/construtoras/data/membros_repository.dart` -- reutilizar `watchMembros(c)`, `watchPendingRequests(c)`; não mudar escrita via Functions.
- `app/lib/src/features/obras/data/obra_repository.dart` -- adicionar `watchObraMembers(c,o)` plural (hoje só `watchObraMember` singular); reutilizar `_membersRef(c,o)`, `Obra.isActive`.
- `app/lib/src/features/obras/presentation/construtora_obras_provider.dart` -- reutilizar/adaptar para `obrasDaConstrutoraProvider(c)` filtrando `isActive==true`.
- `app/lib/src/routing/app_router.dart` -- rota já protegida, não mudar.
- `app/lib/src/common_widgets/access_guard.dart` + `sigo_layout.dart` -- guard e layout responsivo, não mudar.
- `app/lib/src/features/obras/domain/obra_member.dart` + `obra.dart` -- modelos `ObraMember{userId,isActive}`, `Obra{isActive}`.
- `app/lib/src/features/construtoras/domain/membro.dart` -- `Membro{uid,isAdmin,isOwner}`, não mudar lógica de role.
- `app/lib/src/sync/read_cache.dart` -- `cachedList/cachedDocument` para leitura.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/obras/data/obra_repository.dart` -- adicionar `Stream<List<ObraMember>> watchObraMembers(c,o)` filtrando `isActive` no cliente -- base da agregação sem collectionGroup.
- [x] `app/lib/src/features/construtoras/presentation/membros_providers.dart` -- criar `obraMembersProvider((c,o))` + `obrasAtivasProvider(c)` + `contagemObrasPorMembroProvider(c)` com junção em memória `uid→[obras]` -- isola agregação da UI.
- [x] `app/lib/src/features/construtoras/presentation/widgets/role_chip.dart` + `member_row.dart` -- extrair `RoleChip` (tokens owner âmbar stars/admin azul/operário neutro/pendente laranja, ícone+texto, r=12) e `MemberRow` (avatar 40px, title, subtitle, trailing chip+chevron, semantics) -- reuso em 8.2/8.3.
- [x] `app/lib/src/features/construtoras/presentation/membros_screen.dart` -- reescrever lista para usar contagem, pendentes topo, subtitle `Cargo · N obras`, estados loading skeleton/erro retry/vazio, pull-to-refresh com invalidate -- entrega visível da story.
- [x] `app/test/*membros*` -- cobrir agregação uid→N, ordenação pendente-topo, singular/plural e filtro isActive -- garante edge cases da matriz.

**Acceptance Criteria:**
- Given logado como admin ou owner com `AccessGuard(adminOnly:true)` liberado, when abro `/construtora/:cId/membros`, then vejo pendentes no topo (`Pendente · Cargo`) e ativos abaixo com subtitle `Cargo · N obras`.
- Given lista carregada, when membro tem 0/1/N obras ativas, then subtitle mostra `Nenhuma obra vinculada` / `1 obra` / `N obras` com avatar/chip do DESIGN.md.
- Given lista base, when dou pull-to-refresh, then providers de membros e de membros por obra são invalidados e lista atualiza.
- Given leitor de tela ativo, when navego na linha, then ouço nome, cargo, N obras e status.

## Implementation Notes

## Spec Change Log

## Review Triage Log

- B1 invalidate-lê-após-invalidar | verdict: medium | evidência: `membros_screen.dart:24-25` lê `.value` após `invalidate`, loop pula e `obraMembers` fica stale.
- B2 contagem-zero-no-loading | verdict: medium | evidência: `membros_providers.dart:80,83-90` usa `.value ?? []`, exibe `Nenhuma obra vinculada` antes de carregar.
- B3 pending-erro-ignorado | verdict: medium | evidência: `membros_screen.dart:79` usa `pendingAsync.value ?? []`, erro do pendente some silencioso.
- B4 chevron-sem-ontap | verdict: low | evidência: `member_row.dart:85` mostra chevron sempre, mesmo com `onTap==null` na 8.1.
- B5 emoji-semantics-dupla | verdict: low | evidência: `role_chip.dart:36` prefixa `⏳` além do ícone e `Semantics` aninhada anuncia duas vezes.
- B6 watchObras-duplicado | verdict: low | evidência: `membros_providers.dart:40-63` assina `watchObras` 2x com chaves `obras`/`obras-ativas`, leitura e cache dobrados.
- B7 dedup-por-obra | verdict: false | evidência: doc id `members/{uid}` é único por obra, duplicado intra-obra não ocorre.
- B8 orderby-paginacao-server | verdict: false | evidência: lista pequena de membros/obras, sem requisito de ordenação/paginação no intent; `where isActive` server é otimização, não defeito.
- B9 displayName-ativo | verdict: false | evidência: `Membro` não tem `displayName`, só `email/uid`; fallback atual é o possível.
- B10 scroll-physics-erro-bruto | verdict: medium | evidência: `ListView` sem `AlwaysScrollableScrollPhysics` impede pull com pouco conteúdo; `Erro: $err` vaza exceção.
- B11 cobertura-composicao | verdict: medium | evidência: testes mockam `contagem` final, fan-out real não executa; gap real coberto por V1-V3.
- E1 pending-nonstring-crash | verdict: low | evidência: `req['role'] as String?` quebra se Firestore tiver int; dado controlado mas guard é correção direta.
- E2 displayName-whitespace | verdict: low | evidência: `isNotEmpty` sem `trim` permite título em branco.
- E3 email-whitespace | verdict: low | evidência: `membro.email.isNotEmpty` sem `trim` esconde fallback UID.
- E4 pending-loading-erro-some | verdict: medium | evidência: duplicata de B3, pendente some no loading/erro.
- E5 obras-loading-zero | verdict: medium | evidência: duplicata de B2.
- E6 pull-curto-nao-dispara | verdict: medium | evidência: duplicata de B10 (physics).
- E7 invalidate-ordem | verdict: medium | evidência: duplicata de B1.
- E8 role-uppercase | verdict: low | evidência: roles gravadas minúsculas via Functions, mas `toLowerCase` é correção direta.
- E9 dup-userId-infla | verdict: false | evidência: duplicata de B7, impossível por doc id.
- E10 cache-uid-nonstring | verdict: low | evidência: `map['uid'] as String?` quebra se cache corrompido; guard direto.
- E11 stale-apos-refresh-claim | verdict: medium | evidência: duplicata de B1, contagem stale sobrevive ao refresh.
- V1 fanout-sem-teste | verdict: medium | evidência: verification-gap pré-verificada; nenhum teste monta `obrasAtivas+obraMembers→contagem`.
- V2 retry-sem-assert | verdict: medium | evidência: verification-gap pré-verificada; tap Retry sem assert de refetch.
- V3 cachedList-sem-roundtrip | verdict: medium | evidência: verification-gap pré-verificada; `encode/decode` novos nunca executam.

## Design Notes

Agregação cliente: base `watchMembros` + `watchPendingRequests`, depois um `watchObraMembers` por obra ativa filtrada (`isActive==true`), junção `uid→count` em memória. Exemplo subtitle: `Operário · 2 obras`, `Administrador · 1 obra`, pendente `⏳ Pendente · Operário`. Não usar `collectionGroup` (AD-5).

## Verification

**Commands:**
- `flutter analyze` -- expected: No issues found
- `flutter test test/features/construtoras/membros_test.dart` -- expected: All tests passed
