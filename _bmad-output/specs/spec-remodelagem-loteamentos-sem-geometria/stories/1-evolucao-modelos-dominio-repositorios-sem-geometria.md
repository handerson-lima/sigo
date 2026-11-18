---
title: 'Evolução dos Modelos de Domínio e Repositórios Sem Geometria'
type: 'feature'
created: '2026-11-17'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '4a8aa83c1a459fe1d8f28b3143fea0a0852b558b'
context:
  - 'c:/sigo/_bmad-output/specs/spec-remodelagem-loteamentos-sem-geometria/SPEC.md'
  - 'c:/sigo/_bmad-output/specs/spec-remodelagem-loteamentos-sem-geometria/data-contracts.md'
  - 'c:/sigo/_bmad-output/specs/spec-remodelagem-loteamentos-sem-geometria/architecture-diagrams.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Os modelos e repositórios atuais de `Loteamento`, `Quadra`, `Lote` e `Etapa` não armazenam medidas dimensionais, índices urbanísticos, metadados do carimbo do PDF, progresso agregado das 5 etapas ou vínculos desnormalizados de equipes/funcionários, nem suportam criação em massa respeitando o limite de 500 operações por `WriteBatch` do Firestore.

**Approach:** Evoluir `Loteamento`, `Quadra`, `Lote` e `Etapa` (e seus `.g.dart` via `build_runner`) conforme `data-contracts.md`, mantendo compatibilidade retroativa na leitura JSON de documentos legados sem os campos novos, e estender `LoteamentoRepository`, `QuadraRepository`, `LoteRepository` e `EtapaRepository` com criação em massa em batches de até 500 operações, recálculo atômico de progresso das etapas e atribuição/remoção de equipes e funcionários no lote.

## Boundaries & Constraints

**Always:**
- Preservar todos os campos obrigatórios existentes (`id`, `construtoraId`, `loteamentoId`, `quadraId`, `name`, `createdAt`, `updatedAt` em formato ISO-8601).
- Garantir leitura JSON retrocompatível quando campos novos opcionais ou mapas/listas desnormalizadas estiverem ausentes ou `null`.
- Criar as 5 etapas padrão (`Muro`, `Cinza/1ª`, `Cinza/2ª`, `Cinza/3ª`, `Branca/Acabamento` com IDs `${loteId}_${tipo.name}`) para todo lote criado individualmente ou em massa.
- Respeitar rigorosamente o teto de 500 operações por `WriteBatch` em `createLotesEmMassa`, `createQuadraComLotes` e `createLoteamentoEmMassa`.
- Manter o cálculo `progressoPercentual = (sum(percentual das 5 etapas) / 5).round().clamp(0, 100)` atualizado atomicamente em `lotes/{loteId}` ao alterar qualquer `Etapa`.

**Never:**
- Nunca incluir ou exigir campo `geometry` nos modelos ou payloads gravados no Firestore.
- Nunca alterar regras de negócio do módulo de RH (`rh_repository.dart`, chamadas diárias, salários).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| LEITURA_LEGADA_JSON | JSON antigo de `Loteamento`, `Quadra`, `Lote` e `Etapa` sem campos novos | Desserializa sem exceção aplicando `null` nos opcionais, `progressoPercentual=0`, `etapasConcluidasCount=0`, `etapasTotalCount=5`, `statusEtapasMap` todo `'pendente'`, listas vazias e `Etapa.status='pendente'`, `percentual=0` | N/A |
| CRIACAO_MASSA_ACIMA_500 | `createLotesEmMassa` com 90 lotes (90 lotes + 450 etapas = 540 ops) | Executa em 2 batches (500 + 40 ops), persistindo 90 lotes e 450 etapas | Propaga erro se algum commit falhar |
| CRIACAO_LOTEAMENTO_MASSA | `createLoteamentoEmMassa` com 1 loteamento, 2 quadras e 90 lotes (543 ops) | Executa em 2 batches respeitando teto de 500 ops por batch | Propaga erro se commit falhar |
| ATUALIZACAO_ETAPA_PROGRESSO | `updateEtapaProgresso` marcando `muro` como `'concluida'` e `cinza1` como `'em_andamento'` (`50%`) | `muro` fica `100%`, `cinza1` fica `50%`, demais `0%`; lote atualizado atomicamente com `progressoPercentual=30`, `etapasConcluidasCount=1`, `statusEtapasMap` atualizado | Cria etapas padrão faltantes na base de cálculo |
| LOTACAO_LOTE_E_ETAPA | `atribuirEquipe` / `atribuirFuncionario` / `removerEquipe` / `removerFuncionario` | Atualiza `equipesVinculadas` / `funcionariosVinculados` em `lotes/{id}` sem duplicar mesmo vínculo+etapa e sincroniza `etapas/{etapaId}` quando `etapaId` for informado | Ignora remoção inexistente sem falhar |

