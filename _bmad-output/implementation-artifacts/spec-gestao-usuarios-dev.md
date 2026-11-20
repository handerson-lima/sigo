---
title: 'Gestão Completa de Usuários pelo Perfil Dev'
type: 'feature'
created: '2026-11-20'
status: 'done'
route: 'dispatch'
baseline_commit: 'fe2b8170e11a43afd7e82dac173c697bb497173c'
review_loop_iteration: 0
context:
  - '{project-root}/functions/src/index.ts'
  - '{project-root}/firestore.rules'
  - '{project-root}/app/lib/src/features/developer/presentation/users_list_screen.dart'
  - '{project-root}/app/lib/src/features/developer/presentation/user_details_screen.dart'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A gestão de usuários pelo `dev` não possui exclusão global de usuário (Auth + Firestore), ativação/desativação de contas nem redefinição de senha provisória sem expiração; além disso, a remoção de vínculo em `UserDetailsScreen` falha silenciosamente e continua exibindo vínculos inativos.

**Approach:** Criar Cloud Functions exclusivas para `dev` ativo (`adminDeleteUser`, `adminSetUserActive`, `adminResetUserPassword`), bloquear contas com `users/{uid}.isActive == false` em `authority()` e `firestore.rules`, atualizar `UsersListScreen` e `UserDetailsScreen`, e adicionar troca voluntária de senha no menu do avatar em `SigoTopBar`.

## Decisions

- **Senha padrão provisória (Dev):** Diálogo pré-preenchido com `'Mudar@1234'`, editável (mínimo 8 caracteres) e com botão de copiar antes da confirmação.
- **Alteração voluntária pelo usuário:** Menu no avatar da `SigoTopBar` com opção **"Alterar senha"** (diálogo com senha atual, nova senha e confirmação; reautenticação automática antes de `updatePassword`), sem expiração nem bloqueio.

## Boundaries & Constraints

**Always:**
- Exigir `dev_roles/{uid}.isActive === true` antes de chamadas ao Firebase Auth e revalidar na transação Firestore, auditando em `/audit`.
- Bloquear auto-exclusão e auto-desativação do `dev` logado (`target === uid` → `failed-precondition`).
- `adminDeleteUser`: remover conta no Auth, `users/{uid}` (+ `notifications`), `dev_roles/{uid}`, `construtora_members/{uid}`, `obras/*/members/{uid}` e `user_provisioning`, preservando registros históricos (`audit`, `commands`, `despesas`, `diarios`, `movimentacoes`, `funcionarios`).
- `adminSetUserActive`: definir `disabled: !isActive` no Auth, revogar refresh tokens ao desativar e gravar `users/{uid}.isActive`, preservando vínculos de construtora/obra intactos.
- `adminResetUserPassword`: atualizar senha no Auth (`>= 8` chars) sem expiração nem bloqueio de login.
- Tratar ausência de `users/{uid}` ou de `isActive` como ativo nas regras e em `authority()`.

**Never:**
- Nunca apagar dados históricos/contábeis/auditoria ao excluir usuário.
- Nunca impor expiração ou troca obrigatória bloqueante na senha provisória.
- Nunca editar `app_user.g.dart` manualmente (usar `build_runner`) nem editar `firestore.rules` sem delegar ao `firestore-rules-author`.

## I/O & Edge-Case Matrix

| Cenário | Entrada / Estado | Comportamento Esperado | Erro |
|---------|------------------|------------------------|------|
| Excluir usuário | Dev chama `adminDeleteUser(userId)` | Auth, `users/{uid}`, `dev_roles`, `notifications` e memberships removidos; histórico preservado | `not-found` / `permission-denied` |
| Auto-exclusão / auto-desativação | Dev passa o próprio `uid` | Rejeitado antes de alterar Auth/Firestore | `failed-precondition` |
| Ativar/desativar usuário | Dev chama `adminSetUserActive(userId, isActive)` | Auth `disabled` e `users/{uid}.isActive` atualizados; tokens revogados se `false` | `not-found` / `invalid-argument` |
| Redefinir senha | Dev chama `adminResetUserPassword(userId, password)` | Senha atualizada no Auth sem expiração | `invalid-argument` (`< 8` chars) / `not-found` |
| Remover vínculo | Dev remove vínculo em `UserDetailsScreen` | `setMembership` (`isActive: false`) preservando `owner`; lista oculta inativos | `SnackBar` com erro traduzido |
| Token em cache de desativado | `users/{uid}.isActive == false` tenta ler/gravar | Bloqueado em `firestore.rules` e `authority()` | `permission-denied` |

