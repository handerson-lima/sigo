# Plano de Projeto: SIGO - Sistema Inteligente de Gestão de Obra

Este documento descreve a estrutura e os módulos planejados para o aplicativo de gerenciamento de obras.

## Arquitetura e Tecnologias
- **Frontend:** Flutter & Dart (Web App)
- **Backend/Banco de Dados:** Firebase (Firestore para dados, Firebase Storage para fotos e documentos)
- **Processamento Transacional:** Cloud Functions for Firebase ou Cloud Run, responsável por comandos críticos, idempotência, autorização, transações Firestore, cálculos e coordenação de anexos. O cliente não consolida estoque, custos ou financeiro diretamente.
- **Design/UI:** Semelhante ao "Conecta CNX" (tema escuro na barra lateral de navegação, design limpo, espaçoso e focado no conteúdo da página principal).
- **Responsividade (Mobile-First):** O layout deve se adaptar perfeitamente a smartphones, pois será intensamente utilizado diretamente nos canteiros de obras.

## Módulos da Primeira Versão (V1)

O sistema contará com um Dashboard inicial para seleção e acompanhamento rápido, dividindo as operações nos seguintes módulos essenciais:

### 1. Estoque e Custos
Controle rigoroso dos materiais no canteiro de obras. O saldo atual de cada material (`confirmedQuantity`) é uma materialização baseada em um **livro-razão histórico** de movimentações. O sistema não permite overwrites diretos no saldo.
- **Recebimento de Materiais:** Registro de compras (Notas Fiscais), podendo conter múltiplos itens. Exige-se **registros fotográficos** das notas fiscais e/ou materiais entregues (com carimbo visual, GPS, data e hora). O valor dos itens (`itemsAmount`) e o valor total da nota (`totalAmount`) são controlados separadamente, suportando futuras adições de fretes ou descontos.
- **Movimentações de Estoque:** Entradas, saídas para lote, ajustes e devoluções. Toda mudança de saldo gera uma movimentação auditável. Ajustes manuais de estoque (positivos ou negativos) exigem **motivo registrado**. Evidências devem ser armazenadas quando aplicáveis, e sua obrigatoriedade depende de uma política específica ainda pendente; saldo nunca é corrigido por overwrite silencioso.
- **Custo Médio e Apropriação:** O custo médio unitário é recalculado a cada entrada confirmada. O cálculo é: `(valorEstoqueAnterior + valorEntrada) / (quantidadeAnterior + quantidadeEntrada)`. Quando um material sai para um lote, salva-se um "snapshot" do custo atual, que se torna histórico e **não é recalculado retroativamente**.
- **Regras Específicas de Custo e Movimentação:**
  - **Ajuste Negativo:** Usa o `averageUnitCost` confirmado imediatamente antes da consolidação do ajuste.
  - **Ajuste Positivo:** Não assume custo zero automaticamente. Exigirá uma política de valoração específica.
  - **Devolução de Material do Lote:** Quando um material não utilizado retorna, a devolução referencia a transação de saída original (`sourceTransactionId`) e preserva o custo histórico daquela saída. Devolução difere de "Estorno", que é a neutralização de um erro operacional.
- **Diferenciação de Custos:** A "compra" gera uma obrigação financeira global da obra. O "custo do lote" ocorre exclusivamente pela saída documentada do almoxarifado para aquela unidade específica.
- **Alertas:** Níveis mínimos de estoque para evitar paradas na obra.

**Decisões da V1:**
- **Evidências de ajustes:** foto e justificativa são obrigatórias em todo ajuste manual; o administrador pode exigir evidências adicionais por política da obra.
- **Ajuste positivo:** exige custo unitário informado e justificativa, sujeito a confirmação por perfil autorizado. Nunca assume custo zero. O valor informado participa do novo custo médio.
- **Frete, despesas e descontos:** são rateados proporcionalmente pelo valor bruto dos itens da compra e compõem o custo de entrada. Tributos recuperáveis ficam fora do custo; tributos não recuperáveis entram no rateio. A classificação tributária deve ser configurada e validada pela área contábil.

