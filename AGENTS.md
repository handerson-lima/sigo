# AGENTS.md — SIGO

## Preferências do Projeto

- **Sempre invocar os agents BMad adequados** para cada tarefa. Não executar trabalho diretamente quando um agent especializado existir.
- Responder sempre em **pt-br**.

## Mapeamento de Tarefas → Agents BMad

| Tarefa | Agent/Skill BMad |
|--------|------------------|
| Implementar código, corrigir bugs, criar funcionalidades | `bmad-agent-dev` (Amelia) via `bmad-build` |
| Arquitetura, design técnico, decisões de sistema | `bmad-agent-architect` (Winston) via `bmad-architecture` |
| Revisão de código | `bmad-code-review` ou `bmad-review` |
| Criar/atualizar PRD | `bmad-agent-pm` (John) via `bmad-prd` |
| Criar/atualizar spec | `bmad-spec` |
| Planejamento de sprint | `bmad-sprint-planning` |
| Pesquisa, análise de mercado | `bmad-agent-analyst` (Mary) via `bmad-deep-recon` |
| UX/Design | `bmad-agent-ux-designer` (Sally) via `bmad-ux` |
| Brainstorming | `bmad-brainstorming` |
| Testes automatizados | `bmad-qa-generate-e2e-tests` |
| Retrospectiva | `bmad-retrospective` |
| Contexto do repositório | `bmad-project-context` |

## Regras de Execução

1. Antes de começar qualquer trabalho, verificar qual agent/skill BMad é mais adequado.
2. Invoque o skill via ferramenta `skill` e siga o workflow indicado.
3. Subagentes devem ser lançados via ferramenta `task` quando o workflow solicitar.
4. Nunca pule etapas do workflow sem justificativa explícita do usuário.
