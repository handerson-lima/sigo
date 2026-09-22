---
title: '9.2 Atribuir admin + erros e offline'
type: 'feature'
created: '2026-09-22'
status: 'ready-for-dev'
route: 'dispatch'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O `AtribuirObraDialog` (9.1) fixa o papel em "Operário" sem permitir atribuir "Admin da obra". Além disso, erros da Cloud Function `setMembership` (`permission-denied`, `failed-precondition`) e ausência de conectividade retornam mensagens genéricas ou silenciosas, deixando o usuário sem contexto.

**Approach:** Adicionar seleção explícita de papel (`Operário` | `Admin da obra`) no diálogo existente; propagar o role correto (`operario` | `admin`) para `setMembership`; substituir o catch genérico no repositório por tradução de códigos Firebase específicos; e exibir mensagem inline de erro de rede antes de tentar a chamada quando sem conectividade.

## Boundaries & Constraints

**Always:**
- Papéis válidos para atribuição de obra: `operario` e `admin`. O papel `owner` nunca é enviado com `obraId`.
- `Operário` deve ser o papel pré-selecionado (padrão); `Admin da obra` é opção secundária.
- O resumo dinâmico deve atualizar instantaneamente ao trocar de papel: `{Identificador} será {Papel} em {Obra} com acesso a {Módulos}`.
- Erros de `permission-denied` → mensagem: `"Você não tem permissão para realizar esta atribuição."`.
- Erros de `failed-precondition` → mensagem: `"Pré-condição não atendida: verifique se o membro está ativo na construtora."`.
- Erro de rede/offline → mensagem: `"Sem conexão. Verifique sua internet e tente novamente."`. Esse erro deve ser detectado antes de disparar a chamada.
- Todos os demais erros continuam com `e.message` ou fallback genérico (comportamento atual).
- O SnackBar de sucesso deve refletir o papel escolhido: `Atribuído a {obra} como {Papel}.` onde Papel é "Operário" ou "Admin da obra".
- A validação de desabilitação do botão de confirmação permanece: requer obra selecionada + obras disponíveis.
- Invalidação de providers pós-sucesso: idêntica à 9.1 (membrosProvider, contagemObrasPorMembroProvider, contagemObrasMetaProvider, memberDetalheProvider, obrasVinculadasProvider, obraMembersProvider).

