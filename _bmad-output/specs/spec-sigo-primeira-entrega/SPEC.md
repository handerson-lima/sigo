---
id: SPEC-sigo-primeira-entrega
companions: 
  - ../../planning-artifacts/architecture/architecture-design-system-2026-09-23/ARCHITECTURE-SPINE.md
  - ../../planning-artifacts/ux-designs/ux-obras-2026-09-23/primeira-entrega/DESIGN.md
  - ../../planning-artifacts/ux-designs/ux-obras-2026-09-23/primeira-entrega/EXPERIENCE.md
  - ../../planning-artifacts/ux-designs/ux-obras-2026-09-23/primeira-entrega/HANDOFF.md
sources: []
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate. Source documents listed in frontmatter are for traceability — consult them only if you need narrative rationale or prose color this contract intentionally omits.

# SIGO — Design system e logos da primeira entrega

## Why

É necessário implementar a primeira entrega visual do SIGO estabelecendo o design system puro, shell e migração de cards, formulários de lote e gestão de logos. A arquitetura limpa é essencial para não acoplar regras de negócio na camada visual e preparar as bases estruturais (backend, storage, regras de negócio isoladas) que permitirão o escalonamento do produto com adoção segura no ambiente corporativo restrito.

## Capabilities

- **CAP-1**
  - **intent:** O sistema renderiza o shell, estilos de fonte, cores (brand-blue, action-blue, dourado) e o tema global de forma dissociada, mantendo componentes (botões, cards) isolados de providers e contextos externos.
  - **success:** O aplicativo funciona com a nova `ThemeData` e `ThemeExtension` aplicados corretamente na UI, de forma que o acoplamento seja estritamente visual sem importar contextos de tenant nas classes de layout genéricas.
- **CAP-2**
  - **intent:** A interface redimensiona o conteúdo e gerencia quebras de texto (reflow) adequadamente dependendo da largura útil (gaveta até 800 unidades lógicas e sidebar acima).
  - **success:** Telas visualizadas nos pontos de interrupção 320, 390 e 800+ se adaptam sem gerar RenderFlex overflows, e as proporções (250/72) dos menus são mantidas.
- **CAP-3**
  - **intent:** O cliente acompanha a edição de lotes com um ciclo de vida explícito sobre envios de fases, bloqueando confirmações falsas baseadas em leitura de cache ou envios simultâneos incertos.
  - **success:** Envios incompletos (incertos ou que dão timeout) mantêm o usuário notificado da falha sem descartar a digitação, e não declaram o lote salvo até um recibo real e assertivo do banco.
- **CAP-4**
  - **intent:** Administradores autorizados de construtora publicam ou alteram o logotipo da organização através do fluxo robusto em staging, impedindo edições por usuários revogados ou clientes forjando regras (bypass).
  - **success:** Um upload de logo segue ciclo transacional (UUID de operação imutável, revisão incrementada e staging). Usuários mal-intencionados que interceptam chamadas REST perdem acesso ou têm transações revertidas por falha de privilégio via Firestore Rules e Cloud Functions.
- **CAP-5**
  - **intent:** O sistema protege os arquivos publicados aceitando apenas PNG/JPEG com o limite de `2 MiB`, impedindo a leitura pública persistente a usuários sem autorização ativa para a construtora correspondente.
  - **success:** Imagens com tamanhos maiores são rejeitadas de forma rápida; imagens aceitas são redimensionadas no servidor (Sharp, máximo de 10 megapixels) removendo metadados nocivos e só renderizam em contas com link validado pelas regras de Storage.

## Constraints

- **AD-1:** Design system e apresentação estritamente puros e burros, sem misturar lógicas de roteamento ou estados do Firebase (Riverpod) nas visualizações compartilhadas.
- **AD-2:** Proibido uso indiscriminado de fontes e escalas soltas. O tema obedece estritamente às escalas de tipografia explícitas mapeadas da UX e à semântica central de `ThemeData` e `ThemeExtension`.
- **AD-4:** Migração unicamente incremental. Preservar o funcionamento (visual e lógico) intacto dos componentes antigos já existentes em rotas e destinos não alcançados nesta refatoração.
- **AD-7 e AD-8:** Segurança focada 100% no servidor para gravação, recibos e autoridade. Nenhuma regra ou permissão pode ser determinada a partir da entrada não sanitizada do cliente. Controle de roles deve ser delegado a transações Firestore que re-validam o UID e contexto de equipe.
- **AD-11:** É obrigatório verificar ambiente real (runtime Node 22 e Sharp), simulações do backend (Firebase Emulators) e regras de segurança consolidadas antes de mesclar ou disponibilizar o build ativado na produção.

## Non-goals

- Refatoração total ou solução definitiva para a "arquitetura modular de rotas" legada, que permanece sem alteração incidental neste pipeline de trabalho atual.
- Implantação de temas escuros ou carregamentos dinâmicos de fontes externas e extras nesta fase inicial.
- Suporte a fallback de exclusão de logo via aplicação front-end; exclusões ou históricos de revisões passadas não têm suporte em UI para os clientes nessa primeira entrega.

## Success signal

- A interface ativará sua primeira iteração de design, renderizando corretamente o shell, cards de obras e lotes com layout fluido. A administração de logs será executada determinística e livre de vazamento e falsificações na nuvem, concluindo a estabilização UX.
