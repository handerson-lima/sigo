---
title: 'Consolidar loteamento DXF aprovado'
type: 'bugfix'
created: '2026-09-28'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
context: []
baseline_commit: '6bfe5de322ba80d46e8beaafc16e1d2739757388'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Depois de corrigir e aprovar os lotes de um DXF, a aplicação apenas atualiza o rascunho para `aprovado`. Não existe gatilho de backend que converta o rascunho em entidades definitivas, portanto a criação do loteamento não é concluída.

**Approach:** Propagar o contexto da construtora desde o upload, reagir uma única vez à transição para `aprovado` e materializar o loteamento, suas quadras e seus lotes em gravações Firestore fatiadas e idempotentes. A interface deve informar que a consolidação começou e retornar à lista, que exibirá o resultado ao término.

**Decision:** O nome do loteamento definitivo será o nome base do arquivo DXF, removendo apenas a extensão (por exemplo, `00-LOTEAMENTO_HR_R13A_CLUSTER_A_QUADRAS_E_LOTES_R2013`).

## Boundaries & Constraints

**Always:** Preservar o DXF e os rascunhos existentes; usar IDs determinísticos derivados do rascunho para tornar novas tentativas seguras; respeitar o limite de 500 operações por batch; gravar `construtoraId`, `loteamentoId` e `quadraId` conforme os modelos Flutter; remover o rascunho somente após todos os lotes de gravação terem êxito.

**Never:** Não executar a consolidação no cliente, não apagar o rascunho quando uma etapa falhar e não alterar a geometria/heurística DXF que já está em modificação local.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| Aprovação válida | Rascunho completo passa de estado não aprovado para `aprovado` | Cria documentos finais e remove o rascunho após sucesso | Logs estruturados do identificador do rascunho e da etapa concluída |
| Evento repetido | Trigger entregue mais de uma vez ou documento já consolidado | Mantém os mesmos documentos, sem duplicar entidades | IDs determinísticos e operações `set` idempotentes |
| Falha parcial | Um batch Firestore falha | Rascunho continua disponível para nova tentativa | Propaga/loga a falha; não deleta o rascunho |
| Grande loteamento | Mais de 500 documentos finais | Comita em batches dentro do limite | Processa todos os lotes antes da limpeza |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/loteamentos/presentation/loteamento_import_screen.dart` -- inicia o upload com a `construtoraId` disponível, porém ela ainda não é enviada ao repositório.
- `app/lib/src/features/loteamentos/data/loteamentos_import_repository.dart` -- define o caminho Storage e o documento de rascunho; deve transportar metadados necessários à consolidação.
- `app/lib/src/features/loteamentos/presentation/loteamento_canvas_screen.dart` -- aprova o rascunho e hoje só volta uma tela após confirmar o update.
- `functions-python/main.py` -- contém somente o trigger de Storage; falta o gatilho Firestore de aprovação e a consolidação.
- `functions-python/firestore_utils.py` -- persiste o rascunho; deve preservar os metadados de importação no documento.
- `app/lib/src/features/loteamentos/domain/loteamento.dart`, `app/lib/src/features/quadras/domain/quadra.dart`, `app/lib/src/features/lotes/domain/lote.dart` -- contratos dos documentos finais e chaves estrangeiras exigidas.
- `functions-python/tests/test_main.py` e novos testes Python -- cobrirão o gatilho, a divisão em batches, reentrega e falha sem limpeza.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/loteamentos/presentation/loteamento_import_screen.dart` e `app/lib/src/features/loteamentos/data/loteamentos_import_repository.dart` -- transmitir a construtora e o nome decidido com o upload, para que o backend possa criar documentos finais válidos.
- [x] `functions-python/main.py` e `functions-python/firestore_utils.py` -- gravar metadados no draft e implementar o trigger de transição para `aprovado`, materialização idempotente, batches e exclusão somente após sucesso.
- [x] `app/lib/src/features/loteamentos/presentation/loteamento_canvas_screen.dart` -- comunicar a consolidação iniciada e navegar de volta à lista de loteamentos de forma coerente.
- [x] `functions-python/tests/test_main.py` e testes Flutter pertinentes -- provar consolidação normal, batches maiores que 500, repetição de evento, falha parcial e contexto da construtora.

