---
title: 'Importação DXF de loteamento funcional de ponta a ponta'
type: 'feature'
created: '2026-09-29'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'b5d737a273f94b9ba6b99ff8054805ce424c9945'
context:
  - '_bmad-output/implementation-artifacts/spec-retentativa-consolidacao-dxf-aprovado.md'
  - '_bmad-output/implementation-artifacts/spec-importacao-dxf-loteamento.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O upload do DXF de referência (`dwg_dxf/00a-LOTEAMENTO_HR_R13A-Model.dxf`) cria o rascunho, mas o fluxo não chega ao fim: (1) o app só grava `status:'aprovado'` e **nada materializa** `loteamentos`/`quadras`/`lotes` — a consolidação foi revertida (`8a16886`, `6643e8b`); (2) `loteamentos_drafts` **não tem regra** no Firestore, então um membro da construtora não lê/edita/aprova o rascunho; (3) a memória de `processar_dxf` foi elevada a 1 GiB apenas no console, então um deploy a reverte para 512 MiB e o OOM volta.

**Approach:** Reintroduzir a consolidação idempotente ancorada numa solicitação explícita que o app grava ao aprovar e o backend consome (gatilho Firestore + callable manual de retry), gravando `loteamentos`/`quadras`/`lotes` top-level com IDs determinísticos; liberar o acesso do membro da construtora ao rascunho; declarar memória/CPU no código e buildar o codebase `default` antes do deploy; validar no emulador e publicar em `sigo-c2eb2`.

## Boundaries & Constraints

**Always:** Manter o contrato de features do rascunho (`tipo`/`nome`/`quadra`/`status`) e o canvas atual; toda materialização final ocorre no backend via Admin SDK, nunca no Flutter; consolidação idempotente e retomável (IDs determinísticos + `batch.set`); preservar o rascunho e a solicitação quando a consolidação falhar; exigir ao menos um lote para aprovar; declarar memória e CPU no decorator; aceitar exclusivamente `.dxf`.

**Never:** Não usar DWF/PDF/DWG; não materializar a partir do Flutter; não apagar ou recriar dados finais já consolidados numa retentativa; não trocar as coleções finais top-level nem os campos esperados pelo app (`construtoraId`, `loteamentoId`, `quadraId`, `name`); não alterar o contrato do canvas; não depender de configuração só feita no console.

**Decisions:** Acesso a `loteamentos_drafts` é restrito ao membro ativo da construtora do rascunho (lê/atualiza); `create`/`delete` negados. A consolidação usa gatilho Firestore por `consolidationRequestId` **e** uma callable manual de retry para recuperar aprovações quando o gatilho não dispara.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| APROVACAO | Rascunho pendente, zero pendências, ≥1 lote | App grava `status:'aprovado'` + `consolidationRequestId`; gatilho cria loteamento, quadras e lotes top-level | Logs de início e conclusão |
| RETENTATIVA | Rascunho já `aprovado` sem conclusão anterior | Nova aprovação grava novo `consolidationRequestId`; gatilho ou callable reprocessa sem exigir novo upload | Não depende de voltar o status a pendente |
| ENTREGA_DUPLICADA | Mesma solicitação entregue 2x | Só uma execução materializa; documentos persistentes permanecem únicos | Segunda execução ignorada e registrada |
| FALHA_CONSOLIDACAO | Erro de validação ou Firestore | Solicitação não é marcada como concluída; rascunho permanece recuperável | Erro propagado para retry + log de contexto |
| ACESSO_RASCUNHO | Membro ativo da construtora do rascunho | Lê, edita feature e aprova pelo app | Escrita de create/delete negada; non-membro negado |
| DEPLOY_MEMORIA | `firebase deploy` da `functions-python` | `processar_dxf` continua com 1 GiB e não estoura no DXF real | Sem OOM/erro de conexão |

</frozen-after-approval>

## Code Map

- `functions-python/firestore_utils.py:10-64` -- hoje só `save_draft_to_firestore` (serializa `geometry` para String). Reintroduzir `consolidate_approved_draft` lendo `geometry` String/Map e gravando top-level.
- `functions-python/main.py:44-130` -- `processar_dxf` (Storage). Adicionar gatilho Firestore `consolidar_loteamento_aprovado` + callable `consolidar_loteamento_manual`, e declarar `memory=MemoryOption.GB_1`/`cpu=1`. Hoje importa só `storage_fn` (`:14`).
- `functions-python/tests/test_main.py`, `tests/test_firestore_utils.py` -- cobrir gatilho, token, callable, consolidação e parsing de geometry String. `tests_integration/` já grava/relê com emulador.
- `app/lib/src/features/loteamentos/data/loteamentos_import_repository.dart:139-142` -- `approveDraft` só grava `status:'aprovado'`; deve gravar também `consolidationRequestId` único por clique.
- `app/lib/src/features/loteamentos/presentation/loteamento_canvas_screen.dart:76-92` -- guardas de aprovação + mensagem/navegação; não materializar aqui.
- `app/test/src/features/loteamentos/data/loteamentos_import_repository_test.dart:200-210` -- hoje nega `consolidationRequestId`; atualizar e cobrir a tela.
- `firestore.rules:23-25,196-233` -- catch-all `dev()`; `loteamentos`/`quadras`/`lotes` top-level já existem (`:202-233`) com `hierarchyRead`. Falta `match` para `loteamentos_drafts` (membro da construtora do rascunho).
- `firebase.json:9-33` -- codebases `functions` (TS, sem runtime) e `functions-python` (python311); sem `predeploy`.
- `functions/lib/` -- gitignored e sem `predeploy`: rodar `npm run build` antes do deploy do codebase `default`.
- Funções revertidas de referência: `git show 42468bd:functions-python/firestore_utils.py` (IDs, coleções, batches); `git show f4081b4:functions-python/main.py` (claim/TTL e callable manual).