</frozen-after-approval>

## Code Map

- `functions/src/index.ts` -- Callables (`callable`, `authority`, `audit`, `setDevRole`, `membership`, `adminCreateUser`). Reutilizar helpers base; não alterar endpoints de estoque/financeiro.
- `firestore.rules` -- `signed()`/`activeUser()` (L4-20) e `users/{uid}` (L35-40), via `firestore-rules-author`.
- `app/lib/src/features/authentication/domain/app_user.dart` -- `AppUser` (adicionar `isActive` default `true`, rodar `build_runner`).
- `app/lib/src/features/authentication/data/auth_repository.dart` & `app/lib/src/common_widgets/sigo_top_bar.dart` -- Troca voluntária de senha via menu no avatar (`reauthenticateWithCredential` + `updatePassword`).
- `app/lib/src/features/developer/data/dev_users_repository.dart` -- Novo repositório (padrão `MembrosRepository`: offline-check, injeção de `FirebaseFunctions`, erros traduzidos).
- `app/lib/src/features/developer/presentation/users_list_screen.dart` -- Filtro Ativos/Inativos, badge Inativo, menu de ações, senha mínima `>= 8` em `_createUser` e `_ApproveRequestDialog`.
- `app/lib/src/features/developer/presentation/user_details_screen.dart` -- Ações Ativar/Desativar, Redefinir Senha e Excluir Usuário; filtrar vínculos `isActive == true` e corrigir remoção.
- `functions/test/integration.cjs`, `functions/test/security-rules.test.cjs`, `app/test/` -- Suítes de testes.

## Tasks & Acceptance

**Execution:**
- [x] `functions/src/index.ts` -- Adicionar `adminDeleteUser`, `adminSetUserActive`, `adminResetUserPassword` e checagem de `users/{uid}.isActive !== false` em `authority()` -- Implementar ações dev e bloqueio imediato no backend.
- [x] `firestore.rules` -- Via `firestore-rules-author`, bloquear usuários com `users/{uid}.isActive == false` (compatível quando doc/campo ausente) -- Impedir acesso com token em cache.
- [x] `app/lib/src/features/authentication/domain/app_user.dart` -- Adicionar `isActive` (`true` se ausente) e regenerar `app_user.g.dart` -- Expor status na UI.
- [x] `app/lib/src/features/developer/data/dev_users_repository.dart` -- Criar repositório para `adminDeleteUser`, `adminSetUserActive`, `adminResetUserPassword`, `setDevRole`, `setMembership` -- Padronizar chamadas e erros.
- [x] `app/lib/src/features/developer/presentation/user_details_screen.dart` -- Adicionar botões Ativar/Desativar, Redefinir Senha e Excluir Usuário; filtrar vínculos ativos e corrigir remoção -- Corrigir bug e completar gestão.
- [x] `app/lib/src/features/developer/presentation/users_list_screen.dart` -- Filtro por status, badge Inativo, menu de ações e senha `>= 8` chars -- Gestão direta na listagem.
- [x] `app/lib/src/features/authentication/data/auth_repository.dart` & `app/lib/src/common_widgets/sigo_top_bar.dart` -- Implementar menu no avatar com troca voluntária de senha (mínimo 8 caracteres, com reautenticação) -- Permitir alteração quando o usuário quiser.
- [x] `functions/test/integration.cjs`, `functions/test/security-rules.test.cjs`, `app/test/features/developer/` -- Testar matriz I/O no backend, regras e Flutter -- Garantir regressão zero.

**Acceptance Criteria:**
- Given dev ativo, when exclui outro usuário, then Auth e perfil/vínculos somem mantendo histórico e liberando o e-mail para novo cadastro.
- Given usuário desativado, when tenta login ou usar sessão ativa, then é bloqueado até ser reativado com seus vínculos intactos.
- Given senha redefinida pelo dev, when o usuário faz login com a senha provisória a qualquer tempo, then acessa sem expiração.

## Implementation Notes

