# Fluxos de Usuário e Navegação - SIGO

Este documento descreve passo a passo como o usuário vai interagir com as principais telas do aplicativo.

## 1. Login e Autenticação e Seleção de Obra
- **Tela de Login:** E-mail e senha.
- **Validação de Identidade:** O Firebase Auth valida quem é o usuário.
- **Redirecionamento Inteligente (RBAC Multiobra):** O sistema consulta `collectionGroup("members")`, limitada ao próprio UID pelas Security Rules, para descobrir os vínculos ativos. A fonte de verdade permanece `projects/{projectId}/members/{userId}`. Então decide o fluxo:
  - **0 obras disponíveis:** Exibe a mensagem "Nenhuma obra disponível" e bloqueia acesso a qualquer módulo operacional.
  - **1 obra disponível:** Seleciona a obra automaticamente, carrega os `allowedModules` daquela obra e monta o Dashboard.
  - **2 ou mais obras disponíveis:** Exibe uma tela de "Seleção de Obra". O usuário escolhe a obra de trabalho atual.
- **Troca de Obra (Contexto):** Se o usuário decidir trocar de obra no meio do expediente (ex: sair da Obra A para a Obra B), os módulos disponíveis na interface (`allowedModules`) são recalculados instantaneamente. Um módulo permitido apenas na Obra A desaparecerá imediatamente ao entrar na Obra B.

## 2. Dashboard Principal e Estado de Sincronização
Inspirado no "Conecta CNX", operando primariamente como um PWA (Progressive Web App).
- **Menu Lateral Escuro (Sidebar):**
  - Módulos dinâmicos baseados no `allowedModules` (RBAC).
- **Indicador de Sincronização (Área Crítica de UX):** No topo da tela, o usuário sempre tem a visibilidade real de conectividade:
  - `Online — Tudo sincronizado`: Conexão com Firebase verificada (não apenas `navigator.onLine`).
  - `Offline — X operações aguardando sincronização`: Os dados foram salvos no dispositivo (IndexedDB) e a fila local de eventos está crescendo. Ninguém mais no servidor vê esses dados ainda.
  - `Sincronizando — X de Y`: O Sync Engine está enviando anexos e resolvendo operações idempotentes.
  - `Falha / Rejeitada — X operações não puderam ser sincronizadas`: Exige ação do usuário (retry para falhas, resolução para conflitos, ou ciência/revisão administrativa para acessos revogados).
- **Área Central (Main Content):**
  - Cards grandes de atalho para ações rápidas.
  - O usuário pode fechar o PWA a qualquer momento. Operações na fila (`pending`) não serão perdidas. Ao reabrir o PWA e ter rede, o Sync Engine retoma.
## 3. Preparar Obra para Uso Offline
*Contexto: O encarregado está no escritório com Wi-Fi e vai para uma área da obra sem cobertura.*
1. Usuário acessa o sistema (online).
2. Seleciona a **Obra (Projeto)** desejada.
3. Clica em **"Preparar para Uso Offline"**.
4. O sistema verifica a *membership* ativa e identifica quais são os **módulos autorizados** daquela obra específica.
5. O sistema baixa e cacheia SOMENTE os dados essenciais referentes aos módulos permitidos:
   - **Se possui RH:** Equipes, trabalhadores, lotes e últimas alocações relevantes.
   - **Se possui Estoque:** Materiais, lotes, fornecedores e último saldo confirmado.
   - **Se possui Qualidade:** Lotes, etapas e templates de checklist.
   - **Se possui EPI:** Trabalhadores e catálogo de EPI.
   - **Permissões Base:** Dados do usuário, acesso à obra e memberships locais em cache.
6. Mostra uma barra de progresso do download (IndexedDB).
7. Confirma visualmente: "Obra pronta para uso offline".

