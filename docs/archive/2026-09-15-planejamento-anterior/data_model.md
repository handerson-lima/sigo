# Modelagem de Banco de Dados (Firestore) - SIGO

Como usaremos o Firebase (NoSQL), a modelagem é orientada a documentos e coleções. O foco aqui é minimizar leituras (reads) mantendo os dados desnormalizados onde for apropriado para a performance do app mobile (Offline-First).

## Estrutura de Coleções

### 1. `users` (Usuários do Sistema)
Armazena os perfis e permissões de quem tem login no app.

- `id` (String - UID do Firebase Auth)
- `name` (String)
- `email` (String)
- `jobTitle` (String - Título do cargo, ex: "Engenheiro Residente")
- `active` (Boolean)

> **DECISÃO DA V1 — SEM BYPASS GLOBAL:** Não haverá `globalAdmin` capaz de ignorar a checagem por obra. Administradores também precisam de membership ativa e módulos explícitos em cada obra. `jobTitle` serve somente para exibição. Um perfil global poderá ser avaliado futuramente com controles e auditoria próprios.

### 1.1 `projects/{projectId}/members/{userId}` (Vínculo Usuário ↔ Obra ↔ Módulos - NOVO)
Esta estrutura de subcoleção é a **FONTE DE VERDADE DETERMINÍSTICA** para autorização por obra. Um usuário apenas autenticado no Firebase não tem acesso a nenhuma obra até possuir um registro ativo neste caminho.
A localização do vínculo deve ser obrigatoriamente acessível via `projects/{projectId}/members/{request.auth.uid}` para permitir que as Firestore Security Rules encontrem diretamente a autorização através de um caminho previsível.

- `userId` (String - UID do Firebase Auth, redundante ao path mas útil para auditoria/leitura)
- `projectId` (String - Ref. Obra, redundante ao path)
- `allowedModules` (Array of Strings - Define quais módulos o usuário pode acessar nesta obra específica. Ex: `["estoque", "rh"]`)
- `active` (Boolean)
- `createdAt` (Timestamp)
- `updatedAt` (Timestamp)

**Descoberta de obras no login:** A autorização continua tendo como única fonte de verdade esta subcoleção. Para descobrir as obras de um usuário sem conhecer previamente os `projectId`, o cliente fará uma consulta `collectionGroup("members")` com `userId == request.auth.uid` e `active == true`. As Security Rules devem permitir apenas que o usuário leia vínculos cujo ID do documento e `userId` sejam iguais ao seu UID. A consulta exige índice apropriado e deve ser coberta por testes no Emulator Suite. Não será criada uma coleção paralela de memberships.

*(Nota: Onde a documentação citar conceitualmente "project_memberships", entende-se tecnicamente a subcoleção `members` dentro de cada projeto).*

### 2. `projects` (Obras)
Permite que o sistema gerencie múltiplas obras (Loteamentos/Condomínios) no futuro.
- `id` (String)
- `name` (String - ex: "Residencial Popular A")
- `address` (String)
- `status` (String - "em_andamento", "concluida")

### 2.1 `lots` (Lotes / Unidades - NOVO)
Uma Obra contém vários lotes (casas individuais). Essa é a entidade central para a visão 360 do ADM.
- `id` (String)
- `projectId` (String - Ref. Obra)
- `number` (String - ex: "Lote 12", "Casa 05")
- `status` (String - "fundacao", "alvenaria", "entregue")
- `allocatedWorkers` (Array of Strings - UIDs dos profissionais atualmente no lote)

### 3. `workers` (Profissionais - Módulo RH)
Lista de funcionários que atuam na obra.
- `id` (String)
- `projectId` (String - Ref. Obra)
- `name` (String)
- `cpf` (String)
- `role` (String - ex: "Pedreiro", "Ajudante")
- `teamId` (String - Ref. Equipe)
- `employmentType` (String - "CLT", "PJ", "Avulso")
- `salaryBasis` (String - "Mensal" ou "Diária". CLT geralmente é Mensal, Avulso pode ser Diária)
- `baseSalary` (Number - Salário bruto mensal ou valor da diária, dependendo do `salaryBasis`)
- `additionalCosts` (Number - Benefícios e encargos trabalhistas mensais ou diários)
- `totalDailyRate` (Number - [CAMPO CALCULADO] Se a base for Mensal, o sistema divide (baseSalary + additionalCosts) por 30 dias corridos para encontrar o custo da diária, englobando o DSR. Esse é o valor usado na apropriação do Lote).

