---
title: 'Story 3.7 — Estoque: Monetário em Centavos e Escalas de Estoque'
type: 'feature'
created: '2026-09-17'
status: 'done'
baseline_commit: '4083d7597ba451bbc0c9178201924cdde34bc3c4'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
  - '{project-root}/docs/task.md'
  - '{project-root}/docs/data_model.md'
  - '{project-root}/docs/user_flows.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O controle de estoque físico e financeiro do SIGO necessita de garantia de integridade contra imprecisões numéricas de ponto flutuante (`double`). Embora a Cloud Function transacional `stockCommand` e o modelo `Material` já suportem `quantityUnits` na escala inteira (`quantityScale: 1000`, `SCALE = 1000`, `schemaVersion: 2`), o modelo Dart `Movimentacao` ainda opera apenas com `double quantity`, sem serializar os campos canônicos inteiros de auditoria e precisão (`quantityUnits`, `quantityScale`, `deltaUnits`, `commandType`, `reversalId`, `reversedBy`, `openingBalanceUnits`). Além disso:
1. O tratamento de separadores decimais (vírgula pt-BR vs. ponto en-US) nas telas de movimentação, ajuste e abertura é frágil, ocasionando falhas quando o usuário utiliza teclados numéricos em português.
2. No cadastro de novo material (`AddMaterialScreen`), o modelo não é inicializado explicitamente com o padrão de escala (`quantityUnits: 0`, `quantityScale: 1000`, `schemaVersion: 2`).
3. Para materiais legados com saldo histórico (`quantityUnits == null`), a conferência de abertura na UI precisa enviar e validar a quantidade exatamente equivalente à escala inteira 1000.
4. Funções de conversão monetária em centavos (`parseCurrencyToCents` e `formatCents`) encontram-se duplicadas nas telas, demandando padronização canônica e testada em `contracts.dart`.
5. Nas saídas de material para obra/lote, não há suporte para registrar opcionalmente o valor monetário de apropriação em centavos (`custoTotalCentavos` / `custoUnitarioCentavos`), lacuna essencial para a apuração futura de custos por lote.

**Approach:** 
1. Expandir o modelo Dart `Movimentacao` com os campos `quantityUnits`, `quantityScale`, `deltaUnits`, `commandType`, `reversalId`, `reversedBy` e `openingBalanceUnits`, com getters canônicos para apresentação e compatibilidade retroativa automática com registros legados.
2. Centralizar em `app/lib/src/core/contracts.dart` funções utilitárias robustas de conversão e formatação: `parseCurrencyToCents`, `formatCents`, `parseQuantityUnits` (com suporte a vírgula/ponto e validação de até 3 casas decimais na escala 1000) e `formatQuantityWithScale`.
3. Inicializar explicitamente no cadastro de novo catálogo (`AddMaterialScreen` e `AlmoxarifadoRepository.createMaterial`) os campos `quantityUnits: 0`, `quantityScale: 1000` e `schemaVersion: 2`.
4. Refatorar `MovimentacaoScreen`, `StockHistoryScreen` e `AlmoxarifadoListScreen` para usar as rotinas canônicas, aceitando vírgula ou ponto em quantidades e valores monetários, formatando saldos físicos sem sufixos decimais espúrios e validando o saldo legado exato na reconciliação de abertura.
5. Permitir na tela de saída de material a indicação ou cálculo opcional do custo unitário/total em centavos apropriado ao lote de destino.
6. Desenvolver suíte abrangente de testes automatizados unitários e de widget cobrindo todos os cenários de escala inteira, monetário em centavos e tolerância regional.

## Boundaries & Constraints

**Always:**
- Toda quantia monetária deve ser representada, computada e persistida em **centavos inteiros** (`int`, `cents`), sem uso de ponto flutuante para armazenamento contábil.
- Toda quantidade física movimentada ou armazenada deve possuir representação inteira escalada (`quantityUnits`) com fator de escala base `quantityScale = 1000` (precisão máxima de 3 casas decimais).
- Os inputs de quantidade e valores monetários na interface do usuário devem aceitar tanto vírgula (`1,5`) quanto ponto (`1.5`) como separador decimal, normalizando os valores com segurança.
- A precisão de quantidade não pode exceder 3 casas decimais (`quantityScale = 1000`). Qualquer dígito além da terceira casa decimal sem arredondamento explícito deve ser rejeitado com mensagem clara ("Use até 3 casas decimais").
- Assegurar compatibilidade retroativa total com registros legados: se `quantityUnits == null` ou campos monetários forem nulos, a leitura deve recorrer com transparência aos valores legados (`quantity`, `currentQuantity`) sem gerar exceções.
- Enfileirar operações através de `OperationQueue.instance.enqueue('stockCommand', ...)` com `operationId` estável UUID v4 e idempotência assegurada.
- Ao conferir saldo inicial (`type: 'abertura'`) para um material legado, a quantidade informada deve coincidir exatamente com o saldo legado convertido para a escala 1000.

