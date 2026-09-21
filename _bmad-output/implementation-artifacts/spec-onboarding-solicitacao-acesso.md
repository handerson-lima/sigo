---
title: 'Onboarding de Membros via Solicitação de Acesso e Notificações In-App'
type: 'feature'
created: '2026-09-21'
status: 'in-progress'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'dc200d7bc23d285bb26c6d7625d5dd941f2cbf87'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Quando um Admin de Construtora tenta adicionar um membro cujo e-mail ainda não existe no Firebase Auth, a Cloud Function `setConstrutoraRole` retorna um erro técnico opaco (`user-not-found`), quebrando o fluxo de trabalho e obrigando o Admin a buscar o Dev Global por fora do app. O ícone de sino da top bar também é estático e sem funcionalidade.

**Approach:** Ao receber `getUserByEmail` com `not-found`, `membership()` cria automaticamente um documento em `access_requests` em vez de lançar o erro. O Admin e o Dev veem o estado pendente in-app. O Dev aprova via `approveAccessRequest`, que cria o usuário, vincula à construtora e envia uma notificação efêmera in-app ao Admin solicitante com a senha provisória.

## Boundaries & Constraints

**Always:**
- Apenas um Dev Global autenticado (`dev_roles/{uid}.isActive === true`) pode aprovar uma solicitação e chamar `approveAccessRequest`.
- A senha provisória deve trafegar apenas pela notificação in-app (nunca persistida em Firestore nem em log de auditoria).
- Toda aprovação deve registrar entrada em `/audit` com `action: 'approveAccessRequest'`.
- Notificações são efêmeras: deletadas automaticamente após leitura (`read: true`) ou após 7 dias via TTL (campo `expiresAt`).
- O campo `displayName` da solicitação é preenchido pelo Admin no momento do pedido e repassado ao `approveAccessRequest` sem edição pelo Dev.

**Never:**
- Admins comuns não chamam `approveAccessRequest` — qualquer tentativa resulta em `permission-denied`.
- A senha provisória não é armazenada em nenhuma coleção Firestore (apenas na notificação efêmera, que o leitor deve copiar e comunicar ao funcionário).
- Não criar uma aba separada para solicitações na tela de usuários do Dev; usar card de alertas fixo no topo da lista existente.

## I/O & Edge-Case Matrix

| Cenário | Input / Estado | Saída / Comportamento | Tratamento de Erro |
|---------|---------------|----------------------|-------------------|
| Admin adiciona e-mail inexistente | `setConstrutoraRole` com email sem conta Auth | Cria doc em `access_requests` com `status: pending`; retorna `{ok: true, pendingCreation: true}` | N/A |
| Admin adiciona e-mail já existente | `setConstrutoraRole` com email com conta | Vincula normalmente (fluxo ativo, sem mudança) | N/A |
| Dev aprova solicitação | `approveAccessRequest` com `requestId`, `password` válida (≥ 8 chars) | Cria usuário Auth, persiste `users/{uid}`, vincula membro, muda `status: approved`, cria notificação in-app ao Admin | Erro de Auth lançado como `invalid-argument` |
| Dev aprova solicitação duplicada | `approveAccessRequest` com `requestId` já `approved` | Retorna `{ok: true}` (idempotente, sem recriar usuário ou notificação) | N/A |
| Usuário não-Dev chama `approveAccessRequest` | Chamada sem `dev_roles` ativo | `permission-denied: 'Dev confiável obrigatório'` | N/A |
| Admin lê notificação | Toca em notificação no painel do sino | Atualiza `read: true`; notificação some da lista | N/A |
| Notificação expirada | `expiresAt` < now | Não exibida na UI; elegível para limpeza | N/A |

</frozen-after-approval>

## Code Map

- `functions/src/index.ts` — todas as Cloud Functions; `membership()` (linha 46) é onde interceptar `user-not-found`; `callable()` (linha 16) é o wrapper padrão. Nova função `approveAccessRequest` segue o mesmo padrão.
- `app/lib/src/features/construtoras/presentation/add_membro_dialog.dart` — dialog que chama `setConstrutoraRole`; tratar resposta `pendingCreation: true`.
- `app/lib/src/features/construtoras/presentation/membros_screen.dart` — lista de membros; injetar stream de `access_requests` por `construtoraId`.
- `app/lib/src/features/developer/presentation/users_list_screen.dart` — tela de gestão de usuários do Dev; adicionar card de alertas no topo.
- `app/lib/src/common_widgets/sigo_top_bar.dart` — ícone sino (linha 172-175); transformar em `NotificationBell` com badge dinâmico.
- `firestore.rules` — deve autorizar: Admin de construtora a criar em `access_requests`; Dev a atualizar `status`; usuário autenticado a ler/atualizar suas próprias notificações em `users/{uid}/notifications`.
- `firestore.indexes.json` — índice composto: `access_requests` por `construtoraId + status` e por `status` (para o Dev). Índice para `users/{uid}/notifications` por `read + createdAt`.

