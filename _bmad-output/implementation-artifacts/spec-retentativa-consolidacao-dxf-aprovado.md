---
title: 'Permitir retentativa da consolidação de loteamento DXF aprovado'
type: 'bugfix'
created: '2026-09-28'
status: 'in-progress'
route: 'dispatch'
review_loop_iteration: 0
context: []
baseline_commit: '42468bd2af8d1be56fc09c715ce586f573ae5109'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Um rascunho DXF pode receber a confirmação de aprovação sem que o gatilho de consolidação seja consumido. Como o backend só aceita a primeira transição de `status` para `aprovado`, um novo clique de aprovação no mesmo rascunho não gera uma tentativa de criação dos documentos definitivos; por isso a tela de Quadras permanece vazia.

**Approach:** Cada confirmação de aprovação registrará uma solicitação de consolidação identificável no rascunho. O gatilho Firestore consolidará um rascunho aprovado quando detectar uma solicitação nova, mantendo a operação idempotente e permitindo recuperar aprovações feitas antes ou durante uma indisponibilidade do gatilho.

## Boundaries & Constraints

**Always:** Manter a validação de pendências e a exigência de ao menos um lote; preservar o rascunho quando a consolidação falhar; aceitar eventos duplicados sem criar entidades duplicadas; registrar logs suficientes para diferenciar solicitação ignorada, iniciada, concluída e falha; manter a criação final exclusivamente no backend.

**Never:** Não alterar a heurística ou a geometria DXF, não apagar ou recriar os dados já finais para realizar uma retentativa, não executar a consolidação no Flutter e não tornar qualquer edição normal de feature uma nova solicitação de processamento.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| Primeira aprovação | Draft pendente com zero pendências e lotes | Cliente grava `aprovado` e uma solicitação de consolidação; função cria loteamento, quadras e lotes | Mantém a mensagem de início e logs de conclusão |
| Nova aprovação do mesmo draft | Draft já `aprovado`, sem criação final anterior | Cliente atualiza a solicitação; função inicia nova consolidação | Não depende de mudar o status para pendente |
| Evento duplicado | Mesma solicitação entregue duas vezes | Somente uma execução processa a solicitação; documentos determinísticos permanecem únicos | Segunda execução é ignorada e registrada |
| Falha da consolidação | Erro de validação ou Firestore | Solicitação não é marcada como concluída e o draft continua disponível | Função propaga erro para a política de retry e registra contexto |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/loteamentos/data/loteamentos_import_repository.dart` -- `approveDraft` hoje escreve somente `status: aprovado`; será a origem explícita de uma solicitação nova.
- `app/lib/src/features/loteamentos/presentation/loteamento_canvas_screen.dart` -- preserva as guardas de aprovação e chama o repositório; não deve passar a materializar dados diretamente.
- `functions-python/main.py` -- `consolidar_loteamento_aprovado` rejeita hoje todo update `aprovado -> aprovado`; deve comparar a solicitação antes/depois e marcar somente êxitos.
- `functions-python/firestore_utils.py` -- `consolidate_approved_draft` cria documentos finais com IDs determinísticos e deve continuar sendo a única rotina de materialização.
- `functions-python/tests/test_main.py` -- já cobre a transição de status e o retry do trigger; deve cobrir o token de solicitação, repetição e falha.
- `app/test/src/features/loteamentos/presentation/loteamento_canvas_screen_test.dart` -- cobre habilitação e envio da aprovação; deve assegurar que o fluxo continua delegando ao repositório.

## Tasks & Acceptance

**Execution:**
- [ ] `app/lib/src/features/loteamentos/data/loteamentos_import_repository.dart` -- gravar, junto ao status aprovado, um valor de solicitação de consolidação que mude a cada confirmação; isso permite a retentativa sem manipular o status do rascunho.
- [ ] `functions-python/main.py` -- disparar a consolidação de um draft aprovado somente quando houver uma solicitação nova, ignorar reentregas da mesma solicitação, registrar execução e persistir uma marca de conclusão somente depois de êxito.
- [ ] `functions-python/tests/test_main.py` e testes Flutter pertinentes -- validar primeira aprovação, retentativa de draft já aprovado, reentrega idêntica e propagação de erro sem falsa conclusão.
- [ ] Publicação -- fazer deploy da função Firestore atualizada após os testes, pois o gatilho é uma dependência externa da criação de Quadras.

**Acceptance Criteria:**
- Given um draft aprovado cuja criação final não ocorreu, when o usuário confirma a aprovação novamente, then o backend recebe uma solicitação nova e cria o loteamento, suas quadras e seus lotes sem exigir um novo upload.
- Given uma mesma solicitação de consolidação é entregue mais de uma vez, when o gatilho recebe as cópias, then somente uma é processada e as entidades finais não são duplicadas.
- Given a materialização falha, when a função encerra, then o rascunho e sua solicitação permanecem recuperáveis, sem marca de conclusão indevida.
- Given a criação final conclui, when o usuário navega para Quadras, then as quadras correspondentes ao loteamento são carregadas pela consulta existente.

## Implementation Notes

O Firebase usado pelo Flutter e pela função é `sigo-c2eb2`. A função publicada está ativa, mas os logs posteriores à aprovação não exibem execução da consolidação. O contrato será estendido com uma solicitação explícita, em vez de depender implicitamente de uma única mudança de status.

## Spec Change Log

## Review Triage Log

## Design Notes

O valor de solicitação deve ser diferente em cada clique e ser comparável entre o snapshot anterior e o posterior. Uma marca de conclusão associada a esse valor evita que atualizações feitas pela própria função reabram a consolidação. A função continuará idempotente por seus IDs determinísticos, mas a deduplicação no gatilho reduz gravações e deixa os logs operacionais claros.

## Verification

**Commands:**
- `functions-python/venv/bin/pytest functions-python/tests/test_main.py functions-python/tests/test_firestore_utils.py` -- expected: aprovação inicial, retentativa, duplicata e falha passam.
- `cd app && flutter test test/src/features/loteamentos/data/loteamentos_import_repository_test.dart test/src/features/loteamentos/presentation/loteamento_canvas_screen_test.dart` -- expected: aprovação registra uma solicitação e as guardas visuais continuam corretas.
- `firebase deploy --only functions:functions-python:consolidar_loteamento_aprovado --force` -- expected: função ativa com o código de retentativa.
