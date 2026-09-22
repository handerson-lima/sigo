---
title: 'Trocar papel/módulos e remover da obra (Epic 10.1/10.2)'
type: 'feature'
created: '2026-09-22'
status: 'done'
baseline_commit: '9a8683639b695820e51ef483329c1cc9dfc362a0'
route: 'dispatch'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O `ObraVinculoRow` exibe o vínculo obra do membro mas não oferece ações de gestão (menu overflow ausente, stub comentado no Epic 8). O admin/owner não consegue trocar papel/módulos nem remover o membro de uma obra diretamente do detalhe.

**Approach:** Adicionar menu overflow com duas ações ao `ObraVinculoRow`: (1) **Trocar papel** — abre dialog pré-preenchido com papel e módulos atuais, chama `setMembership{obraId, role, modules}`; (2) **Remover da obra** — confirm destructiva, chama `setMembership{obraId, isActive:false}`; ambas invalidam providers após sucesso e exibem snackbar pt-br.

## Boundaries & Constraints

**Always:**
- Toda mutação passa por `ObraMembersRepository.setMembership` (Cloud Function). Nenhuma escrita direta no Firestore.
- Papel de obra válido: `operario` ou `admin`. Nunca enviar `owner` com `obraId`.
- Módulos canônicos: `diario`, `lotes`, `estoque`. `[]` = sem acesso (fail-closed).
- Pré-check offline antes de chamar a CF; dialog permanece aberto em caso de erro com mensagem mapeada pt-br.
- Após mutação invalidar `membrosProvider(construtoraId)` + `obraMembersProvider((construtoraId, obraId))`.
- Alvos de toque ≥48dp; papel nunca só por cor; foco trap e `Esc` fecham dialog.
- Acessibilidade: `semanticsLabel` cobrindo ação e nome da obra.

**Never:**
- Não implementar Story 10.3 (trocar cargo construtora/desativar) — está fora do escopo desta spec.
- Não criar novo StreamProvider ou endpoint; reutilizar `ObraMembersRepository.setMembership` existente.
- Não fechar a dialog de trocar papel/módulos em caso de erro — manter aberta com mensagem.
- Não usar `owner` como opção de papel de obra.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Trocar papel: admin → operário | Vínculo com `isAdmin:true`, usuário seleciona `Operário` e confirma | `setMembership{role:'operario', modules:[...]}` chamado; snackbar `Papel atualizado em {obra}.`; linha reflete Operário | — |
| Trocar papel: operário → admin | Vínculo com `isAdmin:false`, usuário seleciona `Admin da obra` e confirma | `setMembership{role:'admin', modules:[...]}` chamado; snackbar `Papel atualizado em {obra}.`; linha reflete Admin da obra | — |
| Trocar papel: alterar só módulos | Mesmo papel mantido, módulos alterados | `setMembership{role:existente, modules:novos}` chamado; snackbar `Papel atualizado em {obra}.` | — |
| Trocar papel: offline | Dispositivo sem conexão ao confirmar | Dialog mantida aberta, mensagem `Sem conexão. Verifique sua internet e tente novamente.` exibida | Sem fechar dialog |
| Trocar papel: permission-denied | CF retorna `permission-denied` | Dialog mantida aberta, mensagem `Você não tem permissão para realizar esta atribuição.` | Sem fechar dialog |
| Remover da obra: confirmado | Admin confirma remoção | `setMembership{obraId, isActive:false}` chamado; linha some do bloco; contador de obras decrementa; snackbar `Removido de {obra}.` | — |
| Remover da obra: cancelado | Admin cancela dialog destructiva | Nenhuma chamada disparada; estado inalterado | — |
| Remover da obra: offline | Dispositivo sem conexão ao confirmar | Dialog/snackbar de erro `Sem conexão...`; linha permanece | Não retirar linha prematuramente |
| Dialog de trocar papel pré-preenchida | `ObraMember.isAdmin=true, modules=['diario','lotes']` | Dialog abre com `Admin da obra` selecionado e chips `diario`+`lotes` marcados | — |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/construtoras/presentation/widgets/obra_vinculo_row.dart` -- **modificar**: adicionar parâmetros `onTrocarPapel` e `onRemover` (callbacks opcionais); inserir `PopupMenuButton` no `Row` do nome da obra quando callbacks não-nulos; widget é `StatelessWidget`, sem estado local.
- `app/lib/src/features/construtoras/presentation/member_detalhe_sheet.dart` -- **modificar**: no `_blocoObras` (linha ~408) passar callbacks para `ObraVinculoRow`; implementar `_mostrarTrocarPapelDialog` e `_confirmarRemocao`; usar `ref` para chamar `obraMembersRepositoryProvider` e invalidar providers após sucesso.
- `app/lib/src/features/construtoras/presentation/widgets/trocar_papel_dialog.dart` -- **criar** (novo): dialog `StatefulWidget` pré-preenchido com `isAdmin` e `modules` atuais; `DropdownButtonFormField` papel (`Operário`/`Admin da obra`); `FilterChip` módulos; resumo ao vivo; `Confirmar` chama callback; chaves `Key('trocar-papel-dropdown')`, `Key('modulo-diario')`, etc.
- `app/lib/src/features/obras/data/obra_members_repository.dart` -- **reutilizar sem modificar**: `setMembership` já suporta `isActive:false` e tradução de erros.
- `app/lib/src/features/construtoras/presentation/membros_providers.dart` -- **reutilizar sem modificar**: `obraMembersProvider`, `membrosProvider`, `obrasVinculadasProvider` já existem.
- `app/test/features/construtoras/membros_test.dart` -- **adicionar**: suites cobrindo todos os cenários da I/O Matrix (10.1 trocar papel/módulos, 10.2 confirmar/cancelar remoção, erros e offline).

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/construtoras/presentation/widgets/obra_vinculo_row.dart` -- adicionar parâmetros `onTrocarPapel(ObraMember vinculo)` e `onRemover(Obra obra, ObraMember vinculo)` (ambos `VoidCallback`-equivalentes opcionais); inserir `PopupMenuButton` no `Row` do nome da obra quando qualquer callback é não-nulo; `Semantics` da linha deve incluir `Editar vínculo` no rótulo quando overflow disponível -- menu overflow de gestão de vínculo.
- [x] `app/lib/src/features/construtoras/presentation/widgets/trocar_papel_dialog.dart` -- criar `TrocarPapelDialog`: `ConsumerStatefulWidget` recebendo `construtoraId`, `obraId`, `userId`, `isAdminAtual`, `modulesAtuais`; estado `_selectedRole`, `Map<String,bool> _modules`, `_isSubmitting`, `_errorMessage`; `DropdownButtonFormField` com chave `Key('trocar-papel-dropdown')`; `FilterChip` com chaves `Key('modulo-diario')`, `Key('modulo-lotes')`, `Key('modulo-estoque')`; resumo `{email} será {papel} em {obra} com acesso a {módulos}`; botões `Cancelar` / `Confirmar`; `Confirmar` chama `ObraMembersRepository.setMembership`, trata erros sem fechar; em sucesso fecha e retorna mensagem de sucesso -- componente TrocarPapelDialog.
- [x] `app/lib/src/features/construtoras/presentation/member_detalhe_sheet.dart` -- modificar `_blocoObras` (linha ~408) para passar `onTrocarPapel` e `onRemover` em cada `ObraVinculoRow`; implementar `_mostrarTrocarPapelDialog(BuildContext, Obra, ObraMember)` que abre `TrocarPapelDialog.show` e, em sucesso, invalida `obraMembersProvider((cId, oId))` + `membrosProvider(cId)` e exibe SnackBar; implementar `_confirmarRemocao(BuildContext, WidgetRef, Obra, ObraMember)` que exibe `AlertDialog` com texto `Remover {email} de {obra}? Ele perde acesso imediato; diários preservados.` e botões `Cancelar`/`Remover`; em confirmação chama `setMembership{obraId, isActive:false}`, invalida providers, exibe snackbar `Removido de {obra}.` -- wiring das ações no detalhe.
- [x] `app/test/features/construtoras/membros_test.dart` -- adicionar suites `10.1 TrocarPapelDialog` (pré-preenchimento, seleção papel, alteração módulos, resumo ao vivo, erros sem fechar, offline) e `10.2 Remover da obra` (confirm dispara CF, cancel não dispara, erro mantém estado, snackbar pós-sucesso); usar fakes já estabelecidos nas suites 9.x -- cobertura e regressão.

