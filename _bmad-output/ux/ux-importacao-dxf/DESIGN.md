---
name: 'Design - Importação de DXF'
status: final
created: '2026-09-26'
updated: '2026-09-26'
---

# Design — Importação de DXF

## Brand & Style
A funcionalidade de importação estende a identidade visual do painel corporativo da plataforma Obras. O foco é na utilidade, clareza técnica e resolução rápida de problemas (orientado à ação).

## Colors
- **Alerta (Laranja/Amarelo):** Utilizado para preenchimentos de polígonos com status `ambiguo`.
- **Sucesso (Verde Sucesso):** Utilizado para preenchimentos de polígonos que foram corrigidos pelo usuário na UI.
- **Base (Cinza/Neutro):** Utilizado para preenchimentos de lotes válidos e para o fundo infinito do `InteractiveViewer`.

## Components

### Canvas de Revisão (Rascunho)
- Utiliza um canvas contínuo (fundo liso, sem mapa-múndi de satélite por trás) `[ASSUMPTION]`.
- Polígonos são renderizados com bordas sólidas e preenchimentos semitransparentes baseados no `status` presente no GeoJSON.

### Painel Lateral de Correção (Side Panel)
- Posicionado à direita, compartilha espaço da tela ou desliza por cima da borda da planta.
- Contém um campo de texto focado para inserção rápida da identificação correta do lote (ex: Lote 14, Quadra C).
- Contém botões: "Salvar Correção" (Primário) e "Ignorar Lote" (Secundário).

### Lista de Pendências (To-Do / Status Bar)
- Um chip flutuante ou barra no topo relatando a contagem de lotes que precisam de revisão ("X Lotes Ambíguos restando").
