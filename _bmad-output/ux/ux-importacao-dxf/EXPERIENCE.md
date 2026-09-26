---
name: 'Experience - Importação de DXF'
status: final
created: '2026-09-26'
updated: '2026-09-26'
---

# Experience — Importação de DXF

## Foundation
A jornada de revisão foi concebida para **Desktop (Web/Mac/Windows)**. A visualização de plantas geográficas (DXF e GeoJSON) demanda área de tela e uso de mouse para navegação (Pan & Zoom) precisos.

## Information Architecture
- **Tela de Upload:** Área de Dropzone para soltar o arquivo `.dxf`.
- **Tela de Rascunho (Revisão):** Foco máximo no mapa (Canvas). Possui uma barra de navegação no topo com contador de problemas e o Painel Lateral para edição de propriedades.

## State Patterns
- **Processando Background:** Como o Cloud Function está rodando, a tela de upload exibe o documento com status "Processando" e a UI não trava.
- **Rascunho Ambíguo (`status: ambiguo`):** O lote no mapa pulsa levemente e é pintado em cor de Alerta.
- **Botão de Aprovação Final:** Permanece **Desabilitado** enquanto o contador de lotes ambíguos for maior que zero.

## Interaction Primitives
- **Pan & Zoom:** Arrasto de clique e scroll do mouse no Canvas para manipular a planta `[ASSUMPTION]`.
- **Teclado Centrado:** Ao clicar no mapa em um lote problemático, o Painel Lateral foca imediatamente o campo de "Identificador". O usuário pode digitar o lote e apertar `ENTER` para salvar e aplicar a correção, sem precisar mirar no botão com o mouse `[ASSUMPTION]`.

## Key Flows

### 1. Jornada de Correção Rápida
1. Carlos (Protagonista) entra na tela de Revisão após o processamento e o sistema aponta "12 Lotes Ambíguos" na barra superior.
2. Ele visualiza na planta todos os pontos alaranjados.
3. Carlos clica no primeiro polígono laranja.
4. O Painel Lateral desliza da direita e o cursor de texto foca na caixa de identificação.
5. Carlos digita "Lote 5" e aperta a tecla ENTER.
6. Imediatamente o painel pisca o salvamento (no objeto local do state), o lote fica Verde na planta e o contador cai para "11 Lotes Ambíguos".
7. Ele repete a ação. Ao chegar em "0 Lotes Ambíguos", a barra exibe sucesso completo e o botão principal "Aprovar Loteamento Definitivamente" torna-se habilitado para concluir e injetar os dados de produção.