> **POLÍTICA DE CUSTO DE MÃO DE OBRA:** A fórmula, o divisor e o arredondamento são parâmetros versionados da obra, validados pela área contábil. O divisor 30 é apenas o padrão inicial para contratos mensais, não uma regra trabalhista universal. Cada chamada guarda o snapshot da política e do custo diário aplicado.

### 4. `teams` (Equipes - Módulo RH)
Agrupamento de profissionais.
- `id` (String)
- `projectId` (String)
- `name` (String - ex: "Equipe de Alvenaria")
- `leaderId` (String - Ref. Worker líder)

### 5. `attendance_logs` (Chamada / Ponto)
Registro diário de presença para controle de folha e apropriação de custo por Lote.
- `id` (String)
- `date` (Timestamp)
- `teamId` (String)
- `workers` (Array of Objects - Lista detalhada de quem estava presente e onde trabalhou):
  - `workerId` (String)
  - `status` (String - "presente", "falta", "meio-periodo")
  - `allocations` (Array of Objects - Permite rateio do custo diário do funcionário em múltiplos lotes):
    - `lotId` (String - Lote onde trabalhou)
    - `percentage` (Number - Porcentagem do dia gasto neste lote. Ex: 100 para o dia todo, 50 para meio dia).
- `userId` (String - Quem fez a chamada)
- `projectId` (String - Obra à qual a chamada pertence; obrigatório para isolamento multiobra)
- `costPolicyVersion` (String - Versão da política usada no cálculo)
- `costSnapshots` (Map - Custo diário e demais valores históricos aplicados a cada trabalhador)
- `operationId` (String - Chave de idempotência)
- `createdAt` / `confirmedAt` (Timestamp do servidor)

**Invariantes:** trabalhadores ausentes não recebem apropriação; alocações de um trabalhador presente em dia completo somam 100%; meio período utiliza a fração definida na política; duplicidades de trabalhador/data/obra são impedidas no backend. Correções de chamadas confirmadas geram eventos de retificação, sem apagar o histórico original.
### 6. `inventory_items` (Estoque)
Catálogo de materiais e estado consolidado.
- `id` (String)
- `projectId` (String)
- `name` (String - ex: "Saco de Cimento 50kg")
- `unit` (String - ex: "un", "kg", "m³")
- `confirmedQuantity` (Number - Estado materializado e confirmado pelo servidor. NÃO pode ser alterado diretamente pela interface sem uma transação/movimentação correspondente. O histórico oficial vive nas transações).
- `minQuantity` (Number - Para alertas)
- `averageUnitCost` (Number - Custo médio unitário atualizado a cada nova entrada).
- `quantityScale` (Number - Quantidade de casas decimais admitidas para o material)

> **REGRA DE CUSTO MÉDIO:** `novoCustoMedio = (valorEstoqueAnterior + valorEntrada) / (quantidadeAnterior + quantidadeEntrada)`. Não é uma média simples de preços.
> **PRECISÃO FINANCEIRA:** Valores monetários são persistidos como inteiros na menor unidade monetária (`amountInCents`, BRL) e quantidades usam escala decimal explícita. Cálculos e arredondamentos acontecem no backend segundo política versionada; `Number` neste documento é apenas uma descrição conceitual legada.