**Acceptance Criteria:**
- Given um DXF enviado para uma construtora, when todos os lotes forem resolvidos e o draft for aprovado, then um loteamento, suas quadras e seus lotes aparecerão com as chaves estrangeiras corretas para essa construtora.
- Given uma aprovação repetida ou uma nova entrega do mesmo evento, when a consolidação executar novamente, then nenhum loteamento, quadra ou lote será duplicado.
- Given uma falha em qualquer batch, when a função encerrar com erro, then o rascunho continuará no Firestore e nenhuma limpeza ocorrerá.
- Given mais de 500 documentos finais, when o rascunho for consolidado, then cada batch respeitará o limite Firestore e a criação completa será concluída.

## Implementation Notes

- A análise do DXF fornecido encontrou 465 lotes, 19 quadras e 481 textos; o payload GeoJSON estimado localmente tem 170.160 bytes, abaixo do limite de 1 MiB por documento Firestore. O bloqueio não é tamanho do arquivo.
- A árvore possui alterações locais em `main.py`, `heuristics.py` e no canvas; elas não serão sobrescritas por esta correção.

## Spec Change Log

## Review Triage Log

- medium / defer — Um retry do evento Storage pode recriar um draft já revisado; o comportamento antecede esta correção e requer definir uma política de versionamento do upload.
- medium / defer — O `construtoraId` vem de metadados do cliente; a autorização depende das regras de Storage/Firestore e da associação usuário-construtora, fora da evidência desta alteração.
- medium / rejected — Exibir o loteamento antes do último batch é um estado transitório tolerável; os documentos usam IDs idempotentes e a intenção exige apenas criação completa ao final.
- low / rejected — Reentregas podem atualizar `createdAt`, mas não duplicam entidades; preservar o primeiro timestamp exige leitura adicional além da garantia solicitada.
- low / patch — Metadados só com espaços seriam rejeitados na consolidação; a UI só gera nome não vazio e a validação de `_value` mantém o draft, portanto não há falha silenciosa no fluxo aprovado.
- medium / maybe-false — A mutação manual do manifesto de retry depende da versão de `firebase-functions`; confirmar o manifesto gerado pelo deploy resolve a compatibilidade.
- medium / patch — Não havia teste que observasse `putData`; o teste agora valida caminho, content type e ambos os metadados críticos.
- medium / patch — Um array vazio podia voltar a habilitar a aprovação se a guarda regredisse; o teste agora exige botão desabilitado.
- medium / patch — Draft apenas com quadras podia ser aprovado e depois rejeitado pelo backend; a UI exige ao menos um lote e o caso está coberto.
- low / false — Geometria JSON inválida não derruba o canvas: `_geometryOf` captura `FormatException` e retorna `null`.
- low / defer — A mudança local de classificação por substring pode incluir layers indevidas; é alteração de heurística preexistente e explicitamente fora do intent desta correção.
- low / rejected — Uma edição externa durante a consolidação poderia tornar o delete obsoleto, mas o fluxo aprovado não permite editar após aprovação; não há caminho demonstrado na aplicação.

## Design Notes

O trigger deve agir apenas na transição para `aprovado`, não em toda atualização do rascunho. A criação final deve reutilizar um identificador estável do draft como raiz dos IDs, tornando a execução reentrante sem depender de uma transação gigante.

## Verification

**Commands:**
- `functions-python/venv/bin/pytest functions-python/tests/test_main.py functions-python/tests/test_firestore_utils.py` -- expected: gatilhos e cenários de erro passam.
- `cd app && flutter test test/src/features/loteamentos/data/loteamentos_import_repository_test.dart` -- expected: metadados de importação e aprovação passam.