## Tasks & Acceptance

**Execution:**
- [x] `functions-python/firestore_utils.py` -- reintroduzir `consolidate_approved_draft` idempotente: parsear `geometry` String/Map, criar `loteamentos` (`{draft_id}--loteamento`), `quadras` (`{draft_id}--quadra--{i}`/`--ref--{hash}`) e `lotes` (`{draft_id}--lote--{i}`) top-level com FKs, blocos de 500 e marca de conclusão por `consolidationRequestId` -- materializa a aprovação sem duplicar.
- [x] `functions-python/main.py` -- gatilho `on_document_updated('loteamentos_drafts/{draft_id}')` que dispara só quando `consolidationRequestId` muda e difere de `consolidationCompletedRequestId`, com claim/TTL e logs; callable `consolidar_loteamento_manual` para retry; declarar `memory`/`cpu` na `processar_dxf` -- fecha a retentativa e evita OOM após deploy.
- [x] `functions-python/tests/test_main.py` e `tests/test_firestore_utils.py` -- cobrir primeira aprovação, retentativa, entrega duplicada, falha sem falsa conclusão, callable, IDs/coleções e parsing de geometry String -- travas da consolidação.
- [x] `app/lib/src/features/loteamentos/data/loteamentos_import_repository.dart` -- `approveDraft` grava `status:'aprovado'` + `consolidationRequestId` único por clique -- origem da solicitação.
- [x] `app/test/src/features/loteamentos/data/loteamentos_import_repository_test.dart` (+ tela) -- atualizar expectativas e cobrir a solicitação sem quebrar as guardas de aprovação.
- [x] `firestore.rules` -- adicionar `match /loteamentos_drafts/{draft_id}` (read/update do membro ativo da construtora; create/delete negados) -- destrava o cliente.
- [x] `firebase.json` -- `predeploy` para buildar o codebase `functions` -- evita deploy de `lib/` ausente.
- [ ] Publicação -- `firebase deploy --only functions,firestore:rules --project sigo-c2eb2` -- operação irreversível; requer confirmação humana no momento.

**Acceptance Criteria:**
- Given o DXF de referência, when o membro aprova, then o loteamento, suas quadras e seus lotes aparecem nas telas finais carregadas pelos providers existentes.
- Given uma aprovação repetida sem materialização anterior, when o usuário confirma de novo, then o backend consolida sem exigir novo upload e sem duplicar.
- Given a mesma solicitação entregue 2x, when o gatilho recebe as cópias, then só uma materializa.
- Given um membro ativo da construtora do rascunho, when ele abre o rascunho, then vê, corrige e aprova; um usuário não membro é negado.
- Given `firebase deploy`, when concluído, then `processar_dxf` mantém 1 GiB.

## Implementation Notes

- A consolidação revertida esperava `geometry` como Map (`42468bd:firestore_utils.py:64-76`), mas o HEAD grava `geometry` como String JSON; a reaplicação precisa parsear a String.
- Coleções finais são top-level (`loteamentos`/`quadras`/`lotes`), confirmado por `app/lib/src/features/loteamentos/data/loteamento_repository.dart:15-27` e `firestore.rules:202-233`.
- `firebase_functions` expõe `MemoryOption.GB_1` (não `MB_1024`); decorators aceitam `memory=`/`cpu=` via kwargs.
- O app nunca cria rascunhos diretamente; a regra só precisa de `read`/`update`.
- 2026-09-29 (implementação): o DXF de referência não traz rótulos de quadra reconhecíveis, então todo lote chega ao rascunho com `quadra:''` e o agrupamento por nome (comportamento revertido) não materializava quadra alguma. A consolidação passou a resolver a quadra do lote por contenção espacial nos polígonos `tipo:'quadra'` do rascunho e, quando não há contenção, por uma quadra determinística `{draft_id}--quadra--geral` (`Geral`), garantindo `lote.quadraId` preenchido para os providers existentes. IDs de quadras nomeadas (`--ref--hash`) e de features (`--quadra--{i}`) permanecem como na spec.
- 2026-09-29 (implementação): o gatilho Firestore publica `eventTrigger['retry'] = True` via `__firebase_endpoint__` porque `firebase-functions-python` 0.6 não expõe opção pública de retry (verificado no pacote real).

