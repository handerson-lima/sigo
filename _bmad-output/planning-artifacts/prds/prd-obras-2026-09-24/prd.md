---
title: SIGO Obras
status: final
created: 2026-09-24
updated: 2026-09-24
---

# PRD: SIGO Obras
*Working title — confirm.*

> **Status do produto:** brownfield com a maior parte dos módulos implementada em desenvolvimento; **a implantação em produção não está autorizada** e é o principal bloqueador de lançamento (§6, §9 OQ-9).

## 0. Document Purpose

Este PRD consolida, em uma única fonte de requisitos de produto, o que os artefatos dispersos do SIGO Obras descrevem hoje: o `epics.md` vigente (Epics 8–11), os documentos em `docs/` (`task.md`, `implementation_plan.md`, `user_flows.md`, `data_model.md`, `politica.md`, `decisoes.md`, `plano-de-correcao-2026-09-15.md`, `presentation_summary.md`, `implantacao-c0-c6.md`, `validacao-c0-c6.md`) e as specs de módulos já implementados em `_bmad-output/specs/` e `_bmad-output/implementation-artifacts/`. Ele é destinado ao time de produto, aos donos de módulos e aos workflows que consomem o PRD (UX, arquitetura, epics/histórias, QA). A estrutura segue o vocabulário do Glossário; funcionalidades são agrupadas com requisitos funcionais numerados globalmente (`FR-N`) e requisitos não funcionais reunidos à parte. Premissas inferidas estão marcadas inline como `[ASSUMPTION]` e indexadas na §10.

**Relação com artefatos existentes.** Este documento não substitui nem duplica os artefatos técnicos; ele os referencia. UX já existe em `_bmad-output/planning-artifacts/ux-designs/ux-obras-2026-09-21/` (Gestão de Membros) e `.../ux-obras-2026-09-23/primeira-entrega/` (design system, shell, lotes e logo). A arquitetura já existe em `.../architecture/architecture-obras-2026-09-21/ARCHITECTURE-SPINE.md`, `.../architecture-modular-routing-2026-09-23/` e `.../architecture-epic-11-drill-down/ARCHITECTURE-SPINE.md`. O detalhe técnico (caminhos Firestore, Cloud Functions, versões de schema, migrações e decisões arquiteturais) vive no `addendum.md` desta pasta e **não** deve migrar para cá.

**Nota de rigor.** O SIGO é um produto brownfield: grande parte do código já existe e foi validada em desenvolvimento, mas **a implantação em produção não está autorizada** (ver §6 e §9). Este PRD descreve requisitos de produto; onde o código e a documentação divergem, a divergência está registrada em §9 Open Questions em vez de silenciada.

## 1. Vision

O SIGO — Sistema Inteligente de Gestão de Obra — é a plataforma operacional de construtoras e incorporadoras para gerir o canteiro com dados confiáveis e auditáveis. Ele reúne, num só lugar, a estrutura física da obra e suas equipes, o estoque central de materiais, as contas a pagar, o diário de obra com evidências fotográficas, o RH com chamada e custo de mão de obra, a conformidade de EPI (NR-6), a validação de qualidade por lote, fornecedores, compras com nota fiscal e a visão consolidada de custos por lote. Não é uma vitrine nem um painel gerencial decorativo: é a ferramenta de trabalho de quem está no campo e de quem administra do escritório.

O problema de negócio que ele ataca é o canteiro gerido no escuro. Construtoras e incorporadoras operam com informação dispersa entre planilhas, papel e aplicativos de mensagem, sem rastreabilidade de materiais e custos, sem prova documental de entregas e inspeções, sujeitas a perda de evidências, divergência de centavos, pagamento duplicado, passivos trabalhistas e acesso indevido a dados entre empresas. Canteiros raramente têm conectividade estável, o que torna qualquer registro digital frágil se a operação offline não for honesta e durável. O SIGO responde a isso com três compromissos que atravessam todos os módulos: **o servidor é a autoridade** (nenhuma regra de acesso ou consolidado confiado ao cliente), **o dinheiro e o histórico são exatos e imutáveis** (valores em centavos inteiros, sem exclusão física, correções auditadas) e **o offline nunca mente** (nenhuma operação é declarada "sincronizada" sem aceite integral do servidor).

Para a construtora, o resultado é controle operacional e financeiro com trilha de auditoria; para o operador em campo, é conseguir registrar o trabalho mesmo sem rede, sem risco de perder o que digitou; para o proprietário, é enxergar o custo real de cada lote e onde o dinheiro está sendo consumido. O SIGO é multi-tenant e server-authoritative por desenho: cada construtora vê apenas o seu escopo, e a confiança do produto depende de essa fronteira nunca vazar.

## 2. Target User

### 2.1 Jobs To Be Done

- **Dev global** — "Preciso administrar a plataforma inteira e resgatar usuários e dados, sem depender de vínculo em cada construtora." (funcional/operacional; suporte e recuperação)
- **Proprietário (Owner)** — "Quero ter a autoridade máxima da minha construtora e delegar admins, sem que ninguém se promova sozinho." (funcional/político)
- **Administrador da construtora** — "Preciso colocar a pessoa certa na parte certa da obra, com os módulos certos, e conseguir revogar acesso na hora." (funcional)
- **Administrador da obra** — "Preciso tocar a operação da minha obra — lotes, chamada, materiais — sem poderes que não me cabem." (funcional)
- **Membro comum / Operário** — "Preciso lançar o diário e o que fiz no canteiro, mesmo sem internet, e ter certeza de que não perdi nada." (funcional/contextual; sol, luvas, celular)
- **Encarregado** — "Preciso fechar a chamada do dia rapidamente e saber quanto de mão de obra foi gasto em cada lote." (funcional)
- **Almoxarife** — "Preciso registrar entrada e saída de material com fornecedor, nota e destino, sem furos de saldo." (funcional/integridade)
- **Técnico de segurança (EPI)** — "Preciso provar que entreguei o EPI certo, com termo assinado, e controlar validade do C.A." (funcional/legal)
- **Gestor de qualidade** — "Preciso vistoriar por lote com checklist e evidência fotográfica, e não deixar ninguém 'fechar' sem prova." (funcional/legal)
- **RH / Gestor** — "Preciso individualizar trabalhadores, chamada e custo real, para apropriar mão de obra por lote." (funcional)
- **Proprietário/gestor financeiro** — "Preciso ver o custo real por lote e onde está o passivo, em números que batem." (funcional/emocional; confiança)
- **Funcionário/colaborador** — objeto das rotinas de RH, EPI e chamada; não é usuário operacional do sistema.

### 2.2 Non-Users (v1)

- **Cliente final / comprador do imóvel** — o SIGO não é portal de vendas nem vitrine para o consumidor.
- **Corretor / imobiliária** — fora do escopo de operação de canteiro.
- **Órgãos externos** (Receita, SEFAZ, prefeituras) — o sistema registra NF-e e CPF/CNPJ, mas não se integra a esses órgãos nesta versão.
- **Usuário anônimo / não autenticado** — nenhum acesso operacional a dados de obra, estoque, financeiro ou arquivos.
- **Construtora não cadastrada** — o auto-cadastro de empresas não faz parte do fluxo; a criação de construtora é administrativa. `[ASSUMPTION]`

### 2.3 Key User Journeys

*Narrativas reconstruídas dos fluxos e personas já documentados (`ux-obras-2026-09-21/EXPERIENCE.md`, `ux-obras-2026-09-23/primeira-entrega/EXPERIENCE.md`, `docs/user_flows.md`). Personas são cenários de aceite, não pesquisa de usuário.*