**Never:**
- Não enviar `role: 'owner'` para `setMembership`.
- Não criar fila offline para atribuição (operação online-only; AD-6).
- Não exibir diálogo de confirmação adicional para "Admin da obra" (atribuição simples como operário).
- Não refatorar o layout geral do diálogo; adicionar apenas o seletor de papel.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| HAPPY_PATH operário | Membro ativo, papel "Operário", obra selecionada, confirmar | Chama `setMembership{role: 'operario'}`, SnackBar `Atribuído a {obra} como Operário.` | — |
| HAPPY_PATH admin | Membro ativo, papel "Admin da obra", obra selecionada, confirmar | Chama `setMembership{role: 'admin'}`, SnackBar `Atribuído a {obra} como Admin da obra.` | — |
| Resumo papel admin | Usuário troca papel para "Admin da obra" | Resumo atualiza: `{email} será Admin da obra em {Obra} com acesso a {Módulos}` | — |
| permission-denied | CF retorna código `permission-denied` | Mensagem inline: "Você não tem permissão para realizar esta atribuição." | Mantém dialog aberto |
| failed-precondition | CF retorna código `failed-precondition` | Mensagem inline: "Pré-condição não atendida: verifique se o membro está ativo na construtora." | Mantém dialog aberto |
| Offline | Dispositivo sem conexão antes de confirmar | Mensagem inline: "Sem conexão. Verifique sua internet e tente novamente." | Não dispara CF |
| Papel padrão ao abrir | Dialog aberto pela primeira vez | `Operário` pré-selecionado | — |
| textScale 1.3 | Escala de texto 1.3x | Sem overflow no seletor de papel ou resumo | — |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/obras/data/obra_members_repository.dart` -- **modificar**: substituir o `catch (FirebaseFunctionsException)` genérico por tradução de `e.code` para mensagens pt-br de `permission-denied`, `failed-precondition`; adicionar detecção de erro de rede (SocketException / sem conectividade) antes de chamar a CF.
- `app/lib/src/features/construtoras/presentation/widgets/atribuir_obra_dialog.dart` -- **modificar**: adicionar estado `_selectedRole` (String, default `'operario'`); substituir o `InputDecorator` de papel fixo por um `DropdownButtonFormField<String>` com opções `Operário` → `operario` e `Admin da obra` → `admin`; atualizar `_gerarResumo` para usar o rótulo do papel selecionado; atualizar `_confirmar` para passar `role: _selectedRole`; atualizar SnackBar de sucesso com o rótulo de papel.
- `app/test/features/construtoras/membros_test.dart` -- **adicionar**: testes cobrindo seleção de Admin da obra (role `admin` enviado, SnackBar correto), resumo dinâmico com papel Admin, mensagem `permission-denied`, mensagem `failed-precondition`, mensagem offline, e papel padrão Operário ao abrir.

## Tasks & Acceptance

**Execution:**
- [ ] `app/lib/src/features/obras/data/obra_members_repository.dart` -- estender `setMembership` com tradução de `e.code` para `permission-denied` e `failed-precondition`; adicionar verificação de conectividade antes da chamada retornando mensagem de offline -- tratamento de erros granular.
- [ ] `app/lib/src/features/construtoras/presentation/widgets/atribuir_obra_dialog.dart` -- adicionar estado `_selectedRole = 'operario'`; substituir bloco de papel fixo por `DropdownButtonFormField<String>` com duas opções; atualizar `_gerarResumo`, `_confirmar` e SnackBar para usar o papel selecionado -- seleção explícita de papel Admin.
- [ ] `app/test/features/construtoras/membros_test.dart` -- adicionar suite cobrindo todos os cenários da matriz I/O da história 9.2 -- cobertura e regressão.

**Acceptance Criteria:**
- Given dialog aberto, when não altero o papel, then `Operário` está pré-selecionado e `setMembership` recebe `role: 'operario'`.
- Given dialog aberto, when seleciono `Admin da obra` e confirmo, then `setMembership` recebe `role: 'admin'` e o SnackBar exibe `Atribuído a {obra} como Admin da obra.`.
- Given dialog aberto, when troco o papel para Admin, then o resumo dinâmico atualiza para `... será Admin da obra em ...`.
- Given `setMembership` lança `FirebaseFunctionsException(code: 'permission-denied')`, then o diálogo exibe `"Você não tem permissão para realizar esta atribuição."` sem fechar.
- Given `setMembership` lança `FirebaseFunctionsException(code: 'failed-precondition')`, then o diálogo exibe `"Pré-condição não atendida: verifique se o membro está ativo na construtora."` sem fechar.
- Given dispositivo offline, when clico em confirmar, then o diálogo exibe `"Sem conexão. Verifique sua internet e tente novamente."` sem disparar a CF.

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Design Notes

- Seletor de papel: `DropdownButtonFormField<String>` substituindo o `InputDecorator` de papel fixo (linhas 298–317 do dialog atual). Opções: `DropdownMenuItem(value: 'operario', child: Text('Operário'))` e `DropdownMenuItem(value: 'admin', child: Text('Admin da obra'))`.
- Detecção offline: verificar `InternetAddress.lookup` (dart:io) ou capturar `SocketException` dentro do try de `setMembership`. Uma abordagem prática é tratar o `catch` genérico e verificar se `e.toString().contains('SocketException')` ou importar `dart:io` e capturar `SocketException` separadamente antes de `catch (e)`.
- Mapa de rótulos de papel para resumo e SnackBar: `{'operario': 'Operário', 'admin': 'Admin da obra'}`.

## Verification

**Commands:**
- `flutter test test/features/construtoras/membros_test.dart` -- expected: todos os testes passam (≥80 testes incluindo novos de 9.2)
- `flutter analyze` -- expected: No issues found