### 2. Recursos Humanos (RH) - Mão de Obra
Gestão das pessoas e equipes no canteiro.
- **Cadastro de Profissionais:** Registro detalhado dos trabalhadores, cargos e funções (pedreiro, ajudante, mestre de obras) e **Regime de Contratação** (CLT, PJ, Avulso). O sistema permite cadastrar o custo base do funcionário e os custos adicionais (ex: encargos trabalhistas para CLT), gerando um "Custo Diário Total" real.
- **Equipes e Frentes de Trabalho:** Alocação de profissionais em tarefas específicas.
- **Lista de Chamada Diária:** O encarregado bate o ponto da equipe no app, informando em qual lote a equipe vai atuar.
- **Apropriação de Custo:** Com base na presença e no "Custo Diário Total", calculado por política versionada da obra, o sistema apropria o custo gerencial por casa. O divisor 30 é um padrão inicial configurável, não uma regra universal.
- **Controle de Presença (Ponto):** Lista de chamada diária.

### 3. Controle de EPI
Garantia de segurança e conformidade trabalhista.
- **Ficha de EPI:** Registro de entrega de Equipamentos de Proteção Individual para cada profissional (capacete, botas, luvas).
- **Assinaturas/Baixas:** Controle rigoroso de devoluções e substituições por desgaste.
- **Evidência e Integridade:** Cada registro preserva versão do termo, método de confirmação, responsável, timestamps, integridade do artefato e trilha de auditoria. A assinatura desenhada na tela é evidência e não garantia jurídica isolada.

### 4. Validação (Qualidade e Cronograma)
Acompanhamento físico e garantia de conformidade para o Habite-se/Caixa.
- **Controle de Qualidade:** Checklists por etapa construtiva (ex: fundação validada, alvenaria no prumo).
- **Cronograma Físico:** Acompanhamento visual da evolução da obra (planejado vs. realizado), exigindo **registros fotográficos** de comprovação dos serviços executados (com carimbo visual e metadados de georreferenciamento, data e hora salvos para auditoria e prestação de contas com a Caixa/Bancos).
- **Aprovações:** Liberação de frentes de serviço após a validação da etapa anterior.

### 5. ADM (Administração e Documentação)
Centralização da burocracia do canteiro.
- **Gestão de Documentos:** Armazenamento seguro de alvarás, projetos, plantas e documentação ambiental/legal.
- **Manuais:** Acesso rápido ao manual do sistema e procedimentos operacionais padrão.

### 6. Financeiro e Compras (NOVO)
Controle de fornecedores e fluxo de pagamento atrelado ao estoque e aos lotes.
- **Cadastro de Fornecedores:** Base de contatos e CNPJ das empresas que fornecem material.
- **Contas a Pagar:** Quando um **recebimento (compra/NF)** é confirmado pelo servidor, o sistema permite gerar uma ou mais obrigações financeiras (Contas a Pagar) atreladas àquela compra. A dívida nasce da compra global e não da movimentação isolada de um dos itens.
- **Visão Financeira por Lote:** Painel consolidado mostrando os pagamentos efetuados e a efetuar específicos de cada lote. O painel deve somar:
  - Custo de materiais alocados.
  - Custo da mão de obra (profissionais alocados e horas trabalhadas).
  - Custos administrativos/documentação daquele lote.
- **Separação contábil e gerencial:** Compra central gera obrigação financeira global. A saída do estoque gera custo apropriado ao lote, mas não transforma automaticamente a conta do fornecedor em dívida daquele lote. O painel apresenta separadamente custos apropriados, despesas diretamente vinculadas, compromissos globais e eventuais rateios gerenciais.
- **Filtros de Pesquisa:** Capacidade de refinar a visão financeira por data, fornecedor, status de pagamento e lote específico.

---

## Estratégia Arquitetural: Flutter Web PWA Offline-First

