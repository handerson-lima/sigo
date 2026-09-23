# Reconhecimento da UI — primeira entrega

Data: 2026-09-23. Investigação do código somente leitura; este extrato não constitui decisão arquitetural nem implementação. Modo fast confirmado ao coordenador.

## Base e contratos herdados

- Flutter 3.47.2 / Dart 3.13.2: SDK local identificado pelo coordenador em `/Users/usuario/flutter/bin/cache/flutter.version.json`; não foi executado Flutter nesta investigação.
- `app/lib/main.dart:44–58`: `MaterialApp.router`, Riverpod e Material 3; tema atual apenas `ColorScheme.fromSeed(Colors.blue)`.
- `_bmad-output/planning-artifacts/ux-designs/ux-obras-2026-09-23/primeira-entrega/HANDOFF.md`: critérios UX01–UX11; `DESIGN.md` e `EXPERIENCE.md`: tokens, S0–S5, J0–J5, escopo e comportamento. Preservar URLs, contexto, permissões e gravações sequenciais dos lotes.
- `app/lib/src/common_widgets/sigo_layout.dart:23–25`: desktop >800, drawer ≤800; `sigo_sidebar.dart:137–145`: largura 250/72. Valores herdados explicitamente pela UX.
- `app/lib/src/common_widgets/sigo_top_bar.dart:62–74` e `sigo_sidebar.dart:25–32`: contexto extraído da URL. `sigo_top_bar.dart:255–258`: troca de obra navega ao dashboard da obra escolhida.
- `app/lib/src/common_widgets/sigo_sidebar.dart:34–135`: providers, vínculo ativo e módulos controlam visibilidade. `app/lib/src/features/lotes/routing/lotes_routes.dart`: lista com AccessGuard de lotes; Novo Lote acrescenta adminOnly.

## Divergência do routing

Fonte: `_bmad-output/planning-artifacts/architecture/architecture-modular-routing-2026-09-23/ARCHITECTURE-SPINE.md` e `.memlog.md`, ambos finalizados.

- AD-1/AD-2/AD-5 prescrevem módulos isolados e composição plana central. O código em `app/lib/src/features/construtoras/routing/construtora_routes.dart` importa outros módulos e os compõe como filhos; `LotesPaths.list` é relativo (`obra/:oId/lotes`).
- AD-4 exige constantes em toda navegação; shell e listas ainda usam strings literais.
- AD-3, redirect central com guard no builder, e AD-6, preservação de extra, são compatíveis com a intenção UX.
- Decisão pendente: explicitar herança sem assumir que documento e código coincidem. Não corrigir incidentalmente routing durante a migração visual.

## Fronteiras candidatas para discussão

Tokens/tema e componentes visuais puros podem receber conteúdo, callbacks e estado; wrappers nas features continuam observando Riverpod, navegando e chamando repositórios. Componentes puros não devem importar routing, autorização ou persistência.

Candidatos puros: superfície, ações, feedback, badge e anatomia de cards. Wrappers de feature: editor de logo, formulários/edição de lote, providers e navegação. Sidebar/top bar atuais são integrados a providers, mesmo estando em common_widgets.

Alternativas: ThemeData/subtemas para Material com ThemeExtension para tokens semânticos específicos, ou constantes tipadas complementares. Não mapear automaticamente dourado para secondary sem avaliar impacto nos controles herdados. Nenhuma alternativa foi adotada por este extrato.

## Reflow e estilos locais

- `sigo_layout.dart:43–45,69–71`: inset desktop24/mobile16. `construtoras_list_screen.dart:54–55` e `add_lote_screen.dart:65–66` adicionam padding interno: definir proprietário único do inset no recorte.
- `app/lib/src/features/construtoras/presentation/construtoras_list_screen.dart:54–82`: proporção fixa3/2, extensão máxima300, nome truncado e Spacer. Não atende crescimento por texto.
- `app/lib/src/features/lotes/presentation/lotes_list_screen.dart:36–40,60–76,119`: grid quadrado, fundo inteiro por status e enum exposto. Contrato pede badge, card claro e ações independentes.
- `sigo_top_bar.dart:24,117–185`: altura60, título de uma linha e controles horizontais. `:210–230`: seletor de obra com altura36/fonte12. Requer reflow e alvo48, não apenas recoloração.
- Sidebar usa âmbar/brancos locais; top bar usa preto/branco/âmbar. Gradiente escuro demanda avaliar também notificações, sincronização e seletor de obra.
- Grid fixo não acomoda altura arbitrária. Alternativas a avaliar conforme volume: linhas responsivas/Wrap ou virtualização por linhas. Não há evidência suficiente para introduzir biblioteca de layout.

## Gaps funcionais que afetam UX

- `lotes_list_screen.dart:149–182`: fase e status gravados sequencialmente; erro genérico perde resultado por etapa. `app/lib/src/features/lotes/data/lote_repository.dart:45–69`: métodos Future<void> separados, sem atomicidade.
- `lote_repository.dart:29–42`: leitura entrega List<Lote> através de cache, sem metadados de frescor. Cache não comprova confirmação remota.
- `lotes_list_screen.dart:188–237`: sheet sem scroll, fechamento habilitado durante envio e fase assumida dentro de defaultLotePhases.
- `add_lote_screen.dart:32–47`: novo UUID por submissão; retry após resultado incerto não pode ser habilitado apenas porque finally terminou.
- `app/lib/src/features/construtoras/presentation/user_construtoras_provider.dart:9–19`: FutureProvider.autoDispose de catálogo, dependente de auth/trustedDev; confirmar estratégia de atualização do card após publicação da logo.

## Sequência candidata e evidência de aceite

Para discussão: tokens/subtemas → shell com reflow/contraste → cards/listas → formulários/resultados de escrita → integração de logo. Antes de ativar tema global, verificar telas herdadas com estilos locais: TextTheme, bordas e mínimos interativos alteram layout fora do recorte.

Aceite da UX inclui larguras320/390/800/801/1280/1440, escala100/130/200%, textos longos, teclado, destinos/guards e gravação parcial. Não foram executados testes nem declarada conformidade de interface; não há necessidade evidenciada de upgrade de stack.
