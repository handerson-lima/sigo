# SIGO — Modelo de dados atual e evolução proposta

Atualizado em 2026-09-15. A seção 1 descreve o código local; as demais seções são propostas de correção aguardando aprovação. Esta revisão substitui os nomes e a política de acesso do planejamento antigo.

## 1. Estrutura implementada

| Caminho | Campos relevantes observados |
|---|---|
| `users/{uid}` | `id`, `email`, `displayName`, `photoUrl`, `globalRole`, `createdAt`, `updatedAt` |
| `construtoras/{cId}` | Dados da construtora |
| `construtoras/{cId}/construtora_members/{uid}` | `userId`, `isOwner`, `isAdmin`, `isActive`, `joinedAt` |
| `construtoras/{cId}/obras/{oId}` | Dados da obra e `construtoraId` |
| `construtoras/{cId}/obras/{oId}/members/{uid}` | `userId`, `isAdmin`, `modules`, `isActive`, `joinedAt` |
| `construtoras/{cId}/obras/{oId}/lotes/{loteId}` | `id`, `construtoraId`, `obraId`, `name`, `phase`, `status`, `responsavelId`, `createdAt` |
| `construtoras/{cId}/materiais/{materialId}` | `id`, `construtoraId`, `name`, `unit`, `currentQuantity` (`double`) |
| `construtoras/{cId}/materiais/{materialId}/movimentacoes/{movId}` | `id`, `materialId`, `type`, `quantity`, `date`, `responsavelId`, `obraId?`, `loteId?`, `observacao?` |
| `construtoras/{cId}/despesas/{despesaId}` | `id`, `construtoraId`, `obraId?`, `descricao`, `valor` (`double`), `dataVencimento`, `dataPagamento?`, `status`, `categoria`, `responsavelId`, `createdAt` |
| `construtoras/{cId}/obras/{oId}/diarios/{diarioId}` | `id`, `construtoraId`, `obraId`, `date`, `weather`, `efetivo`, `observacoes`, `photoUrls`, `localPhotoPaths`, `isPendingSync`, `responsavelId`, `createdAt` |

O efetivo do diário contém função e quantidade; não constitui cadastro individual de RH ou folha de pagamento.

Os serializadores Dart gravam diversas datas como ISO String. Functions e algumas atualizações usam Timestamp, produzindo formatos mistos. Em particular, `dataPagamento` recebe `serverTimestamp()` e o leitor gerado espera String. Não tratar o banco atual como schema homogêneo.

Descoberta atual: `collectionGroup('construtora_members')` por `userId`/`isActive`; obras de membros comuns usam `collectionGroup('members')` com esses filtros. A consulta de obras e sua autorização precisam ser validadas; não estão cobertas por testes encontrados. Administradores/proprietários usam listagem de obras da construtora no cliente.

## 2. Autorização — dev global preservado

**Decisão do usuário:** dev permanece privilegiado globalmente. Substitui a antiga decisão de não permitir bypass global.

Proposta C1:

- `users/{uid}.globalRole` passa a ser escrito somente por fluxo administrativo confiável no servidor. Cliente comum não cria, altera ou apaga autorização própria.
- Dev confiável tem administração global sem membership individual por obra; sua identidade deve ser verificada antes da migração do fallback legado por e-mail.
- Usuários comuns dependem de `isActive == true` e `modules` no escopo autorizado. Admin/proprietário ativo da construtora dispensa membership em cada obra da própria construtora.
- Adicionar `modules` ao vínculo de construtora para permissões de módulos centrais, começando por `estoque`; migração explícita dos acessos existentes.
- Campos ausentes/ilegíveis não concedem acesso implicitamente; documentos legados serão inventariados e normalizados antes do fechamento das regras.
- IDs de documento e campos de escopo precisam coincidir. Claims são auxiliares e não podem superar revogação no vínculo autoritativo.
- Auditoria administrativa guarda ator, alvo, ação, escopo, instante e resultado; dados de auditoria não são editáveis pelo cliente.