- **UJ-1. Carla coloca Carneiro na obra para ele lançar o diário.**
  - **Persona + contexto:** Carla, administradora da construtora, no escritório (web/desktop); precisa liberar acesso antes do turno.
  - **Entry state:** autenticada, construtora ativa, em `/construtora/:cId/membros`.
  - **Path:** busca "Carneiro" por nome/e-mail → abre o detalhe do membro → toca **Atribuir** → escolhe o nó da Hierarquia Estrutural de destino → mantém papel **Operário** e módulos padrão `[diario]` → confirma.
  - **Climax:** vínculo confirmado via função de servidor; snackbar "Atribuído a {obra} como Operário."; o contador "N nós" atualiza; Carneiro passa a ver o nó no app dele.
  - **Resolution:** Carla volta à lista e pode trocar papel ou remover depois.
  - **Edge case:** se o membro estiver inativo na construtora, a UI bloqueia com erro `failed-precondition` e oferece o atalho **Ativar** (UJ real de José, operário desativado).

- **UJ-2. Carneiro registra o diário no canteiro e sincroniza.**
  - **Persona + contexto:** Carneiro, operário, no celular, em área sem sinal.
  - **Entry state:** já autenticado em sessão anterior; obra liberada no seletor.
  - **Path:** abre o app → seleciona a obra → abre **Diário** → informa clima, efetivo por função e observações → tira foto → confirma.
  - **Climax:** o app mostra **"Salvo no dispositivo"** e os bytes da foto estão persistidos localmente, mesmo offline.
  - **Resolution:** ao reconectar, a fila retoma sozinha e o indicador chega a **"Tudo sincronizado"** somente após aceite do servidor.
  - **Edge case:** se o segundo anexo falhar, o estado é **"Falha"** com ação de reenvio — nunca um sucesso falso.

- **UJ-3. Ana identifica e atualiza um lote.**
  - **Persona + contexto:** Ana, engenheira/gestora de campo, dentro de um loteamento.
  - **Entry state:** autenticada, com acesso à construtora e ao contexto do loteamento.
  - **Path:** navega Loteamento → Quadra → Lote → abre a edição do lote → altera fase e status → confirma.
  - **Climax:** o card do lote reflete a nova fase/status (ex.: "No prazo" → "Atrasado").
  - **Edge case:** envio incerto/timeout mantém a digitação e **não** declara o lote salvo até um recibo real do banco (CAP-3 da primeira entrega).

- **UJ-4. Otávio troca o logo da construtora.**
  - **Persona + contexto:** Otávio, proprietário/owner, identidade visual da empresa.
  - **Entry state:** autenticado e autorizado (Dev/Proprietário/Admin da construtora).
  - **Path:** abre **Gerenciar logo** → seleciona PNG/JPEG dentro do limite → confirma.
  - **Climax:** a imagem do card é substituída pela logo, mantendo nome e proporção; o upload ocorre por ciclo transacional com staging e revisão incrementada.
  - **Edge case:** arquivo acima do limite é rejeitado rapidamente; em falha comprovada a logo anterior é preservada. Admin de obra **não** herda essa capacidade.

- **UJ-5. Davi aprova uma solicitação de acesso.**
  - **Persona + contexto:** Davi, dev global, onboarding de novo usuário.
  - **Entry state:** autenticado no painel dev.
  - **Path:** vê o card de alertas com solicitação pendente → abre → **Aprovar**.
  - **Climax:** a conta Auth é criada e vinculada; o admin solicitante recebe notificação in-app com senha provisória.
  - **Edge case:** tentativa de aprovação por não-dev retorna `permission-denied`; aprovação duplicada é idempotente.

- **UJ-6. Encarregado fecha a chamada do dia.**
  - **Persona + contexto:** Marcos, encarregado, no campo, com luvas e sob sol; alvos táteis precisam ser grandes.
  - **Entry state:** autenticado, obra ativa, módulo `rh`.
  - **Path:** abre **Chamada** → **Marcar Todos Presentes** → ajusta faltas/meio-período → rateia o efetivo entre dois lotes → confirma.
  - **Climax:** a chamada fecha e o custo de mão de obra é apropriado aos lotes na mesma soma (presente 100%, meio 50%, falta 0).
  - **Edge case:** uma segunda chamada para a mesma obra/data é bloqueada.

- **UJ-7. Rita registra saída de material para um lote.**
  - **Persona + contexto:** Rita, almoxarife, estoque central da construtora.
  - **Entry state:** autenticada, módulo `estoque`/`almoxarifado`.
  - **Path:** seleciona material → quantidade → destino obra → lote com apropriação → confirma.
  - **Climax:** o saldo central é decrementado por comando transacional idempotente; o histórico registra o destino e a apropriação.
  - **Edge case:** quantidade maior que o saldo gera conflito e nenhuma baixa parcial.

- **UJ-8. Otávio acompanha a visão 360 de um lote.**
  - **Persona + contexto:** Otávio, proprietário, decisão de custo.
  - **Entry state:** autenticado, módulo `adm` (Financeiro).
  - **Path:** abre o painel executivo → vê os quatro cubos (Materiais, Mão de Obra, Despesas Diretas, Rateio Indireto) e Orçado vs. Realizado → faz drill-down no lote.
  - **Climax:** extrato nominal com ΔCents e rateio sem discrepância.
  - **Edge case:** com mão de obra ainda não fechada, o painel mostra pago vs. passivo sem inferir custo ausente.

- **UJ-9. Usuário navega o drill-down Loteamento → Quadra → Lote → Setor → Equipe.**
  - **Persona + contexto:** qualquer usuário autorizado, após o login.
  - **Entry state:** autenticado, construtora ativa.
  - **Path:** o dashboard lista Loteamentos → clica em um Loteamento → Quadras → Lotes → Setores → Equipes, com breadcrumbs e URL acompanhando.
  - **Climax:** chega ao nó correto, vê os responsáveis atribuídos e restaura a posição por deep link/F5.
  - **Edge case:** nó de outra construtora ou sem vínculo no nó/ancestral tem leitura negada pelas regras.

- **UJ-10. Ana cadastra um novo lote.**
  - **Persona + contexto:** Ana, engenheira de campo, abre uma nova frente de execução.
  - **Entry state:** autenticada, dentro de uma Quadra do loteamento.
  - **Path:** abre o Mapa de Lotes → **Novo Lote** → informa nome e fase/status inicial → confirma.
  - **Climax:** o novo lote aparece no mapa e no drill-down, disponível para apropriação de material e chamada.
  - **Edge case:** campos vazios/whitespace são rejeitados; membro comum não vê a ação de criação.

- **UJ-11. Paulo abre as vistorias de qualidade do lote.**
  - **Persona + contexto:** Paulo, gestor de qualidade, precisa registrar a inspeção de uma etapa.
  - **Entry state:** autenticado, dentro de um Lote, com módulo `validacao`.
  - **Path:** abre **Vistorias** → escolhe o template da disciplina → percorre os itens → marca um item como não conforme e anexa a foto de evidência → conclui.
  - **Climax:** a vistoria fica concluída e imutável; o lote transita de status; a não conformidade tem prova.
  - **Edge case:** item não conforme sem foto não pode ser concluído.

## 3. Glossary

Termos de domínio usados por todo o PRD e que os artefatos a jusante devem reproduzir literalmente. Sinônimos não são permitidos. No corpo do documento, **Admin** é a forma curta aceita para *Administrador da construtora* (quando sem qualificador) e *Administrador da obra* (quando qualificado "da obra"); **Dev** é a forma curta de *Dev global*.