### 6.1 `inventory_receipts` (Recebimentos / Compras - NOVO)
Representa o cabeçalho de uma entrada de material (ex: uma Nota Fiscal), separando a compra da movimentação dos itens.
- `id` (String)
- `projectId` (String)
- `supplierId` (String - Ref. Fornecedor)
- `invoiceNumber` (String - Número da NF)
- `invoiceSeries` (String - Opcional)
- `issueDate` (Timestamp - Data de emissão)
- `receiptDate` (Timestamp - Data de recebimento na obra)
- `itemsAmount` (Number - Soma dos valores dos materiais/itens, ou seja, soma de `receipt_items.totalCost`)
- `freightAmount` (Number - Valor de frete da compra, quando houver)
- `discountAmount` (Number - Desconto financeiro aplicado à compra, quando houver)
- `otherChargesAmount` (Number - Outras despesas adicionais não representadas diretamente nos itens)
- `totalAmount` (Number - Valor financeiro total do documento/compra. Permite validar a composição: `totalAmount = itemsAmount + freightAmount + otherChargesAmount - discountAmount`)
- `dueDate` (Timestamp - Opcional, data de vencimento atrelada)
- `userId` (String - Quem registrou)
- `status` (String - Estado de negócio do recebimento, ex: "confirmed", "cancelled". **ATENÇÃO:** Pendência de sincronização pertence exclusivamente à fila local, usando o estado canônico `pending`, e não deve ser persistida aqui como estado de negócio).
- `evidenceUrls` (Array of Strings - Fotos da NF e canhoto)
- `location` (GeoPoint)
- `operationId` (String - Chave de idempotência)
- `createdAt` (Timestamp)
- `confirmedAt` (Timestamp)

**Subcoleção `receipt_items`:**
Cada recebimento contém os itens comprados (Uma NF pode ter cimento, bloco, aço, etc.).
- `itemId` (String)
- `quantity` (Number)
- `unitCost` (Number - Custo unitário nesta compra)
- `totalCost` (Number - `quantity` × `unitCost`)

### 7. `inventory_transactions` (Movimentações do Livro-Razão de Estoque)
Histórico oficial de entradas, saídas, ajustes e devoluções. Movimentações confirmadas que já produziram efeitos de estoque ou custo não podem ser editadas ou removidas de forma destrutiva. O saldo do material (`confirmedQuantity`) é derivado destas movimentações.
- `id` (String)
- `projectId` (String)
- `itemId` (String)
- `type` (String - "entrada", "saida", "ajuste_positivo", "ajuste_negativo", "devolucao")
- `quantity` (Number)
- `unitCostSnapshot` (Number - O `averageUnitCost` no exato momento de uma saída, ou o `unitCost` da compra no momento de uma entrada).
- `totalCostSnapshot` (Number - `quantity` × `unitCostSnapshot`). Estes valores são históricos e NUNCA são recalculados retroativamente.
- `date` (Timestamp)
- `userId` (String)
- `lotId` (String - Obrigatório se for "saida". Define a apropriação do custo ao lote).
- `sourceType` (String - ex: "inventory_receipt", "manual_adjustment")
- `sourceId` (String - ex: ID do `inventory_receipt`)
- `reason` (String - Motivo obrigatório para ajustes manuais e devoluções. Ex: "Avaria por infiltração")
- `notes` (String - Observações opcionais)
- `evidenceUrls` (Array of Strings - Fotos ou evidências relacionadas ao ajuste, quando aplicável)
- `sourceTransactionId` (String - Em caso de "devolucao" ou "estorno", referencia a movimentação original para preservar o custo histórico sem recalcular com novo médio)
- `operationId` (String - Chave de idempotência gerada pelo cliente para evitar duplicidade em retries).

> **LIVRO-RAZÃO E ESTORNOS:** O histórico oficial de estoque é formado apenas por movimentações confirmadas. Movimentações confirmadas que impactaram custos não são editadas ou apagadas silenciosamente; exigem transação de estorno/reversal.
> **POLÍTICA DE ESTORNO DA V1:** Somente perfil autorizado pode solicitar estorno, informando motivo e evidência. O backend cria uma movimentação inversa ligada por `sourceTransactionId`; nunca edita ou apaga a original. Se o estorno puder produzir saldo inválido ou contrariar movimentações posteriores, ele vai para revisão administrativa. Estorno de compra também exige tratamento coerente da obrigação financeira associada.

