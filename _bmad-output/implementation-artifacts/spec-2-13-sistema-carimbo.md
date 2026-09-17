---
title: 'Story 2.13 — Sistema de Carimbo (Watermark)'
type: 'feature'
created: '2026-09-16'
status: 'done'
baseline_commit: '01372985f017e5fc9373c84dda13f43c3a691946'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
  - '{project-root}/docs/archive/2026-09-15-planejamento-anterior/task.md'
  - '{project-root}/docs/archive/2026-09-15-planejamento-anterior/user_flows.md'
  - '{project-root}/docs/archive/2026-09-15-planejamento-anterior/implementation_plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Em operações no canteiro de obras (como Diário de Obra, Recebimento de Materiais e vistorias técnicas), registros fotográficos capturados no navegador (PWA) precisam servir como prova material auditável para medições contratuais, agentes financeiros (ex.: Caixa Econômica Federal) e auditorias internas. Fotos sem estampagem direta de metadados podem ser contestadas quanto ao momento e local da captura. É indispensável que os pixels da imagem recebam um carimbo visual indelével contendo data/hora, geolocalização (GPS: latitude/longitude) e dados contextuais (obra/responsável), processado 100% no cliente sem dependência de rede e resiliente a falhas de sinal ou negação de permissões de GPS.

**Approach:** Desenvolver um serviço de processamento e carimbo de imagem (`WatermarkService`) e um provedor resiliente de localização (`LocationProvider` / `GeolocationService`) no Flutter:
1. Obtenção de coordenadas geográficas via browser/dispositivo com timeout estrito (ex.: 4 segundos) e tratamento gracioso para permissão negada, ausência de hardware ou sinal degradado.
2. Renderização do carimbo diretamente na imagem através da API de Canvas (`dart:ui.PictureRecorder` e `dart:ui.Canvas`), compondo uma faixa inferior semi-transparente de alto contraste com:
   - Data e hora precisas da captura (`dd/MM/yyyy HH:mm:ss`);
   - Coordenadas geográficas (`Lat: -XX.XXXXX, Long: -YY.YYYYY`) ou aviso legível de contingência (`GPS: Indisponível / Sem Permissão`);
   - Contexto identificador da obra e/ou responsável (`Obra: <id/nome> | Resp: <uid/nome>`).
3. Adaptação tipográfica e espacial dinâmica proporcional às dimensões reais da imagem (retrato ou paisagem, alta ou baixa resolução), garantindo que a tipografia permaneça sempre nítida e proporcional sem estourar as margens nem se tornar ilegível.
4. Integração transparente nas telas de captura fotográfica da aplicação (iniciando pelo Diário de Obra em `add_diario_screen.dart`), substituindo os bytes originais pelos bytes carimbados antes da persistência local no IndexedDB e enfileiramento na `OperationQueue`.
5. Suíte de testes unitários e de widget cobrindo: geração do carimbo com GPS válido, fallback sem GPS/timeout, dimensionamento dinâmico de canvas e persistência correta dos bytes processados.

## Boundaries & Constraints

**Always:**
- O carimbo DEVE ser impresso diretamente nos bytes da imagem (matriz de pixels codificada em JPEG/PNG) antes de qualquer persistência no IndexedDB ou upload ao Firebase Storage. Não é aceitável apenas overlay visual em Flutter/CSS.
- Todo o processamento de imagem e estampagem do carimbo DEVE ocorrer 100% localmente no cliente, garantindo funcionamento ininterrupto em modo offline.
- Quando o usuário negar a permissão de geolocalização ou o sinal de GPS expirar por timeout, a imagem DEVE ser gravada normalmente com data/hora e o texto explícito `GPS: Indisponível`, jamais abortando a operação ou travando a UI.
- A faixa de carimbo DEVE ter contraste garantido (fundo escuro semi-transparente com tipografia branca nítida) e posicionamento inferior não intrusivo.
- O redimensionamento do texto e da barra de carimbo DEVE ser proporcional à resolução da imagem de entrada.

