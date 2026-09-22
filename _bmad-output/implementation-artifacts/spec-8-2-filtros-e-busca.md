---
title: '8.2 Filtros e busca'
type: 'feature'
created: '2026-09-21'
status: 'done'
route: 'dispatch'
baseline_commit: '6f0f2a0d57a605765622536090dc0e607c24a383'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Adm/owner com lista 8.1 carregada não localiza rápido um operário em construtora com muitos membros e obras.

**Approach:** Adicionar na `MembrosScreen` filtro segmentado Todos / Por obra / Pendentes mais busca local por email/displayName e dropdown de obra ativa, filtrando em memória sobre a agregação uid→obras da 8.1 sem nova escrita nem collectionGroup.

## Boundaries & Constraints

**Always:** Rota segue protegida por `AccessGuard(adminOnly:true)`; leitura com cache Firestore via providers 8.1; agregação cliente sem `collectionGroup`; normalizar `member→Operário`, nunca `owner` em obra; filtrar `isActive` no cliente; busca case-insensitive com trim; microcopy pt-br; a11y com anúncio nome/cargo/N/status, papel nunca só por cor, textScale até 1.3x sem quebrar; responsivo via SigoLayout (segmented + busca no topo, dropdown obra, bottomsheet mobile / dialog desktop herdados).

**Never:** Nenhuma escrita neste epic (sem `setMembership`, sem fila offline); não alterar `firestore.rules`, `AccessGuard`/routing nem contratos de cache; não criar `collectionGroup` novo; não incluir detalhe do membro (8.3) nem atribuição/remoção (epics 9/10).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| HAPPY_PATH Todos | Lista 8.1 + filtro Todos sem busca | Pendentes topo + ativos abaixo, subtitle `Cargo · N obras` | N/A |
| Por obra | Seleciono `Por obra` + obra X ativa | Só membros com vínculo ativo em X (junção uid→obras em memória); pendentes excluídos | N/A |
| Pendentes | Seleciono `Pendentes` | Só pedidos pendentes (`Pendente · Cargo`) | N/A |
| Busca ativo | Digito `ana` | Match local `email.contains` lower/trim em ativos; vazio mostra `Nenhum membro encontrado.` | N/A |
| Busca pendente | Digito `ana` com filtro Pendentes ou Todos | Match `email` ou `displayName` do `access_requests` | N/A |
| Dropdown vazio | Nenhuma obra ativa | Dropdown mostra `Nenhuma obra ativa`, seleção Por obra resulta em vazio explícito | N/A |
| Busca sem match | Query sem correspondência | `Nenhum membro encontrado.` | N/A |
| Loading/erro base | Streams 8.1 em loading/erro | Mantém skeleton/erro/retry da 8.1, sem contagem zero falsa | Retry refaz watch |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/construtoras/presentation/membros_screen.dart` -- tela a evoluir; adicionar `SegmentedButton` Todos/Por obra/Pendentes + `SearchBar/TextField` + `DropdownMenu` obra ativa sobre lista 8.1; manter skeleton/erro/vazio/pull-to-refresh.
- `app/lib/src/features/construtoras/presentation/membros_providers.dart` -- adicionar estado local de filtro/busca + helpers puros `filtrarMembros` e `buscarMembros`; reutilizar `membrosProvider`, `pendingRequestsProvider`, `obrasAtivasProvider`, `obraMembersProvider`, `contagemObrasPorMembroProvider`, `agregarContagem`, `apenasObrasAtivas`, `rotuloCargo`, `textoContagemObras`.
- `app/lib/src/features/construtoras/presentation/widgets/member_row.dart` + `role_chip.dart` -- reutilizar sem mudar; lista filtrada segue usando `MemberRow`/`RoleChip`.
- `app/lib/src/features/construtoras/data/membros_repository.dart` -- reutilizar `watchMembros(c)`, `watchPendingRequests(c)`; não mudar.
- `app/lib/src/features/obras/data/obra_repository.dart` -- reutilizar `watchObraMembers(c,o)` com filtro `isActive` cliente; não mudar.
- `app/lib/src/features/construtoras/domain/membro.dart` -- `uid,email,role`; sem `displayName` (busca ativo só por email + fallback UID).
- `app/lib/src/features/obras/domain/obra_member.dart` + `obra.dart` -- `ObraMember{userId,isActive}`, `Obra{isActive}` para junção uid→obras.
- `app/test/features/construtoras/membros_test.dart` -- estender com filtro Por obra/Pendentes, busca email/displayName, trim/case-insensitive, vazio.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/construtoras/presentation/membros_providers.dart` -- criar estado de filtro (`Todos/PorObra/Pendentes` + `obraSelecionada` + `query`) e funções puras de filtro/busca em memória -- isola regra da UI e permite teste unitário.
- [x] `app/lib/src/features/construtoras/presentation/membros_screen.dart` -- compor segmented + busca + dropdown sobre providers 8.1, aplicando filtro/busca no cliente com estados vazio `Nenhum membro encontrado.` / `Nenhuma obra ativa` -- entrega visível da story.
- [x] `app/test/features/construtoras/membros_test.dart` -- cobrir agregação filtrada por obra, exclusão de pendentes em Por obra, busca email/displayName com trim/lower, vazio e dropdown sem obra -- garante matriz I/O.

