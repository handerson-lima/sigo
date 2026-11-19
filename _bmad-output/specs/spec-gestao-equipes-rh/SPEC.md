---
id: SPEC-gestao-equipes-rh
companions:
  - ./stories.yaml
sources:
  - ../../app/lib/src/features/rh/domain/equipe.dart
  - ../../app/lib/src/features/rh/data/rh_repository.dart
  - ../../app/lib/src/features/rh/routing/rh_routes.dart
  - ../../app/lib/src/features/rh/presentation/funcionarios_list_screen.dart
  - ../../app/lib/src/features/rh/presentation/equipes_dialog.dart
  - ../../app/lib/src/features/rh/presentation/funcionario_form_screen.dart
  - ../../app/lib/src/common_widgets/sigo_sidebar.dart
  - ../../app/lib/src/features/lotes/presentation/atribuir_lotacao_lote_sheet.dart
  - ../../app/lib/src/features/etapas/domain/etapa.dart
  - ../../app/lib/src/features/equipes/presentation/equipes_list_screen.dart
  - ../../firestore.rules
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate.

# Gestão Completa de Equipes no RH e Unificação com Lotes e Etapas

## Why

Atualmente, a gestão de equipes no SIGO sofre de três lacunas críticas que prejudicam a usabilidade e a consistência dos dados:

1. **Baixa descoberta e CRUD incompleto no RH:** O gerenciamento de equipes só é acessível por um ícone discreto (`Icons.groups`) na barra superior de `FuncionariosListScreen`, abrindo `EquipesDialog`, que permite apenas criar uma equipe com nome simples e alternar `isActive`. Não há rota própria, não é possível editar nome ou definir/alterar líder (`leaderId` / `leaderName`, já previstos no domínio `Equipe`), não há validação de duplicidade de nome, não há contagem de colaboradores por equipe nem aviso ao inativar uma equipe que ainda possui membros vinculados.
2. **Fricção nos fluxos de cadastro e alocação:** Ao cadastrar ou editar um colaborador (`FuncionarioFormScreen`) ou ao atribuir mão de obra a um lote/etapa (`AtribuirLotacaoLoteSheet`), se a equipe desejada ainda não existe, o usuário precisa abandonar o fluxo atual para criá-la no RH e depois retornar.
3. **Fontes de verdade duplicadas em Etapas:** A tela `EquipesListScreen` na hierarquia de loteamentos (`.../etapas/:etapaId/equipes`) ainda consulta a coleção raiz legada `/equipes` (`EquipeLote`), desconectada do RH e sem criação de registros, enquanto o modelo `Etapa` já possui os campos `equipeId` e `equipeNome` apontando para as equipes do RH (`construtoras/{cId}/equipes`).

Esta especificação estabelece `construtoras/{cId}/equipes` como **fonte única de verdade** para equipes em todo o SIGO, entregue em 3 fases incrementais.

---

## Capabilities

### Fase 1 — Hub RH com Gestão Completa de Equipes

- **CAP-1 (Hub RH, Rota Dedicada e Sidebar)**
  - **intent:** Promover a gestão de equipes para cidadã de primeira classe no módulo de RH com navegação direta por abas e rota dedicada.
  - **success:** Existe a rota `/construtoras/:cId/rh/equipes` (protegida por `AccessGuard(module: 'rh')`), o Hub RH exibe as abas `Funcionários | Equipes` sincronizadas com `/rh/funcionarios` e `/rh/equipes`, e a `SigoSidebar` apresenta rótulo claro sob `canRh` (ex.: `"RH — Funcionários e Equipes"` ou `"Recursos Humanos"`), mantendo destaque ativo em ambas as abas (sem conflitar com `/chamadas`).

- **CAP-2 (Listagem, Filtros, Contagem de Membros e Empty State de Equipes)**
  - **intent:** Permitir visualizar, filtrar e auditar rapidamente todas as equipes da construtora e sua composição atual.
  - **success:** A aba `Equipes` exibe busca por nome/líder, filtro por status (`Ativos`, `Todos`, `Inativos`), nome da equipe, nome do líder (quando definido), contagem de colaboradores ativos vinculados (`f.teamId == equipe.id && f.isActive`), badge de status e empty state amigável com CTA direto para cadastrar a primeira equipe.