O SIGO será desenvolvido **exclusivamente em Flutter Web**, sendo **Mobile-First** e operando diretamente pelo navegador ou instalado como **PWA (Progressive Web App)** na tela inicial. **NÃO haverá aplicativos nativos (Android/iOS)**. Esta arquitetura foi escolhida para facilitar o deploy e a adoção, mas exige cuidados estritos com a intermitência de rede no canteiro.

A aplicação não dependerá exclusivamente do cache automático do Firestore. A arquitetura será baseada em quatro pilares fundamentais:

### A. Cache de Dados (Leitura)
Antes de ir a campo, ao acessar a aplicação com internet, o sistema armazenará no cache do navegador (ex: IndexedDB/WebStorage) os dados essenciais para operação offline:
- Lotes, Trabalhadores, Equipes, Materiais, Fornecedores, Templates de checklist, EPIs e Permissões do usuário.
- O sistema indicará que "os dados necessários para iniciar o trabalho offline" estão prontos.

### B. Fila Local de Operações (Gravação)
As ações realizadas offline (Chamadas, Requisições, Validações) NÃO são gravadas diretamente no Firestore, mas em uma **Fila de Operações Local (IndexedDB)**. Cada registro na fila possui:
- `operationId` (identificador único e idempotente gerado no cliente).
- `operationType` e payload estruturado.
- Data/hora local, usuário e metadados de dependência (anexos).
- Status de sincronização (ex: pendente, falha).
- Tentativas de retry.

### C. Armazenamento Local de Arquivos (Anexos)
Fotos, assinaturas e PDFs gerados offline não farão upload imediato. Ficarão persistidos em **IndexedDB** ou File System API do navegador web. O envio (upload) será gerido pela Fila de Operações, e os caminhos locais (blob URLs) serão usados temporariamente na UI até a confirmação do upload.

### D. Sync Engine e Resolução de Conflitos
Uma camada em background monitorará a conectividade real (não apenas `navigator.onLine`) verificando a latência com o servidor. O Sync Engine irá:
1. Ler operações pendentes da fila.
2. A ordem de sincronização depende do tipo de operação e de suas dependências.
3. Sincronizar o dado estruturado via chamadas idempotentes e efetuar upload de anexos conforme necessário.
4. Uma operação só recebe status `synced` quando todos os seus componentes obrigatórios estiverem confirmados.

O Sync Engine envia **comandos** a endpoints transacionais no backend. Cloud Functions/Cloud Run registra o `operationId`, revalida membership e módulo, executa transações Firestore e retorna o mesmo resultado em retries. Security Rules continuam como barreira obrigatória, mas não substituem validação e regras de negócio no servidor.

**Regras de Conflitos e Duplicidade:**
- **Idempotência Rigorosa:** A conexão cair durante um envio não duplicará registros no financeiro ou estoque, pois o servidor reconhecerá o `operationId`. Um *retry* de um recebimento que o servidor já consolidou apenas retornará o sucesso prévio (sem duplicar saldo, criar nova movimentação ou nova conta a pagar).
- **Snapshots históricos:** Chamadas de RH preservam o custo e a versão da política vigentes no momento do apontamento local. Saídas de estoque não confiam no custo médio cacheado: o backend utiliza o `averageUnitCost` oficial no instante da consolidação e grava esse valor como `unitCostSnapshot`. Depois de confirmados, ambos os snapshots são imutáveis e nunca recalculados retroativamente.
- **Resolução de Recebimento:** Um recebimento criado offline fica na fila local com status `pending`. Não altera saldo oficial, nem cria Conta a Pagar, nem afeta o custo médio. Não se deve criar um documento oficial no Firestore com status de negócio "pending_sync". Ao sincronizar: o backend revalida autorização, resolve idempotência, persiste o recebimento oficialmente, consolida os itens gerando as movimentações históricas, atualiza o `confirmedQuantity`, recalcula o custo médio e gera a obrigação financeira. Só então a operação local vai para `synced`.
- **Resolução de Saídas (Estoque):** Uma saída offline NÃO é uma baixa oficial. A interface exibe um saldo estimado (`estimatedLocalQuantity = confirmedQuantity + pendingLocalDelta`). No backend, a validação é **indivisível/concorrente**: o servidor checa a saída contra o saldo confirmado exato daquele milissegundo. Se dois dispositivos tentarem baixar o mesmo estoque e só houver saldo para um, o segundo receberá `conflict` (Estoque Insuficiente) sem negativar o sistema de forma invisível.

