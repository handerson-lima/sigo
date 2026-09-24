# Addendum — SIGO Obras

Material de profundidade que **não** pertence ao `prd.md`: decisões técnicas, mecanismos, caminhos de dados, funções, migrações e racional de alternativas. Destinado a Arquitetura, Solution Design e implementação. Preservado a partir de `docs/`, specs e spines de arquitetura.

## 1. Stack e plataforma

- Flutter/Dart com **Riverpod** (estado) e **GoRouter** (rotas); organização por feature.
- **Firebase**: Auth, Firestore, Storage e Cloud Functions. Sem Cloud Run nesta fase (`docs/implementation_plan.md` §3).
- **Web/PWA mobile-first** é o alvo; pastas Android/iOS são preservadas, sem promessa de suporte nativo validado.
- Roteador modular: cada feature exporta sua `List<RouteBase>`; `app_router.dart` compõe por `spread`. Ordem: auth → dev → construtora → loteamento → quadra → lote → setor → equipe → features (`architecture-modular-routing-2026-09-23/ARCHITECTURE-SPINE.md`).
- Regra de shell: **≤800 unidades → drawer; >800 → sidebar** (`primeira-entrega/DESIGN.md`).

## 2. Decisões arquiteturais vigentes

- **AD-1** — Toda escrita em `construtora_members` e `obras/{oId}/members` passa por Functions (`setMembership`/`setConstrutoraRole`); Rules bloqueiam escrita direta (server-authoritative).
- **AD-2** — Admin e owner atribuem; com `obraId` o ator exige `obraAdmin`; sem `obraId` exige `admin(c)`.
- **AD-3** — Papel de obra não inclui `owner` (apenas Operário/Admin da obra).
- **AD-4** — Módulos canônicos + fail-closed; obra aceita `diario|lotes|estoque`; construtora aceita `estoque`; `[]` = sem acesso.
- **AD-5** — Filtro "Por obra" agrega no cliente (sem `collectionGroup`).
- **AD-6** — Sem fila offline para vínculo: leitura com cache, escrita exige rede.
- **AD-7** — Desativação sem cascata transacional; revogação imediata via gate `active(cm)`; documentos órfãos não concedem acesso.
- **AD-8** — Só Dev cria/alterar `owner`.
- **AD-9** — Vínculo ativo na construtora é pré-requisito para vínculo em obra.
- **Drill-down (Épico 11)** — hierarquia aninhada Firestore + rotas profundas; ACL por nó.

## 3. Modelo de dados (Firestore)

Caminhos observados/implantados:

```
users/{uid}
construtoras/{cId}
construtoras/{cId}/construtora_members/{uid}
construtoras/{cId}/hierarquia_members/{uid}          # nodeType, nodeId, role, modules, isActive
construtoras/{cId}/obras/{oId}
construtoras/{cId}/obras/{oId}/members/{uid}
construtoras/{cId}/obras/{oId}/diarios/{diarioId}
construtoras/{cId}/obras/{oId}/chamadas/{chamadaId}
construtoras/{cId}/materiais/{materialId}
construtoras/{cId}/materiais/{materialId}/movimentacoes/{movId}
construtoras/{cId}/despesas/{despesaId}
construtoras/{cId}/fornecedores/{fornecedorId}
construtoras/{cId}/funcionarios/{funcionarioId}
construtoras/{cId}/equipes/{equipeId}
construtoras/{cId}/operations/{operationKey}          # idempotência
construtoras/{cId}/loteamentos/{lId}/quadras/{qId}/lotes/{loId}/setores/{sId}/equipes/{eId}
audit/*
dev_roles/{uid}
access_requests/{requestId}
```

Detalhes:
- `members`/`construtora_members`: `isOwner`, `isAdmin`, `isActive`, `role`, `modules`, `joinedAt`.
- `materiais`: `currentQuantity` (double legado) → proposta `quantityUnits`/`quantityScale` e `confirmedQuantityUnits`.
- `despesas`: `valor` (double legado) → `valorEmCentavos` int + `schemaVersion`; `dataPagamento` com formatos mistos (ISO vs `serverTimestamp()`).
- `diarios`: `photoUrls` → manifesto de anexos com ID estável, tipo, tamanho, integridade; `localPhotoPaths` é estado de dispositivo, não do doc compartilhado.
- Formato de datas heterogêneo no banco; não tratar como schema homogêneo.

## 4. Cloud Functions e contratos

- `setMembership` — atribui/altera/desativa vínculo (construtora ou obra/nó), valida escopo e papel; nunca aceita `owner` com obra.
- `setConstrutoraRole` — troca cargo na construtora; `owner` só via autoridade de Dev.
- `adminCreateUser` — criação administrativa de usuário.
- `approveAccessRequest` — aprova solicitação, cria Auth + vínculo; idempotente; auditoria.
- `stockCommand` — comando transacional de estoque: `operationId`, ator, escopo, hash do payload, resultado; saldo + histórico + recibo na mesma transação.
- Auditoria em `/audit`: ator, alvo, ação, escopo, instante, resultado; imutável ao cliente.
- Erros de Function mapeados para pt-br: `permission-denied`, `failed-precondition`, `Papel inválido`, `unavailable`.

