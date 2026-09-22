# Epic 9 Context: Atribuição à obra

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Permitir que admin e owner da construtora atribuam membros ativos da construtora a uma obra específica, selecionando a obra ativa, o papel (Operário ou Admin da obra) e os módulos de acesso (com default `[diario]`), garantindo persistência e sincronização imediata no backend através de Cloud Functions autorizadas (`setMembership`), sem permissões indevidas ou vínculos órfãos.

## Stories

- Story 9.1: Atribuir operário à obra
- Story 9.2: Atribuir admin + erros e offline

## Requirements & Constraints

- Apenas admin ou owner da construtora podem atribuir membros a obras.
- Vínculo ativo na construtora é pré-requisito estrito para atribuição à obra (membro inativo ou inexistente na construtora não pode ser vinculado a obras).
- Ao atribuir a uma obra, o papel deve ser exclusivamente `operario` ou `admin` (`Admin da obra`). O papel `owner` nunca é enviado com `obraId`.
- Módulos padrão para operário são `[diario]`. Módulos vazios `[]` negam acesso funcional na obra (fail-closed).
- A atribuição deve ser executada através da chamada segura à Cloud Function `setMembership{construtoraId, obraId, role, modules, isActive: true, userId/email}`.
- O botão de confirmação do diálogo deve permanecer desabilitado se nenhuma obra for selecionada ou se não houver obras ativas disponíveis.
- Exibir resumo ao vivo da atribuição no diálogo: "{Nome} será {Papel} em {Obra} com acesso a {Módulos}".
- Após atribuição bem-sucedida, exibir feedback via SnackBar (`Atribuído a {obra} como {Papel}.`) e invalidar os providers pertinentes (`membrosProvider`, `obraMembersProvider`, etc.) para atualizar a contagem de obras e a lista.

## Technical Decisions

- Camada Riverpod MVVM: A UI invoca o repositório (`ObraMembersRepository` ou `MembrosRepository`), que chama a Cloud Function `setMembership` via `httpsCallable`. A UI nunca grava diretamente em `construtoras/{cId}/obras/{oId}/members`.
- Normalização de dados: Na leitura de membros da obra, o papel legado `member` é normalizado para `Operário`.
- Resolução e invalidação de estado: O sucesso da mutação invalida o cache/providers locais (`membrosProvider`, `obrasProvider`, `obraMembersProvider`) para refletir a nova contagem de obras alocadas e o novo vínculo no detalhe do membro.
- Tratamento de conexão: Mutações de vínculo são online-only (sem fila offline assíncrona local para atribuição de novos membros de obra).

## UX & Interaction Patterns

- Ponto de entrada: Botão `Atribuir à obra` na tela de Detalhe do Membro (`MembroDetalheScreen` / Bloco de Obras Vinculadas).
- Componente `AtribuirObraDialog`:
  - Dropdown com lista de obras ativas da construtora (estado vazio se nenhuma obra: `Nenhuma obra ativa` e ação desabilitada).
  - Seleção de papel: `Operário` (padrão) ou `Admin da obra`. A opção `owner` fica oculta.
  - Seleção de módulos: checkboxes/chips (com `Diário de Obras` marcado por padrão).
  - Resumo contextual dinâmico exibido antes de confirmar.
  - Botões `Cancelar` e `Confirmar atribuição`.
- Responsividade: Modal/diálogo adaptado para mobile (<800px) e desktop/tablet.

## Cross-Story Dependencies

- Depende do Épico 8 (Story 8.3 - Detalhe do Membro com exibição do bloco de obras vinculadas e botão de atribuição).
- A Story 9.1 foca na atribuição do operário com papel default e módulos default.
- A Story 9.2 expande o diálogo para seleção explícita de `Admin da obra` e tratamento detalhado de erros do servidor (`permission-denied`, `failed-precondition`) e conectividade offline.