</frozen-after-approval>

## Code Map

- `c:/sigo/app/lib/src/features/loteamentos/domain/loteamento.dart` -- Modelo `Loteamento` e `.g.dart`
- `c:/sigo/app/lib/src/features/quadras/domain/quadra.dart` -- Modelo `Quadra` e `.g.dart`
- `c:/sigo/app/lib/src/features/lotes/domain/lote.dart` -- Modelo `Lote` e `.g.dart`
- `c:/sigo/app/lib/src/features/etapas/domain/etapa.dart` -- Modelo `Etapa`, `EtapaTipo` e `.g.dart`
- `c:/sigo/app/lib/src/features/loteamentos/data/loteamento_repository.dart` -- `LoteamentoRepository` (`createLoteamentoEmMassa`, `updateLoteamento`)
- `c:/sigo/app/lib/src/features/quadras/data/quadra_repository.dart` -- `QuadraRepository` (`createQuadraComLotes`)
- `c:/sigo/app/lib/src/features/lotes/data/lote_repository.dart` -- `LoteRepository` (`watchLote`, `watchLoteProvider`, `updateLote`, `createLotesEmMassa`, atribuição/remoção de equipes e funcionários)
- `c:/sigo/app/lib/src/features/etapas/data/etapa_repository.dart` -- `EtapaRepository` (`updateEtapaProgresso`, inicialização de status/percentual nas 5 etapas)
- `c:/sigo/app/test/lote_etapas_atomic_test.dart` -- Testes unitários de domínio e atomicidade dos repositórios
- Fakes em testes de navegação/providers/CRUD que usam `implements LoteamentoRepository` / `QuadraRepository` / `LoteRepository` / `EtapaRepository` (adicionar `noSuchMethod` para compatibilidade)

## Tasks & Acceptance

**Execution:**
- [x] `c:/sigo/app/lib/src/features/loteamentos/domain/loteamento.dart` -- Adicionar campos opcionais (`bairro`, `cidade`, `uf`, `proprietarioNome`, `proprietarioDocumento`, `responsavelTecnicoNome`, `responsavelTecnicoRegistro`) e `copyWith` -- Alinhar ao contrato 1.1
- [x] `c:/sigo/app/lib/src/features/quadras/domain/quadra.dart` -- Adicionar `logradouroPadrao` e `copyWith` -- Alinhar ao contrato 1.2
- [x] `c:/sigo/app/lib/src/features/lotes/domain/lote.dart` -- Adicionar medidas principais, campos opcionais do PDF (quadro de áreas, recuos, carimbo), resumo desnormalizado com defaults retrocompatíveis, helper `calcularAreaTerreno` e `copyWith` -- Alinhar ao contrato 1.3
- [x] `c:/sigo/app/lib/src/features/etapas/domain/etapa.dart` -- Adicionar `status`, `percentual`, `equipeId`, `equipeNome`, `funcionarioId`, `funcionarioNome`, helper de resolução de `EtapaTipo` e `copyWith` -- Alinhar ao contrato 1.4
- [x] `c:/sigo/app/lib/src/features/**/domain/*.g.dart` -- Rodar `dart run build_runner build --delete-conflicting-outputs` em `app/` -- Gerar serializadores atualizados
- [x] `c:/sigo/app/lib/src/features/etapas/data/etapa_repository.dart` -- Atualizar `buildDefaultEtapas` e implementar `updateEtapaProgresso` com recálculo atômico no documento `lotes/{loteId}` -- Garantir consistência entre `etapas` e `lotes`
- [x] `c:/sigo/app/lib/src/features/lotes/data/lote_repository.dart` -- Implementar `watchLote`, `watchLoteProvider`, `updateLote`, `createLotesEmMassa` (batches <= 500 ops) e `atribuirEquipe`/`removerEquipe`/`atribuirFuncionario`/`removerFuncionario` -- Suportar criação em massa e lotação
- [x] `c:/sigo/app/lib/src/features/quadras/data/quadra_repository.dart` -- Implementar `createQuadraComLotes` em batches <= 500 ops -- Permitir criação de quadra + lotes + etapas atomicamente
- [x] `c:/sigo/app/lib/src/features/loteamentos/data/loteamento_repository.dart` -- Implementar `updateLoteamento` e `createLoteamentoEmMassa` em batches <= 500 ops -- Permitir criação de loteamento + quadras + lotes + etapas atomicamente
- [x] `c:/sigo/app/test/lote_etapas_atomic_test.dart` e fakes de teste existentes -- Atualizar fakes com `noSuchMethod` e adicionar testes unitários cobrindo toda a Matriz I/O -- Garantir regressão zero e cobertura da Story 1