- **CAP-3 (Formulário Completo de Criação/Edição e Proteção na Inativação)**
  - **intent:** Garantir integridade e ciclo de vida completo no cadastro de equipes (criação, edição de nome/líder e inativação segura).
  - **success:** Um formulário reutilizável permite criar e editar equipes com validação de nome obrigatório e **unicidade case-insensitive** na construtora (ignorando o próprio `id` na edição), seleção opcional de líder entre funcionários ativos (com opção `"Sem líder"`), e inativação com **diálogo de confirmação explícito** sempre que houver colaboradores vinculados à equipe.

### Fase 2 — Criação Contextual de Equipes

- **CAP-4 (Criação Contextual em `FuncionarioFormScreen`)**
  - **intent:** Eliminar a quebra de fluxo ao cadastrar/editar um colaborador cuja equipe ainda não existe.
  - **success:** Ao lado do dropdown `Equipe de Trabalho (Opcional)` em `FuncionarioFormScreen`, há o botão `+ Nova equipe` que abre o formulário reutilizável de equipe; ao salvar, a nova equipe é **auto-selecionada** no dropdown sem perda dos demais campos preenchidos no formulário.

- **CAP-5 (Criação Contextual em `AtribuirLotacaoLoteSheet`)**
  - **intent:** Permitir criar uma nova equipe diretamente ao atribuir mão de obra a um lote/etapa quando o usuário possui permissão de RH, e orientar claramente quem não possui permissão.
  - **success:** Na aba `Equipes RH` de `AtribuirLotacaoLoteSheet`, usuários com permissão `canRh` visualizam o botão `+ Nova equipe` (no topo e no empty state) e podem criar a equipe sem sair do sheet; usuários sem `canRh` não veem o botão de criação e recebem mensagem orientativa clara explicando que o cadastro de equipes requer permissão de RH ou perfil administrador da construtora.

### Fase 3 — Unificação de `EquipesListScreen` em Etapas

- **CAP-6 (Fonte Única de Verdade em `EquipesListScreen`)**
  - **intent:** Substituir a leitura da coleção raiz legada `/equipes` (`EquipeLote`) pela fonte única `construtoras/{cId}/equipes` e `construtoras/{cId}/funcionarios`, vinculada à etapa via `etapa.equipeId` e `etapa.equipeNome`.
  - **success:** A tela `.../etapas/:etapaId/equipes` exibe a equipe do RH vinculada à etapa (nome, líder, status) e a lista de seus membros ativos (`funcionarios` com `isActive == true` e `teamId == etapa.equipeId`), com tratamento gracioso caso a equipe vinculada esteja inativa ou não exista mais.

- **CAP-7 (Vincular, Alterar e Remover Equipe do RH na Etapa)**
  - **intent:** Permitir gerenciar diretamente na tela de equipe da etapa qual equipe ativa do RH está designada para executá-la.
  - **success:** Usuários autorizados (`admin(c)` conforme `firestore.rules` de `/etapas/{id}`) podem vincular uma equipe ativa do RH à etapa, trocar para outra equipe ativa ou remover o vínculo (`equipeId: null`, `equipeNome: null`), persistindo atomicamente no documento `etapas/{etapaId}` e refletindo imediatamente na UI.

---

## Detalhamento Técnico e Contratos

### 1. Rotas e Navegação (Fase 1)
- `RhPaths` (`app/lib/src/features/rh/routing/rh_routes.dart`):
  - Adicionar `static const equipes = 'rh/equipes';`
  - Adicionar `static String equipesFor(String cId) => '/construtoras/$cId/rh/equipes';`
  - Registrar `GoRoute(path: RhPaths.equipes, ...)` protegido por `AccessGuard(construtoraId: cId, module: 'rh', ...)`.
- **Hub RH**:
  - As rotas `/construtoras/:cId/rh/funcionarios` e `/construtoras/:cId/rh/equipes` renderizam o mesmo shell/hub com `TabBar` contendo `Funcionários` (índice `0`) e `Equipes` (índice `1`), abrindo na aba correspondente à rota.
  - Trocar de aba deve atualizar a URL via `context.go(RhPaths.funcionariosFor(cId))` / `context.go(RhPaths.equipesFor(cId))` (ou manter estado consistente com `activeRoute`), garantindo deep-linking e botão voltar previsíveis.
