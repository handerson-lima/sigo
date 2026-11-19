---
title: 'Criação Manual Individual e em Massa de Loteamentos, Quadras e Lotes'
type: 'feature'
created: '2026-11-18'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'acefc7cad96befc43dd26c58f648491e134e420a'
context:
  - 'c:/sigo/_bmad-output/specs/spec-remodelagem-loteamentos-sem-geometria/SPEC.md'
  - 'c:/sigo/_bmad-output/specs/spec-remodelagem-loteamentos-sem-geometria/data-contracts.md'
  - 'c:/sigo/_bmad-output/specs/spec-remodelagem-loteamentos-sem-geometria/architecture-diagrams.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Os diálogos e telas de criação manual atuais (`LoteamentosListScreen`, `QuadrasListScreen` e `AddLoteScreen`) não expõem campos dimensionais (`frenteM`, `profundidadeM`, `areaTerrenoM2`, `areaConstruidaM2`, `logradouro`), não permitem criar quadras manualmente nem preencher metadados opcionais/urbanísticos de PDF, e exigem cadastrar lote por lote em vez de gerar múltiplos lotes em massa com ajuste pontual de exceções.

**Approach:** Remodelar `_AddLoteamentoDialog` (`LoteamentosListScreen`), adicionar criação manual/em massa de quadras (`QuadrasListScreen`), e evoluir `AddLoteScreen` com modos Individual e Em Massa, mantendo UUID fixo em `initState()` no fluxo individual, cálculo automático da área do terreno (`Lote.calcularAreaTerreno(frenteM, profundidadeM)`) com edição manual, campos urbanísticos/carimbo opcionais em `ExpansionTile`, prévia tabular editável para ajuste de exceções e persistência atômica em batches de até 500 operações.

## Boundaries & Constraints

**Always:**
- Manter UUID fixo inicializado em `initState()` (`late final String _loteId = const Uuid().v4();`) no modo individual de `AddLoteScreen` (proteção contra timeout offline e duplicidade).
- Expor localização, proprietário, responsável técnico, quadro de áreas, recuos e carimbo do PDF apenas em seções opcionais (`ExpansionTile`), mantendo o cadastro rápido totalmente funcional só com nome ou medidas principais.
- Calcular `areaTerrenoM2` automaticamente via `Lote.calcularAreaTerreno(frente, profundidade)` quando frente e profundidade forem positivas, permitindo sobrescrita manual sem travar o campo.
- Aceitar vírgula ou ponto decimal nos campos numéricos em português (`pt-br`).
- Permitir gerar lotes em massa por quantidade/prefixo/número inicial com prévia editável antes de gravar, usando `createLoteamentoEmMassa`, `createQuadraComLotes` e `createLotesEmMassa`.
- Preservar todos os testes existentes (`obras_lotes_crud_test.dart`, `loteamento_quadra_lote_navigation_test.dart`, `loteamentos_list_screen_test.dart`, `quadras_list_screen_test.dart`).

