---
title: 'Story 2.12 — Indicador de Sincronização'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_commit: '4e100292c3ad81ea45cc4f51a6a60b70c88b5c30'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
  - '{project-root}/docs/archive/2026-09-15-planejamento-anterior/task.md'
  - '{project-root}/docs/archive/2026-09-15-planejamento-anterior/user_flows.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Em uma aplicação PWA offline-first, os usuários no canteiro de obras não possuem visibilidade clara sobre o estado da conexão e da sincronização dos dados locais com o Firebase, gerando insegurança sobre se os registros (como diários de obra e movimentações) foram transmitidos com sucesso ou estão salvos com segurança aguardando sinal.

**Approach:** Desenvolver o componente reativo `SyncIndicator` integrado ao `SigoTopBar` em todas as telas da aplicação, conectado aos fluxos em tempo real do `SyncEngine` e do `OperationQueue`:
1. Exibir de maneira clara e determinística os quatro estados essenciais:
   - **Online (Sincronizado):** Conexão ativa e fila local sem pendências (`SyncEngineStatus.idle`, 0 itens pendentes).
   - **Sincronizando:** Transmissão de dados em andamento (`SyncEngineStatus.syncing` ou itens em transmissão), com ícone animado e rótulo indicativo.
   - **Offline / Offline pendente:** Sem conexão de rede (`SyncEngineStatus.offline`), exibindo badge com contagem de alterações salvas localmente aguardando conexão.
   - **Falha / Atenção:** Ocorrência de erros de rede, conflito ou autorização rejeitada (`SyncEngineStatus.error` ou itens com `failed`/`conflict`/`authorization_rejected`), destacando a necessidade de revisão.
2. Permitir interação por clique no indicador, apresentando um diálogo informativo ou navegação contextual para a tela de fila de sincronização (`SyncQueueScreen`), com opção de forçar nova sincronização manual (`syncNow()`).
3. Validar todos os comportamentos por testes unitários e de widget no Flutter cobrindo transições de estado, badges de contagem e ação de disparo manual.

## Boundaries & Constraints

**Always:**
- O indicador DEVE refletir em tempo real qualquer alteração no `SyncEngineStatus` e na quantidade de operações locais da `OperationQueue`.
- Quando offline com dados locais enfileirados, DEVE destacar que os dados estão preservados no dispositivo com a contagem de itens pendentes.
- Falhas de autorização (`authorization_rejected`) e conflitos DEVEM ser destacados como estado de atenção/alerta visual para ação do usuário.
- O clique no indicador deve ser acessível e responsivo tanto em desktop quanto em dispositivos móveis.

**Never:**
- Nunca exibir falso estado de erro quando o dispositivo estiver meramente offline e os dados estiverem guardados com segurança no IndexedDB/fila local.
- Nunca bloquear a navegação ou o uso normal das telas enquanto a sincronização ocorre em segundo plano.
- Nunca disparar múltiplos loops simultâneos de sincronização ao acionar o botão manual de sync.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Dispositivo online e fila zerada | `SyncEngine.isOnline == true`, `status == idle`, 0 pendentes | Ícone verde/cinza sutil (nuvem com check) com rótulo "Online" ou "Sincronizado" | N/A |
| Sincronização em andamento | `SyncEngine.status == syncing` | Ícone giratório ou azul pulsante com texto "Sincronizando..." | N/A |
| Desconexão com dados pendentes | `SyncEngine.isOnline == false`, N operações com state `pending` | Ícone de nuvem offline âmbar com badge `N` e texto "Offline (N pendentes)" | Alerta amigável informando que dados estão salvos localmente |
| Erro de rede ou comando com falha | Fila contém itens `failed` ou `lastError != null` | Ícone vermelho/laranja de alerta com texto "Falha no envio"; diálogo detalha o erro | Botão "Tentar novamente" aciona `syncNow()` |
| Operação rejeitada por autorização | Fila contém operação com state `authorization_rejected` | Alerta visual de revisão necessária; diálogo instrui contato com administração | Encaminha para tela da fila para auditoria |
| Clique do usuário no indicador | Toque/clique sobre o `SyncIndicator` | Abre modal com resumo de conectividade, pendências e botão "Sincronizar agora" | Trata exceções sem quebrar a árvore de widgets |

</frozen-after-approval>

## Code Map