- **Construtora** — organização (tenant) que agrupa obras, estoque central, financeiro, funcionários, fornecedores e membros. Fronteira de isolamento de dados. `construtoras/{cId}`.
- **Dev global** — perfil de plataforma com administração global, sem exigir vínculo por obra; única autoridade que concede/rebaixa o papel de Proprietário. Reconhecido por `dev_roles/{uid}.isActive`.
- **Proprietário (Owner)** — máxima autoridade dentro de uma construtora, acima dos admins; implica privilégios de admin da construtora. Só o Dev global o altera.
- **Administrador da construtora** — administra perfis, vínculos, estoque, financeiro e arquivos no escopo da própria construtora; nunca concede Dev. Dispensa vínculo por nó da própria construtora.
- **Administrador da obra (`obraAdmin`)** — autoridade restrita ao escopo de uma obra; sem poderes globais e sem acesso automático ao financeiro central.
- **Membro comum / Operário** — acesso apenas a vínculos ativos e módulos explicitamente permitidos; módulo vazio significa sem acesso (fail-closed).
- **Vínculo** — associação de um usuário a uma construtora ou a um nó da Hierarquia Estrutural, com papel e módulos. Sujeito a `isActive`.
- **Módulo** — permissão granular de acesso a uma área. Cânônicos: `diario`, `lotes`, `estoque`, `rh`, `epi`, `validacao`, `adm`, `compras`. Aliases legados são normalizados: `rdo`→`diario`, `almoxarifado`→`estoque`, `recursos_humanos`→`rh`, `qualidade`→`validacao`, `financeiro`→`adm`.
- **Hierarquia Estrutural** — árvore espacial canônica **Loteamento → Quadra → Lote → Setor → Equipe**, usada para navegação (drill-down), deep linking e atribuição de responsabilidade por nó.
- **Loteamento** — raiz canônica da Hierarquia Estrutural; agrupador de Quadras. Substitui o contexto genérico de "Obra" como raiz de navegação e de atribuição de vínculos.
- **Quadra** — subdivisão de um Loteamento; agrupa Lotes.
- **Lote** — unidade física de execução; recebe apropriação de material, mão de obra e despesa. Tem `fase` e `status`.
- **Setor** — subdivisão de um Lote (frente de serviço); agrupa Equipes.
- **Equipe** — grupo de trabalho alocado a um nó da Hierarquia Estrutural; tem responsável.
- **Obra** — conceito legado de contexto operacional, consolidado na raiz (**Loteamento**) da Hierarquia Estrutural. Identificadores existentes em `construtoras/{cId}/obras/{oId}` permanecem como contexto dos módulos já implementados (diário, almoxarifado, financeiro) durante a migração.
- **Diário de obra** — registro periódico do canteiro: clima, efetivo por função, observações e anexos.
- **Anexo** — arquivo associado a um registro (foto de diário, evidência de qualidade, comprovante, termo), guardado como referência privada com ID estável e integridade.
- **Almoxarifado / Estoque central** — estoque único e compartilhado por construtora (`construtoras/{cId}/materiais`), com movimentações que apontam destino (obra/lote).
- **Material** — item estocável com unidade, saldo confirmado e histórico de movimentações.
- **Movimentação** — entrada ou saída de material; confirmada transacionalmente no servidor, idempotente e não excluível.
- **Despesa** — conta a pagar da construtora, com categoria, valor em centavos e vínculo opcional a lote/obra.
- **Parcela** — divisão de uma despesa ou compra; a soma das parcelas deve equivaler ao total.
- **Compra / NF** — documento de aquisição com fornecedor corporativo obrigatório e chave NF-e de 44 dígitos.
- **Fornecedor** — cadastro corporativo único da construtora, validado por CPF/CNPJ (módulo-11).
- **EPI** — Equipamento de Proteção Individual; item de catálogo com C.A., vida útil e eventos de entrega/devolução/descarte.
- **C.A.** — Certificado de Aprovação do EPI; tem validade e gera alerta de vencimento.
- **Chamada diária** — registro nominal de presença (`presente`/`falta`/`meio-periodo`) por funcionário, com rateio por lote.
- **Funcionário** — colaborador cadastrado em regime CLT/PJ/Avulso, com custo diário calculado.
- **Vistoria / Checklist** — execução de inspeção de qualidade por lote a partir de template versionado, com evidência obrigatória para não conformidade.
- **Visão 360** — consolidação do custo real por lote a partir de Materiais, Mão de Obra, Despesas Diretas e Rateio Indireto.
- **Fila (OperationQueue)** — fila local durável (IndexedDB) de operações pendentes de sincronização, com estados `pending`, `syncing`, `synced`, `failed`, `conflict`, `authorization_rejected`.
- **Solicitação de acesso** — pedido pendente criado quando se adiciona um e-mail sem conta; aprovado pelo Dev.
- **Auditoria** — trilha no servidor (ator, alvo, ação, escopo, instante, resultado) imutável para o cliente.

## 4. Features

Numeração de FR global e estável. Referências a jornadas são inline (`realiza UJ-N`). O detalhe de implementação (caminhos, funções, schemas) está no `addendum.md`.

**Índice de features:** `FR-95`, `FR-96`, `FR-97`, `FR-98`, `FR-99`, `FR-100` e `FR-101` foram acrescentados na reconciliação e numerados na sequência, sem inserir no meio de faixas existentes.

| Feature | FRs |
|---|---|
| 4.1 Autenticação, Autorização e Perfis | FR-1 – FR-11 |
| 4.2 Onboarding e Solicitação de Acesso | FR-12 – FR-16 |
| 4.3 Hierarquia Estrutural e Navegação | FR-17 – FR-20, FR-95 |
| 4.4 Construtoras, Obras e Lotes | FR-21 – FR-27, FR-97 |
| 4.5 Gestão de Membros e Vínculos | FR-28 – FR-40, FR-96 |
| 4.6 Almoxarifado e Estoque Central | FR-41 – FR-47, FR-99 |
| 4.7 Financeiro e Contas a Pagar | FR-48 – FR-53 |
| 4.8 Diário de Obra e Anexos | FR-54 – FR-59, FR-98, FR-101 |
| 4.9 RH — Cadastro, Chamada e Custos | FR-60 – FR-66, FR-100 |
| 4.10 EPI | FR-67 – FR-70 |
| 4.11 Validação e Qualidade | FR-71 – FR-74 |
| 4.12 Fornecedores | FR-75 – FR-78 |
| 4.13 Compras, NF e Parcelas | FR-79 – FR-84 |
| 4.14 Visão 360 de Custos | FR-85 – FR-89 |
| 4.15 Offline, PWA e Sincronização | FR-90 – FR-94 |

### 4.1 Autenticação, Autorização e Perfis

**Description:** O acesso começa por login por e-mail/senha e pela leitura de uma autorização confiável vinda do servidor. O modelo distingue cinco perfis — Dev global, Proprietário, Administrador da construtora, Administrador da obra e Membro comum — e aplica autorização uniforme em regras, funções e UI. O princípio é server-authoritative: o cliente comum nunca cria nem altera a própria autorização, e a revogação vale imediatamente, independentemente de claims antigas. Ao trocar de escopo, permissões, navegação e dashboard são recalculados antes de exibir qualquer dado do novo escopo. Realiza UJ-1, UJ-9.

**Functional Requirements:**

#### FR-1: Login e sessão autenticada
Usuário autentica-se por e-mail/senha e passa a acessar o shell do produto. Realiza UJ-1..UJ-9.

**Consequences (testable):**
- Credenciais inválidas não concedem sessão; falha é distinguível de acesso negado.
- Sessão expirada é tratada e reconduz ao login.

#### FR-2: Reconhecimento de Dev global
Dev global ativo é reconhecido em Rules, Functions e UI sem exigir vínculo em construtora ou obra. Consequência: dev mantém administração global e acesso de suporte; o acesso não depende de membership individual.

#### FR-3: Reconhecimento de Proprietário e Admin da construtora
Proprietário (`isOwner`) e Admin ativo da construtora acessam todos os nós da própria construtora sem vínculo individual por nó. Consequência: são exceções explícitas e uniformes à exigência de vínculo por nó.

#### FR-4: Reconhecimento de Admin da obra
Admin da obra acessa módulos da própria obra, sem poderes de construtora e sem acesso automático ao financeiro central. Consequência: escopo restrito a `obraAdmin(c,o)`.

#### FR-5: Acesso fail-closed a módulos
Membro comum acessa apenas vínculos ativos e módulos explicitamente permitidos. Consequência: campo ou `modules` ausente, ilegível ou vazio **não** concede acesso; `modules` controla módulos centrais de membros comuns, enquanto o acesso de admin/owner decorre de `isAdmin`/`isOwner`, não de `modules`.