> **POLÍTICA DE INVALIDAÇÃO DE CACHE:** O IndexedDB é particionado por usuário, obra e módulo. Ao logout, troca de conta ou confirmação online de revogação, o app elimina dados de leitura não autorizados. Operações `authorization_rejected` e seus anexos ficam isolados da navegação operacional e preservados apenas para revisão administrativa, conforme retenção definida. Sem conexão, o dispositivo não consegue conhecer imediatamente uma revogação; nenhuma operação offline é consolidada sem revalidação no backend.

> **Nota Crítica:** Se a obra nunca tiver sido preparada anteriormente, determinadas funções podem não estar disponíveis quando o primeiro acesso ocorrer sem internet.

## 4. Fluxos de Materiais (Almoxarifado Central e Lotes)

### 4.1 Recebimento de Materiais (Almoxarifado Central)
*Contexto: Chegou material na obra acompanhado de Nota Fiscal.*
1. Usuário acessa **Estoque** -> **Novo Recebimento (Compra)**.
2. Seleciona o **Fornecedor** e informa dados da Nota (ex: Número).
3. Adiciona os **Itens da NF** (Material, Quantidade, Valor Unitário, Valor Total). Pode haver múltiplos materiais em uma mesma NF.
4. **Carimbo Fotográfico (Obrigatório):** Tira foto da NF/Materiais (com GPS e Horário).
5. **Fluxo Offline/Sincronização:** O recebimento fica na fila local com status `pending`. Nenhum saldo oficial é alterado, nenhum custo médio é recalculado e a Conta a Pagar não é criada oficialmente.
6. Ao sincronizar, o servidor: consolida os itens gerando as movimentações, atualiza o saldo confirmado, recalcula o custo médio e gera a obrigação financeira (Conta a Pagar). O recebimento é salvo no backend com estado de negócio **confirmado** (a operação local passa para `synced`).

### 4.2 Saída/Requisição para o Lote (Casa)
*Contexto: O pedreiro precisa de 10 sacos de cimento na Casa 12.*
1. Usuário acessa **Estoque** -> **Nova Saída (Requisição)**.
2. Seleciona o **Lote de Destino** (ex: "Casa 12").
3. Seleciona o material (Cimento) e a quantidade (10 sacos).
4. **Fluxo de Dupla Confirmação:** O Almoxarife confirma a saída e o pedreiro assina digitalmente no celular atestando que retirou o material.
5. O sistema registra uma **movimentação local pendente** na fila (`local_sync_queue`). Uma saída feita offline NÃO é uma baixa oficial. A interface exibe um saldo estimado (`estimatedLocalQuantity = confirmedQuantity + pendingLocalDelta`).
6. Quando a conexão retorna, o Sync Engine tenta validar a operação de forma concorrente no servidor.
   - Se o saldo real (`confirmedQuantity`) permitir, o servidor usa o `averageUnitCost` oficial no instante da consolidação, cria a movimentação histórica salvando esse snapshot, e apropria o custo exato ao orçamento da Casa 12. O custo médio eventualmente cacheado no dispositivo não é usado para confirmar a saída. O saldo é atualizado.
   - Se o saldo real não permitir (ex: outro usuário zerou o item simultaneamente), a operação passa para `conflict` e o usuário é notificado.
## 5. Fluxo Crítico: Validação de Qualidade e Cronograma (Por Lote)
*Contexto: O mestre de obras terminou as paredes de uma casa e quer dar a etapa como concluída.*
1. Usuário acessa o módulo **Validação (Qualidade)**.
2. Seleciona o **Lote** específico (ex: "Casa 12").
3. Abre o Cronograma/Checklist da etapa atual (ex: "Alvenaria").
4. Preenche as perguntas do checklist (ex: "Paredes no prumo? [Sim/Não]").
5. **Comprovação Fotográfica (Obrigatório):**
   - Clica em "Anexar Foto da Etapa Concluída".
   - Tira a foto do serviço. O app aplica o **Carimbo de GPS, Data e Hora**.
