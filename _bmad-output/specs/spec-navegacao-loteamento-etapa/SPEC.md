---
id: SPEC-navegacao-loteamento-etapa
companions: ["hierarquia-etapas.md"]     
sources: []        
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate. Source documents listed in frontmatter are for traceability — consult them only if you need narrative rationale or prose color this contract intentionally omits.

# Navegação Loteamento e Etapa

## Why

O negócio e a estrutura da aplicação mudaram para refletir corretamente as entidades do domínio, substituindo a antiga denominação "Obras" e "Setor". Isso padroniza o funil de navegação, permitindo ao usuário navegar pelas entidades reais (Loteamento, Quadra, Lote, Etapa, Equipe) de forma coesa, após selecionar uma construtora. Essa mudança garante aderência aos novos requisitos de negócio, impactando diretamente UX e a arquitetura de dados (Firestore e Rotas GoRouter).

## Capabilities

- **CAP-1**
  - **intent:** O sistema deve permitir ao usuário, ao clicar no card de uma construtora, visualizar imediatamente a listagem de cards de Loteamentos vinculados à mesma.
  - **success:** Ao acionar o card de construtora, a tela transita para a listagem apresentando os Loteamentos correspondentes, sem exibir "Obras".
- **CAP-2**
  - **intent:** O usuário deve ser capaz de navegar hierarquicamente aprofundando o contexto de forma sequencial: de Loteamento para Quadra, de Quadra para Lote, de Lote para Etapa, e de Etapa para Equipe.
  - **success:** A interface permite o drill-down completo (Loteamento -> Quadra -> Lote -> Etapa -> Equipe) exibindo a cada passo apenas as sub-entidades pertinentes ao contexto selecionado no nível anterior.

## Constraints

- A nomenclatura "Obras" está totalmente abolida da navegação da aplicação; deve ser substituída por "Loteamentos".
- A nomenclatura "Setor" está abolida da navegação neste contexto; deve ser substituída por "Etapa".
- A navegação deve ser estritamente direcional de acordo com a árvore imposta: Construtora -> Loteamento -> Quadra -> Lote -> Etapa -> Equipe. (Ver ramificações específicas em `hierarquia-etapas.md`).

## Non-goals

- Alteração nos perfis de acesso de construtora ou no dashboard principal (que não seja a refatoração do label/click). O foco é o fluxo de drill-down da hierarquia.

## Success signal

- Um testador ou usuário acessa a aplicação, seleciona uma construtora e encontra "Loteamentos". Ele clica em um Loteamento e é levado às "Quadras", depois "Lotes", "Etapas", até "Equipes", comprovando que o drill-down e a nomenclatura estão corretos.

## Assumptions

- O esquema atual no Firestore precisará de refatoração para comportar os novos nomes ("Loteamento", "Etapa") e os relacionamentos corretos caso ainda não reflitam essa realidade estrita.
- As rotas (do GoRouter) relacionadas à hierarquia antiga serão reescritas para refletir o caminho URL semântico correspondente.
- Não haverá script de migração de dados. Os dados existentes de "Obras" e "Setores" no ambiente de desenvolvimento serão apagados para que a nova estrutura inicie do zero.