**Never:**
- Nunca depender de endpoints remotos, cloud functions ou bibliotecas externas de backend para aplicar o carimbo na foto.
- Nunca bloquear a interface do usuário indefinidamente enquanto aguarda resposta de GPS (timeout máximo de 4s).
- Nunca corromper ou descartar os bytes da imagem caso ocorra erro inesperado na renderização gráfica (aplicar fallback seguro com preservação da foto original se o canvas falhar).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Captura com GPS autorizado e preciso | Bytes de imagem válidos, coordenadas `lat`, `long` obtidas | Imagem JPEG/PNG com faixa inferior contendo `dd/MM/yyyy HH:mm:ss`, `Lat: -XX.XXXXX, Long: -YY.YYYYY` e contexto da obra | N/A |
| Usuário nega permissão de geolocalização | Permissão negada pelo navegador | Imagem carimbada com data/hora e `GPS: Sem Permissão` | Trata graciosamente sem exibir exceção ao usuário |
| Timeout na leitura do GPS (sinal fraco) | GPS demora mais de 4s para responder | Timeout dispara fallback; carimbo grava data/hora e `GPS: Indisponível` | Cancelamento do timer de espera, mantendo fluidez da captura |
| Dispositivo 100% offline | Sem conexão com a internet | Carimbo aplicado normalmente com relógio local do dispositivo e GPS nativo (se disponível) | Totalmente desacoplado de conectividade |
| Imagem em resolução muito alta (ex: 4000x3000) | Bytes de foto de alta definição da câmera | Faixa e tipografia proporcionais à resolução, mantendo proporção visual sem pixelização | Canvas adapta escala baseada na largura/altura |
| Imagem em orientação retrato vs paisagem | Dimensões verticais ou horizontais | Faixa posicionada na base inferior em ambos os formatos | Cálculo dinâmico do `Rect` inferior |
| Falha no pipeline gráfico do Canvas | Formato de imagem corrompido ou erro de decodificação | Log de erro e fallback retornando os bytes originais da foto | Não impede o salvamento do registro no diário |

</frozen-after-approval>

## Code Map

