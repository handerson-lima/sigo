# Sprint Change Proposal: Hierarquia e Drill-down do Dashboard

## 1. Issue Summary
**Problema / Gatilho:** 
Foi identificada a necessidade de refletir uma hierarquia organizacional e espacial muito mais granular no sistema logo após o login. O usuário deverá navegar por um fluxo exato de drill-down no Dashboard: **Loteamento → Quadra → Lote → Setor → Equipe**.
**Contexto:**
Atualmente, as Epics (como a Epic 8, 9 e 10) baseiam-se em atribuições diretas de operários e admins a uma "Obra" genérica pertencente a uma "Construtora". Essa nova hierarquia exige uma revisão estrutural para acomodar as 5 camadas de navegação e atribuição de responsabilidades, impactando o modelo de dados, as rotas e a interface de usuário.

## 2. Impact Analysis
- **Epic Impact:** 
  - *Epic 8, 9 e 10* (Vínculos, Atribuição e Gestão): Precisarão ser refatoradas. Atribuir um membro a uma "Obra" não é mais suficiente; a alocação de equipes ocorre possivelmente na camada "Equipe" ou "Setor" e o agrupamento visual de permissões mudará para suportar N camadas.
  - *Novas Epics:* Será necessária uma nova Epic focada exclusivamente na construção da UI e roteamento do Drill-down do Dashboard em 5 níveis.
- **Artifact Conflicts:**
  - *Documentos Ausentes:* O PRD original não foi localizado, portanto a análise focou em `epics.md`.
  - *Arquitetura:* A definição de roteamento modular (`ARCHITECTURE-SPINE.md`) precisará suportar deep links e breadcrumbs do tipo `/loteamento/:id/quadra/:id/lote/:id/setor/:id/equipe/:id`. O banco de dados precisará de coleções/subcoleções aninhadas ou referências estruturadas para suportar a árvore hierárquica.
  - *UI/UX:* Os mockups atuais de Dashboard/Obras precisarão ser refeitos para acomodar seletores/cards de navegação em profundidade (drill-down).

## 3. Recommended Approach
**Abordagem Selecionada: Option 3 (PRD MVP Review)**
Como a mudança altera a espinha dorsal de navegação e a forma como as entidades principais (Obras/Membros) se relacionam, **não é viável realizar apenas ajustes diretos nas histórias existentes** (Option 1). A revisão do MVP é necessária para alinhar a estrutura de dados (Firestore) e as rotas (GoRouter) antes de criar a interface.

- **Esforço Estimado:** Alto.
- **Risco:** Médio (Requer refatoração cuidadosa da base de dados e providers).
- **Justificativa:** Garantir que a arquitetura escale perfeitamente para esses 5 níveis evitará retrabalho pesado no futuro. As histórias de vínculos de RH (Epic 8, 9, 10) ficarão bloqueadas até que a estrutura de Loteamento a Equipe esteja modelada.

## 4. Detailed Change Proposals (Batch Edit Proposals)

### A. Modificação em epics.md (Epics de RH)
```diff
- Epic 9: Atribuição à obra
- Adm/owner atribui operário e admin à obra com papel + módulos.
+ Epic 9: Atribuição na Hierarquia (Loteamento a Equipe)
+ Adm/owner atribui operário/equipe em um nível específico (ex: Lote ou Equipe) com papel + módulos.
```
*Rationale: A atribuição de acesso não será apenas "por obra", mas baseada no nó da hierarquia.*

### B. Adição de Nova Epic em epics.md
```diff
+ ## Epic 11: Drill-down do Dashboard
+ O usuário navega pela hierarquia estrutural após o login para detalhar os componentes da construção.
+ 
+ ### Story 11.1: Navegação Loteamento → Quadra → Lote
+ As a usuário logado, I want visualizar a lista de Loteamentos e clicar para ver suas Quadras, e em seguida os Lotes, So that eu chegue ao contexto correto.
+ 
+ ### Story 11.2: Navegação Lote → Setor → Equipe
+ As a usuário logado no contexto de um Lote, I want visualizar os Setores e suas respectivas Equipes, So that eu veja quem está responsável.
```
*Rationale: Materializar o drill-down exigido pelo gatilho de mudança da correção de rumo.*

### C. Atualização Arquitetural (Roteamento Modular)
```diff
- Rota principal: /obras/:obraId/dashboard
+ Rotas aninhadas de drill-down:
+ /loteamentos
+ /loteamentos/:loteamentoId/quadras
+ /loteamentos/:loteamentoId/quadras/:quadraId/lotes
+ /.../lotes/:loteId/setores/:setorId/equipes
```
*Rationale: O GoRouter deve espelhar a estrutura de 5 níveis para permitir navegação direta (deep linking).*

## 5. Implementation Handoff
**Classificação de Escopo:** **Major** (Fundamental replan required).

**Plano de Handoff:**
- **Product Manager / Solution Architect (`bmad-agent-architect`, Winston / `bmad-spec`):** Deverão atualizar o `ARCHITECTURE-SPINE.md` e gerar as especificações do banco de dados (Firestore schemas) para a nova árvore.
- **UX Designer (`bmad-agent-ux-designer`, Sally):** Deverá conceber novos mockups para a experiência de drill-down (cards, breadcrumbs, transições).
- **Developer (`bmad-agent-dev`, Amelia):** Irá implementar as rotas, os repositories e as UIs de listagem logo após a arquitetura estar definida.