#### FR-6: Autoproteção da autorização
Usuário comum não cria, altera nem apaga a própria autorização; edita apenas campos pessoais permitidos. Consequência: tentativa de autoelevação é negada.

#### FR-7: Escrita de autorização só no servidor
Toda criação/alteração de papel e vínculo passa por função de servidor auditada; escrita direta no cliente é bloqueada por regras. Consequência: ator, alvo, ação, escopo e resultado ficam registrados.

#### FR-8: Recálculo de permissões na troca de escopo
Ao trocar de construtora, obra ou nó, o sistema recalcula módulos, sidebar e dashboard antes de mostrar conteúdo do novo escopo. Consequência: A→B não retém permissões de A; rota direta não autorizada renderiza acesso negado.

#### FR-9: Estados distintos de acesso negado, vazio e falha
O sistema distingue ausência de dados de ausência de permissão e de falha de rede. Consequência: revogação não é confundida com carregamento.

#### FR-10: Revogação imediata
Vínculo revogado tem efeito imediato; claims antigas não reativam acesso. Consequência: gate de vínculo ativo vale mesmo com documentos órfãos.

#### FR-11: Erros de autorização em pt-br
Erros `permission-denied`, `failed-precondition`, `unauthenticated` e `unavailable` são mapeados para mensagens claras em pt-br. Consequência: usuário entende a falha e a ação possível.

**Feature-specific NFRs:** desempenho de recálculo sem reload; acessibilidade do seletor de escopo.

### 4.2 Onboarding e Solicitação de Acesso

**Description:** Adicionar um membro cujo e-mail ainda não tem conta não deve mais falhar; o sistema registra uma solicitação de acesso pendente, visível ao Admin e ao Dev — este último a aprova criando a conta e o vínculo e entregando a senha provisória por notificação in-app. Realiza UJ-5.

**Functional Requirements:**

#### FR-12: Solicitação de acesso para e-mail sem conta
Ao adicionar membro com e-mail inexistente, o sistema registra `access_request` pendente em vez de falhar com `user-not-found`. Realiza UJ-5.

**Consequences (testable):**
- Adicionar um e-mail sem conta não interrompe o fluxo com erro de sistema.
- A solicitação aparece como "Pendente" para o Admin e no card de alertas do Dev.

#### FR-13: Visibilidade da pendência
Admin vê sinal de pendência na lista de membros; Dev vê card de alertas com as solicitações. Consequência: chip/badge e painel de notificações com TTL de 7 dias.

#### FR-14: Aprovação pelo Dev
Apenas o Dev aprova a solicitação, criando usuário Auth, vínculo e notificando o admin solicitante com senha provisória. Consequência: senha só trafega na notificação in-app, nunca é persistida.

#### FR-15: Negação de aprovação por não-Dev
Tentativa de aprovação por não-Dev retorna `permission-denied`. Consequência: solicitação permanece pendente.

#### FR-16: Aprovação idempotente e auditada
Aprovação duplicada não duplica usuário/vínculo; toda aprovação gera entrada de auditoria. Realiza UJ-5.

### 4.3 Hierarquia Estrutural e Navegação (Drill-down)

**Description:** Após o login, a navegação principal reflete a árvore Loteamento → Quadra → Lote → Setor → Equipe. Cada nível tem rota própria com deep link e breadcrumbs, e a leitura de um nó exige vínculo no nó ou em um ancestral, propagando restrições. Realiza UJ-3, UJ-9.

**Functional Requirements:**

#### FR-17: Drill-down em cinco níveis
Usuário navega da lista de Loteamentos até Quadras, Lotes, Setores e Equipes. Realiza UJ-9.

**Consequences (testable):**
- Cada nível lista os filhos do nó selecionado.
- Ao clicar em um nó, navega para o nível seguinte.

#### FR-18: Deep linking e breadcrumbs
Cada nó tem rota própria e restaurável; breadcrumbs refletem o caminho. Realiza UJ-9.

**Consequences (testable):**
- F5/abertura por URL direta restaura o nó e a posição na árvore.

#### FR-19: Leitura autorizada por nó ou ancestral
Leitura de um nó exige vínculo no próprio nó ou em ancestral seu; fora disso é negada. Consequência: atribuição em um nível propaga restrição corretamente.

#### FR-20: Preservação de contexto entre nós
Navegar entre nós preserva o contexto e recalcula permissões antes de exibir dados. Realiza UJ-9.

#### FR-95: Responsáveis e papéis por nó
Usuário vê, em cada nó da Hierarquia Estrutural, os responsáveis e papéis ali atribuídos. Realiza UJ-9. Consequência: as responsabilidades são visíveis por Setor e Equipe, não apenas na raiz.

**Feature-specific NFRs:** rotas compostas por feature via spread no roteador modular; shell com drawer ≤800 unidades e sidebar acima.

### 4.4 Construtoras, Obras e Lotes

**Description:** O coração estrutural do produto: listar e selecionar construtoras, criar e editar obras e lotes, ver o Mapa de Lotes e manter a identidade visual (logo) da construtora. Realiza UJ-3, UJ-4.

**Functional Requirements:**

#### FR-21: Lista e seleção de construtoras
Usuário vê as construtoras a que pertence e seleciona a ativa. Realiza UJ-1, UJ-9. Consequência: seleção define o tenant de trabalho.

#### FR-22: Criação e edição de obras
Admin/owner/dev criam e atualizam obras. Consequência: membro comum não vê a ação de criação.

**Consequences (testable):**
- A obra criada fica disponível na seleção de escopo do criador.
- Membro comum não vê o botão de criação.

#### FR-23: Mapa de Lotes
Usuário lista os lotes de um contexto com nome, fase e status. Realiza UJ-3, UJ-10.

#### FR-24: Cadastro e edição de lotes
Admin da obra/dev cadastram e atualizam lotes (nome, fase, status). Realiza UJ-3, UJ-10.

**Consequences (testable):**
- Campos vazios/whitespace são rejeitados.
- Fase/status atualizados refletem no card.

#### FR-25: Rótulos de status de lote
Status de lote é exibido como **No prazo / Atrasado / Paralisado / Concluído**, nunca por nomes internos. Consequência: `noPrazo` não aparece na UI; status nunca por cor isolada.

#### FR-26: Gestão do logo da construtora
Admin/owner/dev publicam ou alteram o logo por fluxo transacional com staging e revalidação no servidor. Realiza UJ-4.

**Consequences (testable):**
- Upload aceita apenas PNG/JPEG dentro do limite; imagens maiores são rejeitadas rapidamente.
- A imagem aceita é redimensionada no servidor e tem metadados nocivos removidos.
- Editores revogados e clientes forjando chamadas são barrados pelas regras/funções.

#### FR-27: Preservação e não-remoção do logo
Em falha comprovada, a logo anterior é preservada; não há exclusão de logo via front-end nesta fase. Realiza UJ-4.

#### FR-97: Política de resultado incerto
Em envios cujo resultado é incerto (timeout ou falha parcial de fase/status), o sistema mantém o usuário informado, preserva a digitação e não declara o lote salvo até recibo real; oferece ação de verificação contra a fonte autoritativa. Realiza UJ-3. Consequência: "Fechar" não cancela o envio e a checagem nunca lê cache como confirmação.

**Feature-specific NFRs:** admin de obra **não** herda a gestão de logo. `[ASSUMPTION: limite de arquivo de logo = 2 MiB — ver §9 OQ-2]`

### 4.5 Gestão de Membros e Vínculos

**Description:** O administrador enxerga cada membro com cargo e quantidade de vínculos, abre o detalhe e atribui, troca, remove ou desativa vínculos em nós da Hierarquia Estrutural com papel e módulos. Toda escrita é server-side; a leitura usa cache e a escrita exige rede. Realiza UJ-1, UJ-5.

**Functional Requirements:**

#### FR-28: Lista de membros com cargo e contagem
Adm/owner vê pendentes no topo e ativos abaixo com subtítulo `Cargo · N nós`, avatar/chip por papel. Realiza UJ-1. Consequência: pendentes são distinguíveis; a lista combina observação de vínculos sem `collectionGroup`.

