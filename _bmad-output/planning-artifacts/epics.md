---
stepsCompleted: [step-01-validate-prerequisites, step-02-design-epics, step-03-create-stories, step-04-final-validation]
inputDocuments:
  - _bmad-output/planning-artifacts/architecture/architecture-obras-2026-09-21/ARCHITECTURE-SPINE.md
  - _bmad-output/planning-artifacts/ux-designs/ux-obras-2026-09-21/DESIGN.md
  - _bmad-output/planning-artifacts/ux-designs/ux-obras-2026-09-21/EXPERIENCE.md
---

# obras - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for obras, decomposing the requirements from the PRD, UX Design if it exists, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: Adm/owner visualiza lista de membros com cargo + N obras + pendentes (cargo · N obras, chip por papel)
FR2: Filtrar Todos / Por obra / Pendentes + busca por email/displayName
FR3: Visualizar detalhe do membro (vínculo construtora + obras vinculadas + status)
FR4: Atribuir operário à obra (obra + papel Operário + módulos) via setMembership com obraId
FR5: Atribuir admin à obra (papel Admin da obra)
FR6: Trocar papel/módulos do vínculo na obra
FR7: Remover membro da obra (desativar vínculo obra)
FR8: Trocar cargo na construtora operario↔admin (owner só dev via trustedDev)
FR9: Desativar/remover da construtora com remoção das N obras vinculadas
FR10: Tratar erros mapeados pt-br (permission-denied, failed-precondition vínculo ativo, Papel inválido, sem conexão)

### NonFunctional Requirements

NFR1: Rota /construtora/:cId/membros restrita a admin/owner via AccessGuard(adminOnly:true)
NFR2: Leitura com cache Firestore; escrita de vínculo exige rede, sem fila offline
NFR3: Módulos fail-closed (vazio = sem acesso); normalizar rdo→diario, almoxarifado→estoque
NFR4: Acessibilidade — semântica, foco/teclado web, contraste, textScale 1.3x, papel nunca só por cor
NFR5: Responsivo Mobile + Web PWA em SigoLayout (bottomsheet mobile / dialog desktop)
NFR6: Escrita só via Functions setMembership/setConstrutoraRole; auditoria só servidor

### Additional Requirements

- Brownfield Flutter existente, sem starter template (Epic 1 não precisa setup)
- Criar ObraMembersRepository + providers obraMembersProvider((c,o)), obrasDaConstrutoraProvider(c), watchObrasDoMembro
- Por obra agrega N streams no cliente (sem collectionGroup)
- Desativação sem cascata transacional: N setMembership isActive:false + desativa construtora
- Pré-requisito vínculo ativo construtora antes de obra; UI bloqueia com atalho Ativar
- Após mutação invalidar membrosProvider + obraMembersProvider; pull-to-refresh

### UX Design Requirements

UX-DR1: MemberRow — avatar por papel, subtitle Cargo · N obras, chip + chevron, tap abre detalhe
UX-DR2: RoleChip — Proprietário/Administrador/Operário/Pendente nos tokens DESIGN.md
UX-DR3: ObraVinculoRow — nome obra + papel obra + status + overflow (trocar/remover); vazio Atribuir
UX-DR4: AtribuirObraDialog — dropdown obra ativa, segmented papel, FilterChips módulos (default diario), resumo ao vivo, confirm desabilitado sem obra
UX-DR5: ConfirmDestructiveDialog — remover obra / desativar construtora com consequência explícita
UX-DR6: Tokens e estados — cores, tipografia Material, loading/vazio/erro/retry, snackbars sucesso/erro pt-br
UX-DR7: A11y e plataforma — labels, focus trap, Esc fecha, alvos 48dp, painel desktop >1200px [ASSUMPTION]

### FR Coverage Map

FR1: Epic 8 - lista com N obras + pendentes
FR2: Epic 8 - filtros Todos/Por obra/Pendentes + busca
FR3: Epic 8 - detalhe vínculo construtora + obras vinculadas
FR4: Epic 9 - atribuir operário à obra
FR5: Epic 9 - atribuir admin à obra
FR6: Epic 10 - trocar papel/módulos na obra
FR7: Epic 10 - remover da obra
FR8: Epic 10 - trocar cargo na construtora (owner só dev)
FR9: Epic 10 - desativar da construtora + remover de N obras
FR10: Epic 9 (reuso Epic 10) - erros mapeados pt-br

## Epic List

### Epic 8: Visibilidade dos vínculos
Adm/owner enxerga cada membro com Cargo · N nós da hierarquia e abre o detalhe.
**FRs covered:** FR1, FR2, FR3