**Never:**
- Nunca gravar campo `geometry` nos modelos criados.
- Nunca exibir botões de criação/geração para usuários sem permissão administrativa em `LoteamentosListScreen` e `QuadrasListScreen`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| CRIACAO_SIMPLES_LOTEAMENTO | Usuário informa apenas `name` em `_AddLoteamentoDialog` | Chama `createLoteamento` sem exigir localização, carimbo ou geração em massa | Valida `name` não vazio |
| CRIACAO_MASSA_LOTEAMENTO | Usuário preenche localização opcional + seção em massa (ex.: `Quadra A`, 5 lotes, `10 x 20`) e gera prévia | Calcula `areaTerrenoM2 = 200.0` automaticamente, permite editar exceção na prévia e salva via `createLoteamentoEmMassa` | Valida campos da quadra/quantidade >= 1 |
| CRIACAO_QUADRA_COM_LOTES | Admin abre dialog de nova quadra em `QuadrasListScreen`, informa nome, `logradouroPadrao` e gera 3 lotes (ajustando lote 2 para `12 x 20`) | Salva quadra + 3 lotes editados via `createQuadraComLotes` | Sem lotes na prévia, salva só a quadra via `createQuadra` |
| ADD_LOTE_INDIVIDUAL | Modo Individual em `AddLoteScreen`: primeiro campo é `name`, botões/labels compatíveis com testes legados; preenche frente/profundidade e opcional `ExpansionTile` | Calcula `areaTerrenoM2`, mantém `_loteId` fixo entre tentativas e salva via `createLoteComEtapas` | Valida `name` não vazio (`'Campo obrigatório'`) e timeout 15s |
| ADD_LOTE_EM_MASSA | Modo Em Massa em `AddLoteScreen`: `quantidade=4`, `prefixo='Lote '`, `numeroInicial=10`, `10 x 20` | Gera `Lote 10..Lote 13` na prévia editável com `areaTerrenoM2=200.0`, permite ajustar lote de esquina e grava via `createLotesEmMassa` | Valida quantidade entre `1` e `500` por operação UI razoável (>0) e nomes não vazios na prévia |

</frozen-after-approval>

## Code Map

- `c:/sigo/app/lib/src/features/loteamentos/presentation/loteamentos_list_screen.dart` -- Criação manual individual/em massa de loteamentos com localização/carimbo opcional e subtítulo na lista
- `c:/sigo/app/lib/src/features/quadras/presentation/quadras_list_screen.dart` -- Ação admin de nova quadra (`_AddQuadraDialog`) com `logradouroPadrao` e geração em massa de lotes com prévia editável
- `c:/sigo/app/lib/src/features/lotes/presentation/add_lote_screen.dart` -- Modos Individual e Em Massa, cálculo automático de área, `ExpansionTile` para índices/recuos/carimbo e prévia editável
- (Opcional widget compartilhado em `c:/sigo/app/lib/src/features/lotes/presentation/` se ajudar a evitar duplicação do editor de prévia em massa e parsing decimal entre as 3 telas)
- `c:/sigo/app/test/src/features/loteamentos/presentation/loteamentos_list_screen_test.dart` -- Widget tests de criação individual e em massa
- `c:/sigo/app/test/src/features/quadras/presentation/quadras_list_screen_test.dart` -- Widget tests de nova quadra e criação com lotes em massa
- `c:/sigo/app/test/obras_lotes_crud_test.dart` e/ou `c:/sigo/app/test/src/features/lotes/presentation/add_lote_screen_test.dart` -- Widget tests de criação individual, cálculo automático de área e criação em massa com exceções

## Tasks & Acceptance

**Execution:**
- [x] Extrair helper/componentes reutilizáveis sem duplicar lógica para parsing decimal (`pt-br` vírgula/ponto), rascunho/prévia de geração de lotes em massa e edição de exceções individuais.
- [x] `c:/sigo/app/lib/src/features/loteamentos/presentation/loteamentos_list_screen.dart` -- Evoluir `_AddLoteamentoDialog` com `ExpansionTile` de localização/carimbo e seção opcional de geração em massa (1 quadra + N lotes com prévia editável -> `createLoteamentoEmMassa` / `createLoteamento`) e subtítulo de localização no `ListTile`.
- [x] `c:/sigo/app/lib/src/features/quadras/presentation/quadras_list_screen.dart` -- Adicionar verificação de permissão admin, ação `'Nova Quadra'` / `'Criar Nova Quadra'`, dialog `_AddQuadraDialog` com `logradouroPadrao` e geração opcional em massa (`createQuadraComLotes` / `createQuadra`), e subtítulo `logradouroPadrao` no `ListTile`.
- [x] `c:/sigo/app/lib/src/features/lotes/presentation/add_lote_screen.dart` -- Preservar UUID fixo em `initState()` e compatibilidade com `obras_lotes_crud_test.dart`; adicionar modo **Individual** (medidas principais + auto-cálculo de área + `ExpansionTile` PDF opcional -> `createLoteComEtapas`) e modo **Em Massa** (gerador por quantidade/prefixo/início/medidas + prévia editável -> `createLotesEmMassa`).
- [x] Adicionar/atualizar widget tests cobrindo criação individual, cálculo automático de área (`frente * profundidade`), ajuste de exceções na prévia e persistência via `createLoteamentoEmMassa`, `createQuadraComLotes`, `createLoteComEtapas` e `createLotesEmMassa`.

