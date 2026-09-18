# Epic 5 Context: Módulos Complementares e Visão 360º de Custos

<!-- Compilado a partir do Architecture Spine e das especificações operacionais do SIGO. -->

## Goal

Estruturar e integrar os módulos operacionais complementares da obra no SIGO — Gestão de EPIs, Validação e Qualidade (Checklists/Inspeções), Despesas Administrativas (Contas a Pagar), Fornecedores Corporativos e Desdobramento de Compras em Parcelas —, unificando-os no painel matricial de **Visão 360º de Custos por Lote e Obra**.

## Stories

- **Story 5.1: Módulo EPI** (Catálogo corporativo com C.A., eventos imutáveis de distribuição vinculados aos colaboradores do Epic 4, termos assinados com hash SHA-256 e auditoria).
- **Story 5.2: Módulo Validação (Qualidade & Checklists)** (Templates versionados por disciplina no nível da Construtora, vistorias por lote com status e evidências fotográficas com carimbo/watermark).
- **Story 5.3: Módulo ADM / Contas a Pagar** (Despesas operacionais e títulos da obra, upload de PDFs comprobatórios, controle de liquidação idempotente e valores estritamente em centavos).
- **Story 5.4: Fornecedores Organizacionais** (Catálogo compartilhado no nível da Construtora `construtoras/{cId}/fornecedores/{fId}`, validação de CNPJ/CPF e reutilização entre obras).
- **Story 5.5: Parcelas e Recebimento de Compras / NF** (Desdobramento de notas fiscais em parcelas com garantia matemática $\sum \text{parcelas} \equiv \text{totalCompraCents}$).
- **Story 5.6: Visão 360º de Custos por Lote** (Consolidação multidimensional de Materiais do Almoxarifado, Mão de Obra do RH, Despesas Diretas ADM e Rateios Gerais da Obra).

## Requirements & Constraints

- **Topologia de Dados:**
  - `construtoras/{cId}/fornecedores/{fId}`: Entidade corporativa compartilhada entre obras da mesma construtora.
  - `construtoras/{cId}/catalogo_epis/{epiId}`: Catálogo padronizado com C.A. ativo e validade.
  - `construtoras/{cId}/validacao_templates/{tId}`: Templates de inspeção com versionamento incremental.
  - `construtoras/{cId}/obras/{oId}/despesas_adm/{dId}`: Títulos e contas a pagar da obra.
  - `construtoras/{cId}/obras/{oId}/compras/{cId}`: Compras com array/subcoleção de parcelas.
  - `construtoras/{cId}/obras/{oId}/epi_events/{evId}`: Histórico imutável de entregas/devoluções.
  - `construtoras/{cId}/obras/{oId}/lotes/{lId}/validacoes/{vId}`: Vistorias com fotos privadas.
  - `construtoras/{cId}/obras/{oId}/lotes/{lId}/resumo_custos/consolidado`: Snapshot projetado da Visão 360º.
- **Padrão Monetário em Centavos:**
  - Valores monetários são estritamente inteiros (`amountCents`), com tolerância zero de discrepância de centavos em parcelamentos e desdobramentos contábeis.
- **Autorização e RBAC:**
  - Módulos `epi`, `validacao`, `adm` e `compras` protegidos por `allowedModules` no membro da obra ou construtora, mantendo exceção `dev_roles/{uid}`.
- **Imutabilidade e Segurança:**
  - Bloqueio estrito de exclusão física em registros com efeito contábil ou fiscal (`allow delete: if false;`).
  - Fotos e termos com carimbos de evidência auditáveis em Storage privado.

## Technical Decisions

- **Spine de Arquitetura:** Governado por [`_bmad-output/planning-artifacts/architecture/architecture-epic-5/ARCHITECTURE-SPINE.md`](file:///Users/usuario/obras/_bmad-output/planning-artifacts/architecture/architecture-epic-5/ARCHITECTURE-SPINE.md).
- **Estrutura no Flutter (`app/lib/src/features/`):**
  - `fornecedores/`
  - `epi/`
  - `validacao/`
  - `despesas_adm/`
  - `compras_parcelas/`
  - `custos_360/`
- **Agregação Visão 360º:** Modelo de projeção desacoplada materializada por lote para leitura O(1), atualizada de forma transacional/assíncrona no encerramento de apontamentos de RH, saídas de estoque e liquidação de despesas.

## Cross-Story Dependencies

- **Story 5.4 (Fornecedores)** alimenta tanto as compras do Almoxarifado (Epic 3) quanto as Despesas ADM (5.3) e Parcelas (5.5).
- **Story 5.1 (EPI)** consome os colaboradores cadastrados no Módulo de RH (Story 4.1).
- **Story 5.6 (Visão 360º)** consolida a soma das apropriações de Estoque (Epic 3), RH (Epic 4) e ADM/Parcelas (5.3 / 5.5).