**Acceptance Criteria:**
- Given um JSON legado sem os novos campos opcionais, when `fromJson` é chamado nos 4 modelos, then todos desserializam com valores padrão válidos e sem exceções.
- Given uma lista com 90+ lotes, when `createLotesEmMassa` ou `createLoteamentoEmMassa` é executado, then todas as operações são divididas em `WriteBatch`es de até 500 operações e todas as 5 etapas padrão de cada lote são gravadas.
- Given um lote com suas 5 etapas, when `updateEtapaProgresso` altera uma etapa, then a etapa e os campos desnormalizados do lote (`progressoPercentual`, `etapasConcluidasCount`, `statusEtapasMap`) são atualizados atomicamente no mesmo batch.

## Implementation Notes

- Unificados `LoteRepository` e `EtapaRepository` para leitura e gravação diretas em `_firestore.collection('lotes')` e `_firestore.collection('etapas')` (mantendo métodos estáticos legados), assegurando disparo consistente de `snapshots()` entre criação, transação e `updateLote` no Firestore e no `FakeFirebaseFirestore`.
- Alteração de `firestore.rules` (para `existsAfter`/`getAfter` em criação em batch de `quadras`, `lotes` e `etapas`) registrada em `_bmad-output/implementation-artifacts/deferred-work.md` para delegação ao subagente `firestore-rules-author` na Story 4.

## Spec Change Log

## Review Triage Log