## Tasks & Acceptance

**Execution:**
- [ ] `functions/src/index.ts` — modificar `membership()`: interceptar `auth/user-not-found` em `getUserByEmail`; criar doc em `access_requests` com campos `{email, displayName, role, construtoraId, requestedBy, status: 'pending', createdAt}`; retornar `{ok: true, pendingCreation: true}`.
- [ ] `functions/src/index.ts` — criar função exportada `approveAccessRequest`: validar `requestId`, `password` (≥ 8 chars); verificar `dev`; buscar request; criar usuário Auth com `adminCreateUser`-style; vincular via lógica de `membership`; marcar `status: 'approved'`; criar doc em `users/{requestedBy}/notifications` com `{title, body (inclui senha), read: false, createdAt, expiresAt: +7 dias}`; registrar auditoria.
- [ ] `firestore.rules` — adicionar regras para `access_requests` (create: `admin(c)` da construtora; read/update: dev ou `requestedBy`); para `users/{uid}/notifications` (read/update: próprio usuário; write: apenas backend).
- [ ] `firestore.indexes.json` — adicionar índices compostos para `access_requests` e `users/{uid}/notifications`.
- [ ] `app/lib/src/features/construtoras/presentation/add_membro_dialog.dart` — tratar `pendingCreation: true` na resposta; exibir SnackBar: *"O e-mail não possui conta. Solicitação enviada ao suporte."*; fechar dialog normalmente.
- [ ] `app/lib/src/features/construtoras/presentation/membros_screen.dart` — criar `StreamProvider` para `access_requests` filtrado por `construtoraId` e `status == 'pending'`; renderizar no topo da lista com chip "⏳ Pendente" e e-mail/cargo solicitado.
- [ ] `app/lib/src/features/developer/presentation/users_list_screen.dart` — criar `StreamProvider` para todos os `access_requests` com `status == 'pending'`; renderizar card amarelo de alertas acima da lista de usuários existente; cada item exibe `displayName`, `email`, `role`, `construtoraId`; botão "Aprovar" abre `_ApproveRequestDialog` (campos: password, confirmPassword); ao confirmar chama `approveAccessRequest`.
- [ ] `app/lib/src/common_widgets/sigo_top_bar.dart` — converter `IconButton` do sino em `ConsumerWidget`; criar `StreamProvider` para `users/{uid}/notifications` onde `read == false` e `expiresAt > now`; mostrar `Badge` vermelho com contagem quando > 0; ao clicar exibir `NotificationsPanel` (BottomSheet no mobile, Dialog no desktop) com lista de notificações; toque marca `read: true`.

**Acceptance Criteria:**
- Dado que Admin tenta adicionar `novo@email.com` sem conta, quando confirma o dialog, então o SnackBar exibe mensagem de pendência e `access_requests` tem um doc `{status: 'pending'}`.
- Dado que Admin abre a tela de membros, quando há solicitação pendente, então o item aparece no topo da lista com chip "⏳ Pendente".
- Dado que Dev abre a tela de gestão de usuários, quando há solicitações pendentes, então card amarelo exibe os pedidos no topo.
- Dado que Dev aprova uma solicitação com senha "12345678", quando confirma, então: usuário é criado no Auth; membro é vinculado à construtora; doc em `access_requests` tem `status: approved`; Admin solicitante recebe notificação in-app com a senha.
- Dado que Admin toca a notificação no painel do sino, quando lê, então `read: true` e a notificação some da lista.
- Dado que usuário não-Dev chama `approveAccessRequest`, quando a function é executada, então retorna `permission-denied`.
- Dado que o sino tem notificações não lidas, quando visualizado na top bar, então exibe badge vermelho com contagem correta.

## Implementation Notes

## Spec Change Log

## Design Notes

**`approveAccessRequest` — senha na notificação:**
A senha é passada pelo Dev, usada para criar o usuário no Auth, e imediatamente colocada no campo `body` da notificação (ex: `"A conta de João foi criada. Senha provisória: 12345678. Compartilhe com o funcionário e oriente-o a alterar no primeiro acesso."`). A função nunca persiste a senha em qualquer outro campo do Firestore.

**Notificações efêmeras com TTL:**
`expiresAt = createdAt + 7 dias`. A UI filtra `expiresAt > DateTime.now()`. Um Cloud Scheduler (a ser adicionado futuramente) pode limpar docs expirados; por ora a filtragem client-side é suficiente.

## Verification

**Commands:**
- `cd functions && npm run build` -- expected: 0 erros de TypeScript
- `cd app && flutter analyze` -- expected: sem warnings

**Manual checks:**
- Logar como Admin, tentar adicionar e-mail inexistente → SnackBar de pendência + item na lista de membros com chip.
- Logar como Dev, ver card de alerta → Aprovar → Admin recebe notificação no sino.
- Sino exibe badge vermelho; ao clicar notificação, badge reduz.