### Epic 9: Atribuição na Hierarquia (Loteamento a Equipe)
Adm/owner atribui operário/equipe em um nível específico (ex: Lote ou Equipe) com papel + módulos.
**FRs covered:** FR4, FR5, FR10

### Epic 10: Gestão do vínculo
Adm/owner troca papel/módulos na hierarquia, remove de um nó, troca cargo na construtora e desativa.
**FRs covered:** FR6, FR7, FR8, FR9

### Epic 11: Drill-down do Dashboard
O usuário navega pela hierarquia estrutural após o login para detalhar os componentes da construção.
**FRs covered:** (Nova feature de navegação estrutural)

### Epic 12: Gestão de Construtoras no Painel Dev
Devs podem ativar ou desativar o status das construtoras para suspender acesso global no app.
**FRs covered:** (Gestão global)

## Epic 8: Visibilidade dos vínculos

Adm/owner enxerga cada membro com Cargo · N obras e abre o detalhe.

### Story 8.1: Lista com Cargo · N obras

As a adm/owner da construtora,
I want ver cada membro com cargo e quantidade de obras vinculadas,
So that sei quem está alocado onde antes de atribuir.

**Acceptance Criteria:**

**Given** estou logado como admin ou owner com `AccessGuard(adminOnly:true)` liberado
**When** abro `/construtora/:cId/membros`
**Then** vejo pendentes no topo (`Pendente · Cargo`) e ativos abaixo com subtitle `Cargo · N obras` (ex. `Operário · 2 obras`)
**And** avatar/chip seguem DESIGN.md (owner âmbar stars, admin azul, operário neutro; UX-DR1/UX-DR2)
**And** lista combina `watchMembros(c)` + agregação `watchObraMembers(c,o)` por obra ativa sem collectionGroup (AD-5)

### Story 8.2: Filtros e busca

As a adm/owner,
I want filtrar Todos / Por obra / Pendentes e buscar por email/nome,
So that localizo rápido o operário.

**Acceptance Criteria:**

**Given** a lista 8.1 carregada
**When** seleciono `Por obra` + obra X ou digito busca
**Then** vejo só membros da obra X (junção em memória uid→obras) ou match local email/displayName
**And** estado vazio mostra `Nenhum membro encontrado.`; dropdown vazio mostra `Nenhuma obra ativa` (FR2)

### Story 8.3: Detalhe do membro

As a adm/owner,
I want abrir o detalhe com vínculo da construtora e obras vinculadas,
So that decido atribuir/remover/trocar.

**Acceptance Criteria:**

**Given** um membro da lista
**When** toco na linha
**Then** abre BottomSheet (mobile) / Dialog 480px (desktop) com bloco vínculo (cargo, status, desde quando) + bloco obras (`ObraVinculoRow`) + ações (UX-DR3)
**And** sem obra mostra `Nenhuma obra vinculada — Atribuir`; inativo mostra aviso `Ative na construtora primeiro` (AD-9)
**And** leitor de tela anuncia nome, cargo, N obras, status (NFR4)

## Epic 9: Atribuição na Hierarquia (Loteamento a Equipe)

Adm/owner atribui operário/equipe em um nível específico (ex: Lote ou Equipe) com papel + módulos.

### Story 9.1: Atribuir operário à obra

As a adm/owner,
I want atribuir um operário a uma obra com módulos,
So that ele acessa o diário/lotes/estoque da obra.

**Acceptance Criteria:**

**Given** detalhe de membro ativo na construtora
**When** toco `Atribuir à obra`, seleciono obra ativa, mantenho `Operário`, módulos default `[diario]`, confirmo
**Then** chama `setMembership{construtoraId, obraId, role:operario, modules}` (AD-1/AD-3/AD-4) e vejo `Atribuído a {obra} como Operário.` + lista atualiza N obras
**And** Confirm desabilitado sem obra; resumo ao vivo `X será Operário em Y com acesso a Diário` (UX-DR4)
**And** leitura normaliza `member→Operário`; nunca envia `owner` com obraId

### Story 9.2: Atribuir admin + erros e offline

As a adm/owner,
I want atribuir Admin da obra e entender falhas (sem permissão, pré-requisito, sem conexão),
So that não deixo vínculo inconsistente.

**Acceptance Criteria:**

**Given** o dialog 9.1
**When** seleciono `Admin da obra` e confirmo
**Then** envia `role:admin` e o membro vira `obraAdmin` (AD-2)
**And** `permission-denied` → `Você não tem permissão.` com dialog mantido; `failed-precondition` → `Ative o membro na construtora antes...` + atalho Ativar; `Papel inválido` nunca ocorre (opção owner oculta)
**And** sem conexão → `Sem conexão — tente novamente`, sem fila/enqueue (AD-6/NFR2); sucesso invalida `membrosProvider` + `obraMembersProvider` (FR10)

