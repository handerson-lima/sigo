---
title: 'Trocar cargo na construtora e desativar membro (Epic 10.3)'
type: 'feature'
created: '2026-09-22'
status: 'draft'
baseline_commit: ''
route: 'dispatch'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Os botões `Trocar cargo` e `Desativar` no detalhe do membro (bloco Ações) estão desabilitados desde a Epic 8.3 como stubs para futuras stories. O admin/owner não consegue trocar o cargo do membro na construtora (`operario`↔`admin`) nem desativá-lo (desativando todos os vínculos de obra simultaneamente).

**Approach:** Ativar os dois botões do bloco Ações em `MemberDetalheSheet`: (1) **Trocar cargo** — abre dialog com `DropdownButtonFormField` (`Operário`/`Administrador`; `Proprietário` apenas se `trustedDev`), pré-selecionado com o cargo atual, chama `setConstrutoraRole{role}`; (2) **Desativar** — confirm destructiva listando N obras afetadas, executa N chamadas `setMembership{obraId, isActive:false}` + 1 `setConstrutoraRole{isActive:false}` em paralelo, exibe indicador de progresso; ambas invalidam providers e exibem snackbar pt-br.

## Boundaries & Constraints

**Always:**
- Toda mutação passa por `MembrosRepository.setConstrutoraRole` ou `ObraMembersRepository.setMembership`. Nenhuma escrita direta no Firestore.
- Roles válidos para `setConstrutoraRole`: `operario` e `admin`. `owner` apenas quando `trustedDev == true`.
- Pré-check offline antes de disparar qualquer CF (padrão Epic 9); dialog permanece aberta em caso de erro com mensagem mapeada pt-br.
- Após sucesso invalidar `membrosProvider(construtoraId)` + `memberDetalheProvider((construtoraId, uid))`.
- Na desativação, N chamadas `setMembership{obraId, isActive:false}` + 1 `setConstrutoraRole{isActive:false}`; sem atomicidade; docs órfãos são inócuos enquanto gate `active(cm)` vigorar.
- Alvos ≥48dp; foco trap e `Esc` fecham dialog; `semanticsLabel` cobre ação e nome do membro.
- Indicador de progresso durante a desativação; nenhuma ação interrompida por timeout silencioso.

