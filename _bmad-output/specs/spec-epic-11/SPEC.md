---
id: SPEC-epic-11
companions:
  - ../architecture/architecture-epic-11-drill-down/ARCHITECTURE-SPINE.md
  - ../ux-designs/ux-obras-2026-09-23/EXPERIENCE.md
sources:
  - ../sprint-change-proposal-2026-09-24.md
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate. Source documents listed in frontmatter are for traceability — consult them only if you need narrative rationale or prose color this contract intentionally omits.

# Epic 11: Drill-down do Dashboard em 5 níveis

## Why

Foi identificada a necessidade de refletir uma hierarquia organizacional e espacial muito mais granular no sistema logo após o login. Atribuir um membro a uma "Obra" genérica não é mais suficiente; a alocação de equipes ocorre possivelmente na camada "Equipe" ou "Setor" e exige uma revisão estrutural para acomodar 5 camadas de navegação e atribuição de responsabilidades. Isso garante que a arquitetura escale para suportar a árvore de navegação aninhada e as novas permissões baseadas no nó.

## Capabilities

- **CAP-1**
  - **intent:** O usuário pode navegar sequencialmente pelos níveis de Loteamento, Quadra, Lote, Setor e Equipe via cards de drill-down no dashboard.
  - **success:** Ao acessar a plataforma, o usuário consegue iniciar no nível "Loteamentos" e clicar sucessivamente em cada nível até visualizar os detalhes das equipes alocadas.
- **CAP-2**
  - **intent:** O usuário pode acessar qualquer nível da hierarquia organizacional diretamente através de URL (deep linking) ou usando os breadcrumbs para voltar.
  - **success:** Ao colar uma URL no formato `/loteamentos/:id/quadras/:id/...` no navegador, o sistema carrega o contexto correto do nó solicitado, caso o usuário possua permissão.
- **CAP-3**
  - **intent:** As regras do Firestore negam leitura de um nó da hierarquia quando o usuário não possui vínculo válido naquele nó ou em um ancestral dele.
  - **success:** Um usuário sem vínculo no "Lote A" recebe permissão negada ao tentar acessá-lo; um operário com vínculo no Lote lê o lote e seus setores/equipes, mas é negado em um lote irmão. (Atribuição da ACL em nível de nó pela UI é escopo futuro — ver Non-goals.)

## Constraints

- O banco de dados Firestore deve modelar a hierarquia utilizando estritamente subcoleções aninhadas (`loteamentos/{id}/quadras/{id}...`) (AD-1). Consultas planas que perdem parentesco hierárquico são proibidas.
- O roteamento GoRouter deve espelhar exatamente os 5 níveis hierárquicos para o estado de navegação (AD-2).
- A validação e propagação de permissões através do `firestore.rules` deve funcionar baseada no nó em que o usuário foi atribuído e bloquear a navegação em partes da hierarquia onde o usuário não possui permissão (AD-3).

## Non-goals

- Refatoração dos módulos de Vínculos de RH (Epic 8, 9, 10), incluindo UI/Functions de atribuição de membros a nós específicos da hierarquia. Esta SPEC (Epic 11) foca apenas na construção da UI do Drill-down, roteamento, estrutura de dados e regras de leitura por nó, destravando o caminho para a futura refatoração da atribuição.

## Success signal

A interface do dashboard permite que o usuário navegue pelos 5 níveis com tempos de carregamento aceitáveis, enquanto a base de dados em subcoleções e regras do Firestore negam acesso com sucesso àqueles que não pertencem ao nó. O acesso a um deep link de uma equipe abre imediatamente a visão daquela equipe sem necessidade de iniciar da raiz.

## Open Questions

- Como agregar métricas ou custos totais da raiz a partir de milhares de Lotes/Equipes?