**Limitações Web/PWA e Mitigações:**
- Armazenamento volátil (eviction) pelo sistema operacional (iOS Safari limpa dados web mais agressivamente): Orientar usuários a fixar como PWA na Home e não deixar pendências por muitos dias.
- Sincronização em background: Web tem restrições rigorosas (Background Sync API não é universal). O app deve tentar sincronizar ao ser reaberto se o SO tiver suspendido o PWA.
- Câmera e GPS web dependem de permissões de navegador que podem revogar. O GPS coletado pelo navegador será carimbado, mas não será tratado legalmente como à prova de fraudes de software de simulação local.

**Estados de Sincronização Exibidos (UX):**
O usuário sempre verá um indicador visual global:
- `Online — Tudo sincronizado`
- `Offline — X operações aguardando sincronização` (Neste estado, o usuário nunca deve achar que a informação já está no servidor).
- `Sincronizando — X de Y`
- `Falha — X operações não puderam ser sincronizadas` (com logs visíveis e botão de Retry/Conflito).
- Nenhum evento parcial (ex: formulário enviado, mas foto falhou) é considerado "sincronizado". Apenas a operação lógica completa (unidade de sincronização concluída) muda o status.

**Atualizações e Fechamento:**
- Operações sobrevivem ao fechamento do navegador ou bateria acabando, pois a Fila está em IndexedDB.
- Se o PWA (Service Worker) atualizar a versão da aplicação, a fila NÃO é limpa. Estruturas legadas deverão ser migradas pelo novo app.

### E. Estado Local vs Estado Confirmado
Para evitar ambiguidades, o sistema adota dois conceitos fundamentais para dados alterados:
- **estado local (`pending`)**: operação persistida no dispositivo antes da confirmação do servidor.
- **estado confirmado**: resultado aceito e persistido pelo backend.

Exemplos obrigatórios de interface:
- **Qualidade**: `aprovacao_pendente_sync` (local) vs `aprovada` (confirmada).
- **Estoque**: movimentação local pendente vs movimentação confirmada.
- **RH**: chamada registrada localmente vs chamada sincronizada.
- **Financeiro**: lançamento local pendente vs lançamento confirmado.

Os estados técnicos canônicos da fila são `pending`, `syncing`, `synced`, `failed`, `conflict` e `authorization_rejected`. `pending_sync` pode aparecer apenas como texto explicativo de UI e não é valor persistido.

### F. Versionamento e Migração do Armazenamento Local
- O schema local do IndexedDB possui versão.
- Novas versões do PWA podem exigir migration da estrutura local.
- As migrations devem preservar rigorosamente as operações e anexos pendentes.
- É proibido limpar automaticamente a fila para resolver incompatibilidades de schema.
- Qualquer falha de migration deve ser tratada explicitamente na interface.
## Permissões e Perfis de Acesso (RBAC Multiobra)
O sistema foi arquitetado para suportar acesso multiobra. A autorização efetiva considera a combinação de: **Usuário + Obra + Módulo**. 

### 1. Autenticação vs Autorização
- **Firebase Authentication:** Valida "Quem é o usuário?". O login bem-sucedido não concede automaticamente acesso a dados de obras.
- **Autorização SIGO:** Valida "O que este usuário pode fazer e em qual obra?". Um usuário pode ter módulos diferentes em obras diferentes.

### 2. Contexto de Obra Ativa (`activeProjectId`)
O `activeProjectId` representa somente a obra atualmente selecionada na interface e **NÃO** concede permissão. Antes de qualquer acesso a dados ou módulos, o sistema verifica se existe um *membership* (`project_memberships`) ativo para `userId + activeProjectId` e se o módulo solicitado está no array `allowedModules`.