#### FR-29: Filtros e busca de membros
Adm/owner filtra Todos / Por nó / Pendentes e busca por e-mail/nome. Realiza UJ-1. Consequência: estado vazio mostra "Nenhum membro encontrado."; dropdown vazio mostra "Nenhum nó disponível".

#### FR-30: Detalhe do membro
Adm/owner abre o detalhe com vínculo da construtora e nós vinculados e ações. Consequência: sem vínculo mostra "Nenhum nó vinculado — Atribuir"; inativo mostra aviso "Ative na construtora primeiro".

#### FR-31: Atribuir operário a um nó da Hierarquia Estrutural
Adm/owner atribui operário com papel e módulos (padrão `[diario]`). Realiza UJ-1.

**Consequences (testable):**
- Confirmação desabilitada sem destino; resumo ao vivo do que será atribuído.
- Nunca envia `owner` em vínculo de nó.

#### FR-32: Atribuir Admin da obra
Adm/owner atribui Admin da obra com papel e módulos. Consequência: papel resultante `obraAdmin`.

#### FR-33: Trocar papel e módulos de um vínculo
Adm/owner alterna Operário↔Admin e altera módulos sem remover/readicionar. Consequência: módulos normalizam legados e `[]` nega acesso.

#### FR-34: Remover membro de um nó
Adm/owner remove com confirmação destrutiva explícita; o histórico é preservado. Consequência: acesso revogado imediatamente; diários preservados; o membro vê "Acesso removido" sem retry infinito.

#### FR-35: Trocar cargo na construtora
Adm/owner alterna cargo operário↔admin; a opção `owner` fica oculta sem autoridade de Dev. Consequência: só Dev altera Proprietário.

#### FR-36: Desativar membro da construtora
Adm/owner desativa o membro removendo os vínculos ativos, com confirmação explícita da consequência. Consequência: revogação efetiva imediata via gate de vínculo ativo.

#### FR-37: Pré-requisito de vínculo ativo na construtora
Vínculo ativo na construtora é pré-requisito para vínculo em nó da Hierarquia Estrutural; a UI bloqueia com atalho **Ativar**. Realiza UJ-1 (edge). Consequência: `failed-precondition` orienta a ação.

#### FR-38: Normalização e fail-closed de módulos
Módulos normalizam aliases legados (`rdo`→`diario`, `almoxarifado`→`estoque`, `recursos_humanos`→`rh`, `qualidade`→`validacao`, `financeiro`→`adm`); vazio significa sem acesso. Consequência: nenhum módulo é concedido silenciosamente.

#### FR-39: Escrita de vínculo exige rede
Leitura de membros usa cache; escrita de vínculo exige conexão, sem fila offline. Consequência: sem conexão mostra "Sem conexão — tente novamente" e não enfileira.

#### FR-40: Erros de vínculo em pt-br
Falhas de vínculo são mapeadas para mensagens claras com o dialog mantido. Consequência: `permission-denied`, `failed-precondition` e `Papel inválido` têm mensagens e ações distintas.

#### FR-96: Atribuir equipe a um nó
Adm/owner atribui uma **Equipe** a um nó da Hierarquia Estrutural com papel e módulos. Realiza UJ-1. Consequência: a alocação pode ocorrer no nível de Setor ou Equipe, e não apenas na raiz.

**Feature-specific NFRs:** acessibilidade (semântica, foco/teclado, alvos ≥48dp, papel nunca só por cor, `textScale` 1.3x); responsivo mobile + web PWA (bottomsheet mobile / dialog desktop).

### 4.6 Almoxarifado e Estoque Central

**Description:** Estoque único por construtora, com recebimento (fornecedor, NF, evidência e rateio de frete/despesas/desconto), saída com destino obra/lote e apropriação, e consolidação de saldo exclusivamente por comando transacional idempotente no servidor. Realiza UJ-7.

**Functional Requirements:**

#### FR-41: Cadastro de materiais
Usuário autorizado cadastra e consulta materiais por construtora. Consequência: material novo inicia com saldo zero.

#### FR-42: Recebimento com NF, fornecedor e evidência
Almoxarife registra entrada com fornecedor, número de NF, valores e comprovante. Realiza UJ-7.

**Consequences (testable):**
- Entrada calcula custo total = itens + frete + despesas − desconto, em centavos, e custo unitário com arredondamento.
- Desconto não pode exceder o bruto.

#### FR-43: Saída com destino e apropriação
Almoxarife registra saída informando obra e, quando houver apropriação, lote obrigatório. Realiza UJ-7.

**Consequences (testable):**
- Obra/lote de destino devem pertencer à construtora do material.
- Saída sem apropriação (`loteId: null`) é permitida.

#### FR-44: Consolidação transacional e idempotente
Saldo e histórico atualizam exclusivamente por comando no servidor, idempotente por `operationId`. Realiza UJ-7.

**Consequences (testable):**
- Duas saídas concorrentes não geram saldo negativo.
- Reenvio após confirmação perdida aplica exatamente uma vez.
- Mesmo ID com payload distinto é rejeitado.

#### FR-45: Quantidades inteiras e validação
Quantidades usam representação inteira escalada; negativos, não finitos ou fora da escala são rejeitados. Consequência: material novo com saldo zero; abertura legada explícita e reconciliada.

#### FR-46: Correção auditada sem apagar histórico
Dev/admin corrigem por ajuste/estorno auditado com motivo, sem remover a movimentação original. Consequência: reversão duplicada é impedida.

#### FR-47: Estoque central compartilhado
O estoque é único e compartilhado entre obras da mesma construtora. Consequência: saída de uma obra A reduz o saldo comum sem alterar o histórico de outra obra B nem de outra construtora; não existem "estoques por obra".

#### FR-99: Custo unitário efetivo e apropriado na saída
A saída de material carrega o custo unitário efetivo apurado no recebimento e registra o custo apropriado ao destino. Realiza UJ-7, UJ-8. Consequência: o custo apropriado ao lote não se perde entre recebimento e saída.

**Feature-specific NFRs:** valores em centavos; escrita direta de saldo bloqueada inclusive para fluxos administrativos.

### 4.7 Financeiro e Contas a Pagar

**Description:** Cadastro e ciclo de vida de despesas por construtora, com parcelamento determinístico, liquidação idempotente, comprovantes e apropriação a lote; leitura compatível com documentos legados. Realiza UJ-8.

**Functional Requirements:**

#### FR-48: Cadastro de despesas
Usuário autorizado cadastra despesas com categoria padronizada e valor em centavos. Consequência: despesa central não vira custo de lote automaticamente.

#### FR-49: Apropriação a lote ou rateio indireto
Despesa pode ser apropriada diretamente a um lote ou distribuída por rateio indireto. Realiza UJ-8. Consequência: critério de rateio explícito.

#### FR-50: Parcelamento determinístico
O sistema parcela despesas com a invariante soma das parcelas ≡ total. Consequência: o resto é alocado de forma determinística (1ª parcela).

#### FR-51: Liquidação idempotente
Marcação de pagamento é idempotente, com data do servidor e comprovante anexo. Realiza UJ-8.

**Consequences (testable):**
- Repetir o pagamento não reaplica efeito nem altera a data original.

#### FR-52: Imutabilidade de liquidadas e correção lógica
Despesas/parcelas liquidadas são imutáveis; não há exclusão física; correções são lógicas e auditadas. Consequência: `allow delete` impossível para o cliente.

#### FR-53: Compatibilidade com legado e centavos
Listagem lê documentos legados (ISO/Timestamp/nulo) sem mudar o dia do vencimento, e valores migram de `double` para centavos inteiros reconciliados. Consequência: leitor prioriza o campo novo sem dupla contagem.

**Feature-specific NFRs:** comprovantes em Storage privado, tipos seguros e limite de tamanho.

### 4.8 Diário de Obra e Anexos

**Description:** Registro periódico do canteiro com clima, efetivo e observações, e anexos fotográficos persistidos de forma durável e retomável, com sinais de sincronização honestos. Realiza UJ-2.