- **Sidebar (`SigoSidebar`)**:
  - Sob a guarda existente `if (cId != null && canRh)`, atualizar o rótulo do item de `'Funcionários (RH)'` para `'Recursos Humanos'` (ou `'Funcionários e Equipes'`), mantendo `isActive: activeRoute.contains('/rh') && !activeRoute.contains('/chamadas')`.
  - O `btn_open_equipes` na AppBar de `FuncionariosListScreen` pode ser removido (pois agora existe a aba dedicada `Equipes`) ou direcionado para a aba `Equipes`, evitando duplicidade confusa com o antigo `EquipesDialog`.

### 2. Formulário Reutilizável de Equipe (Fases 1 e 2)
- Componente sugerido: `showEquipeFormDialog({required BuildContext context, required String construtoraId, Equipe? initialEquipe}) -> Future<Equipe?>` (em `app/lib/src/features/rh/presentation/equipe_form_dialog.dart`).
- Campos e regras:
  - **Nome (`name`)**: obrigatório, `trim()`, mínimo 2 caracteres (ou não vazio).
  - **Duplicidade case-insensitive**: validar contra `equipesStreamProvider(construtoraId)` (ou `getEquipes(construtoraId)`) comparando `existing.name.trim().toLowerCase() == candidate.trim().toLowerCase()` e `existing.id != initialEquipe?.id`. Em caso de colisão, bloquear salvamento e exibir erro de validação claro (`"Já existe uma equipe com este nome."`).
  - **Líder (`leaderId` / `leaderName`)**: opcional. Dropdown populado por `funcionariosStreamProvider(construtoraId)` filtrando `f.isActive == true`, precedido pela opção `null` (`"Sem líder"`).
    - Caso em edição `initialEquipe.leaderId` aponte para um funcionário inativo, incluir uma opção de fallback com rótulo `"${initialEquipe.leaderName ?? 'Líder atual'} (inativo)"` para preservar o estado até que o usuário altere explicitamente.
    - Ao selecionar `"Sem líder"`, persistir `leaderId: null` e `leaderName: null` (`copyWith(clearLeader: true)`).
  - **Retorno**: ao concluir criação ou edição com sucesso, fechar o diálogo retornando o objeto `Equipe` salvo (`Navigator.of(context).pop(savedEquipe)`).
- **Inativação com confirmação**:
  - Ao acionar inativação (`isActive: true -> false`), contar colaboradores vinculados (`funcionarios.where((f) => f.teamId == equipe.id && f.isActive).length`, informando também se há inativos ou focando nos ativos vinculados).
  - Se `vinculadosCount > 0`, exibir `AlertDialog` de confirmação informando a quantidade exata de colaboradores vinculados e que a inativação oculta a equipe de novas seleções sem apagar o histórico. Só persistir `setEquipeActive(cId, eq.id, false)` após confirmação explícita.
  - Se `vinculadosCount == 0`, pode inativar diretamente ou com confirmação simples, exibindo `SnackBar` de feedback.

### 3. Criação Contextual (Fase 2)
- **`FuncionarioFormScreen`**:
  - Envolver o `DropdownButtonFormField<String?>` (`funcionario_team_select`) em um layout responsivo (`Row` com `Expanded` + botão `OutlinedButton.icon` / `TextButton.icon` `+ Nova equipe`).
  - Manter uma lista local de equipes recém-criadas (ou fallback para `_recentlyCreatedEquipe`) para que, caso `setState(() => _teamId = created.id)` ocorra antes da próxima emissão do stream, o `DropdownButtonFormField` nunca lance erro de `initialValue`/`value` inexistente nos `items`.
  - Se em edição o colaborador estiver vinculado a uma equipe inativa, incluir essa equipe como item de fallback `"${eq.name} (inativa)"` no dropdown para evitar crash.
- **`AtribuirLotacaoLoteSheet`**:
  - Calcular `canRh` usando os mesmos providers da sidebar (`trustedDevProvider` e `construtoraPermissionProvider(widget.construtoraId)`):
    `isDev || isConstrutoraAdmin || (construtoraMember['isActive'] == true && (modules.contains('rh') || modules.contains('recursos_humanos')))`.
  - Se `canRh == true`: exibir botão `+ Nova equipe` no topo da aba `Equipes RH` e também no empty state quando não houver equipes ativas.
  - Se `canRh == false`: não exibir botão `+ Nova equipe`; exibir banner/mensagem orientativa discreta (e no empty state) informando que apenas usuários com acesso ao RH ou administradores da construtora podem cadastrar novas equipes.