- Backend (`functions/src/index.ts`): implementadas `adminDeleteUser`, `adminSetUserActive` e `adminResetUserPassword` com validação transacional `authority(tx, uid).dev` antes das mutações no Firebase Auth, bloqueio de auto-ação, `users/{uid}.isActive !== false` em `authority()` e `requireDevPrecheck()`, além de criação completa de `users/{target}` a partir do `UserRecord` quando ausente.
- Regras (`firestore.rules` via `firestore-rules-author` e `storage.rules`): adicionado helper `activeUser()` bloqueando leitura/escrita e Storage de contas com `users/{uid}.isActive == false` (compatível com ausência de doc/campo).
- App (`app/`): atualizado `AppUser.isActive` (com `build_runner`), criado `DevUsersRepository` (incluindo tradução de `internal`), atualizadas `UsersListScreen` e `UserDetailsScreen` (ações globais, filtro Ativos/Inativos, preservação de `owner`/`isAdmin` e fallback de navegação), adicionado menu **"Alterar senha"** em `SigoTopBar` + `AuthRepository.changePassword` e logout automático em `MyApp` quando `isActive == false`.
- Diagnóstico adicional (`internal [0]` em produção `sigo-c2eb2`): `firebase functions:list` confirmou que `adminDeleteUser`, `adminSetUserActive` e `adminResetUserPassword` ainda não foram implantadas na nuvem, causando `404`/CORS na web.

## Spec Change Log

## Review Triage Log