- **[high | defer -> Story 4]** `firestore.rules:197-249` usa `exists(...)`/`get(...)` pré-batch em `quadras`, `lotes` e `etapas` em vez de `existsAfter(...)`/`getAfter(...)`, o que rejeitaria criações atômicas pai+filho no mesmo batch para admins não-`dev`. Evidência: confirmado em `firestore.rules:197-249`; edição de `firestore.rules` é reservada à Story 4 via subagente `firestore-rules-author` conforme `AGENTS.md` e `stories.yaml`.
- **[high | patch]** `lote_repository.dart:204-286`: atribuir equipe/funcionário diferente a uma `etapaId` já ocupada mantém entrada antiga no array do lote enquanto sobrescreve o slot único na etapa; falta também validar `etapaId` pertencente a outro lote / `etapaId` desconhecida e semear as 5 etapas padrão ao criar etapa faltante em lote legado. Evidência: confirmado em `LoteRepository._upsertVinculoInLote`.
- **[high | patch]** `etapa_repository.dart:156-265` e `lote_repository.dart:213-341`: leituras `.get()` fora de transação seguidas de `WriteBatch` permitem lost update em atualizações concorrentes no mesmo lote. Evidência: confirmado; migrar para `_firestore.runTransaction` (quando `batch == null` no caso de `updateEtapaProgresso`).
- **[high | patch]** `lote_repository.dart:105-108`: `updateLote` envia `toJson()` completo, sobrescrevendo campos derivados/concorrentes (`progressoPercentual`, `etapasConcluidasCount`, `etapasTotalCount`, `statusEtapasMap`, `equipesVinculadas`, `funcionariosVinculados`). Evidência: confirmado; remover essas 6 chaves do payload de `updateLote`.
- **[medium | patch]** `etapa_repository.dart:79-132`: `createDefaultEtapas` com `SetOptions(merge: true)` e objeto completo sobrescreveria `status`, `percentual` e vínculos caso uma etapa já exista; além disso, `createLoteComEtapas` usa `DateTime.now()` em vez de `lote.createdAt`. Evidência: confirmado em `createDefaultEtapas` e `createLoteComEtapas`.
- **[medium | patch]** `etapa_repository.dart:161-193`: `updateEtapaProgresso` aceita parâmetros de hierarquia divergentes de `loteData`, faz fallback silencioso quando `etapaId` não existe mas o `EtapaTipo` já existe ou pertence a outro lote, e não usa `doc.id` ao mapear `Etapa` do snapshot. Evidência: confirmado.
- **[medium | patch]** `lote_repository.dart:33-55`: `appendLotesComEtapasWrites` enfileira todos os `lotes` antes de todas as `etapas`; acima de 500 ops, falha no batch 2 deixa dezenas de lotes órfãos sem etapas. Intercalar cada `lote` seguido imediatamente de suas 5 `etapas` mantém `[500, 40]` ops e minimiza risco por lote. Evidência: confirmado.
- **[medium | patch]** `lote.dart:138-214`, `loteamento.dart:37-68`, `quadra.dart:27-45`: `copyWith` não permite limpar campos opcionais de volta para `null` (diferente de `Etapa.copyWith`); e `QuadraRepository` carece de `updateQuadra` + validação de FKs/IDs duplicados na criação em massa. Evidência: confirmado.
- **[medium | patch]** `contracts.dart:186-205`, `etapa.dart:73-83`, `lote.dart:7-50,131-136`, `lote_repository.dart:110-211`: faltam guarda de `maxOpsPerBatch` (`1..500`), `isFinite` em números, validação de `EtapaStatus.values`, filtro de chaves/valores válidos e mapa mutável em `_statusEtapasMapFromJson`, conversão segura de chaves em `_mapListFromJson`, checagem de área finita em `calcularAreaTerreno`, guarda contra IDs vazios e leitura segura de `entry['etapaId']` em `_matchesVinculo`. Evidência: confirmado.
- **[false | rejected]** `fromJson` falha se `createdAt`/`updatedAt` estiverem ausentes/nulos: campos obrigatórios pelo `data-contracts.md`, e `compatibleDates`/`readDate` em `contracts.dart` segue o padrão do app inteiro.
- **[low | patch]** `equipe.g.dart`: diff cosmético de formatação fora do escopo da story; restaurar arquivo ao baseline `4a8aa83`.
- **[high | patch]** `verification-gap`: 4 gaps reais de teste em `lote_etapas_atomic_test.dart` (`Timestamp` em `fromJson` dos 4 modelos; `percentual` explícito, clamping e erros de validação em `updateEtapaProgresso`; atribuição em lote legado sem etapas, substituição na mesma etapa, proteção de dono distinto na remoção e remoção de vínculo geral; sanitização de JSON não-nulo com mapa parcial, números fora da faixa/`NaN` e status em branco/inválido). Evidência: confirmado na suíte atual.

## Verification

**Commands:**
- `cd c:\sigo\app && dart run build_runner build --delete-conflicting-outputs` -- expected: Exit code 0 e `.g.dart` atualizados
- `cd c:\sigo\app && flutter analyze` -- expected: `No issues found!`
- `cd c:\sigo\app && flutter test` -- expected: `All tests passed!`
- `cd c:\sigo && functions-python\venv\Scripts\pytest.exe functions-python/tests` -- expected: Todos os testes passando
