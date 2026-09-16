---
title: 'C0–C6 — Estabilização SIGO com dev global'
type: 'bugfix'
created: '2026-09-15'
status: 'completed'
baseline_commit: 'c456de9'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/docs/plano-de-correcao-2026-09-15.md'
---

<frozen-after-approval reason="escopo C0–C6 e matriz aprovados expressamente pelo usuário">

## Intent

**Problema:** permissões editáveis, anexos sem isolamento, pagamentos incompatíveis, saldo sem idempotência e fila não durável impedem uso confiável do SIGO.

**Abordagem:** executar C0–C6 do plano aprovado: testes/emuladores, autorização confiável, arquivos privados, centavos/datas, comandos transacionais e persistência Web/PWA, com migrações simuláveis e validação integrada.

## Boundaries & Constraints

**Sempre:** preservar dev global, hierarquia existente e estoque central; dados/URLs legados devem ter leitores compatíveis e migração explícita; testes isolados de produção. Privilégios globais dispensam vínculos, não integridade transacional.

**Nunca:** publicar ou migrar produção nesta rodada; confiar em globalRole legado sem comprovação; apagar pendências; recriar projeto ou expandir RH/EPI/qualidade. Identidades reais dos devs serão verificadas antes de qualquer provisionamento de produção.

## I/O & Edge-Case Matrix

| Cenário | Entrada | Resultado | Falha |
|---|---|---|---|
| Dev | Registro confiável no servidor | Administração global sem vínculo | Papel autoatribuído não concede acesso |
| Revogação | Vínculo inativo, claim antigo | Negado | Sem retry infinito |
| Estoque | Comando repetido | Mesmo resultado, um efeito | Payload divergente rejeitado |
| Concorrência | Duas saídas | Saldo não negativo | Conflito explícito |
| Pagamento | ISO/Timestamp/nulo | Leitura compatível, centavos | Valor inválido rejeitado |
| Anexo | Upload parcial ou ausente | Retomada por ID | Não declarar sucesso falso |
| Offline | Reabertura/troca de conta | Fila durável e isolada | Quota/revogação visíveis |

</frozen-after-approval>

## Code Map

- `functions/src/index.ts`, `firestore.rules`, `storage.rules`: autorização e comandos; remover confiança em e-mail/claims legados após provisionamento ensaiado.
- `app/lib/src/features/authentication`, `construtoras`, `obras`, `developer`: perfis, vínculos e UI administrativa; normalizar aliases `rdo`/`almoxarifado`.
- `app/lib/src/features/financeiro`: reader Timestamp e gravação de pagamento; preservar API de exibição em reais.
- `app/lib/src/features/almoxarifado`: transação atual no cliente, substituir por comando.
- `app/lib/src/features/diario`: File/putFile e localPhotoPaths, substituir na web por bytes e fila.
- `app/lib/src/routing/app_router.dart`, `common_widgets`: guardas e estados de permissão.
- `firebase.json`, `functions/package.json`, `app/test`: configuração de emuladores e testes.

## Tasks & Acceptance

**Execução:**

- [x] `functions/test`, `app/test`, `firebase.json` — base C0 e regressões.
- [x] `functions/src`, `firestore.rules`, `storage.rules` — C1/C2/C3/C4: autorização, administração, auditoria, comandos e anexos.
- [x] `app/lib/src/features/authentication`, `construtoras`, `obras`, `developer`, `routing`, `common_widgets` — matriz e UI C1.
- [x] `app/lib/src/features/financeiro`, `almoxarifado` — contratos de comandos, datas, centavos e quantidades C3/C4.
- [x] `app/lib/src/features/diario`, `app/lib/src/sync`, `app/web` — fila durável, bytes e retomada C5.
- [x] `functions/scripts`, `docs` — inventário, ensaio de migração, recuperação e implantação C0/C6.
- [x] `functions/test`, `app/test` — testar matriz de bordas e integração.

**Aceite:**

- Dado dev confiável sem membership, quando administra usuários/escopos, então conserva acesso; dado usuário comum, quando altera o próprio papel, então é negado.
- Dadas duas construtoras, quando se acessam documentos/anexos da outra sem permissão, então há negação mesmo com claims antigas.
- Dado saldo central, quando há concorrência/reenvio/estorno, então existe somente um efeito válido por comando e histórico preservado.
- Dadas despesas legadas, quando são lidas/pagas/recarregadas, então datas e totais são corretos.
- Dada operação local, quando app reabre ou upload falha, então bytes sobrevivem e sucesso exige confirmação integral.
- Dados pacotes concluídos, quando análise/testes/build e ensaio isolado executam, então resultados e limitações ficam documentados sem declarar validação de produção.

## Implementation Notes

- Investigação: `java` é stub sem runtime; Firebase CLI global falha via firepit. Validar emuladores após preparar ferramentas locais, sem simular sucesso.
- Contrato de dev: `dev_roles/{uid}.isActive` é a autoridade exclusivamente administrativa; `users.globalRole` é espelho de exibição.

- Aprovação de C0–C6 e matriz concedida pelo usuário nesta rodada; dispensa pedir novamente confirmação do mesmo escopo. Pacotes mantidos juntos conforme aprovação explícita.
- Versionamento Git indisponível; não existe branch/revisão para registrar. Preparar controle de alterações local antes de implementar.
- Nomes e caminhos internos novos são decisões técnicas; produção e identificação de devs reais não são ações desta rodada.

## Spec Change Log

## Review Triage Log

## Design Notes

Separar registro confiável de dev em coleção exclusivamente administrativa, mantendo perfil de exibição compatível. Provisionamento aceita somente UIDs explicitamente verificados. Fila persiste comandos/anexos com identidade estável e escopo do usuário; execução backend revalida autorização dentro da transação.

## Verification

- `cd functions && npm test` — testes unitários/integração conforme scripts.
- Emulator Suite com projeto demo — testes de Rules, Storage e comandos sem produção.
- `cd app && flutter analyze && flutter test && flutter build web` — análise, testes e build.
- Ensaio navegador: reabertura, offline, falha parcial e troca de conta. Safari móvel exige dispositivo disponível; registrar limitação se não houver.