**Functional Requirements:**

#### FR-54: Registro do diário
Usuário registra clima, efetivo por função e observações. Realiza UJ-2.

#### FR-55: Anexos com referência privada e integridade
Anexos são guardados com ID estável, tipo, tamanho, integridade e referência privada. Realiza UJ-2. Consequência: fotos legadas continuam legíveis durante a conversão.

#### FR-56: Sinais de sincronização honestos
O sistema marca "Salvo no dispositivo" apenas após persistir os bytes e "Sincronizado" apenas após aceite integral do servidor. Realiza UJ-2. Consequência: cache nunca vira confirmação remota.

#### FR-57: Falha explícita de arquivo
Arquivo ausente ou armazenamento cheio geram falha explícita com ação de recuperação; nunca sucesso falso. Realiza UJ-2 (edge). Consequência: anexo obrigatório não verificado impede conclusão.

#### FR-58: Retomada e isolamento de pendências
Pendências e anexos sobrevivem a reabertura/atualização da PWA; outro dispositivo não limpa pendência alheia. Realiza UJ-2.

#### FR-59: Encerramento por revogação
Ao perder acesso, exibe "Acesso removido — operação não sincronizada", preserva evidências isoladas e suspende retries. Realiza UJ-2.

#### FR-98: Carimbo de evidência
Fotos de evidência recebem carimbo embutido com data/hora e, quando disponível, geolocalização, formando prova de contexto. Realiza UJ-2, UJ-11. Consequência: o carimbo é aplicado aos bytes da imagem e é indelével.

#### FR-101: Validação de anexos
O sistema valida tipo, tamanho e conteúdo dos anexos (JPEG/PNG/WebP/PDF, limite de tamanho, verificação de assinatura do arquivo e integridade por hash) antes de aceitar o upload. Realiza UJ-2. Consequência: arquivos fora do tipo/limite são rejeitados com mensagem clara.

**Feature-specific NFRs:** operação em segundo plano não é prometida; dados removidos pelo navegador/usuário não são prometidos como recuperáveis.

### 4.9 RH — Cadastro, Chamada e Custos

**Description:** Individualiza trabalhadores e equipes, registra presença nominal por dia, permite rateio de mão de obra entre lotes e calcula o custo diário de forma determinística e imutável após o fechamento. Realiza UJ-6.

**Functional Requirements:**

#### FR-60: Cadastro de funcionários
RH/admin cadastra funcionários (CLT/PJ/Avulso) com CPF validado, custos base e adicionais, e custo diário calculado. Consequência: CLT mensal divide por divisor configurável; inativação é lógica.

#### FR-61: Cadastro de equipes
RH/admin cadastra equipes com líder e membros. Realiza UJ-6. Consequência: equipe pode ser alocada a um nó da Hierarquia Estrutural.

#### FR-62: Chamada diária nominal
Encarregado registra presença (`presente`/`falta`/`meio-periodo`) por funcionário, com alvos táteis ≥48dp. Realiza UJ-6.

#### FR-63: Rateio de presença entre lotes
A chamada rateia o efetivo entre múltiplos lotes com soma ≡ 100%. Realiza UJ-6.

#### FR-64: Custo de mão de obra
O sistema calcula custo diário: presente 100%, meio-período 50%, falta 0. Consequência: a falta custa zero, não um valor inferido.

#### FR-65: Invariantes de chamada
O sistema bloqueia chamada duplicada obra/data e conflito cross-obra com alocação >100%. Realiza UJ-6 (edge).

#### FR-66: Fechamento e retificação
Chamadas fechadas são imutáveis; retificação auditada gera snapshot histórico e exige justificativa. Consequência: retificação restrita a admin/`obraAdmin`/dev.

#### FR-100: Snapshot imutável de custo de mão de obra
O custo de mão de obra é congelado no fechamento da chamada; reajustes salariais posteriores não recalculam períodos já fechados. Realiza UJ-6, UJ-8. Consequência: histórico de custo não sofre distorção retroativa.

**Feature-specific NFRs:** valores em centavos; sem delete físico.

### 4.10 EPI

**Description:** Gestão de EPI com conformidade NR-6: catálogo com C.A. e vida útil, eventos imutáveis de movimentação e termo de responsabilidade com assinatura digital e integridade. Realiza UJ-6 (contexto de campo).

**Functional Requirements:**

#### FR-67: Catálogo de EPI com C.A.
O sistema mantém catálogo corporativo com C.A. e vida útil e alerta de vencimento próximo (30 dias). Consequência: entrega com C.A. expirado é bloqueada.

#### FR-68: Eventos imutáveis de EPI
Entregas, substituições, devoluções e descartes são eventos imutáveis vinculados a funcionário ativo. Consequência: sem exclusão física.

#### FR-69: Termo de responsabilidade digital
O termo é assinado (canvas/PIN) e guardado com hash SHA-256 em Storage privado. Consequência: integridade verificável.

#### FR-70: Painel de conformidade de EPI
O sistema exibe conformidade por colaborador/obra. Consequência: pendências visíveis antes de fiscalização.

**Consequences (testable):**
- Colaborador sem EPI em dia aparece sinalizado no painel.
- A tentativa de entrega com C.A. expirado é refletida como bloqueio no painel.

**Feature-specific NFRs:** RBAC de módulo `epi`; offline via fila. `[ASSUMPTION: não há baixa automática de estoque de EPI nesta versão]`

### 4.11 Validação e Qualidade

**Description:** Padroniza inspeções de qualidade por lote com templates versionados, evidência fotográfica obrigatória para não conformidade e ciclo de status auditável. Realiza UJ-11.

**Functional Requirements:**

#### FR-71: Templates versionados por disciplina
O sistema mantém templates de checklist versionados por disciplina. Consequência: vistoria fixa a versão do template.

#### FR-72: Vistoria por lote
Gestor executa vistoria por lote registrando conformidade item a item. Realiza UJ-11.

#### FR-73: Evidência obrigatória de não conformidade
Item não conforme exige foto com carimbo de evidência. Realiza UJ-11. Consequência: sem foto, o item não é dado como não conforme.

#### FR-74: Ciclo de status e imutabilidade
O lote transita por pendente/aprovado/reprovado/reaberto; vistorias concluídas são imutáveis. Realiza UJ-11. Consequência: critério fixado por versão.

**Feature-specific NFRs:** Storage privado; offline com sincronização de fotos.

### 4.12 Fornecedores

**Description:** Cadastro corporativo único de fornecedores, com validação de documento, visível a todas as obras e integrado a Almoxarifado e Contas a Pagar. Realiza UJ-7.

**Functional Requirements:**

#### FR-75: Cadastro corporativo de fornecedores
Usuário autorizado cadastra fornecedores uma vez por construtora, visíveis a todas as obras.

#### FR-76: Validação de CPF/CNPJ e duplicidade
O sistema valida CPF (11) e CNPJ (14) por módulo-11, normaliza sem máscara e bloqueia duplicados. Consequência: risco fiscal de documento inválido reduzido.

#### FR-77: Dados e autocomplete
Fornecedor guarda contato, categorias e dados de pagamento (Pix/bancário) e aparece por autocomplete em Almoxarifado e Contas a Pagar. Realiza UJ-7.

#### FR-78: Inativação sem quebrar referências
Fornecedor é inativado logicamente preservando integridade referencial. Consequência: sem delete físico.

### 4.13 Compras, NF e Parcelas

**Description:** Compra/NF estruturada com chave NF-e, cálculo exato de total, parcelamento determinístico, liquidação idempotente e entrada física rastreável no Almoxarifado. Realiza UJ-7, UJ-8.

**Functional Requirements:**

#### FR-79: Compra/NF estruturada
Usuário autorizado registra compra/NF com fornecedor corporativo obrigatório e chave NF-e de 44 dígitos. Consequência: fornecedor avulso não é aceito.

#### FR-80: Total em centavos
O total da compra é itens + frete + acessórias − desconto, em centavos. Realiza UJ-8.