**Acceptance Criteria:**
- Given lista 8.1 carregada, when seleciono `Por obra` + obra X, then vejo só membros com vínculo ativo em X via junção uid→obras em memória.
- Given lista 8.1 carregada, when digito busca, then vejo match local email (ativos) ou email/displayName (pendentes), e vazio mostra `Nenhum membro encontrado.`.
- Given nenhuma obra ativa, when abro dropdown, then vejo `Nenhuma obra ativa`.
- Given filtro/busca ativos, when dou pull-to-refresh, then lista base atualiza mantendo filtro.

### Review Findings (2026-09-21 — 6f0f2a0..dea3828)

Revisão completa com quatro revisores independentes: blind-hunter, edge-case-hunter, verification-gap e acceptance-auditor. 18 achados individuais, agrupados por causa em 9 itens `patch`; 0 `decision-needed`, 0 `defer`, 0 rejeitados. Nenhuma camada falhou. Usuário autorizou aplicar todos os nove ajustes sem confirmação por item. Correções em andamento; preservar o escopo aprovado e o histórico da revisão.

- [x] [Review][Patch][medium] **P1 — Erro dos vínculos aparece como ausência de membros.** Preservar o erro do stream da obra selecionada e exibir mensagem com recuperação, em vez de `Nenhum membro encontrado.`. A junção transforma erro sem valor em lista vazia e a tela só protege loading. Viola a matriz Loading/erro base. [app/lib/src/features/construtoras/presentation/membros_providers.dart:250; app/lib/src/features/construtoras/presentation/membros_screen.dart:351]
- [x] [Review][Patch][medium] **P2 — Pendentes ainda carregando aparecem como lista vazia.** Quando ativos já chegaram, a proteção de loading da lista base não atua; selecionar Pendentes exibe ausência antes da resposta. Preservar o estado de carregamento nos resultados dependentes de solicitações e testar a emissão posterior. [app/lib/src/features/construtoras/presentation/membros_screen.dart:280; app/lib/src/features/construtoras/presentation/membros_screen.dart:337]
- [x] [Review][Patch][medium] **P3 — Carregamento de outra obra bloqueia busca e filtros.** O estado agregado de todas as obras substitui a tela por skeleton quando a obra escolhida está vazia ou a busca não corresponde. Usar o estado dos vínculos da obra selecionada para decidir carregamento do resultado e manter os controles disponíveis. [app/lib/src/features/construtoras/presentation/membros_screen.dart:247; app/lib/src/features/construtoras/presentation/membros_screen.dart:353]
- [x] [Review][Patch][medium] **P4 — Nome extenso de obra causa overflow no dropdown móvel.** Limitar o conteúdo à largura disponível (`isExpanded: true`) e testar nome longo em largura móvel com escala 1,3. Reprodução em 360 px confirmou RenderFlex overflow de 1299 px. [app/lib/src/features/construtoras/presentation/membros_screen.dart:177]
- [x] [Review][Patch][medium] **P5 — Falta testar refresh preservando filtro, obra e busca.** O teste existente comenta reload, mas só seleciona a obra. Executar pull-to-refresh real, verificar nova leitura/emissão e lista atualizada com filtro, obra selecionada e busca preservados, cobrindo o AC explícito. [app/test/features/construtoras/membros_test.dart:734]
- [x] [Review][Patch][low] **P6 — Falta testar desativação/remoção da obra selecionada.** Cobrir a transição de lista de obras que invalida a seleção e o callback pós-frame: limpar provider/dropdown, mostrar orientação e permitir selecionar outra obra. A ausência desta verificação não demonstra defeito atual na limpeza; deixa esse novo comportamento sem proteção de regressão. [app/lib/src/features/construtoras/presentation/membros_screen.dart:306; app/test/features/construtoras/membros_test.dart:704]
- [x] [Review][Patch][low] **P7 — Lista base vazia elimina os novos controles.** Incluir a barra de filtros no estado sem membros e sem solicitações; hoje não se pode selecionar Por obra nem observar `Nenhuma obra ativa` nessa combinação. [app/lib/src/features/construtoras/presentation/membros_screen.dart:284]
- [x] [Review][Patch][medium] **P8 — Falta testar carregamento dos vínculos após selecionar obra.** Usar stream controlado, selecionar obra antes da primeira emissão, assegurar que não aparece vazio falso e que os membros surgem após a resposta. Os testes atuais cobrem loading do contador em Todos ou lista de obras sem seleção. [app/lib/src/features/construtoras/presentation/membros_screen.dart:353; app/test/features/construtoras/membros_test.dart:364; app/test/features/construtoras/membros_test.dart:811]
- [x] [Review][Patch][medium] **P9 — Falta testar erro de pendentes combinado com filtros.** Verificar supressão do banner em Por obra e preservação do aviso com estado vazio em Todos/Pendentes sem correspondência. A cobertura atual testa erro apenas em Todos com membro visível. [app/lib/src/features/construtoras/presentation/membros_screen.dart:346; app/test/features/construtoras/membros_test.dart:269]

