# Epic 2 Context: Processamento Geométrico Assíncrono (Backend Python)

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

O arquivo DXF recebido é lido e traduzido de CAD para um modelo geográfico no backend de forma assíncrona. Os polígonos passam por cálculos espaciais (point-in-polygon) e validação de textos. Áreas problemáticas (ex: ambiguidades de identificação) são detectadas, isoladas e devolvidas como um rascunho imutável no formato GeoJSON para posterior revisão do usuário na UI.

## Stories

- Story 2.1: Gatilho OnFinalize e Extração de Geometria Bruta
- Story 2.2: Algoritmo Espacial Point-in-Polygon
- Story 2.3: Heurística de Ambiguidades e Persistência do Rascunho (GeoJSON)

## Requirements & Constraints

- O sistema deve processar a geometria do arquivo DXF de maneira invisível ao usuário final, operando em background.
- O resultado do processamento é a geração de um rascunho temporário e imutável armazenado no Firestore (coleção `loteamentos_drafts`).
- O rascunho deve mapear a relação espacial (Lotes dentro de Quadras).
- Textos associados a polígonos que não puderem ser claramente identificados como identificadores válidos resultarão em marcação de ambiguidade para que o usuário corrija manualmente.
- O processamento NUNCA deve ocorrer no cliente web para evitar travamento da thread principal em interfaces Flutter.

## Technical Decisions

- **Ambiente Backend:** Implementado através de Cloud Functions em Python (Gen 2; versão 3.11+).
- **Trigger:** Cloud Storage acionado via `OnFinalize` (quando o arquivo DXF termina de ser salvo).
- **Bibliotecas Core:** Utilização compulsória de `ezdxf` para parsing CAD e `shapely` para algoritmos de Point-in-Polygon.
- **Formato Estrutural:** A comunicação entre UI e Backend via Firestore deve utilizar rigorosamente o formato `GeoJSON`.
- **Atributos Estendidos no GeoJSON:** As propriedades de cada Feature devem incluir estritamente `tipo` (quadra ou lote), `nome` (o identificador resolvido) e `status` (neutro/válido ou `ambiguo`).
- **Heurística:** O algoritmo aplicará regras iniciais para tentar parear os lotes e remover textos supérfluos (como "Área", "Casa"). O que falhar ou gerar colisão vira `ambiguo`.

## UX & Interaction Patterns

*(O Epic 2 em si não tem interface, atua no backend)*
Os dados estruturados por esta épica guiarão diretamente a UX do Epic 3, portanto o uso rigoroso da propriedade `status: "ambiguo"` é a única forma de habilitar a renderização com cor de Alerta na UI (Pulse Laranja/Amarelo).

## Cross-Story Dependencies

- Depende indiretamente do término do upload do DXF no Cloud Storage pela UI (Epic 1).
- É pré-requisito fundamental para a Epic 3 (Revisão e Resolução Interativa de Ambiguidades) que consumirá o rascunho gerado pela Story 2.3.
