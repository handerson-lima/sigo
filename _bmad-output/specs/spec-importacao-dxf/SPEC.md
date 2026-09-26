---
id: SPEC-importacao-dxf
companions:
  - architecture-diagrams.md
sources:
  - ../planning-artifacts/architecture/architecture-obras-2026-09-26/ARCHITECTURE-SPINE.md
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate. Source documents listed in frontmatter are for traceability — consult them only if you need narrative rationale or prose color this contract intentionally omits.

# Importação de DXF para Loteamentos

## Why

Necessidade de importar arquivos DXF complexos de loteamentos (processamento de geometria pesada) sem bloquear a interface web em Flutter ou exceder limites de transação do Firestore.

## Capabilities

- **CAP-1**
  - **intent:** O usuário pode fazer upload de um arquivo DXF para iniciar o processamento em background.
  - **success:** O arquivo chega no Cloud Storage e o pipeline assíncrono é iniciado.
- **CAP-2**
  - **intent:** O sistema processa a geometria do DXF (Point-in-Polygon) no backend, gerando um rascunho em GeoJSON.
  - **success:** O documento é salvo na coleção `loteamentos_drafts` no Firestore.
- **CAP-3**
  - **intent:** O sistema identifica lotes ambíguos durante o processamento e os sinaliza no GeoJSON para correção.
  - **success:** Lotes sem identificação clara recebem status ambiguo no rascunho.
- **CAP-4**
  - **intent:** O usuário visualiza o rascunho na UI, resolve ambiguidades e o aprova.
  - **success:** O status do rascunho é atualizado para aprovado no Firestore, disparando a ingestão final.
- **CAP-5**
  - **intent:** O sistema executa as inserções em lote nas coleções de produção (loteamentos, quadras, lotes) em background e apaga o rascunho.
  - **success:** Os dados são persistidos de forma flat nas coleções raízes e o rascunho é deletado.

## Constraints

- O parsing do DXF e cálculos de Point-in-Polygon ocorrem no backend via Cloud Function Python (`ezdxf`, `shapely`), nunca no client web (AD-3).
- O cliente não deve executar os batch writes finais de inserção massiva para evitar falhas e congelamento da UI (Firestore 500-write limit) (AD-5).
- A persistência final deve ocorrer em coleções raízes (`loteamentos`, `quadras`, `lotes`), sem aninhamento, respeitando o modelo relacional flat (AD-1).
- O Payload de comunicação entre UI e Backend deve ser exclusivamente GeoJSON com propriedades estendidas `tipo`, `nome` e `status`.

## Non-goals

- Estilização detalhada e interações de mapa no front-end estão fora de escopo (postergado para UX/Design).
- Formatação e extração de metadados acessórios adicionais (ex: área bruta) não estão definidos e não são escopo desta entrega.

## Success signal

- O arquivo DXF é completamente ingerido, convertido em um Loteamento com suas respectivas Quadras e Lotes distribuídos flatly no Firestore de produção, sem intervenções parciais incompletas.
