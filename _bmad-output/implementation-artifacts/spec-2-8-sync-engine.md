---
title: 'Story 2.8 — Sync Engine'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_commit: '88f69842f5ba0ee4ef027bdc0f1f7352d9884652'
route: 'dispatch'
review_loop_iteration: 1
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
  - '{project-root}/docs/task.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Embora a fila de operações (`OperationQueue`) e o IndexedDB estejam estruturados, a sincronização não pode depender apenas de um timer cego e periódico ou de chamadas manuais pontuais. Em condições reais de campo (canteiros de obras com conectividade intermitente ou alternância rápida de rede móvel/Wi-Fi):
1. O aplicativo precisa sincronizar imediatamente assim que a conectividade for restabelecida, sem aguardar intervalos passivos de timer.
2. Quando em modo comprovadamente offline, o motor não deve realizar tentativas inúteis de requisição de rede que desperdiçam bateria, geram ruído de erro ou bloqueiam recursos locais.
3. Ao alternar de abas ou quando o app volta ao primeiro plano (`AppLifecycleState.resumed`), deve haver verificação ativa e imediata de sincronização pendente.
4. O estado atual da sincronização (`idle`, `syncing`, `offline`, `paused`, `error`) precisa ser publicado de forma reativa e determinística para abastecer os componentes visuais e o indicador de sincronização.

**Approach:** Construir o `SyncEngine` (`app/lib/src/sync/sync_engine.dart`):
1. Monitorar conectividade por meio de stream de conectividade (`connectivity_plus`) com detecção imediata de transições offline -> online.
2. Monitorar ciclo de vida da aplicação (`WidgetsBindingObserver` / `AppLifecycleListener`) para sincronização reativa ao retornar ao app.
3. Gerenciar estados do motor de sincronização via enum/classe reativa `SyncEngineStatus`: `idle`, `syncing`, `offline`, `paused`, `error`.
4. Implementar controle de pausa (`pause`), retomada (`resume`) e encerramento seguro (`dispose`), desacoplando o ciclo de vida do motor das instâncias globais.
5. Suportar injeção de dependência de conectividade e timer para testes unitários 100% determinísticos e herméticos sem dependência de hardware real.
6. Integrar provedores Riverpod (`syncEngineProvider`, `syncStatusProvider`) para consumo limpo em toda a arquitetura Flutter.

## Boundaries & Constraints

**Always:**
- O `SyncEngine` deve reagir instantaneamente a eventos de restauração de rede (`ConnectivityResult` != `none`), disparando `sync()` na fila.
- Se o dispositivo estiver offline (`ConnectivityResult.none`), o motor deve reportar `SyncEngineStatus.offline` e não deve disparar `execute` ou `upload` de rede na fila de operações.
- O motor deve monitorar e reportar seu status em tempo real via `ValueListenable` e `Stream` para que a interface reflita o estado sem polling.
- Quando o usuário encerra sessão (`logout`) ou desativa o serviço, `pause()` ou `dispose()` deve cancelar todas as inscrições ativas e timers.
- Testes unitários devem validar os fluxos de reconexão, transição de estado, ciclo de vida e pausa com mocks herméticos.

**Never:**
- Nunca disparar requisições em lote quando a conectividade estiver confirmada como offline.
- Nunca deixar streams de conectividade ou timers órfãos em vazamento de memória após o encerramento do `SyncEngine`.
- Nunca sobrescrever ou mascarar operações marcadas como `authorization_rejected` ou `conflict`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Restauração de rede | Conectividade muda de `none` para `wifi`/`mobile` | `SyncEngine` detecta mudança e dispara `queue.sync()` imediatamente | Captura e registra último erro sem crash |
| Dispositivo offline | Conectividade reporta `none` | Status transiciona para `SyncEngineStatus.offline`; timers ignoram ticks de rede | Preserva estado local intacto |
| Retorno de plano de fundo | Evento de ciclo de vida `AppLifecycleState.resumed` | Se online, engatilha sincronização imediata | Ignora se offline |
| Sincronização em andamento | Operação de sync ativa | Status transiciona para `SyncEngineStatus.syncing` até conclusão | Evita sincronizações concorrentes sobrepostas |
| Pausa e descarte | Chamada de `pause()` ou `dispose()` | Timers e streams cancelados; status transiciona para `paused` | Liberação segura de recursos |

</frozen-after-approval>

## Code Map

- `app/lib/src/sync/sync_engine.dart` -- Implementação central do `SyncEngine`, monitor de conectividade, ciclo de vida, status reativo e provedores Riverpod.
- `app/lib/src/sync/operation_queue.dart` -- Integração com o `SyncEngine` e suporte a trigger externo de sync e verificação de prontidão.
- `app/test/sync_engine_test.dart` -- Suite completa de testes unitários herméticos testando transições de conectividade, ciclo de vida, retentativas e publicação de status.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/sync/sync_engine.dart` -- Criar classe `SyncEngine`, enum `SyncEngineStatus`, integração com conectividade e ciclo de vida, e provedores Riverpod.
- [x] `app/lib/src/sync/operation_queue.dart` -- Ajustar ou alinhar métodos de controle de sincronização para consumo harmonioso pelo `SyncEngine`.
- [x] `app/test/sync_engine_test.dart` -- Implementar testes unitários cobrindo reconexão imediata, transições de status, modo offline e descarte limpo.

**Acceptance Criteria:**
- Given o dispositivo com operações pendentes e estado offline, when a conectividade for restabelecida, then o `SyncEngine` aciona a sincronização imediatamente.
- Given o dispositivo sem conectividade, when o timer periódico disparar, then o motor não realiza tentativas de rede e permanece em `SyncEngineStatus.offline`.
- Given o retorno da aplicação ao primeiro plano (`resumed`), when online, then um ciclo de sincronização é executado.
- Given o encerramento ou descarte do `SyncEngine`, then todos os timers e listeners são limpos sem vazamento de recursos.

## Implementation Notes

- **sync_engine.dart:** Criada a engine reativa com escuta contínua de conectividade (`connectivity_plus`), ciclo de vida (`WidgetsBindingObserver`), status reativo (`SyncEngineStatus`), controle explícito de `pause()`, `resume()`, `syncNow()` e descarte seguro (`dispose()`).
- **operation_queue.dart:** Exposto `isBusy` para observabilidade da fila de operações.
- **sync_engine_test.dart:** Criados 8 testes unitários cobrindo inicialização, reconexão imediata, supressão de chamadas quando offline, retomada ao voltar de plano de fundo (`resumed`), pausa/retomada e provedores Riverpod.
- **Verificação:** 69/69 testes Dart passando (`flutter test`), 0 issues no `flutter analyze`, e 5/5 testes Chromium Playwright passando no navegador.

## Spec Change Log

- 2026-09-16: Criação, aprovação e conclusão da implementação da Story 2.8.

## Review Triage Log

- Nenhum issue impeditivo ou regressão identificada durante a revisão e execução das baterias de testes.