## 5. Offline e fila (C5)

- `OperationQueue` em IndexedDB, schema versionado; chave `[uid, construtoraId, obraId, action, operationId]`.
- Estados: `pending`, `syncing`, `synced`, `failed`, `conflict`, `authorization_rejected`.
- Lease TTL ~120s para multi-aba; backoff exponencial; aborto em troca de sessão.
- Anexos validados por SHA-256; persistir operação+anexos antes de confirmar salvamento local.
- Service Worker cacheia apenas shell atômico (`sigo-shell-<hash>`), navegação `mode === 'navigate'` servida por `index.html` offline; nunca intercepta dados de negócio.
- `authorization_rejected` suspende retries; rejeições auditadas.

## 6. Precisão financeira e integridade

- Valores monetários sempre `int` centavos; proibido `double` nos contratos novos.
- `schemaVersion` por documento; leitor prioriza campo novo sem dupla contagem.
- Instantes = Timestamp; vencimento = data civil preservando o dia (sem drift de fuso).
- Idempotência: `operationId`/`paymentKey`/`idempotencyKey`; payload divergente rejeitado.
- `allow delete: if false;` em funcionários, equipes, chamadas, obras, lotes, movimentações, despesas liquidadas.
- Correção via estorno/ajuste auditado com motivo; histórico confirmado preservado.

## 7. Migração e implantação (C0–C6)

Sequência: **C0 → C1 → C2 → C3 → C4 → C5 → C6** (C3 pode seguir C0; C2/C4 dependem de C1; C5 depende de C1/C2/C4).

1. C0 — inventário, emuladores, testes úteis, versionamento.
2. C1 — autorização com Dev global preservado; fallback de e-mail → UID.
3. C2 — isolamento de Storage por escopo/módulo; referências privadas; invalidação de tokens legados.
4. C3 — datas e precisão financeira (centavos).
5. C4 — estoque central confiável (comando transacional).
6. C5 — diário, anexos e PWA offline.
7. C6 — aceite, regressão e preparação de implantação.

Status observado (2026-09-15 a 2026-09-24): C0–C6 **implementados e validados em desenvolvimento** (`docs/validacao-c0-c6.md`, ACEITO); **produção não autorizada**. Pendências de evidência: identidade dos devs legítimos, regras de produção publicadas, volume de dados legados.

## 8. Racional de alternativas

- **Estoque por obra** — rejeitado; preservado o estoque central por construtora para evitar migração estrutural (D2).
- **Proibição de bypass global de Dev** — revertida; Dev global mantido com concessão protegida (D1).
- **Cloud Run / nova plataforma** — rejeitado nesta fase.
- **Recriar `projects`/coleções antigas** — rejeitado; adaptar `projectId`→`obraId`, `organizationId`→`construtoraId`.
- **Fallback de exclusão de logo via front-end** — fora da primeira entrega.
- **Custo médio / NF multi-itens / contas a pagar automáticas** — evolução futura.

## 9. UX, design system e acessibilidade

- Paleta: sidebar `#082344`; gradiente `#0D47A1→#1565C0`; ação `#1565C0`; dourado é marca, **nunca** sinal único de status; cor da empresa não altera o tema SIGO.
- Tipografia Material 3 nativa (sem fonte externa): página 40/48/700 desktop e 28/36/700 mobile; construtoras espaçosas, lotes compactos.
- Acessibilidade: contraste ≥4,5:1 (texto normal) e ≥3:1 (grandes/indicadores); alvo ≥48dp; foco visível/restaurado; status com texto + ícone; Esc fecha antes do envio; reflow em 320/390/800/801/1280/1440 e texto 100/130/200%.
- Marca oficial obrigatória: `sigo_logo_light.png` / `sigo_logo_dark.png` (não redesenhar).

## 10. Módulos implementados — rastreio de specs

