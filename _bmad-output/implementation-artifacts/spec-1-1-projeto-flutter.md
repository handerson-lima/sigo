---
title: 'Epic 1 - 1-1-projeto-flutter'
type: 'feature'
created: '09-14-2026'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O projeto SIGO necessita de uma fundação limpa em Flutter (PWA Mobile-First) antes de integrarmos qualquer dependência complexa. 

**Approach:** Vamos rodar o `flutter create` para estabelecer a base do projeto, adicionar configurações recomendadas para Web/PWA e configurar os lints ou ferramentas iniciais sem tocar em lógica de Firebase ou Auth.

**Decisions:**
- Inicialização de Pastas: Criar o projeto em uma subpasta `/app` para isolamento do código fonte.
- State Management: `flutter_riverpod`.
- Roteamento: `go_router`.

## Boundaries & Constraints

**Always:** Manter a estrutura orientada a Web/PWA.
**Never:** Não instalar ou configurar pacotes do Firebase nesta fase. Não criar fluxo de login visual; esta etapa é estritamente infraestrutura de pastas e pacotes básicos.

</frozen-after-approval>

## Code Map

- `app/pubspec.yaml` -- Para dependências base.
- `app/lib/main.dart` -- Ponto de entrada do app (limpeza do contador padrão).

## Tasks & Acceptance

**Execution:**
- [ ] `flutter create app` -- Criação base -- Estabelecer fundação.
- [ ] `app/pubspec.yaml` -- Adicionar dependências core -- Pacotes decididos (flutter_riverpod, go_router).
- [ ] `app/lib/main.dart` -- Limpeza -- Remover código template (contador).

**Acceptance Criteria:**
- Given que o projeto Flutter foi criado, when executo `cd app && flutter run -d chrome`, then a aplicação Web carrega uma tela inicial em branco ou Hello World sem erros no console.

## Implementation Notes

## Spec Change Log

- 2026-09-15 — Reconciliação documental: o `status: done` do cabeçalho é o registro histórico da criação da base. O código evoluiu com Firebase e módulos; as restrições da fundação descrevem somente aquela etapa. A execução de build web/aceite dessa fundação não foi demonstrada na análise atual, portanto o sprint registra `review`. Planejamento vigente: [docs/implementation_plan.md](../../docs/implementation_plan.md). Privilégios globais de dev mantidos por solicitação do usuário; correções aguardam aprovação em [plano C0–C6](../../docs/plano-de-correcao-2026-09-15.md).

## Review Triage Log

## Verification

**Commands:**
- `cd app && flutter analyze` -- expected: Sem erros de linting.
- `cd app && flutter build web` -- expected: Build completado com sucesso.