6. Assina digitalmente na tela do celular.
7. Clica em "Aprovar Etapa".
8. **Fluxo Offline/Sincronização:** 
   - A operação entra na `local_sync_queue` com status `pending` (incluindo respostas, assinatura e fotos em formato Blob). A interface exibe um indicador local de pendência.
   - A operação não é considerada concluída até o Sync Engine enviar todos os arquivos e dados lógicos de forma unificada. Quando isso ocorre com sucesso, o servidor salva o checklist com status de negócio `aprovado` (estado confirmado) e a operação local passa para `synced`.
## 6. Fluxo Específico: Visão 360 do ADM (Gestão por Lote e Financeiro)
*Contexto: O Engenheiro/ADM quer ver o andamento e a saúde financeira de uma casa específica.*
1. ADM acessa o módulo **Administração**.
2. Seleciona o **Mapa de Lotes** e clica em um Lote (ex: "Casa 05").
3. O painel exibe de forma consolidada:
   - **Documentação:** Alvarás, plantas e licenças.
   - **Progresso:** % do cronograma físico executado.
   - **Mão de Obra Alocada:** Quais profissionais trabalharam no lote.
   - **Painel Financeiro do Lote:**
     - **Custo Total Atual:** Soma do custo de materiais + valor diário dos profissionais alocados + custos de documentação (taxas).
     - **Visão Financeira Separada:** Mostra custos apropriados ao lote, despesas diretamente vinculadas ao lote, pagamentos realizados e compromissos globais da obra. Uma compra central continua sendo obrigação global mesmo quando seus materiais são posteriormente consumidos por um lote; eventual rateio é identificado como gerencial.
   - **Filtros e Pesquisa:** O ADM pode usar filtros no topo da tela (Data de Vencimento, Fornecedor, Status da Conta) para refinar os gastos do lote e gerar relatórios.

## 7. Fluxo Crítico: Lista de Chamada (RH)
*Contexto: Início do expediente no canteiro.*
1. Usuário acessa **Gestão de Pessoas -> Lista de Chamada**.
2. Seleciona a Equipe (ex: "Equipe de Alvenaria") e o Lote de destino (ex: "Casa 15").
3. Vê a lista de membros da equipe (Nome e Cargo).
4. Para cada membro, há um botão *toggle* rápido: [Presente] / [Falta].
5. Clica em "Salvar Chamada".
6. **Apropriação Automática e Histórica:** A lista de presença vira uma **chamada registrada localmente**. A operação entra na `local_sync_queue` carregando o snapshot do custo diário e da política de cálculo vigente na obra. O divisor e o arredondamento são configuráveis e validados pela área contábil; 30 dias é apenas o padrão inicial para contratos mensais. Somente após a validação do Sync Engine ela se torna uma **chamada sincronizada** (confirmada no backend).

## 8. Fluxo Crítico: Ficha de EPI (Controle de Equipamentos)
*Contexto: O trabalhador precisa receber uma nova bota de segurança.*
1. O Almoxarife (ou Técnico de Segurança) acessa **Controle de EPI**.
2. Seleciona o profissional (ex: "João - Pedreiro") e o item (ex: "Bota CA 1234").
3. **Fluxo de Dupla Confirmação:**
   - O Almoxarife registra a entrega no seu app.
   - O trabalhador (João) recebe uma notificação no app dele e clica em "Confirmar Recebimento".
   - **Plano de Contingência:** Como muitos operários não usam smartphone na obra, o Almoxarife usa a "Assinatura Manual", e João assina com o dedo diretamente na tela do celular do Almoxarife para atestar o recebimento.
4. O sistema gera a Ficha de EPI digital com versão do termo, identificação das partes, método de confirmação, timestamps, integridade do artefato e trilha de auditoria. A assinatura desenhada é uma evidência e não uma garantia jurídica isolada.

---
## Perguntas Abertas (Para sua revisão)
> [!NOTE]
> A confirmação no mesmo aparelho é adotada como contingência operacional para trabalhadores sem smartphone. Antes do uso formal, a empresa deve validar o termo, a retenção e o conjunto de evidências com as áreas jurídica e trabalhista.