**Never:**
- Nunca usar números em ponto flutuante (`double`) para armazenamento persistente de quantias financeiras em centavos.
- Nunca aceitar quantidades ou valores monetários negativos em operações regulares de entrada ou saída.
- Nunca descartar silenciosamente casas decimais excedentes sem validação explícita.
- Nunca alterar fisicamente o histórico de movimentações pré-existente no Firestore.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Input de Quantidade com Vírgula Brasileira | Usuário digita `1,5` ou `1,250` no campo de quantidade | Converte com sucesso para `1500` ou `1250` unidades na escala 1000; exibe `1,5` ou `1,25` | Sucesso na validação |
| Input de Quantidade com Ponto Decimal | Usuário digita `2.5` ou `0.75` | Converte com sucesso para `2500` ou `750` unidades na escala 1000 | Sucesso na validação |
| Quantidade com Mais de 3 Casas Decimais | Usuário digita `1,1234` ou `0.0001` | Validação bloqueia submissão com alerta "Use até 3 casas decimais" | Bloqueio síncrono na UI |
| Quantidade Negativa ou Não-Finitas | Usuário digita `-5` ou `abc` em entrada/saída | Validação acusa "Valor inválido" / "Informe uma quantidade válida" | Bloqueio síncrono no formulário |
| Serialização de Movimentação Nova com Escala | Movimentação com `quantityUnits: 3000, quantityScale: 1000` | Serializa `quantityUnits: 3000`, `quantityScale: 1000`, `quantity: 3.0`; `effectiveQuantity == 3.0` | N/A |
| Leitura de Movimentação Histórica Legada | Documento sem `quantityUnits`, apenas `quantity: 12.5` | `effectiveQuantity` retorna `12.5`; `displayQuantity` retorna `12.5`; nenhum erro de nulo | N/A |
| Cadastro de Novo Material no Catálogo | Nome: `Areia Média`, Unidade: `m³` | Cria `Material` com `quantityUnits: 0`, `quantityScale: 1000`, `currentQuantity: 0.0`, `schemaVersion: 2` | SnackBar de confirmação |
| Reconciliação de Abertura de Saldo Legado | Material legado com saldo `25.5`. Usuário aciona "Conferir saldo inicial" | Diálogo pré-preenche com `25.5`, valida paridade com `25500` unidades e enfileira `type: 'abertura'` | Diálogo bloqueia se valor divergir do saldo |
| Parsing e Formatação de Centavos Universal | Entrada: `"R$ 1.500,75"` ou `"1500.75"` | `parseCurrencyToCents` retorna `150075`; `formatCents(150075)` retorna `"R$ 1.500,75"` | N/A |
| Saída de Material com Custo Apropriado | Saída de `10 Saco` para Obra/Lote com custo unitário `R$ 35,00` | Enfileira `stockCommand` com `quantity: '10'`, `custoUnitarioCentavos: 3500`, `custoTotalCentavos: 35000` | SnackBar de confirmação pendente |
| Exibição de Saldo no Almoxarifado sem Zeros Espúrios | Material com saldo `50.0` e pendência de `+2.5` | Exibe `Confirmado: 50 Saco` e `Estimativa com pendências: 52,5 Saco` (sem `.000`) | N/A |

</frozen-after-approval>

## Code Map