- **Foundation/PWA/Router**: `spec-1-1-projeto-flutter`, `spec-1-8-recalculo-modulos`, `spec-2-1-service-worker-pwa`, `spec-2-4-fila-sincronizacao`, `spec-2-11-executar-autorizacao`, `spec-routing-fixes`, `spec-modularizar-router`.
- **Estoque**: `spec-3-1-crud-projetos-lotes`, `spec-3-2-estoque-recebimento`, `spec-3-3-estoque-saida`, `spec-3-4-estoque-ajustes`, `spec-3-5-estoque-estorno`, `spec-3-6-estoque-rateio`, `spec-3-7-monetario-centavos`.
- **RH**: `spec-4-1-rh-cadastro`, `spec-4-2-rh-chamada`, `spec-4-3-rh-custos`, `spec-4-4-rh-invariantes-auditoria`.
- **Módulos do Épico 5**: `spec-5-1-modulo-epi`, `spec-5-2-modulo-validacao`, `spec-5-3-modulo-adm`, `spec-5-4-fornecedores`, `spec-5-5-parcelas-recebimento`, `spec-5-6-visao-360-custos`, `spec-5-7-gestao-proprietario-owner`.
- **Vínculos**: `spec-8-1-lista-com-cargo-n-obras`, `spec-8-2-filtros-e-busca`, `spec-8-3-detalhe-do-membro`, `spec-9-1-atribuir-operario-a-obra`, `spec-9-2-atribuir-admin-erros-e-offline`, `spec-10-1-2-trocar-papel-remover-obra`, `spec-10-3-trocar-cargo-na-construtora-e-desativar`.
- **Drill-down**: `spec-11-1-navegacao-loteamento-quadra-lote`, `spec-11-2-navegacao-lote-setor-equipe`.
- **Design/primeira entrega**: `spec-sigo-primeira-entrega`, `ux-obras-2026-09-23/primeira-entrega/*`.
- **Onboarding/segurança**: `spec-onboarding-solicitacao-acesso`, `spec-permissao-irrestrita-dev-firestore`, `spec-hardening-credenciais-seed`.

## 11. Dívida técnica e action items abertos

- E2E offline com Service Worker ativo e cold start (retro do Épico 2).
- Fila offline para RH (retro do Épico 4).
- Carga/idempotência da Visão 360 sob atualizações simultâneas de RH e Estoque (retro do Épico 5).
- E2E de anexos fotográficos e PDFs sob conectividade intermitente (retro do Épico 5).
- Achados de a11y/guards dos Épicos 8–10 (retros 2026-09-22).
- Reconciliar AC da Story 9.2 e epics.md com o intent congelado das specs.
- Alinhar os vínculos (Épicos 8–10) à Hierarquia Estrutural canônica (Loteamento → Quadra → Lote → Setor → Equipe); migração dos vínculos por obra mapeada como OQ-1 do PRD.

## 12. Mecanismos e restrições complementares

Mecanismos e restrições que o PRD cita em nível de capacidade e cujo "como" fica aqui (absorvidos na reconciliação de inputs):

- **Precedência de permissão**: `modules` controla os módulos centrais de membros comuns; o acesso de admin/owner decorre de `isAdmin`/`isOwner` e do perfil, **não** de `modules` (fonte `docs/politica.md` §3).
- **Carimbo de evidência (FR-98)**: carimbo embutido nos bytes da imagem com data/hora e geolocalização quando disponível, com fallback quando GPS indisponível (fontes `spec-2-13-sistema-carimbo`, `spec-2-5-armazenamento-local-blobs`).
- **Limites de anexo (FR-101)**: limite de tamanho (**10 MB** em comprovantes; **2 MiB** para logo — unidades conforme as fontes), tipos JPEG/PNG/WebP/PDF, verificação por magic bytes e integridade por SHA-256 (fontes `spec-2-5`, `spec-5-3`).
- **Custo na movimentação (FR-99)**: custo unitário efetivo apurado no recebimento e custo apropriado propagado à saída/apropriação (fontes `spec-3-6-estoque-rateio`, `spec-3-7-monetario-centavos`).
- **Snapshot de custo de mão de obra (FR-100)**: `lotCostSummaries` imutáveis por chamada fechada/retificada; vedação de recálculo retroativo por reajuste salarial (fontes `spec-4-3`, `spec-4-4`).
- **Resultado incerto (FR-97)**: bloqueio transitório durante o envio; "Fechar" não cancela; "Verificar estado atual" consulta a fonte autoritativa, nunca cache (fonte `primeira-entrega/HANDOFF.md`, `EXPERIENCE.md`).
- **Invalidação após mutação**: invalidar os providers afetados e oferecer pull-to-refresh; agregação "por obra/nó" no cliente sem `collectionGroup` (fonte `epics.md`, `architecture-obras-2026-09-21`).
- **Seed/credenciais (D8)**: seed cloud exige `GOOGLE_APPLICATION_CREDENTIALS` sem fallback; CI reprova commit de credenciais (`.gitignore` + job `no-secrets`) (fonte `docs/decisoes.md` D8, `spec-hardening-credenciais-seed`).
- **Restrições de build**: runtime Node 20 (Functions); `firebase` SDK 12.19.0, `firebase-tools` 15.30.1 e Sharp; verificar emuladores e regras antes de publicar (fonte: `functions/package.json`, `docs/implantacao-c0-c6.md`).
- **Bypass de escrita**: o Dev administra/corrige por comandos auditados; não há gravação direta irrestrita de saldo/histórico/privilégios (fontes `spec-permissao-irrestrita-dev-firestore`, `spec-5-7`).
