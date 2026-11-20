---
title: 'Gestão Completa de Usuários pelo Perfil Dev'
type: 'feature'
created: '2026-11-20'
status: 'in-review'
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

## Spec Change Log

## Review Triage Log

## Verification

**Commands:**
- `cd /Users/usuario/obras/functions && npm test && npm run test:rules` -- expected: 100% aprovados.
- `cd /Users/usuario/obras/app && flutter analyze && flutter test` -- expected: zero warnings e testes passando.