### 8. `epi_records` (Módulo EPI)
Controle de entrega de equipamentos.
- `id` (String)
- `projectId` (String - Obrigatório)
- `workerId` (String)
- `epiItemId` (String - Referência ao catálogo de EPI)
- `epiNameSnapshot` (String - Nome histórico do item)
- `caNumberSnapshot` (String - Número do Certificado de Aprovação no momento do registro)
- `quantity` (Number)
- `size` (String - Quando aplicável)
- `eventType` (String - "entrega", "troca", "devolucao", "baixa")
- `reason` (String - Obrigatório para troca, devolução e baixa)
- `deliveryDate` (Timestamp)
- `deliveredByUserId` (String - Responsável pelo registro/entrega)
- `confirmationMethod` (String - "worker_app" ou "on_device_signature")
- `signatureObjectKey` (String - Caminho privado no Storage)
- `signedTermVersion` (String - Versão imutável do termo aceito)
- `signatureHash` (String - Hash usado para verificar integridade do artefato assinado)
- `evidenceObjectKeys` (Array of Strings - Evidências privadas)
- `location` (GeoPoint - Quando autorizado e necessário)
- `deviceOccurredAt` (Timestamp - Horário informado pelo dispositivo)
- `createdAt` / `confirmedAt` (Timestamp do servidor)
- `operationId` (String - Chave de idempotência)

> **REGISTRO ASSINADO:** O desenho da assinatura é uma evidência, não uma garantia isolada de autenticidade ou validade jurídica. O registro deve preservar identidade, termo aceito, integridade, timestamps e trilha de auditoria. A política jurídica e trabalhista da empresa define sua utilização formal.

### 9. `quality_checklists` (Validação)
Formulários de aprovação.
- `id` (String)
- `projectId` (String)
- `lotId` (String - Obrigatório. Ref. Lote/Casa que está sendo inspecionada)
- `stage` (String - ex: "Fundação", "Alvenaria")
- `templateId` / `templateVersion` (String - Modelo e versão imutável aplicados)
- `status` (String - "pendente", "aprovado", "reprovado")
- `verifiedBy` (String - UID do usuário)
- `date` (Timestamp)
- `answers` (Array of Objects - `questionId`, texto/versionamento da pergunta, resposta, observação e evidências associadas)
- `photoObjectKeys` (Array of Strings - Caminhos privados das fotos probatórias)
- `signatureObjectKey` (String - Assinatura, quando exigida pela política da etapa)
- `location` (GeoPoint)
- `previousStageChecklistId` (String - Dependência confirmada, quando aplicável)
- `rejectionReason` (String - Obrigatório quando reprovado)
- `supersedesChecklistId` (String - Checklist anterior substituído por correção/reabertura)
- `operationId` (String - Chave de idempotência)
- `deviceOccurredAt` / `confirmedAt` (Timestamp do dispositivo e do servidor)

Checklists confirmados não são sobrescritos. Correções ou reaberturas criam nova versão ligada por `supersedesChecklistId`, preservando o histórico auditável.

### 10. `organizations/{organizationId}/suppliers/{supplierId}` (Fornecedores - NOVO)
Cadastro compartilhado das empresas que fornecem material para as obras da mesma construtora.
- `id` (String)
- `organizationId` (String - Construtora proprietária do cadastro)
- `name` (String - Razão Social / Fantasia)
- `cnpj` (String)
- `contact` (String - Telefone/Email)

O vínculo operacional do fornecedor com cada obra é validado no recebimento. Usuários só consultam fornecedores da organização quando também possuem módulo autorizado na obra ativa; dados comerciais sensíveis podem exigir permissão adicional.

### 11. `accounts_payable` (Contas a Pagar - NOVO)
Controle financeiro vinculado às compras de estoque. Nasce do cabeçalho da compra/recebimento, não de um item isolado.
- `id` (String)
- `projectId` (String)
- `supplierId` (String - Ref. Fornecedor)
- `purchaseReceiptId` (String - Ref. ao recebimento (`inventory_receipts`) que gerou a dívida)
- `installmentNumber` / `installmentCount` (Number - Número e total de parcelas)
- `lotId` (String - Opcional. Apenas se for uma conta/taxa exclusiva de um lote. Para materiais comprados via almoxarifado central, fica vazio, pois o custo do lote só ocorre na saída do material).
- `amount` (Number - Valor a pagar desta parcela/conta)
- `dueDate` (Timestamp - Data de Vencimento)
- `status` (String - "aberto", "pago", "atrasado")
- `paymentDate` (Timestamp - Opcional)
- `receiptUrl` (String - Comprovante de pagamento)

> **PARCELAMENTO NA V1:** Um recebimento pode gerar uma ou mais parcelas. A soma das parcelas deve ser igual ao `totalAmount` da compra, e a combinação `purchaseReceiptId + installmentNumber` é única. Retries com o mesmo `operationId` não criam parcelas adicionais.