#### FR-81: Parcelamento determinístico
O parcelamento usa a invariante soma das parcelas ≡ total, com resto alocado de forma determinística.

#### FR-82: Liquidação por parcela
Cada parcela é liquidada de forma idempotente (`idempotencyKey`) com comprovante e status aberto/parcial/pago. Realiza UJ-8.

#### FR-83: Recebimento físico rastreável
A entrada física no Almoxarifado é vinculada à NF com rastreabilidade mútua. Realiza UJ-7.

#### FR-84: Cancelamento lógico auditado
Cancelamento de compra é lógico e auditado, preservando o histórico.

### 4.14 Visão 360 de Custos

**Description:** Consolida o custo real por lote a partir de Materiais, Mão de Obra, Despesas Diretas e Rateio Indireto, com painel executivo, orçado vs. realizado e drill-down por lote. Realiza UJ-8.

**Functional Requirements:**

#### FR-85: Painel executivo de custos
O sistema consolida os quatro cubos por lote em painel com KPIs. Realiza UJ-8.

**Consequences (testable):**
- Os quatro cubos somam ao custo total do lote exibido.
- Lote sem dados mostra estado vazio, e não custo zero inferido.

#### FR-86: Orçado vs. Realizado
O painel compara orçado e realizado com gráfico. Realiza UJ-8. Consequência: compra central não vira custo de lote automaticamente.

#### FR-87: Drill-down por lote
O usuário abre o extrato nominal do lote com ΔCents. Realiza UJ-8.

#### FR-88: Rateio indireto consistente
O rateio indireto é proporcional com resto no primeiro lote e discrepância zero. Realiza UJ-8.

#### FR-89: Pago vs. passivo
O custo distingue valores pagos de passivos, sem inferir custo de dados ausentes. Realiza UJ-8.

**Feature-specific NFRs:** projeções materializadas; custo por lote consistente sob atualização simultânea de RH e Estoque.

### 4.15 Offline, PWA e Sincronização

**Description:** Base transversal para operar no canteiro sem rede: shell cacheado pelo Service Worker (nunca dados de negócio), fila durável em IndexedDB com idempotência, isolamento por conta e indicador de sincronização honesto. Realiza UJ-2.

**Functional Requirements:**

#### FR-90: Shell PWA e navegação offline
O Service Worker cacheia apenas o shell estático e serve a navegação SPA offline; dados de negócio nunca são cacheados pelo SW. Consequência: build sem CDN externa; manifesto instalável.

#### FR-91: Fila durável de operações
Operações offline críticas (diário, estoque, chamada, financeiro) entram em fila IndexedDB com estados `pending`, `syncing`, `synced`, `failed`, `conflict`, `authorization_rejected`. Realiza UJ-2.

#### FR-92: Isolamento por conta e escopo
A fila é particionada por usuário/construtora/obra/módulo; troca de conta remove cache não autorizado e isola pendências. Consequência: uma conta não vê nem sincroniza dados de outra.

#### FR-93: Reenvio idempotente
O reenvio usa ID estável e não duplica operações; payload divergente é rejeitado. Consequência: lease multi-aba evita duplo processamento.

#### FR-94: Indicador de sincronização honesto
O indicador mostra estados reais (Tudo sincronizado / Salvo no dispositivo / Sincronizando / Falha / Conflito / Acesso removido) e nunca infere sucesso pela presença de rede. Realiza UJ-2.

**Feature-specific NFRs:** sem dependência de execução contínua em segundo plano; migração de schema preserva fila e blobs. `[ASSUMPTION: operação em segundo plano não é garantida — a retomada ocorre na abertura/reconexão]`

## 5. Non-Goals (Explicit)

- O SIGO **não** é um portal do comprador, corretor ou market place imobiliário.
- **Não** é folha de pagamento: não emite holerite, FGTS, INSS, GPS, eSocial, nem fechamento contábil mensal.
- **Não** se integra a Open Finance, CNAB 240/400, SEFAZ (MDe/XML) ou SPED nesta versão.
- **Não** emite nota fiscal nem calcula retenções (ISS/IRRF/INSS).
- **Não** é motor de custo médio completo nem gera contas a pagar automaticamente a partir de compras.
- **Não** oferece tema escuro, carregamento dinâmico de fontes externas ou exclusão/rollback de logo pela UI nesta fase.
- **Não** promete recuperação de dados removidos pelo navegador/usuário nem execução contínua em segundo plano.
- **Não** valida CPF/CNPJ em bases da Receita/Sintegra; apenas dígito verificador.
- **Não** libera gravação direta irrestrita de saldo, histórico ou privilégios — nem para o Dev; toda correção usa comando auditado.
- **Não** adiciona, nesta primeira entrega, busca nova, KPIs, percentual/foto/custo no card de lote, nem atomicidade/rollback de ações: os envios são bloqueantes e não transacionais.
- **Não** é gamificado nem usa ilustração decorativa.
- **Não** autoriza, por este PRD, a implantação em produção (§6, §9).

## 6. MVP Scope

O SIGO é brownfield: a maior parte dos módulos abaixo **já tem código implementado em desenvolvimento**. Aqui "MVP" significa **escopo do produto na primeira entrega** — o que a plataforma precisa fazer para ir a produção — e não um conjunto de trabalho novo construído do zero. O delta real até o lançamento é: (a) alinhar os vínculos à Hierarquia Estrutural canônica; (b) concluir as validações pendentes (Epic 6/7 e aceite manual em mobile); e (c) **autorizar e executar a implantação em produção**, hoje fora do escopo aprovado.

**Nota de status (não confundir "código presente" com "aceite validado").**
- **Divergência de fontes.** Fornecedores, Compras/NF e Visão 360 aparecem como concluídos no `sprint-status.yaml`, mas ainda constam como "evolução futura" em `docs/task.md`. Este PRD **não** afirma aceite de produção desses módulos; a divergência está registrada em §9 OQ-10.
- **Drill-down.** A navegação Loteamento → Quadra → Lote (Story 11.1) está entregue; Lote → Setor → Equipe (Story 11.2) está **em andamento**.
- **Vínculos.** O alinhamento dos vínculos (Epics 8–10) à Hierarquia Estrutural está **em andamento**, não concluído.

### 6.1 In Scope

- Autenticação, autorização server-authoritative e cinco perfis.
- Onboarding com solicitação de acesso e aprovação pelo Dev.
- Hierarquia Estrutural com drill-down Loteamento → Quadra → Lote → Setor → Equipe e deep linking (11.1 entregue; 11.2 em andamento).
- Construtoras, obras, Mapa de Lotes e gestão de logo.
- Gestão de membros e vínculos (lista, filtros, detalhe, atribuição, troca, remoção, desativação).
- Alinhamento dos vínculos (Epics 8–10) à Hierarquia Estrutural canônica, com a raiz em Loteamento (em andamento).
- Almoxarifado central com recebimento, saída, rateio e saldo transacional.
- Financeiro/Contas a pagar com parcelamento, liquidação e centavos.
- Diário de obra com anexos e PWA offline.
- RH com cadastro, chamada, custo de mão de obra e invariantes.
- EPI com C.A., eventos e termo assinado.
- Validação/qualidade com templates e evidências.
- Fornecedores com validação de CPF/CNPJ *(status divergente — OQ-10)*.
- Compras/NF/parcelas e recebimento rastreável *(status divergente — OQ-10)*.
- Visão 360 de custos por lote *(status divergente — OQ-10)*.
- Fila offline durável, Service Worker e indicador de sincronização.

### 6.2 Out of Scope for MVP

- **Implantação em produção** — fora da autorização vigente; requer simulação, devs verificados e plano de recuperação. `[NOTE FOR PM]` bloqueador de lançamento.
- **Bateria E2E offline e de integridade (Epic 6)** — a capacidade offline está no escopo, mas o harness E2E (Service Worker ativo, conectividade intermitente, cold start) ainda é backlog.
- **Responsividade formal (Epic 7)** — backlog.
- **Custo médio, snapshots e apropriação financeira automática** — evolução futura (deferido).
- **Qualidade/cronograma avançados e documentos/visão 360 documental** — evolução futura.
- **Tema escuro, remoção de logo, fontes externas, novas buscas/KPIs** — v2+.
- **Aceite manual em Safari móvel e Chrome Android** — pendente de execução; `[NOTE FOR PM]` bloqueador de lançamento, junto à responsividade (Epic 7).

