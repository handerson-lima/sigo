---
title: '8.3 Detalhe do membro'
type: 'feature'
created: '2026-09-21'
status: 'done'
route: 'dispatch'
baseline_commit: '39ef70436128668d4994bf23f0815ce19b17d4b2'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Adm/owner vê a lista 8.1/8.2 com cargo e N obras, mas não consegue abrir o detalhe de um membro para ver vínculo da construtora (cargo, status, desde quando) e obras vinculadas antes de decidir atribuição ou gestão (epics 9/10).

**Approach:** Ligar `onTap` nas `MemberRow` ativas para abrir `MemberDetalheSheet` — `BottomSheet` arrastável ~70% no mobile (`<800px`) ou `Dialog 480px` no desktop — com blocos Vínculo construtora (dados de `construtora_members/{uid}` via `ConstrutoraRepository.getMember`), Obras vinculadas (`ObraVinculoRow` a partir de `uidObrasPorMembro` + `obrasAtivas` + `obraMembers`) e Ações; somente leitura, sem escrita.

## Boundaries & Constraints

**Always:** Rota segue `AccessGuard(adminOnly:true)`; leitura com cache Firestore (`cachedRead`/streams já usados); sem `collectionGroup`; normalizar `member→Operário`, nunca `owner` como papel de obra; pendente não abre detalhe (tap pendente sem `onTap`); microcopy pt-br (`Detalhe de {email}`, `Nenhuma obra vinculada — Atribuir`, `Ative na construtora primeiro`); a11y anuncia nome, cargo, N obras, status; chips com `Semantics` e ícone+texto; textScale até 1.3x sem overflow; responsivo: BottomSheet mobile / Dialog 480px desktop (breakpoint 800px, mesmo de `SigoLayout`); `Card elevation 1` só no resumo do detalhe; dialogs `r=16px`; não expor `uid` cru (só fallback `UID:`).

**Never:** Nenhuma escrita neste epic (sem `setMembership`, sem fila offline, sem `AtribuirObraDialog` funcional); não alterar `firestore.rules`, `AccessGuard`/routing nem contratos de cache 8.1/8.2; não criar `collectionGroup` novo; não implementar atribuição/remoção/troca de papel (epics 9/10); não tratar `owner` como papel de obra; não abrir detalhe de pendente.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| HAPPY_PATH detalhe | Admin toca membro ativo da lista | BottomSheet/Dialog `Detalhe de {email}` com bloco vínculo (cargo, status Ativo/Inativo, desde quando via `joinedAt`), bloco obras (`ObraVinculoRow`: nome + papel obra + status) e bloco ações | N/A |
| Sem obra | Membro ativo com 0 obras | `Nenhuma obra vinculada — Atribuir` no bloco obras | N/A |
| Membro inativo | `construtora_members/{uid}.isActive==false` | Aviso inline `Ative na construtora primeiro` (AD-9); ações de atribuição bloqueadas | N/A |
| Loading vínculo | `getMember` em andamento | Spinner no sheet (não vazio falso) | — |
| Erro vínculo | Falha ao ler `construtora_members/{uid}` | Mensagem de erro + Retry no sheet | Retry refaz leitura |
| Pendente | Linha de pendente na lista | Sem `onTap`/sem chevron; não abre detalhe | N/A |
| Obras loading | `uidObrasPorMembro`/`obraMembers` em loading | Skeleton/spinner no bloco obras, sem `Nenhuma obra vinculada` falso | — |
| Obras erro | Stream de obras em erro | Erro + Retry no bloco obras (padrão 8.2: não virar vazio) | Retry refaz watch |
| A11y | Leitor de tela no sheet | Anuncia nome, cargo, N obras, status; foco no dialog; Esc fecha | N/A |
| textScale 1.3 | Escala máxima | Sem overflow em CTA, chips ou `ObraVinculoRow` | N/A |

**Decisões (aprovadas pelo humano):**
- Bloco Ações: botões visíveis porém desabilitados (`onPressed: null`) com dica `Disponível em breve` — placeholder honesto que prepara os epics 9/10 sem simular efeito.
- CTA `Atribuir` e overflow `ObraVinculoRow` (Trocar papel, Remover): ocultos como controles interativos na 8.3. Estado vazio mantém a microcopy congelada `Nenhuma obra vinculada — Atribuir` como texto estático (sem botão acionável); menu overflow só entra no epic 10.