#### Evidências de validação (após P1–P9)

- `flutter analyze`: No issues found (exit 0).
- `flutter test test/features/construtoras/membros_test.dart`: 67/67 All tests passed.
- Patches P1–P9 aplicados e verificados no código (`membros_screen.dart`, `membros_providers.dart`, `membros_test.dart`).

#### Triagem individual antes do agrupamento

| ID | Origem | Achado | Veredito | Evidência / destino |
|---|---|---|---|---|
| 1 | blind-hunter | Erro no vínculo vira vazio | medium | Reprodução de AsyncError sem valor mostra vazio sem aviso; P1. |
| 2 | blind-hunter | Pendentes carregando aparecem inexistentes | medium | Ativos carregados evitam guarda totalBase; reprodução confirma vazio em Pendentes; P2. |
| 3 | blind-hunter | Outra obra bloqueia controles | medium | Meta agrega todos os streams; reprodução com obra selecionada vazia e outra em loading remove controles; P3. |
| 4 | blind-hunter | Dropdown com nome longo transborda | medium | Reprodução móvel com escala 1,3 confirma overflow do dropdown; P4. |
| 5 | blind-hunter | Teste de reload não executa reload | medium | Leitura do teste confirma apenas seleção e pumpAndSettle; AC de refresh sem cobertura; P5. |
| 6 | blind-hunter | Remoção da obra selecionada sem teste | low | Fixtures estáticas não exercitam callback após alteração da lista; risco de regressão da limpeza; P6. |
| 7 | blind-hunter | Base vazia remove controles | low | Retorno antes da barra confirmado em teste; P7. |
| 8 | edge-case-hunter | Erro dos vínculos ocultado | medium | Mesmo erro terminal reproduzido no P1; P1. |
| 9 | edge-case-hunter | Pendentes em loading viram vazio | medium | Mesma combinação de ativos carregados e pendentes sem resposta; P2. |
| 10 | edge-case-hunter | Outra obra bloqueia busca | medium | Skeleton depende do agregado, não da obra selecionada; P3. |
| 11 | edge-case-hunter | Nome longo excede largura | medium | Overflow reproduzido após construir dropdown; P4. |
| 12 | verification-gap | Loading dos vínculos selecionados sem teste | medium | Evidência pré-verificada: testes 364/811/704 não exercitam combinação; P8. |
| 13 | verification-gap | Erro de pendentes com filtros sem teste | medium | Evidência pré-verificada: teste 269 permanece em Todos com ativo; P9. |
| 14 | verification-gap (other) | Erro de vínculos vira vazio | medium | Inspeção e reprodução confirmam erro sem valor descartado; P1. |
| 15 | verification-gap (other) | Pending loading com ativos vira vazio | medium | Inspeção e reprodução confirmam guarda insuficiente; P2. |
| 16 | acceptance-auditor | Erro não preserva matriz Loading/erro | medium | Erro terminal de vínculos não chega a mensagem/retry da lista; P1. |
| 17 | acceptance-auditor | Pendentes não preserva loading | medium | Estado sem resposta é apresentado como ausência; P2. |
| 18 | acceptance-auditor | Base vazia impede estado sem obras | low | Barra ausente impossibilita Por obra nesta combinação; P7. |

#### Rejected

Nenhum achado rejeitado nesta rodada. As repetições foram agrupadas somente após veredito individual; achados e refutações históricos anteriores permanecem preservados abaixo.

## Implementation Notes