## 7. Success Metrics

*Cada métrica referencia os FRs que valida. Onde não há baseline medido, a meta é binária/qualitativa e será calibrada no piloto de campo. As métricas de integridade (SM-1..SM-3) são guardrails: não devem ser trocadas por velocidade. Contrapesos evitam otimizar o alvo errado.*

**Primary (resultado de negócio)**
- **SM-1**: Nenhuma evidência de canteiro perdida por falha de sincronização — em piloto com conectividade intermitente, 100% das operações confirmadas no servidor e zero operação marcada "sincronizada" sem aceite. Valida FR-56, FR-57, FR-94.
- **SM-2**: Custo por lote confiável — zero divergência de centavos e zero saldo negativo sob concorrência/reenvio; relatório de reconciliação fecha. Valida FR-44, FR-50, FR-51, FR-80, FR-82.
- **SM-3**: Acesso sob controle — 100% dos vínculos e papéis gravados por função de servidor com auditoria; zero autoelevação em testes de abuso. Valida FR-7, FR-16, FR-35, FR-36.
- **SM-4**: Onboarding sem atrito — solicitações de acesso resolvidas dentro do app (solicitação → aprovação → vínculo), sem intervenção manual de suporte. Valida FR-12, FR-14, FR-16.

**Secondary**
- **SM-5**: Adoção de campo — proporção de obras com diário e chamada registrados na semana (meta a calibrar no piloto). Valida FR-54, FR-62.
- **SM-6**: Redução do tempo de fechamento da chamada diária por obra frente ao baseline manual. Valida FR-62.
- **SM-7**: Porteira de qualidade — cobertura de testes e `flutter analyze` limpo por módulo. Valida todos os FRs de módulo.
- **SM-8**: Cobertura de custo — proporção do custo real por lote reconstruída (materiais + mão de obra + despesas) com discrepância zero no rateio. Valida FR-85, FR-88.

**Counter-metrics (do not optimize)**
- **SM-C1**: Número de telas/funcionalidades — não otimizar amplitude em detrimento de confiabilidade. Contrapesa SM-5.
- **SM-C2**: Velocidade de sincronização reportada — não marcar "sincronizado" cedo para parecer rápido. Contrapesa SM-1.
- **SM-C3**: Redução de fricção de acesso — não abrir atalhos de autoatribuição de papel. Contrapesa SM-3.
- **SM-C4**: Completude de dados de custo — não inferir custos ausentes nem zerar valores inválidos. Contrapesa SM-8.

## 8. Requisitos Não Funcionais Transversais

Atributos de qualidade que valem para o sistema inteiro, além dos NFRs específicos de cada feature.

- **Desempenho e escala**: listas, busca e paginação no cliente bastam até a ordem de centenas de membros/nós; dropdown com busca acima de 10 nós; troca de escopo e recálculo de permissões sem reload; reflow sem overflow em 320/390/800/801/1280/1440.
- **Acessibilidade**: contraste ≥4,5:1 (texto normal) e ≥3:1 (textos grandes/indicadores); alvo mínimo de 48 unidades lógicas; foco visível e restaurado em overlays; `Esc` fecha antes do envio; status sempre com texto + ícone (nunca só cor); leitor de tela anuncia nome, cargo, contagem e status; ordem de teclado visual; `textScale` até 1,3x com verificação a 200%; nomes de 80 e fase de 60 caracteres sem corte.
- **Segurança**: autoridade única no servidor; regras fail-closed; isolamento estrito entre construtoras; Storage privado com validação de tipo/tamanho e assinatura do arquivo; senha provisória só em notificação in-app e nunca persistida; auditoria server-side imutável ao cliente; escrita direta de saldo, histórico, relacionamento e privilégios bloqueada inclusive para fluxos administrativos.
- **Confiabilidade e integridade**: valores monetários em centavos inteiros (sem `double`); idempotência por chave de operação; ausência de exclusão física; correções auditadas; feedback de sincronização sempre honesto.
- **Offline**: Service Worker cacheia apenas o shell; fila IndexedDB durável com lease multi-aba; retomada na abertura/reconexão; isolamento por conta; sem dependência de execução contínua em segundo plano.
- **Observabilidade**: auditoria server-side (sem UI nesta etapa); os eventos de resultado de persistência de lote/logo são dependências a definir na arquitetura.
- **Plataforma**: Flutter + Riverpod + GoRouter + Firebase; PWA mobile-first; Android/iOS preservados, sem promessa de suporte nativo validado.
- **Idioma**: pt-br em toda a interface e em todas as mensagens de erro.

## 9. Open Questions

1. **OQ-1 — Migração de vínculos existentes.** Com a Hierarquia Estrutural canônica (Loteamento → Quadra → Lote → Setor → Equipe) substituindo o escopo genérico de "Obra" na atribuição, como migrar os vínculos por obra já existentes para os nós correspondentes, preservando `isActive`, papel e histórico?
2. **OQ-2 — Limite de upload de logo.** 2 MiB (contrato da primeira entrega) vs 5 MB ≈ 4,8 MiB (`HANDOFF.md`, `[ASSUMPTION]`). Qual é o canônico?
3. **OQ-3 — Agregação de custos da raiz.** Como agregar métricas/custos do Loteamento a partir de milhares de Lotes/Equipes — rollup documents ou Functions de agregação? *(deferido na arquitetura)*
4. **OQ-4 — Custo médio e apropriação automática.** Modelo definitivo de custo médio e de geração de contas a pagar a partir de compras.
5. **OQ-5 — LGPD e dados sensíveis.** Retenção, acesso e finalidade de dados pessoais de funcionários e terceiros.
6. **OQ-6 — Identidade dos devs legítimos** — `pendente-evidência`; bloqueia migração do fallback de e-mail. *(fonte: `docs/politica.md`)*
7. **OQ-7 — Regras de produção publicadas** — `pendente-evidência`.
8. **OQ-8 — Volume real e dados legados** (quantidades, saldos, anexos) — `pendente-evidência`.
9. **OQ-9 — Autorização de implantação em produção** — fora do escopo aprovado; apresentar separadamente.
10. **OQ-10 — Status real dos módulos Epic 5.** Fornecedores, Compras/NF e Visão 360 aparecem como concluídos no `sprint-status.yaml` e como evolução futura em `docs/task.md`; é preciso reconciliar qual é o estado de aceite desses módulos.

## 10. Assumptions Index

*Premissas `[ASSUMPTION]` do documento, para confirmação explícita:*

- §2.2 — Criação de construtora é administrativa; não há auto-cadastro de empresa.
- §4.4 (NFR) — Limite de logo assumido como 2 MiB por divergência entre contrato e UX (OQ-2).
- §4.10 (NFR) — Sem baixa automática de estoque para EPI nesta versão.
- §4.15 — Operação em segundo plano não é garantida; retomada ocorre na abertura/reconexão.

## 11. Estética e Tom

- **Direção expressiva**: azul profundo/vivo + dourado; sidebar `#082344`; gradiente de cabeçalho `#0D47A1→#1565C0`; ação `#1565C0`. O dourado é marca, **nunca** sinal único de status; a cor da empresa não altera o tema SIGO.
- **Tipografia e densidade**: Material 3 nativa, sem fonte externa; construtoras espaçosas, lotes compactos; superfícies claras com sombra suave e elevação que não comunica status.
- **Tom**: pt-br direto e operacional, com nome da obra/empresa e papel do usuário sempre explícitos; sem gamificação e sem ilustração decorativa.
- **Marca oficial obrigatória**: `sigo_logo_light.png` / `sigo_logo_dark.png`; não redesenhar.