---

## Estrutura de Modelos Locais (IndexedDB) - Exclusivos do Cliente
Os dados abaixo NÃO são coleções do Firestore, mas sim estruturas que existirão exclusivamente no armazenamento local do navegador (IndexedDB) para garantir o funcionamento Offline-First e o isolamento da fila de sincronização.

### A. `local_sync_queue` (Fila de Operações Local)
Gerencia as ações realizadas offline antes da consolidação no servidor.
- `operationId` (String - Identificador idempotente único gerado pelo cliente, ex: UUIDv4)
- `operationType` (String - ex: "CREATE_ATTENDANCE", "CREATE_REQUISITION", "UPDATE_INVENTORY")
- `entityType` (String - ex: "attendance_logs", "inventory_transactions")
- `projectId` (String)
- `lotId` (String - Quando aplicável)
- `payload` (JSON/Map - O corpo dos dados a serem enviados)
- `localTimestamp` (Timestamp - Momento em que a ação ocorreu)
- `userId` (String - Autor da ação)
- `status` (String - "pending", "syncing", "synced", "failed", "conflict", "authorization_rejected")
- `retryCount` (Number - Número de tentativas frustradas de sincronização)
- `lastError` (String - Log do último erro encontrado, se houver)
- `attachments` (Array of Strings - Chaves/IDs para blobs locais na `local_file_storage` associados à operação. A ordem de sincronização entre dados e anexos depende das regras da operação. O status synced ocorre apenas quando todos os componentes obrigatórios estiverem confirmados).
- `historicalSnapshots` (Map - Variáveis históricas autorizadas para o tipo de operação. Ex.: custo diário e versão da política para RH. Em saídas de estoque, o custo oficial é definido pelo backend na consolidação, não por este campo local).

### B. `local_file_storage` (Armazenamento de Evidências Locais)
Arquivos brutos (fotos, assinaturas) capturados em campo que aguardam upload (pois não podem depender do Firebase Storage estando offline).
- `fileId` (String - Identificador local)
- `blobData` (Blob - Arquivo binário real no IndexedDB)
- `mimeType` (String - ex: "image/jpeg", "image/png")
- `fileSize` (Number)
- `associatedOperationId` (String - Referência à `local_sync_queue`)
- `status` (String - "pending_upload", "uploading", "uploaded", "failed", "orphaned")
- `storageObjectKey` (String - Caminho remoto no Firebase Storage após upload)
- `remoteObjectKey` (String - Caminho privado no Firebase Storage após upload; URLs temporárias são geradas somente após autorização)
- `gpsLat` / `gpsLng` (Coordenadas capturadas no browser, independentes da foto)

> **Nota sobre `orphaned`**: Arquivo local que não está mais associado a uma operação válida na fila ou que falhou de forma irrecuperável e aguarda limpeza controlada para não inflar o armazenamento do dispositivo.

## Auditoria, Privacidade e LGPD

- Dados são particionados por `userId` e `projectId` no armazenamento local. Logout, troca de usuário e revogação confirmada disparam limpeza segura do cache não autorizado, preservando apenas operações que precisem de revisão administrativa em área isolada e inacessível ao fluxo operacional.
- Revogação não pode ser detectada durante ausência total de rede. Permissão cacheada representa somente o último estado conhecido e nunca autoriza consolidação no servidor.
- CPF, salários, assinaturas, localização, notas fiscais e documentos são acessíveis apenas aos módulos e perfis que necessitem deles. Listagens comuns usam dados minimizados.
- Objetos do Storage são privados; não se persistem URLs públicas permanentes. Downloads dependem de autorização atual e usam referências ou URLs temporárias.
- Deve existir trilha de auditoria append-only para ações críticas, contendo ator, obra, entidade, ação, `operationId`, timestamps do dispositivo e servidor e resultado, sem registrar payloads sensíveis desnecessários.
- A empresa deve definir base legal, finalidade, prazo de retenção, procedimento de correção/exclusão quando aplicável, atendimento ao titular, backup e resposta a incidentes antes da produção.
- Logs técnicos não devem conter CPF, assinatura, tokens, imagens ou conteúdo integral de documentos.