No login, as obras acessíveis são descobertas com uma consulta `collectionGroup("members")` filtrada por `userId == request.auth.uid` e `active == true`. A subcoleção determinística continua sendo a única fonte de verdade; não existe coleção top-level paralela. Índices e Security Rules devem garantir que cada usuário consulte somente os próprios vínculos.

### 3. Integração RBAC com Offline-First
O funcionamento offline respeita a autorização, com os seguintes comportamentos definidos:
- Os *memberships* são armazenados localmente para permitir navegação offline.
- A permissão cacheada é apenas o último estado conhecido e NÃO substitui a validação do servidor.
- Durante a sincronização de operações da fila local (`pending`), as permissões são obrigatoriamente revalidadas no backend.
- Se o servidor recusar uma operação porque o usuário perdeu acesso (ex: revogação durante o período offline), a operação assume o estado `authorization_rejected`.
  - **Diferenciação:** Falha (`failed`) é um erro técnico potencialmente recuperável; Conflito (`conflict`) é erro de dados ou de negócio; Rejeição (`authorization_rejected`) ocorre estritamente porque o servidor identificou perda de autorização.
  - **Comportamento da UX:** A interface NÃO trata a rejeição como um erro comum. Ela impede retries automáticos ou manuais que seriam inúteis.
  - A operação permanece armazenada localmente (sem ser apagada automaticamente) preservando todas as evidências e anexos.
  - O usuário é informado claramente: *"Acesso removido. Esta operação não pôde ser sincronizada porque seu acesso à obra ou ao módulo foi revogado após o registro local."*
  - A interface permite acessar "Ver detalhes" para manter o registro disponível para diagnóstico e futura revisão administrativa ou restauração de acesso.

**Política de invalidação:** O cache local é particionado por usuário, obra e módulo. Ao logout, troca de conta ou confirmação online de revogação, dados de leitura não autorizados são eliminados. Operações rejeitadas e suas evidências ficam isoladas do uso operacional, somente para revisão administrativa e conforme prazo de retenção. Sem rede, a revogação não pode ser conhecida imediatamente; por isso, a autorização cacheada nunca permite consolidação e toda sincronização é revalidada no backend.

### 4. Segurança de Backend (Rules) e UI
Ocultar botões e menus na interface melhora a UX, mas não é mecanismo de segurança real. Um usuário mal-intencionado manipulando URLs ou APIs não pode acessar dados não autorizados.
A arquitetura prevê como requisito estrutural obrigatório, na fase de Segurança e Isolamento Multiobra (antes dos módulos operacionais), a implementação de:
- **Firestore Security Rules:** Proteção das coleções validando explicitamente os *memberships*.
- **Firebase Storage Security Rules:** Proteção do acesso e upload de arquivos por obra.
- Validações em chamadas críticas.

### 5. Auditoria, Privacidade e LGPD

- Objetos no Storage são privados e acessados por referência ou URL temporária após autorização; não serão persistidas URLs públicas permanentes para documentos, notas, fotos ou assinaturas.
- CPF, salários, localização, assinatura e documentos seguem minimização, acesso por necessidade e retenção definida pela empresa.
- Operações críticas geram trilha append-only com ator, obra, entidade, ação, `operationId`, timestamps e resultado, sem copiar dados pessoais sensíveis para logs técnicos.
- O armazenamento local é isolado por usuário e obra, com limpeza segura no logout e após revogação confirmada.
- Antes da produção, a empresa deve aprovar bases legais, finalidades, retenção, atendimento ao titular, backups e resposta a incidentes.

---

## Próximos Passos (Para sua aprovação)

> [!NOTE]
> O escopo está muito bem definido agora, focando no essencial para garantir que o canteiro de obras funcione sem falhas e custos invisíveis.

Podemos dar início à execução? Os primeiros passos técnicos serão:
1. Criar o projeto Flutter na pasta do workspace.
2. Inicializar o Firebase no projeto.
3. Montar a estrutura base da interface (Dashboard com barra lateral escura no estilo Conecta CNX).
