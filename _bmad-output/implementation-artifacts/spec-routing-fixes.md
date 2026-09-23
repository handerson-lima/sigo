---
title: 'Fix Routing Architecture'
type: 'refactor'
created: '2026-09-23'
status: 'in-review'
baseline_commit: 'dfda67bb97b4a0d4fb9f8d9aa6342eee583e5efe'
route: 'dispatch'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A nova arquitetura modular de rotas apresenta problemas identificados em code review: falta de tratamento para 404 (erro de rota), estrutura plana que quebra o *navigation stack*, duplicação de acessos no RH, uso inadequado de `extra` para passar estados em memória e guards redundantes no módulo dev.

**Approach:** Refatorar o `GoRouter` no `app_router.dart` para utilizar rotas aninhadas em vez de concatenar listas planas globais. Adicionar um `errorBuilder` na instância principal. Corrigir as rotas do RH unificando os acessos duplicados e trocando a passagem via `extra` pela recuperação via ID. Limpar as chamadas redundantes ao `AccessGuard` nas rotas filhas de desenvolvedor.

## Boundaries & Constraints

**Always:** Manter a separação de rotas por feature (`*_routes.dart`), mas utilizando-os como sub-rotas ou integrados hierarquicamente para que a navegação do sistema mantenha o histórico corretamente.

**Never:** Usar `state.extra` para passagem de dados críticos entre telas de navegação profunda; não depender de rotas totalmente planas no `GoRouter` raiz para recursos aninhados.

**Decisões Arquiteturais:**
Utilizar a Opção A (Nested Router Root) para a hierarquia da construtora. Todas as rotas de `obras`, `rh`, `diario`, etc. deverão ser configuradas como rotas filhas no `app_router.dart`.

</frozen-after-approval>

## Code Map

- `app/lib/src/routing/app_router.dart` -- Ponto de entrada do GoRouter. Precisa do `errorBuilder` e de reestruturar a montagem das rotas filhas para suportar aninhamento (nested routes).
- `app/lib/src/features/developer/routing/dev_routes.dart` -- Remover a duplicação do `AccessGuard` interno, confiando no `app_router`.
- `app/lib/src/features/rh/routing/rh_routes.dart` -- Consolidar `RhPaths.rh` e `RhPaths.funcionarios`. Remover o uso de `state.extra` em `editarFuncionario`.
- `app/lib/src/features/construtoras/routing/construtora_routes.dart` -- Ajustar para suportar aninhamento das demais rotas filhas (obras, diário, RH).
- Demais arquivos `*_routes.dart` -- Atualizar seus `paths` (retirando prefixos estáticos de caminho pai) caso passem a ser declaradas como sub-rotas.

## Tasks & Acceptance

**Execution:**
- [ ] `app/lib/src/routing/app_router.dart` -- Adicionar `errorBuilder` retornando uma tela de erro padrão ou redirecionando -- Lida com rotas não encontradas (404).
- [ ] `app/lib/src/features/developer/routing/dev_routes.dart` -- Remover `AccessGuard(devOnly: true)` dos `GoRoute` -- Reduz complexidade pois `app_router.dart` já possui `redirect` global.
- [ ] `app/lib/src/features/rh/routing/rh_routes.dart` -- Remover rota duplicada (`RhPaths.rh` / `RhPaths.funcionarios`) -- Limpeza de código e evitar duas URIs pra mesma tela.
- [ ] `app/lib/src/features/rh/routing/rh_routes.dart` -- Alterar passagem do Funcionario do `extra` para usar o `fId` no fetch -- Suporte real a deep link.
- [ ] `app/lib/src/routing/app_router.dart` e `*_routes.dart` -- Refatorar para usar nested routes hierárquicas (ex: rotas filhas de `/construtora/:cId`) -- Consertar a pilha de navegação (back button).

**Acceptance Criteria:**
- Given que acesso uma URL inválida, when carregar, then o `errorBuilder` entra em ação impedindo crash.
- Given que navego para a página de Editar Funcionário a partir de um link direto (deep link / F5), when o `fId` está na URL, then a página carrega corretamente os dados sem quebrar por falta de estado no `extra`.
- Given que o aplicativo monta o Router, when eu verifico a rota de desenvolvedor, then não há múltiplos `AccessGuard` sobrepondo-se desnecessariamente.

## Design Notes

A hierarquia de rotas de entidades vinculadas à construtora deve seguir este padrão aproximado no `app_router`:

```dart
GoRoute(
  path: '/construtora/:cId',
  builder: (context, state) => ..., 
  routes: [
    ...obraRoutes,   // path passará a ser 'obra/:oId' (e não '/construtora/:cId/obra/:oId')
    ...rhRoutes,
    ...diarioRoutes,
  ]
)
```
Isso demandará atualizar os `path` nos arquivos de sub-rotas para serem relativos ou ajustados conforme documentação do GoRouter.