- `app/lib/src/common/services/watermark_service.dart` -- [NEW] Serviço central de aplicação de carimbo utilizando `dart:ui.PictureRecorder` e `Canvas` (ou biblioteca gráfica compatível), calculando posições relativas, fundo semi-transparente e renderização de múltiplas linhas de metadados auditáveis.
- `app/lib/src/common/services/geolocation_service.dart` -- [NEW] Camada de obtenção de coordenadas geográficas com timeout defensivo, detecção de permissão e abstração para ambiente Web e mobile.
- `app/lib/src/features/diario/presentation/add_diario_screen.dart` -- Integração da rotina de carimbo no momento do `_pickPhoto`, aplicando o carimbo antes de salvar a lista `_selectedPhotos`.
- `app/test/watermark_service_test.dart` -- [NEW] Testes unitários validando a geração do carimbo sobre imagens, formatação de textos (com GPS, sem GPS, timeout), cálculo proporcional de dimensões e resiliência de fallback.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/common/services/geolocation_service.dart` -- Implementar serviço de geolocalização com método `getCurrentPosition({Duration timeout})` retornando coordenadas ou indicação de indisponibilidade/permissão negada.
- [x] `app/lib/src/common/services/watermark_service.dart` -- Implementar `applyWatermark(Uint8List imageBytes, WatermarkMetadata metadata)` via Canvas/`dart:ui`, gravando tarja semi-transparente inferior com data/hora, coordenadas e dados da obra.
- [x] `app/lib/src/features/diario/presentation/add_diario_screen.dart` -- Plugar `WatermarkService` no fluxo de adição de fotos, exibindo indicador sutil de processamento e garantindo fotos carimbadas.
- [x] `app/test/watermark_service_test.dart` -- Desenvolver suíte abrangente de testes cobrindo todos os cenários da matriz de I/O.

**Acceptance Criteria:**
- Given uma foto selecionada pelo usuário no Diário de Obra, when o processamento for concluído, then a imagem adicionada à lista `_selectedPhotos` contém a faixa de carimbo com data, hora e metadados contextuais visíveis diretamente nos bytes.
- Given uma situação em que o navegador não possui permissão de GPS ou o hardware não responde em até 4 segundos, when o carimbo for aplicado, then a imagem é salva com sucesso exibindo o aviso `GPS: Indisponível` ou `GPS: Sem Permissão`.
- Given o aplicativo operando em modo desconectado (offline), when o usuário capturar uma foto, then o carimbo é gerado instantaneamente no cliente e enfileirado na `OperationQueue` com bytes carimbados.
- Given suíte de testes automatizados do Flutter, when executada, then todos os testes passam com 0 erros e o `flutter analyze` reporta 0 apontamentos.

## Implementation Notes

- **app/lib/src/common/services/geolocation_service.dart:** Implementados o modelo `GeoLocationResult` com formatação padronizada e o contrato `GeolocationService`. A classe `DefaultGeolocationService` suporta injeção de delegados de geolocalização para testes e fallback defensivo com timeout de 4s (garantindo que atrasos de GPS jamais travem o fluxo do usuário).
- **app/lib/src/common/services/geolocation_platform.dart (e variantes native / web):** Implementada abstração condicional utilizando `dart:js_interop` no Web e fallback nativo/desktop para testes, integrando-se à função `sigoGetCurrentPosition` em `queue.js`.
- **app/lib/src/common/services/watermark_service.dart:** Implementado serviço de estampa indelével via Canvas nativo do Flutter (`dart:ui.PictureRecorder` e `Canvas`). Renderiza faixa inferior semi-transparente (70% opacidade preta com linha sutil superior em tom ciano SIGO), formatando em tipografia nítida e com cálculo proporcional dinâmico (compatível com orientações retrato, paisagem e altas resoluções). Contém fallback defensivo que preserva os bytes originais da foto em caso de falha de decodificação.
- **app/lib/src/features/diario/presentation/add_diario_screen.dart:** Integrado o serviço de carimbo no momento do `_pickPhoto`, acionando a obtenção assíncrona de GPS e estampando a foto com dados contextuais da obra e do responsável antes da persistência local e do envio.
- **app/test/watermark_service_test.dart:** Criada suíte completa com 10 testes cobrindo todos os cenários da matriz de I/O: leitura e formatação de GPS, permissão negada, timeout defensivo, exceções de hardware, renderização de carimbo sobre PNG real, proporções retrato/paisagem/alta resolução, fallback de bytes inválidos e execução integrada via `stampPhoto`.
- **Verificação:** 10/10 testes da suíte de carimbo passando, 104/104 testes globais do Flutter passando (`flutter test`), 8/8 testes do Cloud Functions passando (`npm test`), 0 issues no `flutter analyze`.

## Spec Change Log

## Review Triage Log

- **blind-hunter / edge-case-hunter / verification-gap:** Todas as 3 lentes revisadas e triadas. Veredito: 0 defeitos reais, 0 regressões e 0 lacunas de verificação. O sistema de carimbo opera 100% no cliente sem dependência de rede, possui fallback gracioso para contingência de GPS (permissão negada, tempo esgotado ou ausência de sinal), preserva a foto intacta em caso de anomalia gráfica, adapta-se dinamicamente a diferentes resoluções e orientações, e conta com cobertura automatizada em testes unitários e de integração no Flutter.

## Verification

**Commands:**
- `cd app && flutter test test/watermark_service_test.dart` -- expected: Suíte do serviço de carimbo e geolocalização passa com código 0.
- `cd app && flutter test` -- expected: Toda a suíte global de testes do Flutter passa com código 0.
- `cd app && flutter analyze` -- expected: 0 erros e 0 warnings.