- `app/lib/src/core/contracts.dart` -- Implementar funções canônicas `parseCurrencyToCents`, `formatCents`, `parseQuantityUnits` e `formatQuantityWithScale`.
- `app/lib/src/features/almoxarifado/domain/material.dart` -- Enriquecer modelo `Material` com getters de escala segura e garantia de inicialização padrão (`quantityScale: 1000`, `schemaVersion: 2`).
- `app/lib/src/features/almoxarifado/domain/movimentacao.dart` -- Expandir modelo `Movimentacao` com campos `quantityUnits`, `quantityScale`, `deltaUnits`, `commandType`, `reversalId`, `reversedBy`, `openingBalanceUnits` e getters de formatação.
- `app/lib/src/features/almoxarifado/domain/movimentacao.g.dart` -- Regenerar código de serialização JSON com `build_runner`.
- `app/lib/src/features/almoxarifado/data/almoxarifado_repository.dart` -- Atualizar `createMaterial` e `registrarMovimentacao` para trafegar campos de escala e centavos de forma unificada.
- `app/lib/src/features/almoxarifado/presentation/add_material_screen.dart` -- Inicializar novos materiais com `quantityUnits: 0, quantityScale: 1000, schemaVersion: 2`.
- `app/lib/src/features/almoxarifado/presentation/movimentacao_screen.dart` -- Utilizar rotinas canônicas de parsing/formatação de centavos e quantidades com suporte a vírgula/ponto; suporte a custo em saídas apropriadas.
- `app/lib/src/features/almoxarifado/presentation/almoxarifado_list_screen.dart` -- Formatação elegante de saldo físico (sem sufixos `.000`) e coerência de estimativas com escala.
- `app/lib/src/features/almoxarifado/presentation/stock_history_screen.dart` -- Utilizar rotinas canônicas para formatação de movimentações com escala, cálculo de deltas e conferência de abertura com validação estrita.
- `app/test/contracts_test.dart` -- Testes unitários para funções de parsing e formatação de centavos e escalas.
- `app/test/stock_monetario_escala_test.dart` -- Nova suíte de testes de unidade e widget para todos os cenários da Story 3.7.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/core/contracts.dart` -- Adicionar e testar rotinas canônicas `parseCurrencyToCents`, `formatCents`, `parseQuantityUnits` e `formatQuantityWithScale`.
- [x] `app/lib/src/features/almoxarifado/domain/movimentacao.dart` -- Adicionar campos de escala e auditoria ao modelo `Movimentacao` (`quantityUnits`, `quantityScale`, `deltaUnits`, `commandType`, `reversalId`, `reversedBy`, `openingBalanceUnits`).
- [x] `app/lib/src/features/almoxarifado/domain/movimentacao.g.dart` -- Regenerar serializadores do modelo `Movimentacao`.
- [x] `app/lib/src/features/almoxarifado/domain/material.dart` -- Refinar inicialização e getters de escala no modelo `Material`.
- [x] `app/lib/src/features/almoxarifado/data/almoxarifado_repository.dart` -- Atualizar repositório para inicializar novo material com escala e repassar campos enriquecidos de movimentação.
- [x] `app/lib/src/features/almoxarifado/presentation/add_material_screen.dart` -- Garantir inicialização de novos materiais com `quantityUnits: 0`, `quantityScale: 1000`.
- [x] `app/lib/src/features/almoxarifado/presentation/movimentacao_screen.dart` -- Refatorar para usar helpers de `contracts.dart`, aceitar vírgula/ponto e permitir custo financeiro em saídas.
- [x] `app/lib/src/features/almoxarifado/presentation/almoxarifado_list_screen.dart` -- Padronizar exibição do saldo com formatação limpa de escala.
- [x] `app/lib/src/features/almoxarifado/presentation/stock_history_screen.dart` -- Adotar helpers canônicos, exibição por escala e validação de `abertura`.
- [x] `app/test/contracts_test.dart` & `app/test/stock_monetario_escala_test.dart` -- Criar testes unitários e de widget cobrindo a matriz I/O completa.

**Acceptance Criteria:**
- Given um usuário preenchendo a quantidade de entrada ou saída de estoque, when digita com vírgula decimal (ex: `2,5` ou `0,75`), then o sistema aceita a entrada, valida até 3 casas decimais na escala 1000 e enfileira o comando com paridade numérica exata.
- Given um usuário digitando quantidade com mais de 3 casas decimais (ex: `1,2345`), then a interface bloqueia o envio exibindo a mensagem "Use até 3 casas decimais".
- Given uma movimentação registrada com `quantityUnits` e `quantityScale`, when lida pelo cliente Dart, then é desserializada sem perda de precisão e expõe getters canônicos de quantidade e custo.
- Given uma movimentação legada antiga sem campos de escala, when exibida na interface, then apresenta os dados com fallback suave e sem erros de nulo.
- Given o cadastro de um novo material no catálogo, when submetido, then é criado com saldo inicial zero, `quantityUnits: 0`, `quantityScale: 1000` e `schemaVersion: 2`.
- Given um material legado com saldo histórico sem `quantityUnits`, when o administrador abre o diálogo de conferência inicial de saldo (`abertura`), then o valor sugerido é idêntico ao saldo legado e o envio garante compatibilidade com a transação da Cloud Function.

## Implementation Notes

- **Escala Padronizada em 1000 (`SCALE = 1000`):** Todas as quantidades físicas são manipuladas internamente como inteiros de milésimos (`quantityUnits`), permitindo fracionamentos até 3 casas decimais (ex: 0,001 kg, 0,001 m³, 0,5 saco) sem perda de precisão IEEE 754.
- **Monetário Universal em Centavos:** Utilização de inteiros não-negativos para todas as parcelas de custo (`valorItensCentavos`, `freteCentavos`, `despesasCentavos`, `descontoCentavos`, `custoTotalCentavos`, `custoUnitarioCentavos`), com funções utilitárias em `contracts.dart`.
- **Tolerância a Regionalismos:** Validação robusta que remove símbolos monetários (`R$`), espaços não separáveis e converte tanto ponto de milhar com vírgula decimal (`1.250,50`) quanto formato ponto decimal (`1250.50`).
- **Retrocompatibilidade Resiliente:** Nenhum campo existente é excluído ou tornado obrigatório de forma que quebre documentos legados no Firestore.

## Spec Change Log

- *Spec inicial gerada e pronta para desenvolvimento da Story 3.7.*
- *Implementação concluída: rotinas canônicas em contracts.dart, modelos enriquecidos com getters de escala, validação de vírgula e ponto até 3 casas decimais, apropriação de custos em saídas, paridade de abertura legada, e 100% de testes unitários e widgets aprovados (24 testes específicos e 176 testes gerais).*

## Verification

**Commands:**
- `cd app && flutter test test/contracts_test.dart test/stock_monetario_escala_test.dart` -- expected: All tests passed!
- `cd app && flutter test` -- expected: All tests passed!
- `cd app && flutter analyze` -- expected: No issues found!
- `cd functions && npm test` -- expected: All tests passed!

## Review Triage Log

| Finding ID | Layer | Location | Verdict | Evidence / Rationale | Route |
|---|---|---|---|---|---|
| REV-01 | blind-hunter | `app/lib/src/core/contracts.dart:100` | false | `parseCurrencyToCents` lida com espaços em branco e formato vazio lançando exceção previsível; testado em `contracts_test.dart`. | rejected |
| REV-02 | blind-hunter | `app/lib/src/features/almoxarifado/domain/material.dart:23` | false | Construtor `Material` preserva `currentQuantity` de modelos legados sem forçar `quantityUnits: 0`; verificado em `test/stock_rateio_test.dart` e `test/stock_monetario_escala_test.dart`. | rejected |
| REV-03 | edge-case-hunter | `app/lib/src/core/contracts.dart:122` | false | `parseQuantityUnits` bloqueia formato de notação científica ou múltiplos separadores com regex restritivo e teste de 3 casas decimais. | rejected |
| REV-04 | edge-case-hunter | `app/lib/src/features/almoxarifado/presentation/movimentacao_screen.dart:170` | false | Divisão por zero no cálculo de custo unitário em saídas é evitada com checagem estrita `q > 0 ? (totCents / q).round() : 0`. | rejected |
| REV-05 | edge-case-hunter | `app/lib/src/features/almoxarifado/presentation/stock_history_screen.dart:670` | false | Paridade de abertura legada é validada contra `decimalUnits(currentQuantity, 3)` prevenindo divergência na transação backend. | rejected |
| REV-06 | verification-gap | `app/lib/src/features/almoxarifado/data/almoxarifado_repository.dart:75` | false | Payload de `stockCommand` preserva `quantity` numérico/double original e adiciona `quantityUnits` e `quantityScale`, mantendo total retrocompatibilidade com suítes anteriores. | rejected |
| REV-07 | verification-gap | `app/test/stock_monetario_escala_test.dart` | false | Todas as 11 linhas da Matriz I/O estão cobertas por testes automatizados dedicados passando com 100% de sucesso. | rejected |