### 4. Unificação em Etapas e Deprecação de `/equipes` (Fase 3)
- **`EtapaRepository` (`app/lib/src/features/etapas/data/etapa_repository.dart`)**:
  - Adicionar `Stream<Etapa?> watchEtapa(String etapaId)` e provider `watchEtapaProvider = StreamProvider.family<Etapa?, String>(...)` (ou ler a etapa correspondente via `watchEtapasProvider`).
  - Adicionar método `assignEquipe({required String etapaId, String? equipeId, String? equipeNome})` que atualiza em `etapas/{etapaId}`:
    - `'equipeId': equipeId`
    - `'equipeNome': equipeNome`
    - `'updatedAt': DateTime.now().toIso8601String()`
- **`EquipesListScreen` (`app/lib/src/features/equipes/presentation/equipes_list_screen.dart`)**:
  - Parar de consumir `watchEquipesProvider` (`EquipeRepository` / `/equipes`).
  - Consumir `watchEtapaProvider(etapaId)` (ou `watchEtapasProvider`), `equipesStreamProvider(construtoraId)` e `funcionariosStreamProvider(construtoraId)`.
  - Exibir:
    1. Breadcrumbs (`SigoBreadcrumbs`) e resumo da etapa.
    2. Card da equipe vinculada (`etapa.equipeId != null`): nome da equipe (preferindo o nome vivo do RH e fazendo fallback para `etapa.equipeNome`), líder da equipe, badge se inativa/arquivada, botões **Alterar equipe** e **Remover vínculo** (visíveis apenas para usuários com permissão de escrita em `etapas`, i.e., `isDev || isConstrutoraAdmin`).
    3. Seção **Membros ativos da equipe**: listagem dos `funcionarios` com `f.isActive == true && f.teamId == etapa.equipeId` (nome e cargo/função), ou mensagem `"Nenhum colaborador ativo vinculado a esta equipe no RH."`.
    4. Estado vazio quando `etapa.equipeId == null`: `SigoEmptyState` informando que nenhuma equipe do RH está vinculada à etapa, com botão **Vincular equipe do RH** (para usuários autorizados).
  - Seletor de equipe da etapa: diálogo ou bottom sheet listando equipes ativas de `construtoras/{cId}/equipes` com busca por nome/líder.
- **Deprecação de `/equipes` e `EquipeLote`**:
  - Marcar `EquipeLote` (`app/lib/src/features/equipes/domain/equipe.dart`) e `EquipeRepository` (`app/lib/src/features/equipes/data/equipe_repository.dart`) com `@Deprecated('Use construtoras/{cId}/equipes (RhRepository) e etapa.equipeId/equipeNome')`.
  - Nenhuma nova gravação deve ser feita na coleção raiz `/equipes`.
  - A remoção definitiva dos arquivos legados e das regras `match /equipes/{id}` fica explicitamente fora deste escopo (ver *Non-goals*) para preservar compatibilidade com dados históricos/migração.

### 5. Regras de Segurança (`firestore.rules`)
- Escrita em `construtoras/{c}/equipes/{e}` permanece restrita a `rh(c)` (`dev`, `admin(c)` ou membro ativo da construtora com módulo `rh` / `recursos_humanos`).
- **Atenção de leitura cross-módulo:** Atualmente `match /equipes/{e}` e `match /funcionarios/{f}` sob `construtoras/{c}` exigem `allow read: if rh(c);`. Caso usuários com módulo `lotes` (mas sem módulo `rh`) precisem visualizar equipes/membros em `AtribuirLotacaoLoteSheet` ou `EquipesListScreen`, a atualização de `firestore.rules` (ex.: `allow read: if rh(c) || hierarchyRead(c);` ou manter `rh(c)` conforme política de privacidade de salários em `funcionarios`) deve ser avaliada e aplicada exclusivamente via subagente `firestore-rules-author`, garantindo que dados salariais sensíveis em `funcionarios` não sejam expostos indevidamente.

---

## Chaves de Widget (`Key`) Recomendadas

Para estabilidade de testes de widget e E2E, padronizar as seguintes `Key`s:

| Fluxo / Componente | `Key` recomendada |
|--------------------|-------------------|
| Sidebar item RH | `Key('sidebar_nav_rh')` |
| Hub RH — Tab Funcionários | `Key('rh_tab_funcionarios')` |
| Hub RH — Tab Equipes | `Key('rh_tab_equipes')` |
| Aba Equipes — Campo de busca | `Key('search_equipes_input')` |
| Aba Equipes — Filtros de status | `Key('equipes_filter_ativos')`, `Key('equipes_filter_todos')`, `Key('equipes_filter_inativos')` |
| Aba Equipes — Botão/FAB Nova Equipe | `Key('btn_add_equipe_fab')` |
| Aba Equipes — CTA no empty state | `Key('btn_empty_add_equipe')` |
| Aba Equipes — Card de equipe | `Key('equipe_card_${equipe.id}')` |
| Aba Equipes — Contagem de membros | `Key('equipe_members_count_${equipe.id}')` |
| Aba Equipes — Menu/Botão Editar | `Key('btn_edit_equipe_${equipe.id}')` |
| Aba Equipes — Menu/Botão Inativar/Reativar | `Key('btn_toggle_equipe_${equipe.id}')` |
| Diálogo de Equipe — Input nome | `Key('equipe_form_name_input')` |
| Diálogo de Equipe — Dropdown líder | `Key('equipe_form_leader_select')` |
| Diálogo de Equipe — Botão salvar | `Key('btn_save_equipe_form')` |
| Diálogo de Equipe — Erro duplicidade | `Key('equipe_form_duplicate_error')` (ou mensagem de validator) |
| Confirmação de inativação com membros | `Key('dialog_confirm_inativar_equipe')`, `Key('btn_confirm_inativar_equipe')` |
| `FuncionarioFormScreen` — Botão contextual | `Key('btn_nova_equipe_contextual_funcionario')` |
| `AtribuirLotacaoLoteSheet` — Botão contextual | `Key('btn_nova_equipe_contextual_lote')` |
| `AtribuirLotacaoLoteSheet` — Aviso sem permissão RH | `Key('msg_sem_permissao_criar_equipe')` |
| `EquipesListScreen` (Etapa) — Card da equipe vinculada | `Key('etapa_equipe_vinculada_card')` |
| `EquipesListScreen` (Etapa) — Botão vincular/alterar | `Key('btn_vincular_equipe_etapa')`, `Key('btn_alterar_equipe_etapa')` |
| `EquipesListScreen` (Etapa) — Botão remover vínculo | `Key('btn_remover_equipe_etapa')` |
| `EquipesListScreen` (Etapa) — Lista de membros ativos | `Key('etapa_equipe_membro_${funcionario.id}')` |

---

## Critérios de Aceite Verificáveis

### Fase 1
- **CA-1.1:** Navegar para `/construtoras/:cId/rh/equipes` com usuário autorizado (`canRh == true`) abre diretamente o Hub RH na aba `Equipes`, com o item de RH destacado na `SigoSidebar`. Usuário sem `canRh` recebe `AccessDeniedScreen`.
- **CA-1.2:** Alternar entre as abas `Funcionários` e `Equipes` preserva a experiência fluida e atualiza corretamente o contexto de rota (`/rh/funcionarios` ↔ `/rh/equipes`).
- **CA-1.3:** Quando não há equipes cadastradas, a aba `Equipes` exibe empty state com botão `btn_empty_add_equipe` que abre o formulário de criação.
- **CA-1.4:** Criar equipe com nome `"Equipe Alvenaria 1"` e líder ativo `"João"` persiste em `construtoras/{cId}/equipes/{id}` com `name`, `leaderId`, `leaderName`, `isActive: true`.
- **CA-1.5:** Tentar criar ou renomear equipe para `"equipe alvenaria 1"` (mesmo nome com caixa diferente ou espaços extras) é bloqueado com erro de duplicidade e não grava no Firestore.
- **CA-1.6:** Editar uma equipe existente permite alterar `name` (sem colidir consigo mesma), alterar o líder ou limpar o líder (`leaderId == null`, `leaderName == null`).
- **CA-1.7:** Cada card de equipe exibe corretamente o total de colaboradores ativos cujo `teamId == equipe.id`.
- **CA-1.8:** Ao tentar inativar uma equipe com 1 ou mais colaboradores vinculados, é exibido diálogo de confirmação (`dialog_confirm_inativar_equipe`) citando a quantidade de colaboradores; cancelar mantém `isActive == true`, confirmar atualiza `isActive == false`.