**Acceptance Criteria:**
- Given vínculo ativo em obra X, when abro overflow em `ObraVinculoRow` e seleciono `Trocar papel`, then `TrocarPapelDialog` abre pré-preenchido com papel e módulos atuais.
- Given `TrocarPapelDialog` aberta com `isAdmin=true`, when confirmo sem alterar nada, then `setMembership` recebe `role:'admin'` e os módulos atuais.
- Given `TrocarPapelDialog` aberta, when confirmo com sucesso, then dialog fecha, snackbar `Papel atualizado em {obra}.` aparece, e providers são invalidados.
- Given dispositivo offline, when confirmo `TrocarPapelDialog`, then dialog permanece aberta com mensagem `Sem conexão...`.
- Given vínculo ativo em obra X, when abro overflow e seleciono `Remover da obra`, then confirm dialog aparece com texto explicitando perda de acesso e preservação de histórico.
- Given confirm dialog de remoção, when clico `Cancelar`, then nenhuma CF é chamada.
- Given confirm dialog de remoção, when confirmo com sucesso, then `setMembership{isActive:false}` é chamado, linha some do bloco, snackbar `Removido de {obra}.` aparece.
- Given `setMembership` retorna `permission-denied` em qualquer ação, then mensagem `Você não tem permissão para realizar esta atribuição.` é exibida sem fechar o dialog.

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Design Notes

- `TrocarPapelDialog` reutiliza a estrutura visual de `AtribuirObraDialog` (mesmo padrão de `FilterChip` para módulos e `DropdownButtonFormField` para papel), mas recebe `isAdminAtual` e `modulesAtuais` para pré-preenchimento. Diferente do `AtribuirObraDialog`, não tem dropdown de obra (já conhecida).
- `ObraVinculoRow` mantém-se `StatelessWidget` — callbacks injetados externamente, sem acoplamento ao repositório dentro do widget.
- `member_detalhe_sheet.dart` é `ConsumerWidget`, portanto já tem acesso ao `ref` para chamar o repositório e invalidar providers.
- Invalidação mínima após mutação: `obraMembersProvider((cId, obraId))` e `membrosProvider(cId)` — suficiente para atualizar contagem e lista de obras vinculadas.
- SnackBar para sucesso de trocar papel: `Papel atualizado em {nome da obra}.`

## Verification

**Commands:**
- `flutter test test/features/construtoras/membros_test.dart` -- expected: todos os testes passam incluindo novas suites 10.1 e 10.2
- `flutter analyze` -- expected: No issues found
