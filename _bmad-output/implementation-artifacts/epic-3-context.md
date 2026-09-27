# Epic 3 Context: Revisão e Resolução Interativa de Ambiguidades (Flutter UI)

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

O usuário visualiza o loteamento em um Canvas responsivo, localiza lotes problemáticos visualmente e os corrige rapidamente através do Painel Lateral utilizando atalhos de teclado, até destravar a aprovação final.

## Stories

- Story 3.1: Canvas Interativo e Renderização Estilizada de Polígonos
- Story 3.2: Fluxo Rápido de Correção via Painel Lateral e Teclado
- Story 3.3: Gestão de Pendências e Gatilho de Aprovação

## Requirements & Constraints

- A persistência do rascunho em edição utiliza o banco de dados (coleção `loteamentos_drafts` no Firestore) para gravar cada ajuste unitário.
- A aprovação final só deve ser habilitada quando não houverem mais lotes com status "ambiguo".
- Após todas correções, o sistema atualiza o status do rascunho inteiro para "aprovado" (que dispara o processamento em background da ingestão).
- O payload deve ser obrigatoriamente GeoJSON.
- A renderização do GeoJSON no front-end não deve efetuar o processamento algorítmico, operando apenas sobre as marcações de status feitas pelo backend.

## Technical Decisions

- Stack: Flutter Web/PWA utilizando GoRouter para navegação.
- Estado: A gestão dos lotes em tela e do status global do arquivo de rascunho deve usar provedores locais (Riverpod) em sincronia com o backend.

## UX & Interaction Patterns

- **Canvas Contínuo:** Pan & Zoom para navegar na planta, exibindo lotes com cores de feedback (ambíguo=laranja com pulso, válido=neutro, corrigido=verde).
- **Painel Lateral:** Digitação rápida do nome/número com auto-focus e atalho `ENTER` para salvar lote selecionado.
- **Barra de Progresso:** Chip visível superior com a contagem de "X Lotes Ambíguos" restantes, controlando a liberação do botão "Aprovar Definitivamente".

## Cross-Story Dependencies

- Depende da Epic 1 e Epic 2 para a criação inicial do documento GeoJSON rascunho contendo a propriedade "status" = "ambiguo" nos lotes irregulares.
- Dispara a execução das functions da Epic 4 a partir da aprovação do documento.