### Fase 2
- **CA-2.1:** Em `FuncionarioFormScreen`, clicar em `btn_nova_equipe_contextual_funcionario`, preencher e salvar uma nova equipe fecha o diálogo, seleciona automaticamente a equipe criada em `funcionario_team_select` e preserva todos os campos já digitados no formulário de colaborador.
- **CA-2.2:** Em `AtribuirLotacaoLoteSheet` (aba `Equipes RH`), com `canRh == true`, o botão `btn_nova_equipe_contextual_lote` é exibido (inclusive no empty state) e cria a equipe diretamente em `construtoras/{cId}/equipes`, disponibilizando-a imediatamente para atribuição.
- **CA-2.3:** Em `AtribuirLotacaoLoteSheet` (aba `Equipes RH`), com `canRh == false`, `btn_nova_equipe_contextual_lote` **não** é renderizado e a mensagem orientativa (`msg_sem_permissao_criar_equipe`) é exibida.

### Fase 3
- **CA-3.1:** `EquipesListScreen` (`.../etapas/:etapaId/equipes`) não realiza mais consultas à coleção raiz `/equipes` (`EquipeRepository`).
- **CA-3.2:** Quando `etapa.equipeId` está preenchido, a tela exibe o card da equipe vinculada (`etapa_equipe_vinculada_card`), nome, líder e todos os colaboradores ativos com `teamId == etapa.equipeId` (ocultando inativos).
- **CA-3.3:** Quando `etapa.equipeId` é nulo, a tela exibe estado vazio com botão `btn_vincular_equipe_etapa` (para usuários autorizados).
- **CA-3.4:** Vincular ou alterar a equipe da etapa atualiza `etapa.equipeId` e `etapa.equipeNome` no documento `etapas/{etapaId}` com dados de uma equipe ativa do RH.
- **CA-3.5:** Remover o vínculo limpa `etapa.equipeId` e `etapa.equipeNome` para `null` no documento `etapas/{etapaId}` após confirmação.
- **CA-3.6:** Se `etapa.equipeId` referenciar uma equipe inativada no RH, a tela renderiza fallback gracioso com `etapa.equipeNome` e indicação visual de equipe inativa, sem erros de runtime.

---

## Constraints

- **Fonte única de verdade:** Toda criação, edição e listagem de equipes deve operar exclusivamente sobre `construtoras/{cId}/equipes` via `RhRepository`.
- **Sem exclusão física:** Equipes são apenas inativadas (`isActive: false`), preservando integridade referencial de funcionários, chamadas e etapas históricas.
- **Segurança em camadas:** Botões de criação/edição de equipes na UI devem respeitar `canRh`; escrita em `etapas/{id}` deve respeitar `admin(c)`/`dev`; alterações em `firestore.rules` só podem ser feitas pelo subagente `firestore-rules-author`.
- **Compatibilidade de dropdowns:** Nenhum `DropdownButtonFormField` pode lançar `AssertionError` quando um registro existente referenciar equipe ou líder inativado posteriormente.
- **Idioma e Design System:** Toda interface, mensagens de erro e documentação em `pt-br`, seguindo `SigoThemeExtension` e os componentes padrão do SIGO (`SigoLayout`, `SigoEmptyState`, `SigoErrorState`, `SigoBreadcrumbs`).

## Non-goals

- Remoção física da coleção raiz `/equipes` no Firestore ou migração automatizada de documentos legados de `EquipeLote` nesta entrega.
- Gestão de sub-equipes hierárquicas ou múltiplos líderes simultâneos por equipe.
- Alteração de regras de cálculo de diárias, folha de pagamento ou chamada diária (`ChamadaFormScreen`).
- Exclusão definitiva (`delete`) de equipes pelo usuário final.

## Success signal

- Usuário com `canRh` gerencia o ciclo completo de equipes pelo Hub RH (`/construtoras/:cId/rh/equipes`) sem depender do antigo ícone oculto.
- Criação contextual funciona sem perda de contexto em `FuncionarioFormScreen` (com auto-seleção) e em `AtribuirLotacaoLoteSheet` (com guarda `canRh` e orientação para sem permissão).
- `EquipesListScreen` em Etapas exibe e gerencia exclusivamente equipes do RH (`etapa.equipeId` / `etapa.equipeNome`) e seus membros ativos.
- `flutter analyze` sem erros e suíte de testes unitários e de widget cobrindo as 3 fases 100% verde.
