# Reconciliação — specs

Veredito de cobertura: **alta** — o PRD captura bem as regras estruturais (autorização server-authoritative, imutabilidade/hard-delete, idempotência, offline/PWA, onboarding, owner/dev), mas omite detalhes operacionais das specs (carimbo de fotos, limites de anexo, snapshot de custo, critérios de motivo/evidência) e diverge das specs quanto à raiz do financeiro e à Hierarquia Estrutural.

## Lacunas

1. **Carimbo indelével e geolocalização de fotos** — `spec-2-13-sistema-carimbo` (e `spec-2-5-armazenamento-local-blobs`). O PRD só cita "foto com carimbo de evidência" na validação (FR-73). Falta descrever o `WatermarkService`: estampa nos **bytes** da imagem (data/hora `dd/MM/yyyy HH:mm:ss`, GPS lat/long, obra/responsável), com fallback explícito `GPS: Indisponível`/`GPS: Sem Permissão`, timeout de 4s, 100% client-side/offline, substituindo os bytes antes da persistência e do enfileiramento. O diário (FR-54/55) não menciona o carimbo.

2. **Limites e validação de anexos/arquivos** — `spec-2-5-armazenamento-local-blobs`, `spec-5-3-modulo-adm`. FR-55/57 e a NFR de "limite de tamanho" não fixam números nem formatos. Falta: limite de **10 MB** (10.485.760 bytes), aceitar apenas JPEG/PNG/WebP (e PDF/imagem nos comprovantes ADM), validação por **magic bytes**, rejeição imediata de arquivo vazio (0 bytes) ou acima do limite, e a trava de não sincronizar anexo cujo tamanho/SHA-256 divirja do metadado.

3. **Custo apropriado na saída e custo unitário efetivo** — `spec-3-6-estoque-rateio`, `spec-3-7-monetario-centavos`. FR-42 cobre o total de recebimento (itens + frete + despesas − desconto) e "desconto ≤ bruto", mas o PRD não descreve que o **custo unitário efetivo = round(custoTotal / quantidade)** é apurado e exibido no histórico do almoxarifado, nem que a **saída** de material pode carregar `custoUnitarioCentavos`/`custoTotalCentavos` para apropriação por lote (FR-43 fala só de destino/apropriação). Também omite a escala inteira de quantidades (`quantityScale = 1000`, 3 casas) e a tolerância a vírgula/ponto.

4. **Snapshot imutável de custo de mão de obra e vedação de recálculo retroativo** — `spec-4-3-rh-custos`, `spec-4-4-rh-invariantes-auditoria`. O PRD FR-60/64/66 descreve divisor configurável, custo por presença e retificação auditada, porém **não enuncia a invariante** de que o fechamento persiste snapshot do salário/divisor aplicado e que reajustes cadastrais posteriores **nunca** afetam chamadas passadas ("Nunca aplicar recálculo dinâmico retroativo que sobrescreva o snapshot"). Fica implícito, sem cobertura testável explícita.

5. **Critérios mínimos de motivo, evidência e travas de reversão** — `spec-3-4-estoque-ajustes`, `spec-3-5-estoque-estorno`, `spec-5-3-modulo-adm`, `spec-5-5-parcelas-recebimento`, `spec-4-4-rh-invariantes-auditoria`. FR-46/84 usam apenas "auditado com motivo". Faltam os contratos das specs: ajuste/estorno exigem **motivo ≥ 5 caracteres e evidência obrigatória**, restrição a administradores, proibição de estornar `abertura` e de reversão duplicada via `reversedBy`, `motivoCancelamento` de despesa/compra com **≥ 10 caracteres**, e justificativa de retificação de chamada com **≥ 10 caracteres**.

6. **Não-objetivos das specs ausentes no §5 do PRD** — `spec-5-1-modulo-epi`, `spec-5-2-modulo-validacao`, `spec-5-7-gestao-proprietario-owner`, `spec-5-4-fornecedores`. O §5 não registra: ausência de certificação **ICP-Brasil A1/A3** e Gov.br (EPI e Validação usam canvas/PIN + SHA-256), ausência de **laudo pericial A3**, não bloquear automaticamente medição de empreiteiro por vistoria, **não limitar a um único owner** por construtora, e **fornecedor inativado não selecionável** em novos lançamentos de compra/despesa até reativação.

7. **Bypass global de escrita do Dev no Firestore** — `spec-permissao-irrestrita-dev-firestore`. FR-2 fala só de "administração global e acesso de suporte", sem registrar que o dev ativo (`dev_roles/{uid}.isActive`) recebe `match /{document=**} { allow read, write }` em todo o banco e é tratado como membro de qualquer construtora/obra. Essa exceção tensiona com "o servidor é a autoridade" e "cliente nunca cria/altera a própria autorização" (FR-6/FR-7) e deveria constar explicitamente (com limite e racional), não só no addendum.

## Conflitos