- `[edge-case-hunter] functions/src/index.ts:157-158 (adminSetUserActive doc parcial)` | verdict: `high` | route: `patch` | evidence: `Quando users/{target} não existe mas existe no Auth, tx.set grava apenas {id, isActive, updatedAt} sem email/displayName, causando TypeError em AppUser.fromJson.`
- `[edge-case-hunter] functions/src/index.ts:100-131 (adminDeleteUser > 450 docs)` | verdict: `high` | route: `patch` | evidence: `Os lotes remainingRefs executam após a transação que remove users/{target} e Auth; falha parcial torna retry impossível (not-found).`
- `[edge-case-hunter] functions/src/index.ts:92-118 (adminDeleteUser Auth antes da tx)` | verdict: `high` | route: `patch` | evidence: `admin.auth().deleteUser roda antes de authority(tx, uid).dev na transação, podendo excluir no Auth mesmo se Firestore rejeitar.`
- `[edge-case-hunter] functions/src/index.ts:150-156 (adminSetUserActive Auth antes da tx)` | verdict: `high` | route: `patch` | evidence: `admin.auth().updateUser e revokeRefreshTokens rodam antes da transação validar authority(tx, uid).dev.`
- `[edge-case-hunter] functions/src/index.ts:170-178 (adminResetUserPassword Auth antes da tx)` | verdict: `high` | route: `patch` | evidence: `admin.auth().updateUser roda antes da transação validar authority(tx, uid).dev e auditar.`
- `[edge-case-hunter] user_details_screen.dart:130 (context.pop() sem canPop)` | verdict: `medium` | route: `patch` | evidence: `Após excluir usuário, context.pop() sem canPop() lança GoError se a tela foi aberta diretamente por URL.`
- `[edge-case-hunter] user_details_screen.dart:443 (legado isAdmin true com role member)` | verdict: `medium` | route: `patch` | evidence: `user_details_screen.dart usa apenas role == 'admin', ignorando memberData['isAdmin'] == true e rebaixando legado na remoção.`
- `[edge-case-hunter] users_list_screen.dart:1110-1136 (_ApproveRequestDialog copy sem trim)` | verdict: `low` | route: `patch` | evidence: `_copyPassword copia _passCtrl.text sem trim() enquanto _approve envia _passCtrl.text.trim().`
- `[edge-case-hunter] sigo_top_bar.dart:210-231 (divider com email vazio)` | verdict: `low` | route: `patch` | evidence: `PopupMenuDivider é renderizado no topo mesmo quando email.isEmpty.`
- `[edge-case-hunter] sigo_top_bar.dart:213-216 (barrierDismissible no _ChangePasswordDialog)` | verdict: `medium` | route: `patch` | evidence: `Diálogo permite fechar ao tocar fora durante _isSaving, suprimindo feedback de sucesso ou erro.`
- `[edge-case-hunter] dev_users_repository.dart:147-148 (lista vazia de conectividade)` | verdict: `low` | route: `patch` | evidence: `results.any((r) => r != ConnectivityResult.none) retorna false para lista vazia, bloqueando chamadas online.`
- `[edge-case-hunter] auth_repository.dart:46-65 (currentPassword vazio)` | verdict: `low` | route: `patch` | evidence: `EmailAuthProvider.credential com currentPassword vazio pode lançar ArgumentError fora de _traduzirErroAuth em chamadas diretas.`
- `[blind-hunter] #1 adminSetUserActive cria users/{uid} parcial sem email/displayName` | verdict: `high` | route: `patch` | evidence: `Mesma causa raiz de functions/src/index.ts:157-158; corrigir preenchendo dados do UserRecord do Auth.`
- `[blind-hunter] #2 Mutações Auth antes da transação e batches >450 em adminDeleteUser` | verdict: `high` | route: `patch` | evidence: `Mesma causa raiz dos achados de ordem transacional e lote >450 em functions/src/index.ts.`
- `[blind-hunter] #3 Janela de bypass após exclusão em firestore.rules via !exists(users/{uid})` | verdict: `low` | route: `defer` | evidence: `Inerente a JWT stateless (até 1h) combinado à regra congelada da spec que exige compatibilidade quando users/{uid} não existe; mitigável apenas com Auth Blocking Functions.`
- `[blind-hunter] #4 storage.rules não valida users/{uid}.isActive != false` | verdict: `high` | route: `patch` | evidence: `storage.rules:5,9,10,44-46 permitem leitura/upload por usuários ou devs desativados enquanto o token ID não expirar.`
- `[blind-hunter] #5 Sessão ativa no cliente e erro user-disabled sem tradução no login` | verdict: `medium` | route: `patch` | evidence: `AuthRepository.signInWithEmailAndPassword não traduz user-disabled e sessão ativa não encerra ao receber isActive: false.`
- `[blind-hunter] #6 Switch Acesso de Desenvolvedor sem guarda isSelf e context.pop() em UserDetailsScreen` | verdict: `low` | route: `patch` | evidence: `SwitchListTile permite auto-revogação disparando erro do backend e context.pop() sem canPop() falha em acesso direto.`
- `[blind-hunter] #7 _LinkConstrutoraDialog sem filtro/erro/operario e FutureBuilder por rebuild` | verdict: `low` | route: `defer` | evidence: `Comportamento pré-existente de _LinkConstrutoraDialog e dos tiles de vínculo em UserDetailsScreen fora do escopo desta entrega.`
- `[blind-hunter] #8 _CreateUserDialog fecha antes da chamada e _ApproveRequestDialog usa MembrosRepository` | verdict: `low` | route: `defer` | evidence: `Padrão pré-existente de fechamento prévio do diálogo de criação e uso de MembrosRepository.approveAccessRequest.`
- `[blind-hunter] #9 Possível overflow no ListTile.trailing de UsersListScreen e mutação de mapa` | verdict: `low` | route: `defer` | evidence: `Layout de trailing Row e mutação data['_cId'] em allUserMembershipsProvider são padrões pré-existentes na lista.`
- `[blind-hunter] #10 adminCreateUser sem tratamento de email-already-exists + SigoTopBar divider/barrier` | verdict: `low` | route: `patch` | evidence: `Parte da SigoTopBar entra em patch; tratamento de email-already-exists em adminCreateUser é pré-existente e vai para defer.`
- `[verification-gap] #1 storage.rules sem verificação de users/{uid}.isActive != false e sem testes de Storage` | verdict: `high` | route: `patch` | evidence: `Pre-verified: storage.rules e security-rules.test.cjs não verificam nem testam bloqueio de Storage para usuários/devs desativados.`
- `[verification-gap] #2 AuthRepository.changePassword e caminho de erro de _ChangePasswordDialog sem cobertura` | verdict: `medium` | route: `patch` | evidence: `Pre-verified: testes atuais usam apenas _FakeAuthRepository no caminho feliz, sem testar reauthenticateWithCredential, _traduzirErroAuth ou erro no diálogo.`
- `[verification-gap] #3 approveAccessRequest sem teste de integração (dev ativo/desativado) e widget de 8 chars` | verdict: `medium` | route: `patch` | evidence: `Pre-verified: integration.cjs e dev_users_management_test.dart não exercitam approveAccessRequest nem _ApproveRequestDialog.`
- `[verification-gap] #4 Ações de ciclo de vida e travas isSelf em UsersListScreen/UserDetailsScreen sem widget tests` | verdict: `medium` | route: `patch` | evidence: `Pre-verified: dev_users_management_test.dart não testa toggle_active, _CreateUserDialog, setDevRole, _LinkConstrutoraDialog nem isSelf.`
- `[verification-gap] Other: adminSetUserActive cria users/{uid} parcial sem email/displayName` | verdict: `high` | route: `patch` | evidence: `Mesma causa raiz de functions/src/index.ts:157-158.`

## Verification

**Commands:**
- `cd /Users/usuario/obras/functions && npm test && npm run test:rules` -- expected: 100% aprovados.
- `cd /Users/usuario/obras/app && flutter analyze && flutter test` -- expected: zero warnings e testes passando.