- `app/lib/src/sync/sync_indicator.dart` -- [NEW] Widget reativo `SyncIndicator` que consome `syncEngineProvider` e `OperationQueue.watch()`, exibindo ícone, badge e abrindo diálogo de detalhes da sincronização.
- `app/lib/src/common_widgets/sigo_top_bar.dart` -- Inclusão do `SyncIndicator` na barra de navegação superior, antes das notificações e do avatar.
- `app/lib/src/sync/sync_engine.dart` -- Exposição de helpers/providers adicionais de contagem e agregação caso facilitem o binding de UI.
- `app/test/sync_indicator_test.dart` -- [NEW] Suíte de testes de widget validando renderização dos 4 estados, contadores de itens pendentes e clique para sincronizar.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/sync/sync_indicator.dart` -- Criar componente `SyncIndicator` e modal de status com resumo e ação de sincronização manual.
- [x] `app/lib/src/common_widgets/sigo_top_bar.dart` -- Integrar `SyncIndicator` nas ações do `SigoTopBar`, garantindo responsividade mobile/desktop.
- [x] `app/lib/src/sync/sync_engine.dart` -- Assegurar emissão reativa e determinística para os widgets consumidores.
- [x] `app/test/sync_indicator_test.dart` -- Criar testes cobrindo estados Online, Sincronizando, Offline pendente, Falha e interação de sincronização manual.

**Acceptance Criteria:**
- Given o dispositivo conectado à internet e sem operações pendentes, when a aplicação carregar, then o `SyncIndicator` exibe o estado "Online" com ícone de nuvem sincronizada.
- Given o usuário desconectado da rede e com 2 operações locais enfileiradas, when visualizar a barra superior, then o indicador mostra estado offline com contador de 2 pendências e aviso de dados preservados.
- Given uma sincronização em execução (`syncing`), when o usuário estiver em qualquer tela com `SigoTopBar`, then o indicador exibe visual de sincronização em andamento.
- Given o usuário clicar no indicador de sincronização, when o diálogo for aberto, then são exibidos detalhes do status e a opção de acionar "Sincronizar agora".

## Implementation Notes

- **app/lib/src/sync/sync_indicator.dart:** Criado o modelo `SyncSummary` e o provider `syncSummaryProvider` agregando reativamente o estado do `SyncEngine` (`isOnline`, `status`, `lastError`) e a fila do `OperationQueue.instance.watch()`. Desenvolvido o widget `SyncIndicator` com apresentação contextual para os 4 estados principais: `Sincronizado` (nuvem com check em tom teal), `Sincronizando...` (ícone de sync com animação de rotação contínua e badge de itens em trânsito), `Offline` (nuvem offline com badge âmbar indicando contagem de alterações salvas localmente) e `Falha`/`Atenção` (destaque visual com contagem de erros ou conflitos/autorizações rejeitadas). Implementado o diálogo `showSyncStatusDialog` com detalhes da conexão, contadores e acionamento de sincronização manual (`syncNow`).
- **app/lib/src/common_widgets/sigo_top_bar.dart:** Integrado o `SyncIndicator` nas `actions` da barra superior em todas as telas, tornando a visualização de conectividade e sincronização universal no shell da aplicação. Implementados helpers de navegação resilientes (`_canPop` e `_pop`) com fallback seguro para contextos sem roteador ativo.
- **app/test/sync_indicator_test.dart:** Criada suíte completa de 8 testes de widget e unidade validando todos os cenários da matriz de I/O: renderização de Sincronizado, Sincronizando (com RotationTransition), Offline com pendências, Offline puro, Falha no envio, Atenção em conflito/autorização rejeitada, abertura do modal com disparo de sincronização manual e integração no `SigoTopBar`.
- **Verificação:** 8/8 testes da suíte de `sync_indicator_test.dart` passando, 94/94 testes globais do Flutter passando (`flutter test`), 0 issues no `flutter analyze`.

## Spec Change Log

## Review Triage Log

- **blind-hunter / edge-case-hunter / verification-gap:** Todas as 3 lentes revisadas e triadas. Veredito: 0 defeitos reais, 0 regressões e 0 lacunas de verificação. O componente SyncIndicator agrega de forma determinística os estados de SyncEngine e OperationQueue, provê feedback visual contextual (Sincronizado, Sincronizando, Offline com contagem de pendências preservadas, Falha e Atenção), possui diálogo de detalhes com disparo de sincronização manual, integra-se de forma resiliente ao SigoTopBar com fallbacks de navegação, e conta com 8 testes automatizados no Flutter cobrindo toda a matriz de I/O.

## Verification

**Commands:**
- `cd app && flutter test test/sync_indicator_test.dart` -- expected: Testes do componente de indicador de sincronização passam com código 0.
- `cd app && flutter test` -- expected: Toda a suíte de testes do Flutter passa com código 0.
- `cd app && flutter analyze` -- expected: 0 erros e 0 warnings.
