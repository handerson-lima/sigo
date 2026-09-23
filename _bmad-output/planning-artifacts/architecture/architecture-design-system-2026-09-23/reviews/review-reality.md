# Reality/currentness review — design system SIGO

Data: 2026-09-23. Snapshot: ARCHITECTURE-SPINE.md com AD-1–11, incluindo fingerprint canônico, invalidação do catálogo e remoção de auto-provisionamento Dev. Somente leitura de contrato, código/lockfiles e fontes primárias; sem instalação, deploy ou execução de testes.

## Verdict

**Adequate, com duas correções técnicas antes de fechar o contrato.** A stack declarada e as capacidades centrais são reais; não há motivo para atualizar dependências apenas por existir versão mais nova. Faltam um desenho explícito dentro do orçamento de leituras das Storage Rules e o prazo concreto do ciclo de vida do Node 20.

## RC1 — medium — Orçamento de duas leituras das Storage Rules não foi incorporado

**Local:** AD-6, AD-8, AD-10; evidence/technology-check.md, Storage Rules.

A política exige staging vinculado à operação e autoridade atual. Reutilizar `dev() || manager(cm)` e acrescentar a operação alcança três documentos distintos para um administrador que não é Dev. Para leitura estrita da versão corrente, ponteiro na construtora + dev_roles + membership também pode alcançar três. O código existente em storage.rules mostra helpers que consultam essas autoridades separadamente; copiar o padrão não resolve esse limite.

A documentação oficial fixa **no máximo dois documentos Firestore por avaliação de Storage Rules**. Isso é limite de viabilidade da autorização, não uma otimização: [condições Storage/Firestore](https://firebase.google.com/docs/storage/security/rules-conditions).

**Correção mínima sugerida:** na abertura server-side, registrar na operação qual autoridade a habilitou e seu caminho imutável. Staging lê operação + esse único documento (Dev ou membership), mantendo ator/alvo/prazo e revogação; se o grant escolhido for revogado, negar aquele staging mesmo que o usuário tenha outro grant, sem ampliar os dois reads. Finalize continua relendo a autoridade integral em transação Firestore.

Para imagens, permitir leitura autenticada de versões publicadas privadas do tenant por Dev ativo ou membro ativo (dois documentos), com o aplicativo resolvendo somente o ponteiro corrente e sem UI de histórico. Isso permite a um membro ainda autorizado ler uma versão anterior cujo caminho já conheça até a coleta; exige explicitar essa concessão no contrato. Se “somente corrente” for requisito de autorização estrito, usar serviço/proxy autenticado que faça todas as verificações, em vez de prometer que a regra direta atual cabe no limite. Cobrir contas Dev, membro, revogado, sem vínculo e sem dev_roles nos testes, incluindo contagem máxima de documentos.

## RC2 — medium — Prazo do runtime Node 20 precisa constar no gate operacional

**Local:** Stack/Node.js, AD-11, Deferred/runtime; evidence/technology-check.md/Node20.

`functions/package.json` realmente declara Node20 e firebase.json não o sobrescreve. A página resumida Firebase ainda o lista, mas remete ao calendário de suporte. O calendário primário indica depreciação em **2026-04-30** e descomissionamento em **2026-10-30** para Node20, inclusive primeira geração. Após descomissionamento, criação e redeploy ficam indisponíveis. Em 2026-09-23 há janela operacional curta; “patch a conferir” não captura essa restrição. [Calendário oficial de runtime](https://docs.cloud.google.com/functions/docs/runtime-support).

**Correção sugerida:** manter Node20 como fato da baseline, registrar essas datas e tornar o runtime de implantação uma decisão com prazo anterior ao build/rollout. Se a entrega ou sua manutenção avançar além de 2026-10-30, adotar runtime suportado e validar dependências/binário; Node22 aparece no mesmo calendário para primeira geração e pode ser avaliado sem migrar geração. Não se trata de atualizar para latest indiscriminadamente nem de alegar que o ambiente atual já está desativado.

## Verificações positivas

- SDK local `/Users/usuario/flutter/bin/cache/flutter.version.json` confirma Flutter3.47.2/Dart3.13.2. app/pubspec.lock confirma as oito dependências Flutter declaradas. functions/package-lock.json confirma firebase-admin12.7.0, firebase-functions5.1.1 e TypeScript5.9.3; manifest declara firebase-tools15.30.1. Sharp não está instalado, coerente com proposta nova.
- Sharp0.35.4 tem release oficial de 2026-08-26; instalação oficial pede Node-API v9, exemplificada por Node>=20.9.0, e oferece binários Linux. Os gates de integração/binário permanecem necessários e já estão declarados. [Release](https://sharp.pixelplumbing.com/changelog/v0.35.4/), [instalação](https://sharp.pixelplumbing.com/install/).
- `functions/src/contracts.ts` confirma manager por vínculo ativo e isAdmin/isOwner/role. `functions/src/index.ts` confirma contexto autenticado, authority.admin distinta de obraAdmin, callables da primeira geração e setDevRole protegido. AD-6/7 refletem código real, incluindo o bootstrap inseguro ainda presente no cliente/regras e a necessidade de removê-lo.
- `lote_repository.dart` confirma duas atualizações independentes e leitura com cache sem recibo; user_construtoras_provider.dart confirma FutureProvider.autoDispose. AD-5 e a invalidação explícita de catálogo em AD-10 respondem a lacunas reais.
- Não se presumem produção, plano, bucket, recursos IAM nem testes aprovados. Esses limites estão documentados corretamente; devem continuar como gates, sem relato de conformidade implementada.

Contagem: critical0, high0, medium2, low0. Nenhuma alteração feita no spine ou código.

## Rechecagem após correções — 2026-09-23

**Verdict atualizado: strong para currentness/reality do planejamento; RC1 e RC2 resolvidos no contrato.**

- **RC1 resolvido:** AD-8 fixa `uploadGrantKind` pelo servidor e deriva o caminho de ator/tenant, limitando staging a operação + grant atual e mantendo revalidação integral em finalize. AD-10 limita leitura a dois documentos de autoridade e explicita versões anteriores privadas acessíveis aos mesmos autorizados até coleta; consumo da versão corrente pertence ao cliente. A concessão antes implícita agora é explícita e cabe no orçamento documentado.
- **RC2 resolvido:** AD-11 registra as duas datas de Node20, propõe Node22 na primeira geração antes da ativação e exige compatibilidade dos SDKs/Sharp e reconferência do calendário. Stack e Deferred separam baseline local de alvo futuro; evidence/technology-check.md registra a fonte oficial específica.

Restam os testes e gates futuros já declarados, sem achado aberto desta lente. Contagem atual: critical0, high0, medium0, low0. Os achados originais permanecem acima como trilha da revisão; não significam pendências atuais. Nenhuma implantação ou compatibilidade de binário foi alegada como verificada.
