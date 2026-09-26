---
epic: 1
date: 2026-09-26
verdict: accepted
criteria: declared
headless: false
---

# Retrospectiva do Epic 1: Upload e Monitoramento de Rascunho (Flutter UI)

## 1. Epic Summary

- **Épico:** Epic 1 — Upload e Monitoramento de Rascunho (Flutter UI)
- **Objetivo:** Permitir que o usuário faça upload do arquivo DXF de loteamento e acompanhe o estado ("Processando Geometria") até o recebimento do rascunho via backend.
- **Faixa de Diff e Commits:** `cb5d391..2b0f467`
- **Histórias do Épico:**
  - `1-1-componente-de-upload-de-arquivo-dxf` (Upload DXF) — Aceito (`done`)
  - `1-2-listener-de-processamento-e-sala-de-espera-animação` (Sala de espera e transição) — Aceito (`done`)
- **Inventário de Evidências:**
  - **Especificações e Contexto:** `epic-1-context.md`, `spec-1-1-componente-de-upload-de-arquivo-dxf.md`, `spec-1-2-listener-de-processamento-e-sala-de-espera.md`.
  - **Código Fonte Modificado:**
    - `app/lib/src/features/loteamentos/data/loteamentos_import_repository.dart`
    - `app/lib/src/features/loteamentos/presentation/loteamento_import_screen.dart`
    - `app/lib/src/features/loteamentos/presentation/loteamento_processing_screen.dart`
    - `app/lib/src/features/loteamentos/routing/loteamentos_routes.dart`
    - `app/lib/src/features/loteamentos/presentation/loteamentos_list_screen.dart`

---

## 2. Findings (Achados e Visões Agregadas)

### 2.1 Architecture Delta & Layering
- **Repositórios e Upload Direto:** O Firebase Storage foi utilizado diretamente do cliente Flutter (`loteamentos_import_repository.dart`) para upload dos arquivos DXF, enquanto o Firestore escuta o documento `loteamentos_drafts/{id}`.
- **Disposição:** *Accept as-is* (Padrão alinhado ao AD-4).

### 2.2 Spec-to-Implementation Reconciliation
- O documento de contexto exigia que a tela de "Processando Geometria..." não travasse a UI e realizasse micro-interações sem polling agressivo. O uso do `StreamProvider` com a stream do Firestore garante atualização real-time sem sobrecarga.
- O upload checa a extensão do arquivo `.dxf`, mas não impõe um limite explícito de tamanho para o payload, o que poderia levar a abusos do Storage ou problemas de timeout (Verification Gap).
- A transição automática após processamento redireciona para `/construtoras/.../loteamentos/draft/...`. Contudo, a tela/rota de draft ainda não foi criada (pertence ao Epic 3). O usuário pode receber um erro 404 até que a história subsequente seja feita.
- **Disposição:** *Fix now* (Gerar itens de ação para tamanho do arquivo e alerta sobre rota 404).

---

## 3. Behavior Verification (Verificação de Comportamento)

- Não foi realizada verificação de comportamento em tempo de execução via navegador/servidor nesta sessão automatizada, porém o log do desenvolvedor relata "Formaliza aceite das Stories 1.1 e 1.2 após walkthrough" (commit `2b0f467`). 
- As transições do Riverpod, GoRouter e do Firebase Storage aparentam corretas em nível de código (verificação estática pela revisão do diff).

---

## 4. Previous-Retro Follow-Through

- N/A para esta versão focada de escopo, já que a retrospectiva anterior do Épico 1 (RBAC) dizia respeito a uma implementação de outra fase do projeto.

---

## 5. Action Items (Itens de Ação)

| ID | Ação | Responsável | Status |
| :--- | :--- | :--- | :---: |
| `epic-1-retro-item-1-dxf-size-limit` | Implementar limite máximo de tamanho de arquivo no DXF antes/durante o upload no Firebase Storage para prevenir estouro. | `dev (Amelia)` | `open` |
| `epic-1-retro-item-2-draft-route` | Garantir que o Epic 3 e a Story do Canvas de Revisão implementem corretamente a rota de draft, caso contrário os usuários sofrerão 404 no final do upload. | `maranduteam` | `open` |

---

## 6. Acceptance Verdict (Veredito de Aceitação)

- **Veredito Final:** **`accepted`**
- **Justificativa:** Os critérios funcionais primários (upload do DXF para Storage e stream do rascunho do Firestore) foram contemplados integralmente pelo código sem acoplamento indevido de lógica de renderização espacial, e passaram por um walkthrough humano conforme relatado nos logs.

---

## 7. Open Questions

1. O que deve acontecer se o Cloud Function do backend falhar ao processar o `.dxf` (ex: arquivo corrompido)? Deve o backend escrever um `{status: 'error', message: '...'}` no Firestore para que a tela de Processing Screen redirecione ou avise o usuário ao invés de ficar presa?