## Epic 10: Gestão do vínculo

Adm/owner troca papel/módulos, remove da obra, troca cargo na construtora e desativa.

### Story 10.1: Trocar papel/módulos na obra

As a adm/owner,
I want trocar Operário↔Admin da obra e módulos,
So that ajusto acesso sem remover e readicionar.

**Acceptance Criteria:**

**Given** vínculo ativo em obra X
**When** abro overflow `Trocar papel`, altero para Admin + módulos `[diario,lotes]` e confirmo
**Then** chama `setMembership{obraId:X, role:admin, modules}`; linha atualiza papel + snackbar de sucesso (FR6, AD-3/AD-4)
**And** módulos normalizam legados e `[]` nega acesso (fail-closed)

### Story 10.2: Remover da obra

As a adm/owner,
I want remover o membro de uma obra com confirmação,
So that revogo acesso preservando histórico.

**Acceptance Criteria:**

**Given** vínculo ativo em obra X
**When** confirmo `Remover de X? Ele perde acesso imediato; diários preservados.`
**Then** chama `setMembership{obraId:X, isActive:false}`; vínculo some, contador decrementa, snackbar `Removido de X.` (FR7, AD-7, UX-DR5)
**And** membro tenta abrir X e vê `Acesso removido` sem retry infinito

### Story 10.3: Trocar cargo na construtora e desativar

As a adm/owner,
I want trocar cargo operário↔admin e desativar da construtora removendo das obras,
So that gerencio o ciclo completo do membro.

**Acceptance Criteria:**

**Given** detalhe do membro
**When** troco cargo para Administrador e confirmo
**Then** chama `setConstrutoraRole{role:admin}`; opção `owner` oculta sem `trustedDev` (só dev altera owner — AD-8/FR8)
**And** ao Desativar com N obras → confirm `Remover de N obras + desativar?` dispara N `setMembership{obraId,isActive:false}` + `setMembership{isActive:false}` construtora (AD-7/FR9)
**And** revogação efetiva imediata via gate `active(cm)` mesmo com docs órfãos

## Epic 11: Drill-down do Dashboard

O usuário navega pela hierarquia estrutural após o login para detalhar os componentes da construção.

### Story 11.1: Navegação Loteamento → Quadra → Lote

As a usuário logado,
I want visualizar a lista de Loteamentos e clicar para ver suas Quadras, e em seguida os Lotes,
So that eu chegue ao contexto correto.

**Acceptance Criteria:**
**Given** estou logado e tenho acesso à construtora
**When** abro o dashboard
**Then** vejo a lista de Loteamentos disponíveis
**And** ao clicar em um Loteamento, navego para a lista de suas Quadras, e sucessivamente até os Lotes.

### Story 11.2: Navegação Lote → Setor → Equipe

As a usuário logado no contexto de um Lote,
I want visualizar os Setores e suas respectivas Equipes,
So that eu veja quem está responsável.

**Acceptance Criteria:**
**Given** que naveguei até um Lote
**When** acesso seus detalhes
**Then** vejo os Setores associados e as Equipes alocadas
**And** posso visualizar as responsabilidades e papéis em cada nó.

## Epic 12: Gestão de Construtoras no Painel Dev

Devs podem ativar ou desativar o status das construtoras para suspender acesso global no app.

### Story 12.1: Adicionar controle de ativação de construtora no Painel Dev

As a dev no Painel Dev,
I want poder ativar e desativar o status de uma construtora,
So that eu suspenda o acesso globalmente a ela.

**Acceptance Criteria:**
**Given** estou logado como dev no Painel Dev
**When** altero o toggle/switch de uma construtora
**Then** atualiza o campo `isActive` no model e no banco
**And** um snackbar de confirmação é exibido.

### Story 12.2: Ocultar construtoras inativas na listagem do usuário

As a usuário final,
I want ver apenas construtoras ativas,
So that eu não acesse projetos inativos indevidamente.

**Acceptance Criteria:**
**Given** que acesso a tela de "Minhas Construtoras"
**When** a lista é carregada
**Then** não vejo construtoras que tenham `isActive == false`
**And** a restrição é forçada no backend (queries `.where('isActive', isEqualTo: true)`) e também via Security Rules (Firestore).

## Epic 13: Navegação Hierárquica Loteamento a Equipe

Este epic implementa a fundação completa de dados e navegação para a nova hierarquia de domínio: Construtora → Loteamento → Quadra → Lote → Etapa → Equipe.

### Story 13.1: Atualizar esquema de dados raiz no Firestore

### Story 13.2: Rotas Declarativas e Drill-down Inicial

### Story 13.3: Ramificação Específica de Etapas por Lote

### Story 13.4: Navegação Final: Alocação de Equipe na Etapa