Matriz completa: [plano de correções](plano-de-correcao-2026-09-15.md#3-matriz-de-acesso-proposta).

## 3. Contratos propostos para estabilização

### Financeiro — C3

- `valorEmCentavos`: inteiro em BRL; `schemaVersion` identifica o formato novo.
- `valor` permanece apenas para compatibilidade durante migração, sem dupla contagem. Conversão decimal e arredondamento terão regra explícita e relatório de reconciliação.
- Instantes como pagamento/criação usam Timestamp; leitores aceitam ISO legado/Timestamp/nulo conforme campo.
- Vencimento representa data civil; contrato deve preservar o dia ao converter formatos e fusos.
- Pagamento autorizado por comando idempotente, com data do servidor e auditoria, sem edição direta de campos consolidados.

### Estoque central — C4

- Preservar a coleção de materiais na construtora. `obraId` e `loteId` são destinos, não partições independentes de saldo nesta etapa.
- Introduzir quantidade inteira escalada (`quantityUnits`, `quantityScale`) e saldo equivalente no material (`confirmedQuantityUnits`). Migração reconcilia `currentQuantity` e guarda versão do schema.
- Cada comando guarda `operationId`, ator, escopo, hash do payload e resultado. Proposta de caminho: `construtoras/{cId}/operations/{operationKey}`, com chave derivada de ator/tipo/ID de forma não ambígua; somente backend escreve.
- Saldo, movimentação e recibo idempotente são confirmados na mesma transação. ID repetido com payload distinto é rejeitado.
- Valores negativos, não finitos ou fora da escala são rejeitados. Obra/lote de destino devem pertencer à construtora/material da operação.
- Histórico confirmado é preservado. Correções criam eventos vinculados à original, com motivo/evidência; dev/admin usa o mesmo contrato auditado.
- Dados antigos sem histórico suficiente geram abertura reconciliada, não histórico inventado. Custos antigos desconhecidos permanecem explicitamente desconhecidos.

Custo médio, NF multi-itens e contas a pagar geradas por compra ficam na evolução futura, não são pré-requisitos para afirmar que entradas/saídas centrais estão estabilizadas.

### Diário e anexos — C2/C5

- Substituir `photoUrls` por referências privadas e manifesto de anexos com IDs estáveis, tipo, tamanho e integridade.
- Manter leitura compatível das fotos legadas durante conversão; planejar invalidação de tokens/URLs antigos separadamente do deploy de Rules.
- `localPhotoPaths` e estado técnico de fila pertencem ao dispositivo, não ao documento compartilhado. Migração deve preservar pendências existentes e não apagá-las a partir de outro dispositivo.
- Documento confirmado referencia anexos obrigatórios verificados; arquivo ausente mantém erro explícito e impede conclusão falsa.

### Fila local Web — C5

IndexedDB com schema versionado, particionado por `userId`, `construtoraId`, `obraId` quando aplicável e módulo.

- Operação: `operationId`, tipo, escopo, payload, IDs de anexos, hora local, tentativas, erro e estado.
- Estados: `pending`, `syncing`, `synced`, `failed`, `conflict`, `authorization_rejected`.
- Anexo: ID estável, bytes/blob, tipo, tamanho, integridade, operação associada e referência remota quando disponível.
- Persistir operação/anexos antes de confirmar salvamento local. Confirmar `synced` apenas após aceite integral do backend.
- Logout/troca de conta remove cache de leitura não autorizado e isola pendências. A outra conta não pode ver ou sincronizar dados do usuário anterior.
- Reabertura, atualização de schema e falhas transitórias preservam operações. Revogação impede retry inútil; nenhuma autorização cacheada consolida dados no servidor.

## 4. Migração e compatibilidade

1. Inventariar dados e devs confiáveis; preparar simulação em ambiente isolado.
2. Introduzir leitores compatíveis antes das novas escritas; versionar documentos.
3. Executar conversões retomáveis e reconciliar contagens, centavos, saldos e anexos.
4. Coordenar cliente, Functions e Rules; fechar escritas legadas após preparar a transição.
5. Preservar recuperação de dev e dados. Rollback não reabre autoatribuição de privilégios.

Não foram executadas migrações ou consultas à produção nesta atualização.

## 5. Modelo futuro preservado

O [modelo anterior arquivado](archive/2026-09-15-planejamento-anterior/data_model.md) contém contratos conceituais de RH, equipes, presença, EPI, qualidade, compras, parcelas e custos. Permanecem referências para refinamento futuro, não schema vigente.

Ao retomá-los, adaptar `projectId` → `obraId`, `organizationId` → `construtoraId`, escopo central do estoque e a exceção dev global. Não criar coleções antigas paralelas como `projects` somente para seguir nomes históricos.