**Acceptance Criteria:**
- Given o formulário individual ou gerador em massa, when `frenteM` e `profundidadeM` são preenchidas com valores positivos, then `areaTerrenoM2` é calculada automaticamente podendo ainda ser ajustada manualmente.
- Given uma geração em massa com N lotes, when o usuário altera as medidas de um lote específico na prévia editável antes de salvar, then apenas esse lote recebe as medidas ajustadas no payload enviado ao repositório.
- Given um lote criado manualmente sem preencher os índices/recuos opcionais do PDF, when é gravado, then o documento é salvo sem erros e sem campos geométricos.

## Implementation Notes

- Commits `0657ea1` e `200c11a` implementaram:
  - Helper e componente compartilhado `app/lib/src/features/lotes/presentation/lote_mass_generator_section.dart` (`parseDecimalPtBr`, `formatDecimalPtBr`, `validateOptionalDecimalPtBr`, `DimensionalAreaCoordinator`, `LoteMassDraft`, `LoteMassGeneratorSection` e `_LotePreviewItemEditor`).
  - Evolução de `LoteamentosListScreen` (`_AddLoteamentoDialog`) e `QuadrasListScreen` (`_AddQuadraDialog`) com guarda de permissão admin, subtítulos informativos, `ExpansionTile(maintainState: true)` para campos opcionais e geração em massa via `createLoteamentoEmMassa` / `createQuadraComLotes`.
  - Evolução de `AddLoteScreen` com modos Individual (UUID fixo em `initState()`, cálculo automático de `areaTerrenoM2` com sobrescrita manual, `ExpansionTile` de dados técnicos/PDF) e Em Massa (`createLotesEmMassa`), sem qualquer campo `geometry`.
  - Cobertura de testes de widget em `loteamentos_list_screen_test.dart`, `quadras_list_screen_test.dart` e `add_lote_screen_test.dart`, mantendo compatibilidade com `obras_lotes_crud_test.dart` e `loteamento_quadra_lote_navigation_test.dart`.

## Spec Change Log

## Review Triage Log

- **Revisão Story 2 (`acefc7c..HEAD`) — APROVADO (2026-11-19):**
  - `flutter analyze`: 0 erros e 0 warnings nos arquivos da Story 2 (apenas 2 `info` pré-existentes fora do escopo em `dev_construtoras_list_screen.dart:313` e `:558`).
  - `flutter test` (5 suites): 38/38 testes passaram (`All tests passed!`).
  - Todos os invariantes e critérios de aceite verificados (UUID fixo em `initState()`, `ExpansionTile` para campos opcionais, cálculo automático de `areaTerrenoM2`, parsing pt-br vírgula/ponto, prévia editável de exceções, permissão admin e ausência do campo `geometry`).
  - **Observação não-bloqueante:** em `add_lote_screen.dart:202`, o modo Em Massa gera `uuid.v4()` ao submeter; futuramente pode reutilizar `draft.uid` para idempotência também em retry pós-timeout em massa (opcional, pois a spec exige UUID fixo apenas no fluxo individual).

## Verification

**Commands:**
- `cd c:\sigo\app && flutter analyze` -- expected: 0 erros nos arquivos alterados
- `cd c:\sigo\app && flutter test` -- expected: Todos os testes da feature e testes de navegação/CRUD passando
- `cd c:\sigo && functions-python\venv\Scripts\pytest.exe functions-python/tests` -- expected: 141 passed
