# Epic 2 Context: Processamento Geométrico Assíncrono (Backend Python)

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

O arquivo enviado é traduzido perfeitamente de CAD para um modelo geográfico navegável no backend de forma assíncrona, com áreas problemáticas analisadas, isoladas e devolvidas como um Rascunho Imutável (GeoJSON). Isso evita bloqueios de thread no cliente e prepara os dados topológicos para revisão.

## Stories

- Story 2.1: Gatilho OnFinalize e Extração de Geometria Bruta
- Story 2.2: Algoritmo Espacial Point-in-Polygon
- Story 2.3: Heurística de Ambiguidades e Persistência do Rascunho (GeoJSON)

## Requirements & Constraints

- O processamento da geometria (parsing e testes topológicos) nunca deve ocorrer no cliente web para não bloquear a thread principal, deve ser executado no backend.
- O pipeline deve usar Cloud Functions em Python (Gen 2; 3.11+) com `ezdxf` e `shapely`.
- O processamento inicia via trigger `OnFinalize` no Cloud Storage.
- Lotes com identificação ambígua devem receber a propriedade estendida `"status": "ambiguo"`.
- O payload de saída para o Flutter deve ser estritamente em formato GeoJSON, armazenado no Firestore na coleção temporária `loteamentos_drafts`.

## Technical Decisions

- **Async Pipeline & Immutable Drafts (AD-4):** O Flutter faz upload direto para o Cloud Storage e escuta o rascunho. O backend faz todo o processamento e não realiza inserções em massa no banco de dados raiz ainda, apenas grava um rascunho GeoJSON no `loteamentos_drafts`.
- **Parser Boundary and Stack (AD-3):** O backend realiza a leitura do .dxf via `ezdxf` e o teste Point-in-Polygon via `shapely` de forma isolada.
- **Ambiguity Resolution (AD-5):** A Cloud Function deve aplicar heurísticas iniciais para tentar extrair os nomes/números e se falhar/houver dúvidas, marcar como "ambiguo" para delegar a resolução humana na UI.

## Cross-Story Dependencies

- Story 2.2 depende das geometrias extraídas na Story 2.1.
- Story 2.3 depende do cálculo Point-in-Polygon concluído na Story 2.2 para associar Lotes a Quadras e montar o GeoJSON final.
- Epic 3 (Flutter UI) depende inteiramente do documento GeoJSON gerado ao final da Story 2.3.