- Correções P1–P9: a tela consulta o estado assíncrono do vínculo da obra selecionada para apresentar carregamento/erro com recuperação; mantém filtros em resultados vazios e aguardando resposta; dropdown usa largura disponível.
- Validação das correções: `flutter analyze` sem problemas e `flutter test test/features/construtoras/membros_test.dart` com 48 testes aprovados (10 cenários adicionais), incluindo retry com nova leitura, streams controlados, gesto real de refresh, remoção/desativação e erros combinados.
- Limitação visual preexistente fora dos nove ajustes: ao montar a tela completa em 360 px e escala 1,3, as ações do `AppBar` em `app/lib/src/common_widgets/sigo_top_bar.dart:88` geraram `RenderFlex overflowed by 42 pixels on the right`. O teste de regressão P4 valida o dropdown real extraído da tela em um Scaffold de 360 px/escala 1,3, fechado e aberto, sem suprimir exceções. Isso comprova o ajuste do dropdown, não valida toda a tela nessa configuração; o componente global não foi alterado.

## Spec Change Log

## Review Triage Log

- B1 busca-nome-ativo | verdict: false | evidência: `Membro` não tem `displayName`, spec manda email-only ativos e email/displayName pendentes; label `email ou nome` cobre ambos os tipos.
- B2 dropdown-initialValue | verdict: medium | evidência: `membros_screen.dart:178` usa `initialValue`, FormField não atualiza exibição após `selecionar()` ou reload de obras; troca para `value` é correção direta.
- B3 mapa-parcial-vazio-falso | verdict: medium | evidência: `membros_providers.dart:247,250-257` usa `.value ?? []`, `filtrarMembros` com mapa parcial retorna `[]` e mostra `Nenhum membro encontrado.` durante loading.
- B4 porobra-sem-selecao-mesmo-vazio | verdict: low | evidência: `membros_screen.dart:279-281` sem obra cai no mesmo `Nenhum membro encontrado.` de sem-match; falta orientação `Selecione uma obra`.
- B5 obra-selecionada-stale | verdict: low | evidência: `obraSelecionadaProvider` global sem reset quando obra sai de `obrasAtivas`; `selecionadaValida` mascara mas filtro fica preso em vazio.
- B6 controller-query-dessinc | verdict: false | evidência: `_buscaController` e `buscaMembrosProvider` têm mesmo ciclo de vida da tela; `autoDispose` só limpa com tela descartada, sem stale observado.
- B7 acento-debounce-perf | verdict: false | evidência: spec manda só trim/lower, lista pequena sem requisito de acento/debounce; otimização especulativa sem dano nomeado.
- B8 dropdown-buscavel-layout | verdict: false | evidência: spec pede `Dropdown` de obra ativa, sem requisito de busca interna ou limite desktop; enhancement fora do intent.
- B9 uid-curto-doc | verdict: false | evidência: código usa `UID: uid` completo e testes cobrem; mismatch é só doc `UID:curto` e fix seria editar spec, rejeitado por regra.
- E1 segmented-empty-first | verdict: false | evidência: `SegmentedButton` com `emptySelectionAllowed=false` default nunca entrega seleção vazia; `.first` seguro.
- E2 autodispose-query-reset | verdict: false | evidência: duplicata de B6, mesmos ciclos de vida; sem cenário que resete provider com controller vivo.
- E3 stream-loading-some | verdict: medium | evidência: duplicata de B3, mesma causa `.value ?? []` em `uidObrasPorMembroProvider`.
- E4 obra-removida-hint | verdict: low | evidência: duplicata de B5, mesma causa obra inválida sem `limpar()`.
- E5 vazio-com-erro-pendente | verdict: medium | evidência: `membros_screen.dart:299` pula ramo vazio quando `pendingErro=true`, com `totalFiltrado==0` renderiza só filtro + banner sem `Nenhum membro encontrado.`.
- V1 fanout-loading-falso | verdict: medium | evidência: verification-gap pré-verificada; nenhum teste monta `obraMembers` loading com Por obra selecionado.
- V2 dropdown-loading-erro-sem-teste | verdict: medium | evidência: verification-gap pré-verificada; nenhum teste monta obras loading/erro com Por obra.
- V3 limpar-busca-sem-teste | verdict: medium | evidência: verification-gap pré-verified; nenhum teste toca `Limpar busca` para restaurar lista.
- V4 erro-pendente-filtro-sem-teste | verdict: medium | evidência: verification-gap pré-verificada; nenhum teste combina pendente erro com Por obra ou sem-match.

## Design Notes

Junção em memória: `contagemObrasPorMembro` já agrega `uid→N`; filtro Por obra usa o detalhe `uid→[obraIds]` da mesma fonte para `members.where(uid em obra X)`. Pendentes nunca têm obra, logo somem em Por obra e são exclusivos em Pendentes. Busca ativos: `email.toLowerCase().trim().contains(q)` com fallback `UID:curto` quando email vazio; pendentes: `email` ou `displayName` do map. Exemplo: query `ana` acha `Ana@obra.com` e pendente `{displayName: Ana Souza}`.

## Verification

**Commands:**
- `flutter analyze` -- expected: No issues found
- `flutter test test/features/construtoras/membros_test.dart` -- expected: All tests passed
