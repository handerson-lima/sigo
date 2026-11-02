# AGENTS.md — SIGO

## Preferências do Projeto

- **Sempre invocar os agents e skills BMad adequados** para cada tarefa. Não executar trabalho diretamente quando um agent ou workflow especializado existir.
- Responder e gerar documentação sempre em **pt-br** (`communication_language = "pt-br"`, `document_output_language = "pt-br"`).

## Agents BMad Instalados (`.agent/agents/` & `.agent/skills/`)

| Agent ID | Persona | Papel Principal |
|----------|---------|-----------------|
| `bmad-agent-dev` | 💻 **Amelia** (Senior Software Engineer) | Implementação TDD (red-green-refactor), correção de bugs, testes E2E/API, code review e retrospectivas |
| `bmad-agent-architect` | 🏗️ **Winston** (System Architect) | Arquitetura técnica, decisões de design (ADRs), invariantes de sistema e prontidão de implementação |
| `bmad-agent-pm` | 📋 **John** (Product Manager) | Descoberta de produto, criação/validação de PRD, quebra em épicos/stories e correção de rumo |
| `bmad-agent-ux-designer` | 🎨 **Sally** (UX Designer) | Design de experiência e interface (`DESIGN.md` / `EXPERIENCE.md`) e revisão de UX/UI Flutter |
| `bmad-agent-analyst` | 📊 **Mary** (Business Analyst) | Pesquisa de mercado/domínio/técnica, brainstorming, Product Brief, PRFAQ e contexto do repositório |

## Mapeamento de Tarefas → Agents e Workflows BMad

| Tarefa | Agent BMad | Skill / Workflow BMad (`.agent/skills/<skill>/SKILL.md`) |
|--------|------------|----------------------------------------------------------|
| Implementar código, corrigir bugs, criar funcionalidades | `bmad-agent-dev` (Amelia) | `bmad-build` |
| Ciclo autônomo de desenvolvimento (iteração não assistida) | `bmad-agent-dev` (Amelia) | `bmad-build-auto` |
| Arquitetura, design técnico, decisões de sistema | `bmad-agent-architect` (Winston) | `bmad-architecture` |
| Revisão de código (adversarial, edge cases, verification gaps, UX) | `bmad-agent-dev` (Amelia) / `bmad-agent-ux-designer` (Sally) | `bmad-code-review` ou `bmad-review` |
| Walkthrough / revisão guiada de mudanças para humanos | `bmad-agent-dev` (Amelia) | `bmad-walkthrough` |
| Criar/atualizar/validar PRD | `bmad-agent-pm` (John) | `bmad-prd` |
| Criar/atualizar/validar Spec ou quebrar Spec em stories | `bmad-agent-pm` (John) / `bmad-agent-dev` (Amelia) | `bmad-spec` |
| Quebrar requisitos em Épicos e User Stories | `bmad-agent-pm` (John) | `bmad-create-epics-and-stories` |
| Planejamento de sprint, prontidão e status (`sprint-status.yaml`) | `bmad-agent-pm` (John) / `bmad-agent-dev` (Amelia) | `bmad-sprint-planning` |
| Avaliar impacto de mudança de escopo durante a sprint | `bmad-agent-pm` (John) | `bmad-correct-course` |
| Pesquisa de mercado, domínio, técnica, competitiva ou escolha de tecnologia | `bmad-agent-analyst` (Mary) | `bmad-deep-recon` |
| Criar/atualizar Product Brief | `bmad-agent-analyst` (Mary) | `bmad-product-brief` |
| Working Backwards / PRFAQ | `bmad-agent-analyst` (Mary) | `bmad-prfaq` |
| Stress-test / validação de ideia bruta | `bmad-agent-analyst` (Mary) | `bmad-forge-idea` |
| Brainstorming facilitado | `bmad-agent-analyst` (Mary) | `bmad-brainstorming` |
| Elicitação avançada / crítica profunda (Socrático, Pre-mortem, Red Team) | `bmad-agent-analyst` (Mary) | `bmad-advanced-elicitation` |
| UX/Design (`DESIGN.md` e `EXPERIENCE.md`) | `bmad-agent-ux-designer` (Sally) | `bmad-ux` |
| Discussão multi-agente / mesa redonda entre personas BMad | Todos os agents BMad | `bmad-party-mode` |
| Testes automatizados (API e E2E) | `bmad-agent-dev` (Amelia) | `bmad-qa-generate-e2e-tests` |
| Retrospectiva de épico concluído | `bmad-agent-dev` (Amelia) | `bmad-retrospective` |
| Configurar, atualizar ou auditar instruções de `AGENTS.md` | `bmad-agent-analyst` (Mary) | `bmad-project-context` |
| Customizar overrides de agents/workflows BMad (`_bmad/custom/`) | Qualquer agent | `bmad-customize` |
| Dúvidas sobre o BMad ou recomendação do próximo passo | Qualquer agent | `bmad-help` |

## Regras de Execução

1. **Seleção de Agent/Skill**: Antes de começar qualquer trabalho, identifique na tabela acima qual agent e skill BMad são mais adequados.
2. **Ativação de Skills**:
   - No **Antigravity**: leia o arquivo `.agent/skills/<nome-do-skill>/SKILL.md` usando `read_file` (ou acione o skill correspondente) antes de iniciar e siga rigorosamente o workflow indicado.
   - Em outros ambientes (Claude Code / OpenCode): invoque via ferramenta `skill` quando disponível ou leia `.agent/skills/<nome-do-skill>/SKILL.md`.
3. **Execução de Subagentes**:
   - No **Antigravity**: lance subagentes via `invoke_subagent` utilizando os agents BMad nativos registrados em `.agent/agents/` (`bmad-agent-dev`, `bmad-agent-architect`, `bmad-agent-pm`, `bmad-agent-ux-designer`, `bmad-agent-analyst`) ou `self` / `research` conforme solicitado pelas etapas do workflow (ex.: implementação em `step-03-implement.md` e camadas de revisão em `step-04-review.md`). Para regras do Firestore (`firestore.rules`), delegue obrigatoriamente ao subagente `firestore-rules-author`.
   - Em outros ambientes: utilize a ferramenta `task` quando o workflow solicitar.
4. **Scripts BMad no Sandbox**:
   - Ao executar scripts em `_bmad/scripts/*.py` (como `render_skill.py`, `resolve_config.py`, `resolve_customization.py`, `memlog.py`) dentro do sandbox, prefira `python3 "{project-root}/_bmad/scripts/<script>.py"` caso `uv run` esteja bloqueado pelo sandbox.
5. **Disciplina de Workflow**: Nunca pule etapas do workflow (clarify, plan, implement, review, present) nem checkpoints de aprovação sem justificativa explícita do usuário.
