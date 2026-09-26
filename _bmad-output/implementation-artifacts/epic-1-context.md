# Epic 1 Context: Upload e Monitoramento de Rascunho (Flutter UI)

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

O usuário consegue submeter o arquivo físico do loteamento (DXF) e acompanhar visualmente o estado de carregamento contínuo ("Processando Geometria") até que o rascunho seja retornado pelo backend para visualização inicial.

## Stories

- Story 1.1: Componente de Upload de Arquivo DXF
- Story 1.2: Listener de Processamento e Sala de Espera (Animação)

## Requirements & Constraints

- O sistema deve permitir que o usuário faça o upload de um arquivo DXF para iniciar o processamento em background (FR1).
- O Flutter deve fazer upload do DXF diretamente para o Cloud Storage, que acionará o processamento via Cloud Function. O Flutter apenas escuta as mudanças em loteamentos_drafts no Firestore (AD-4).
- A comunicação entre UI e Backend via Firestore deve utilizar formato GeoJSON.

## Technical Decisions

- O upload ocorre diretamente do client (Flutter) para o Cloud Storage.
- A persistência do rascunho será realizada em uma coleção Firestore `loteamentos_drafts`. O Flutter deverá escutar essa coleção aguardando o rascunho.
- As rotas da UI devem seguir as diretrizes do GoRouter (AD-2).

## UX & Interaction Patterns

- **Tela de Upload:** Área de Dropzone para soltar o arquivo `.dxf`.
- **Processando Background:** Enquanto o processamento ocorre no backend, a tela exibe status "Processando Geometria..." com animação contínua (micro-interação sem polling agressivo) e sem travar a UI. A transição para a próxima etapa (Canvas de Revisão) é automática assim que o snapshot do rascunho é recebido via stream do Firestore.