## Spec Change Log

## Review Triage Log

- BH1 callable `consolidar_loteamento_manual` sem autorização — **high** → patch. Verificado: `main.py` não usa `request.auth`; qualquer chamador com o `draftId` materializa dados de outra construtora.
- BH2 IDs determinísticos sem escopo de construtora — **maybe-false** → defer. O `draft_id` carrega timestamp em ms, tornando colisão entre construtoras improvável; settle: provar dois uploads com o mesmo `draft_id`.
- BH3 `createdAt`/`updatedAt` regerados no retry — **low** → rejeitado. Só churn de `updatedAt` em reexecução; o conserto exige leitura/existência (mais que correção direta).
- BH4 documentos obsoletos ao remover features — **low** → rejeitado. Re-edição pós-aprovação é improvável (a tela navega para fora) e reconciliar/remover exige complexidade.
- BH5 erro permanente com `retry=True` vira poison message — **medium** → patch. `ValueError` de validação re-lançado indefinidamente; classificar e não re-lançar.
- BH6 consolidação perdida em crash pós-claim — **maybe-false** → defer. Janela estreita (morte do processo entre claim e release); settle: simular crash e observar a reentrega.
- BH7 gatilho não compara `before` — **medium** → patch. Verificado: `event.data.before` ignorado; qualquer update de rascunho aprovado re-dispara, contrariando a spec.
- BH8 rules não limitam campos do update — **medium** → patch. Membro forja `consolidationCompletedRequestId`/`consolidationRequestId`; allowlist de `affectedKeys`.
- BH9 `approveDraft` sem validar lote/pendências — **false**. A tela só habilita com `ambiguos == 0 && possuiLote`; o backend rejeita.
- BH10 schema final não conferido com os modelos Flutter — **false**. `loteamento_repository`/`quadra_repository`/`lote_repository` leem `name`/FKs; o teste de integração confirma String ISO e FKs.
- BH11 falta teste de tela da aprovação — **false**. `loteamento_canvas_screen_test.dart` cobre guardas, mensagem e navegação com repositório fake.
- BH12 `test_consolidation_reference` depende do fixture sem skip — **false**. O DXF é versionado e já usado por `test_dxf_extraction`.
- BH13 fakes duplicados nos testes — **low** → rejeitado. Deduplicação entre pacotes de teste é mais que correção direta.
- BH14 `__firebase_endpoint__` é API interna — **low** → rejeitado. Verificado no pacote real; guard de versão adiciona complexidade sem falha demonstrada.
- BH15 nome de quadra duplicado aborta — **low** → rejeitado. Não demonstrado no fixture (nomes vazios); mesclar exige decisão de produto.
- BH16 falta de documentação/observabilidade — **low** → rejeitado. Correção editaria docs e não há defeito de comportamento demonstrado.
- BH17 sem teste cross-tenant do callable — **high** → patch (mesma raiz de BH1).
- ECH1 callable sem auth — **high** → patch (BH1).
- ECH2 lock single-flight por TTL insuficiente — **maybe-false** → defer (BH6).
- ECH3 órfãos em re-edição — **low** → rejeitado (BH4).
- ECH4 rules permitem forjar marcadores — **medium** → patch (BH8).
- ECH5 import quebra se `__firebase_endpoint__` mudar — **low** → rejeitado (BH14).
- ECH6 `before` não lido — **medium** → patch (BH7).
- VG-main callable manual não é acionado pelo app — **medium** → patch. Pré-verificado: nenhum consumidor chama `consolidar_loteamento_manual`; o fallback de retry previsto no design não é usado.
- VG-other callable sem verificação de chamador — **high** → patch (BH1).

## Design Notes

A solicitação explícita evita depender de uma única transição de status (motivo do design da spec de retentativa) e o callable manual cobre o caso observado nos logs em que o gatilho não disparou. O claim transacional com TTL mantém a idempotência mesmo com redelivery. A marca de conclusão é gravada no rascunho retido, nunca apagado.

## Verification

**Commands:**
- `cd functions-python && ./venv/bin/python -m pytest tests/test_main.py tests/test_firestore_utils.py -q` -- expected: passam, incluindo gatilho/token/callable e parsing de String.
- `cd functions && npm run test:draft-persistence` -- expected: emulador Firestore sobe e persistência passa.
- `cd app && flutter analyze && flutter test test/src/features/loteamentos` -- expected: sem novos diagnósticos; testes passam.
- `cd functions && npm run test:rules` -- expected: rules de `loteamentos_drafts` e do Storage passam.
- `firebase deploy --only functions,firestore:rules --project sigo-c2eb2` -- expected: `processar_dxf` e `consolidar_loteamento_aprovado` ativas com 1 GiB.

**Manual checks (if no CLI):**
- Aprovar o rascunho do fixture e confirmar documentos em `loteamentos`/`quadras`/`lotes` com FKs preenchidas.