</frozen-after-approval>

## Code Map

- `app/lib/src/features/construtoras/presentation/membros_screen.dart` -- adicionar `onTap` nas `MemberRow` ativas (linhas de ativos ~:460-466); pendentes permanecem sem onTap; chamar `MemberDetalheSheet.show(context, membro)`; não mudar filtros/busca 8.2.
- `app/lib/src/features/construtoras/presentation/widgets/member_row.dart` -- reusar como está; `onTap` já controla chevron/`Semantics(button)` (:10-28, :58-60, :88-91, :95).
- `app/lib/src/features/construtoras/presentation/widgets/role_chip.dart` -- reusar `RoleChip`/`papelDe` no sheet e linhas de obra.
- `app/lib/src/features/construtoras/presentation/member_detalhe_sheet.dart` -- **novo**: widget estático `show` que decide BottomSheet (`isScrollControlled`, drag, ~70%) vs `Dialog` `SizedBox(width: 480)` por breakpoint `>800`; blocos Vínculo / Obras / Ações; padrões de sheet inspirados em `rateio_lotes_sheet.dart:24-49`; dialog 480px como `chamada_audit_timeline_dialog.dart:27-28`.
- `app/lib/src/features/construtoras/presentation/widgets/obra_vinculo_row.dart` -- **novo**: `ObraVinculoRow` (nome obra + papel obra + status Ativo/Inativo; **sem overflow menu na 8.3** — decidido); estado vazio estático `Nenhuma obra vinculada — Atribuir` (sem botão acionável).
- `app/lib/src/features/construtoras/presentation/membros_providers.dart` -- adicionar `FutureProvider.autoDispose.family` (ou stream) para `ConstrutoraMember` do uid aberto, usando `ConstrutoraRepository.getMember(c, uid)` (já com `cachedRead`); reusar `membrosProvider`, `uidObrasPorMembroProvider`, `obrasAtivasProvider`, `obraMembersProvider`, `contagemObrasPorMembroProvider`, `rotuloCargo`, `textoContagemObras`.
- `app/lib/src/features/construtoras/data/construtora_repository.dart` -- reusar `getMember` (:19-27) sem mudar; fonte de `joinedAt`/`isActive`/cargos do bloco vínculo.
- `app/lib/src/features/construtoras/data/membros_repository.dart` -- reusar `watchMembros`/`watchPendingRequests`; não mudar.
- `app/lib/src/features/construtoras/domain/construtora_member.dart` -- `joinedAt`, `isActive`, `isOwner`, `isAdmin` para status/desde quando/cargo.
- `app/lib/src/features/construtoras/domain/membro.dart` -- `uid,email,role,isAdmin,isOwner` para título e cargo da lista.
- `app/lib/src/features/obras/domain/obra_member.dart` + `obra.dart` -- `ObraMember{userId,isAdmin,modules,joinedAt,isActive}`, `Obra{id,name,isActive}` para `ObraVinculoRow`.
- `app/lib/src/common_widgets/sigo_layout.dart` -- breakpoint `isDesktop = maxWidth > 800` (:25); espelhar no sheet (não mudar o arquivo).
- `app/lib/src/sync/read_cache.dart` -- leitura cache já usada por `getMember`; não mudar.
- `app/test/features/construtoras/membros_test.dart` -- estender com `group('8.3 ...')`: abertura do sheet, blocos, vazio, inativo, loading/erro, a11y, textScale; padrão de overrides `base82()` já existente (:669+).

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/construtoras/presentation/member_detalhe_sheet.dart` -- criar `MemberDetalheSheet.show` com responsivo BottomSheet/Dialog, blocos Vínculo (cargo, status, desde quando), Obras e Ações, estados loading/erro/vazio/inativo -- entrega visível da story.
- [x] `app/lib/src/features/construtoras/presentation/widgets/obra_vinculo_row.dart` -- criar `ObraVinculoRow` (nome, papel, status; sem overflow na 8.3) + estado vazio estático `Nenhuma obra vinculada — Atribuir` -- UX-DR3.
- [x] `app/lib/src/features/construtoras/presentation/membros_providers.dart` -- adicionar provider do `ConstrutoraMember` por uid (via `getMember`) e helpers de formatação de `joinedAt` -- dados do bloco vínculo sem acoplar à UI.
- [x] `app/lib/src/features/construtoras/presentation/membros_screen.dart` -- ligar `onTap` só em ativos para abrir o sheet; manter pendentes inertes -- fluxo de abertura.
- [x] `app/test/features/construtoras/membros_test.dart` -- cobrir matriz I/O: abertura, vínculo, obras, vazio, inativo, loading/erro, não-abertura de pendente, a11y básica e textScale 1.3 -- garante ACs.

**Acceptance Criteria:**
- Given um membro ativo na lista, when toco na linha, then abre BottomSheet (mobile) / Dialog 480px (desktop) com bloco vínculo (cargo, status, desde quando) + bloco obras (`ObraVinculoRow`) + ações (UX-DR3).
- Given membro sem obras, when abro o detalhe, then vejo `Nenhuma obra vinculada — Atribuir`; given membro inativo, then vejo aviso `Ative na construtora primeiro` (AD-9).
- Given leitor de tela, when navego no detalhe, then ouço nome, cargo, N obras e status (NFR4).
- Given linha de pendente, when toco, then o detalhe não abre.

## Implementation Notes

- Implementação inicial (baseline 39ef704): `MemberDetalheSheet`, `ObraVinculoRow`, provider `memberDetalheProvider`, onTap na lista, 16 testes 8.3. `flutter analyze` limpo; 63 testes passando.
- Review 2026-09-21 (3 camadas): 14 patches + 1 defer; 6 rejeitados. Patches em processamento.

## Spec Change Log

## Review Triage Log

- B1 getMember-null-como-erro | verdict: low | evidência: doc ausente vira `_vinculoErro`+Retry em `member_detalhe_sheet.dart:211-212`; alcançável só com delete concorrente; retry futil mas dano mínimo.
- B2 a11y-contagem-zero-loading | verdict: medium | evidência: sheet usa `contagem[uid]??0` no label (`member_detalhe_sheet.dart:91,100`) sem variantes `carregando obras`/`erro ao carregar obras` que a lista tem (`membros_screen.dart:456-460`); anuncia vazio falso.
- B3 cargo-dual-source | verdict: medium | evidência: a11y usa `rotuloCargo(membro)` (:90) e chip usa `rotuloCargoFlags(vinculo)` (:215-218); cache vs `getMember` pode divergir e o leitor contradiz o chip.
- B4 indent-8.2 | verdict: low | evidência: `membros_test.dart:1107` com indent 8 vs 6 dos vizinhos; só cosmético.
- B5 retry-obras-stale | verdict: medium | evidência: `_retryObras` lê `obrasAtivasProvider.value` após invalidate (:393-394); com erro sem valor o loop de `obraMembers` não roda — mesmo root cause do VG1.
- B6 status-chip-dup | verdict: false | evidência: duplicação sem divergência demonstrada; sem chamado de trouble concreto.
- B7 sprint-status-desalinhado | verdict: low | evidência: spec `in-review` vs sprint-status `in-progress` para `8-3-detalhe-do-membro`.
- B8 matrix-gaps | verdict: false | evidência: correção exigiria editar a matriz congelada — rejeitado (fix = editar spec).
- B9 breakpoint-800 | verdict: low | evidência: Intent congelado manda mobile `<800`; código usa `>800` (`member_detalhe_sheet.dart:36`), então largura exata 800 abre BottomSheet; caso-limite raro.
- B10 AC-omitem-decisoes | verdict: false | evidência: fix = editar AC dentro do bloco congelado — rejeitado.
- B11 testes-vacuos | verdict: medium | evidência: `find.widgetWithText(FilledButton,'Atribuir')` nunca casa `'Atribuir à obra'` (:1249); `find.text('Nenhuma obra vinculada') findsNothing` (:1543) passa mesmo se o label correto sumir; `onPressed isNull` do inativo é true para todos (:1265-1268).
- B12 textScale-fora-do-shell | verdict: medium | evidência: teste monta `MemberDetalheSheet` cru no Scaffold (:1528-1536), não passa por `show()`/BottomSheet 70%/Dialog 480 — overflow do shell real não coberto.
- B13 word-ativas-ambigua | verdict: false | evidência: fix = editar prosa da spec — rejeitado.
- B14 matrix-inativo-enganosa | verdict: false | evidência: fix = editar matriz congelada — rejeitado.
- B15 dica-disponivel-sem-associacao | verdict: low | evidência: `'Disponível em breve'` é `Text` solto (:161-166), não description dos botões disabled; SR pode não anunciar junto.
- B16 verification-sem-resultados | verdict: low | evidência: seção Verification só com `expected:`, sem evidência de execução no artefato.
- B17 semantics-duplo-aviso/vazio | verdict: low | evidência: `ObraVinculoVazio` (:19-27) e aviso inativo (:244-265) usam `Semantics(label:)` sem `excludeSemantics` sobre `Text` com a mesma string (diferente de `_statusChip`/`ObraVinculoRow`).
- B18 spec-ObraMember-role | verdict: false | evidência: fix = editar Code Map da spec — rejeitado; código usa `isAdmin` corretamente.
- B19 testes-owner-admin-uid | verdict: medium | evidência: filha de VG2+VG3 — caller do chip e fallback `UID:` no título sem teste de widget.
- E1 a11y-contagem-zero | verdict: medium | evidência: duplicata de B2.
- E2 cargo-lista-vs-chip | verdict: medium | evidência: duplicata de B3.
- E3 offline-loading-infinito | verdict: maybe-false | evidência: se stream de obras não emitir offline sem cache, `meta.carregando` fica true sem timeout no sheet; settles: teste com stream que não emite + expect de erro/timeout, ou evidência de comportamento Firestore offline.
- E4 obra-name-vazio | verdict: low | evidência: `ObraVinculoRow` renderiza `obra.name` cru (:71); nome `''` → linha em branco.
- E5 breakpoint-800 | verdict: low | evidência: duplicata de B9.
- VG1 retry-obras-sem-teste-obraMembers | verdict: medium | evidência: pré-verificada — apagar loop `obraMembers` de `_retryObras` e os testes 8.3 continuam verdes; erro em `obraMembers` com obras ok não é coberto.
- VG2 chip-cargo-sem-caller | verdict: medium | evidência: pré-verificada — helper coberto, todo teste 8.3 abre sheet só com operário; literal `'Operário'` no sheet não falha suíte.
- VG3 uid-fallback-sem-teste | verdict: medium | evidência: pré-verificada — fallback `_titulo` `UID:` sem teste no sheet; remover fallback não falha suíte.
- VG-other a11y-contagem | verdict: medium | evidência: duplicata de B2.

**Rejected:** B6, B8, B10, B13, B14, B18 (regras de rejeição: spec congelado / sem harm nomeado).

**Agrupamentos roteados:**
- patch [medium] a11y-contagem-loading-erro: B2+E1+VG-other
- patch [medium] cargo-dual-source: B3+E2
- patch [medium] retry-obras-obraMembers: B5+VG1
- patch [medium] testes-vacuos: B11
- patch [medium] textScale-shell: B12
- patch [medium] testes-owner-admin-uid: B19+VG2+VG3
- patch [low] getMember-null: B1
- patch [low] indent: B4
- patch [low] sprint-status: B7
- patch [low] breakpoint->=800: B9+E5
- patch [low] dica-a11y-acoes: B15
- patch [low] verification-resultados: B16
- patch [low] semantics-duplo: B17
- patch [low] obra-name-vazio: E4
- defer [medium unverified] offline-loading-sheet: E3

## Design Notes

Breakpoint único 800px igual a `SigoLayout.isDesktop`. Vínculo: `getMember` devolve `ConstrutoraMember` (server + cache); cargo = `RoleChip.papelDe(isOwner, isAdmin)` + `rotuloCargo`; status = `Ativo`/`Inativo` a partir de `isActive`; desde quando = `joinedAt` formatado pt-br. Obras: interseção `uidObrasPorMembro[uid]` ∩ `obrasAtivas`, papel da obra via `obraMembers` (normalizar `member→Operário`, nunca owner). Loading/erro do vínculo e das obras tratados como AsyncValue distintos — nunca `.value ?? []` que vira vazio falso (lição P1/P2 da revisão 8.2).

## Verification

**Commands:**
- `flutter analyze` -- expected: No issues found — actual: No issues found (exit 0)
- `flutter test test/features/construtoras/membros_test.dart` -- expected: All tests passed — actual: 63/63 All tests passed