**Never:**
- Não implementar Trocar papel/módulos em obra (já feito em 10.1/10.2).
- Não criar novo StreamProvider ou endpoint; reutilizar `MembrosRepository.concederAcesso` / adicionar método `setCargo` em `MembrosRepository` para encapsular `setConstrutoraRole`.
- Não fechar dialog de Trocar cargo em caso de erro — manter aberta com mensagem.
- Não oferecer `owner` como opção sem o flag `trustedDev`.
- Não usar fila offline para estas escritas (mesma decisão do Epic 9).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Trocar cargo: admin → operário | Vínculo com `isAdmin:true`, seleciona `Operário` e confirma | `setConstrutoraRole{role:'operario'}` chamado; snackbar `Cargo atualizado.`; chip de cargo reflete Operário | — |
| Trocar cargo: operário → admin | Vínculo com `isAdmin:false`, seleciona `Administrador` e confirma | `setConstrutoraRole{role:'admin'}` chamado; snackbar `Cargo atualizado.`; chip reflete Administrador | — |
| Trocar cargo: offline | Dispositivo sem conexão ao confirmar | Dialog mantida aberta, mensagem `Sem conexão. Verifique sua internet e tente novamente.` | Sem fechar dialog |
| Trocar cargo: permission-denied | CF retorna `permission-denied` | Dialog mantida aberta, mensagem `Você não tem permissão para realizar esta atribuição.` | Sem fechar dialog |
| Trocar cargo: owner visível com trustedDev | `trustedDevProvider` = true | Dropdown exibe 3 opções: Operário, Administrador, Proprietário | — |
| Trocar cargo: owner oculto sem trustedDev | `trustedDevProvider` = false | Dropdown exibe só Operário e Administrador | — |
| Desativar: 2 obras vinculadas | Membro com obras [o1, o2] | Confirm lista `o1` e `o2`; após confirmação, 2×`setMembership{isActive:false}` + 1×`setConstrutoraRole{isActive:false}`; indicador de progresso; snackbar `Membro desativado.`; membro some da lista de ativos | — |
| Desativar: sem obras | Membro sem obras ativas | Confirm lista "nenhuma obra vinculada"; após confirmação, apenas `setConstrutoraRole{isActive:false}` | — |
| Desativar: falha parcial | 1 das 3 chamadas retorna erro | Exibe mensagem de erro; membro pode permanecer parcialmente ativo (docs órfãos são inócuos) | Exibir erro mapeado via SnackBar |
| Desativar: cancelado | Admin cancela confirm dialog | Nenhuma CF chamada; estado inalterado | — |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/construtoras/data/membros_repository.dart` -- **modificar**: adicionar método `setCargo(String construtoraId, String userId, String role, {bool isActive = true})` que chama `setConstrutoraRole` com pré-check offline e tradução de erros (mesmo padrão de `ObraMembersRepository`); método reutilizável pelos dois botões.
- `app/lib/src/features/construtoras/presentation/member_detalhe_sheet.dart` -- **modificar**: ativar botões `Trocar cargo` e `Desativar` (linhas ~190-196 — atualmente `onPressed: null`); remover o texto "Disponível em breve" (linha ~200-206); implementar `_mostrarTrocarCargoDialog` e `_confirmarDesativar`; importar `trustedDevProvider` de `authentication/data/user_repository.dart`.
- `app/lib/src/features/construtoras/presentation/widgets/trocar_cargo_dialog.dart` -- **criar** (novo): `TrocarCargoDialog` `ConsumerStatefulWidget` recebendo `construtoraId`, `userId`, `cargoAtual` (`operario`|`admin`|`owner`), `isDev`; estado `_selectedRole`, `_isSubmitting`, `_errorMessage`; `DropdownButtonFormField` com chave `Key('trocar-cargo-dropdown')`; opção `Proprietário` condicional (`isDev`); `Confirmar` chama `MembrosRepository.setCargo`; erro não fecha; sucesso fecha retornando `true`.
- `app/lib/src/features/authentication/data/user_repository.dart` -- **reutilizar sem modificar**: `trustedDevProvider` já existe na linha 60.
- `app/lib/src/features/obras/data/obra_members_repository.dart` -- **reutilizar sem modificar**: `setMembership` + `mensagemSemConexao` já usados para desativação de obras.
- `app/test/features/construtoras/membros_test.dart` -- **adicionar**: `FakeMembrosRepository` implementando `setCargo`; suites `10.3 TrocarCargoDialog` e `10.3 Desativar membro`.

## Tasks & Acceptance

**Execution:**
- [ ] `app/lib/src/features/construtoras/data/membros_repository.dart` -- adicionar método `setCargo(String construtoraId, String userId, String role, {bool isActive = true})`: pré-check offline via `Connectivity().checkConnectivity()` (mesmo padrão de `ObraMembersRepository`); chama `httpsCallable('setConstrutoraRole').call({construtoraId, userId, role, isActive})`; trata `FirebaseFunctionsException` com tradução equivalente a `traduzirErroSetMembership` (mapear `permission-denied`, `failed-precondition`); propaga `Exception` com mensagem pt-br -- método de mutação de cargo.
- [ ] `app/lib/src/features/construtoras/presentation/widgets/trocar_cargo_dialog.dart` -- criar `TrocarCargoDialog`: `ConsumerStatefulWidget`; `DropdownButtonFormField` com `Key('trocar-cargo-dropdown')` e itens `['operario', 'admin']` (+ `'owner'` se `isDev`); labels: `operario→Operário`, `admin→Administrador`, `owner→Proprietário`; valor inicial = `cargoAtual`; `_isSubmitting` bloqueia botão; em sucesso fecha com `Navigator.pop(true)`; em erro exibe `_errorMessage` sem fechar; botões `Cancelar`/`Confirmar` -- componente TrocarCargoDialog.
- [ ] `app/lib/src/features/construtoras/presentation/member_detalhe_sheet.dart` -- substituir `onPressed: null` nos botões `Trocar cargo` e `Desativar`; remover texto "Disponível em breve"; converter widget para ler `trustedDevProvider` (já tem acesso via `ref`); implementar `_mostrarTrocarCargoDialog(BuildContext, WidgetRef, ConstrutoraMember)` — abre `TrocarCargoDialog.show`, em `true` invalida `membrosProvider(cId)` + `memberDetalheProvider(key)` e exibe snackbar `Cargo atualizado.`; implementar `_confirmarDesativar(BuildContext, WidgetRef, ConstrutoraMember, List<Obra>)` — dialog destructiva listando obras afetadas, em confirmação: paralleliza N×`setMembership{obraId, isActive:false}` + aguarda + `setCargo{isActive:false}`, exibe `CircularProgressIndicator` durante execução, invalida providers, snackbar `Membro desativado.` -- wiring das ações.
- [ ] `app/test/features/construtoras/membros_test.dart` -- adicionar `FakeMembrosRepository` com campo `chamadas` e `setCargo`; suites: `10.3 TrocarCargoDialog` (pré-seleção, troca, erro sem fechar, offline, owner condicionado a trustedDev); `10.3 Desativar membro` (confirm lista obras, confirmar dispara N+1 CFs, cancelar não dispara, falha parcial exibe erro) -- cobertura I/O Matrix.

**Acceptance Criteria:**
- Given membro com `isAdmin:true`, when abro `Trocar cargo`, then `TrocarCargoDialog` abre com `Administrador` pré-selecionado no dropdown.
- Given `trustedDev=false`, when abro `TrocarCargoDialog`, then `Proprietário` não aparece entre as opções.
- Given `trustedDev=true`, when abro `TrocarCargoDialog`, then `Proprietário` aparece como terceira opção.
- Given `TrocarCargoDialog` aberta, when confirmo com sucesso, then dialog fecha, snackbar `Cargo atualizado.` aparece, e providers são invalidados.
- Given dispositivo offline, when confirmo `TrocarCargoDialog`, then dialog permanece aberta com mensagem `Sem conexão...`.
- Given membro com 2 obras vinculadas, when clico `Desativar`, then confirm dialog lista as 2 obras pelo nome.
- Given confirm de desativação, when confirmo, then são disparadas 2×`setMembership{isActive:false}` + 1×`setConstrutoraRole{isActive:false}`, indicador de progresso é exibido.
- Given confirm de desativação, when cancelo, then nenhuma CF é chamada.
- Given qualquer CF retorna `permission-denied` em Trocar cargo, then mensagem `Você não tem permissão para realizar esta atribuição.` é exibida sem fechar o dialog.

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Design Notes

- `TrocarCargoDialog` segue a estrutura visual de `TrocarPapelDialog` (já existe em 10.1): mesmo padrão de `ConsumerStatefulWidget`, `_isSubmitting`, `_errorMessage`, layout com `DropdownButtonFormField` sem `FilterChip` (papel de construtora não tem módulos).
- Para a desativação, a execução paralela (Future.wait) é mais rápida que sequencial; tratar falhas com `Future.wait(..., eagerError: false)` para coletar todos os resultados antes de decidir sobre o erro.
- `MembrosRepository.concederAcesso` já chama `setConstrutoraRole` mas acoplado ao fluxo de concessão (email + role). O novo `setCargo` é especializado para mutação de cargo/status de membro existente (userId, sem email).

## Verification

**Commands:**
- `flutter test test/features/construtoras/membros_test.dart` -- expected: todos os testes passam incluindo novas suites 10.3
- `flutter analyze` -- expected: No issues found
