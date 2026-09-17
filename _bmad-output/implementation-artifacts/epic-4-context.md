# Epic 4 Context: Módulos Core - RH e Custos de Mão de Obra

<!-- Compiled from planning artifacts and SIGO specifications. -->

## Goal

Estabelecer o módulo de Recursos Humanos (RH) e Gestão de Pessoas no SIGO, abrangendo o cadastro estruturado de profissionais (próprios e terceirizados) e equipes, a lista de chamada diária com alocação em lotes, o cálculo versionado do custo de mão de obra em centavos e a apropriação imutável de despesas de pessoal por obra e lote.

## Stories

- **Story 4.1: RH - Cadastro de Funcionários e Equipes** (Regimes CLT, PJ e Avulso, base salarial em centavos, encargos e equipes de trabalho).
- **Story 4.2: RH - Lista de Chamada Diária** (Registro de presença/falta/meio-período, persistência do "Lote Atual" e rateio percentual entre lotes).
- **Story 4.3: RH - Custos de Mão de Obra e Apropriação** (Taxa diária versionada, encargos, divisor configurável e snapshots imutáveis no fechamento diário).
- **Story 4.4: RH - Validação de Invariantes e Auditoria** (Invariante de 100% de alocação para presentes, zero apropriação para ausentes, prevenção de duplicidade trabalhador/data/obra e retificações auditadas).

## Requirements & Constraints

- **Localização dos Dados:**
  - Funcionários são cadastrados no nível da construtora (`construtoras/{cId}/funcionarios/{fId}`), permitindo sua disponibilidade e transferência entre diferentes obras da mesma empresa.
  - Equipes podem ser corporativas ou específicas da obra (`construtoras/{cId}/equipes/{eId}`).
  - Apontamentos de chamada e apropriações residem no escopo da obra (`construtoras/{cId}/obras/{oId}/chamadas/{chId}`).
- **Padrão Monetário em Centavos:**
  - Em estrita consonância com a Story 3.7 e C3, todos os valores financeiros (`baseSalaryCents`, `additionalCostsCents`, `totalDailyRateCents`) devem ser representados como números inteiros (`int`), eliminando imprecisões de ponto flutuante.
- **Autorização e Matriz de Acesso:**
  - Acesso ao módulo de RH requer: Dev Global (`dev`), Administrador/Owner da construtora (`admin(c)`) ou membro com módulo `rh` autorizado (`'rh' in cm(c).get('modules',[])` ou no vínculo de membro da obra).
  - Usuários sem módulo `rh` ou perfil administrativo não têm acesso às rotas nem permissão de leitura/escrita nas coleções de RH.
- **Integridade e Não-Exclusão:**
  - Proibida exclusão física de funcionários e equipes no Firestore (`allow delete: if false;`).
  - Desativação operacional deve utilizar inativação lógica (`isActive: false`).
- **Resiliência Offline:**
  - Leitura e listagem de colaboradores com suporte a cache local (IndexedDB / `read_cache.dart`) para viabilizar chamada de campo mesmo sem conectividade com a internet.

## Technical Decisions

- **Arquitetura:** Camadas de Domínio, Dados e Apresentação no pacote `app/lib/src/features/rh/`.
- **Modelagem de Colaboradores:**
  - `id`: UUID v4 estável.
  - `name`: Nome completo obrigatório.
  - `cpf`: CPF com validação de formato e dígitos verificadores.
  - `role`: Cargo/Função (ex: Pedreiro, Servente, Carpinteiro, Encarregado, Eletricista).
  - `teamId`: Referência opcional à equipe.
  - `employmentType`: Enum (`clt`, `pj`, `avulso`).
  - `salaryBasis`: Enum (`mensal`, `diaria`).
  - `baseSalaryCents`: Inteiro em centavos de Real.
  - `additionalCostsCents`: Encargos e benefícios estimados em centavos de Real.
  - `totalDailyRateCents`: Valor da diária calculado para apropriação nos lotes (para regime mensal: `(baseSalaryCents + additionalCostsCents) ~/ 30` dias corridos padrão com DSR; para diária: `baseSalaryCents + additionalCostsCents`).
  - `isActive`: Flag booleana de controle de status ativo/inativo.
  - `schemaVersion`: Inteiro `1`.
- **Roteamento:** GoRouter protegido com `AccessGuard(module: 'rh')`.

## UX & Interaction Patterns

- **Listagem de Funcionários (`FuncionariosListScreen`):** Cards detalhados com badge de regime (CLT / PJ / Avulso), status visual (Ativo / Inativo), cargo, equipe associada e taxa diária calculada formatada em BRL (R$).
- **Filtros rápidos:** Filtragem por status (Ativos / Inativos / Todos), pesquisa por nome/cargo e filtro por equipe.
- **Formulário de Cadastro (`FuncionarioFormScreen`):** Máscara automática de CPF, campos monetários formatados em centavos reais com preview dinâmico em tempo real da taxa diária estimada (`R$/dia`).
- **Feedback & Validação:** Validação reativa síncrona com indicação clara de campos obrigatórios e confirmação de sucesso com SnackBar contextual.

## Cross-Story Dependencies

- **Story 4.1** é o pré-requisito indispensável para todas as histórias subsequentes do Epic 4:
  - Story 4.2 (Chamada Diária) consome a lista de funcionários ativos e equipes da construtora.
  - Story 4.3 (Custos e Snapshots) utiliza a `totalDailyRateCents` de cada colaborador para consolidar a apropriação financeira nos lotes da obra.
  - Story 4.4 (Invariantes) audita a consistência dos registros de ponto e rateio de horas/custos com base nos contratos estabelecidos na 4.1.
