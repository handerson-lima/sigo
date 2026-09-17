---
title: 'Story 3.1 — CRUD de Projetos e Lotes'
type: 'feature'
created: '2026-09-17'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
  - '{project-root}/docs/task.md'
  - '{project-root}/docs/user_flows.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A gestão de projetos (obras) e lotes possuía lacunas operacionais: ausência de interface e métodos no cliente para criação de novas obras por administradores/devs, manipulador de atualização de fase e status de lotes não implementado (TODO vazio) no card de lote, fragilidade com operador de asserção não-nula forçada na navegação de referências do Firestore e inexistência de testes automatizados dedicados ao módulo de Lotes.

**Approach:** Implementar a criação de Obras no repositório e UI (`ObrasListScreen`), ativar o diálogo de atualização de fase e status ao tocar no card do Lote (`LotesListScreen`), sanitizar validações de whitespace e navegação hierárquica segura, e criar a suíte de testes de unidade e widgets de Lotes e Obras.

## Boundaries & Constraints

**Always:**
- Preservar a estrutura hierárquica `construtoras/{cId}/obras/{oId}` e `construtoras/{cId}/obras/{oId}/lotes/{lId}`.
- Respeitar estritamente a matriz de permissões: apenas `admin` da construtora, `owner` ou `dev` confiável podem criar obras; apenas `obraAdmin` ou `dev` podem criar/atualizar lotes.
- Proibir exclusão física direta de obras e lotes conforme regras de segurança (`allow delete: if false;`).
- Manter o suporte offline-first e compatibilidade com Web/PWA.

**Never:**
- Não permitir a criação de obras ou lotes com nomes vazios ou compostos exclusivamente por espaços em branco.
- Não usar asserções forçadas `!` em navegação de documentos pais sem verificação prévia de nulidade.
- Não descartar silenciosamente dados em cache no stream de monitoramento de lotes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Criação de Obra por Admin | Admin na construtora clica em "Nova Obra", preenche nome e salva | Nova obra é gravada em `construtoras/{cId}/obras/{oId}` com `isActive: true` e listagem atualiza | SnackBar de erro em falha de conexão |
| Criação de Obra por Membro Comum | Usuário comum sem papel de admin na construtora | Botão/Ação de criação não é renderizado | Rota e Rules impedem criação |
| Atualização de Fase/Status do Lote | Usuário clica no `_LoteCard` no mapa de lotes | Abre BottomSheet/Dialog exibindo fase e status atuais com opções de alteração; ao salvar chama `updatePhase`/`updateStatus` | Feedback de erro em caso de falha |
| Nome de Lote com espaços | Usuário digita `"   "` no nome do lote | Validador rejeita com mensagem "Campo obrigatório" | Impede submissão |
| Consulta de Obras com hierarquia inesperada | `collectionGroup('members')` retorna documento em caminho atípico | Navegação segura de referências parentais sem lançar exceção NullCheck | Ignora documento malformado |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/obras/data/obra_repository.dart` -- Repositório de obras: adicionar `createObra`, `updateObra` e sanitizar navegação de pais em `_loadgetConstrutoraObras`.
- `app/lib/src/features/obras/presentation/obras_list_screen.dart` -- Listagem de obras: adicionar ação/botão "Nova Obra" para admins e diálogo de cadastro.
- `app/lib/src/features/lotes/data/lote_repository.dart` -- Repositório de lotes: permitir leitura local em cache no stream.
- `app/lib/src/features/lotes/presentation/add_lote_screen.dart` -- Formulário de lote: validação de whitespace e seleção de status.
- `app/lib/src/features/lotes/presentation/lotes_list_screen.dart` -- Mapa de lotes: implementar diálogo/bottom sheet para edição de fase e status no card.
- `app/test/obras_lotes_crud_test.dart` -- Suíte de testes automatizados cobrindo criação de obra, lotes, validações e mutações de fase/status.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/obras/data/obra_repository.dart` -- Adicionar `createObra`, `updateObra` e navegação defensiva de ancestrais.
- [x] `app/lib/src/features/obras/presentation/obras_list_screen.dart` -- Adicionar botão de Nova Obra e diálogo de formulário para admins.
- [x] `app/lib/src/features/lotes/data/lote_repository.dart` -- Ajustar stream de lotes para não descartar snapshots de cache.
- [x] `app/lib/src/features/lotes/presentation/add_lote_screen.dart` -- Adicionar validação `trim().isEmpty` e seleção opcional de status inicial.
- [x] `app/lib/src/features/lotes/presentation/lotes_list_screen.dart` -- Ativar `onTap` no card para alterar fase e status via modal bottom sheet.
- [x] `app/test/obras_lotes_crud_test.dart` -- Adicionar testes unitários e de widget cobrindo todo o fluxo de CRUD e tratamento de bordas.

**Acceptance Criteria:**
- Given um administrador na tela de obras da construtora, when clica em "Nova Obra" e preenche os dados, then a obra é criada e exibida na listagem.
- Given um usuário visualizando a lista de lotes, when clica em um lote, then um modal é exibido permitindo alterar a fase e o status, persistindo a alteração no repositório.
- Given um formulário de novo lote, when o usuário tenta submeter nome com apenas espaços, then o formulário bloqueia a submissão.
- Given a suíte de testes do Flutter, when executada com `flutter test`, then todos os testes passam com 100% de sucesso.

## Implementation Notes

- `ObraRepository`: Métodos `createObra` e `updateObra` implementados usando conversor tipado para coleção `construtoras/{cId}/obras/{oId}`.
- `ObrasListScreen`: Adicionado botão contextual "Nova Obra" na AppBar e no empty state para `admin`/`dev`, abrindo diálogo modal `_AddObraDialog` com validação de nome, descrição opcional e invalidação reativa de provedor.
- `LotesListScreen`: Card de lote transformado em `ConsumerWidget` acionando `_EditLoteSheet` para atualização instantânea de fase de construção e status operacional via `updatePhase` e `updateStatus`.
- `AddLoteScreen`: Validador de nome sanitizado com `.trim().isEmpty` impedindo submissão de whitespace puro, e adicionado dropdown de seleção de `LoteStatus`.
- `obras_lotes_crud_test.dart`: 6 novos testes cobrindo serialização de modelos, validação de formulários, edição via BottomSheet e controle de acesso baseado em papéis.

## Spec Change Log

- 2026-09-17: Criação da especificação, auditoria completa, implementação das correções pontuadas no code review e aceite com 100% de cobertura e hot-reload ativo.

## Review Triage Log

| Finding | Source | Verdict | Route | Evidence |
|---------|--------|---------|-------|----------|
| Ausência de UI/método para criar Obra | adversarial | high | patch | Implementado `createObra` em `ObraRepository` e `_AddObraDialog` em `ObrasListScreen` |
| `onTap` do `_LoteCard` com TODO vazio | adversarial | high | patch | Implementado `_EditLoteSheet` em `LotesListScreen` com `updatePhase` e `updateStatus` |
| Navegação com operador `!` em ancestrais | edge-case-hunter | medium | patch | Sanitizado em `obra_repository.dart` com checagens de nulidade de pais |
| Nome com whitespace aceito no form | edge-case-hunter | medium | patch | Sanitizado em `add_lote_screen.dart` com `.trim().isEmpty` |
| Stream de lotes descartava cache local | edge-case-hunter | medium | patch | Removido filtro de descarte em `lote_repository.dart` |
| Ausência de testes de Lotes | verification-gap | high | patch | Criado `app/test/obras_lotes_crud_test.dart` com 6 testes (120/120 passando na suite) |