1. **Raiz do financeiro: obra vs construtora** — `spec-5-3-modulo-adm` (e `spec-5-6`, `epic-5-context`) gravam despesas em `construtoras/{cId}/obras/{oId}/despesas_adm/{despesaId}`, com `obraId`/`loteId` obrigatórios; o `addendum.md` §3 e o Glossário/§4.7 do PRD tratam "Despesa — conta a pagar **da construtora**" em `construtoras/{cId}/despesas/{despesaId}`. O PRD deve fixar se a conta a pagar é corporativa ou por obra (impacta FR-48, FR-49, FR-53 e a Visão 360).

2. **Loteamento como raiz canônica vs atribuição por Obra** — O PRD (Glossário, §4.3, §6.1, FR-31/FR-32) define Loteamento como raiz que "substitui Obra" e descreve atribuição de membros a nós da Hierarquia Estrutural. A `spec-epic-11` declara em **Non-goals** que a refatoração dos Vínculos (Epics 8/9/10) e a atribuição a nós "é escopo futuro", e as specs `9-1`, `9-2`, `10-1-2`, `10-3` atribuem por `obraId`. O PRD apresenta como in-scope o que a spec congela como futuro.

3. **Caminho canônico dos Lotes** — Quality/RH/Visão 360 usam `obras/{oId}/lotes/{lId}/...` (`spec-5-2`, `spec-5-6`, `spec-4-2`), enquanto a Hierarquia Estrutural (`spec-epic-11`, `spec-11-1`, `spec-11-2`) usa subcoleções aninhadas `loteamentos/{lId}/quadras/{qId}/lotes/{loId}/...`. São duas árvores de "Lote" sem ponte explícita no PRD; o Glossário só legitima a convivência com a "Obra" legada, não a duplicação de lotes.

4. **Conjunto de módulos por escopo** — AD-4 do `addendum.md` restringe módulos a `diario|lotes|estoque` na obra e `estoque` na construtora, mas `spec-5-3`, `spec-5-4`, `spec-5-5` e `spec-5-6` autorizam `adm`, `compras`, `financeiro`, `rh` e `almoxarifado` no escopo obra. O PRD (Glossário, FR-38) lista os módulos mas não fecha qual conjunto vale por escopo.

5. **Limite do logo (já em OQ-2)** — A spec canônica `spec-sigo-primeira-entrega` CAP-5 fixa **2 MiB** e o processamento Sharp (máx. 10 megapixels), enquanto o `HANDOFF.md` cita 5 MB. O PRD mantém `[ASSUMPTION]` de 2 MiB e delega a OQ-2; a spec canônica já resolveu o valor, cabendo ao PRD deixar de tratá-lo como incógnita.

## Cobertura OK

Regras das specs já fielmente refletidas no PRD (sem ação):

- **Idempotência de comandos** — reenvio idêntico retorna o resultado, payload divergente vira `conflict`/`already-exists`, `operationId` determinístico (`spec-2-10`; FR-44, FR-51, FR-82, FR-93).
- **Offline/PWA** — shell cacheado sem dados de negócio, fila IndexedDB com os seis estados, lease multi-aba de 120s, isolamento por conta/escopo, indicador honesto, migração de schema não destrutiva (`spec-2-1`, `spec-2-4`, `spec-2-7`, `spec-2-8`, `spec-2-12`, `spec-2-14`; FR-90–94, NFR §4.15).
- **Imutabilidade e não-exclusão** — `allow delete: if false` em funcionários, equipes, chamadas, obras, lotes, movimentações, despesas liquidadas, fornecedores, vistorias e eventos de EPI (`spec-3-4`, `spec-3-5`, `spec-4-1`, `spec-4-2`, `spec-5-1`, `spec-5-2`, `spec-5-3`, `spec-5-4`, `spec-5-5`; FR-46, FR-52, FR-66, FR-68, FR-74, FR-78, FR-84).
- **Monetário em centavos** — inteiros, sem `double`, parcelamento com soma ≡ total e resto determinístico (`spec-3-6`, `spec-3-7`, `spec-5-3`, `spec-5-5`, `spec-5-6`; FR-42, FR-45, FR-50, FR-64, FR-80, FR-81, FR-88).
- **Onboarding e notificação** — solicitação pendente para e-mail sem conta, aprovação só pelo Dev, idempotente, auditada, senha provisória apenas na notificação in-app com TTL de 7 dias (`spec-onboarding-solicitacao-acesso`; FR-12–16).
- **Autorização server-authoritative** — escrita de papel/vínculo só por Function, owner só pelo Dev, dev/membro fail-closed por módulo, mapeamento pt-br, recálculo de escopo (`spec-1-8`, `spec-2-11`, `spec-5-7`, `spec-9-1`, `spec-9-2`, `spec-10-1-2`, `spec-10-3`; FR-2–FR-11, FR-28–FR-40).
- **Domínio fiscal e de qualidade** — CPF/CNPJ módulo-11 sem máscara e sem duplicidade, fornecedor corporativo obrigatório, NF-e de 44 dígitos, evidência obrigatória de não conformidade e template versionado (`spec-5-2`, `spec-5-4`, `spec-5-5`; FR-71–FR-79).
- **Visão 360** — quatro cubos por lote, orçado vs realizado, pago vs passivo, rateio indireto com discrepância zero (`spec-5-6`; FR-85–FR-89).
