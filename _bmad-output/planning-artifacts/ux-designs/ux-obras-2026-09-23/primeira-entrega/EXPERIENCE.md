---
name: SIGO — Primeira entrega
status: final
updated: 2026-09-23
sources:
  - ../EXPERIENCE.md
  - ../.memlog.md
  - ../.working/brand-extract.md
  - ../.working/lotes-extract.md
  - DESIGN.md
---

## Foundation

Contrato de comportamento da primeira entrega, apenas planejamento. Flutter Material 3 herdado; [DESIGN.md](DESIGN.md) define identidade e calibração visual proposta. Telefone e desktop oferecem as mesmas tarefas autorizadas. Mudar apresentação não concede acesso nem altera persistência. Cadastro e troca da logo da construtora foram incluídos pelo usuário nesta entrega; sem ampliar para cadastro de empresa.

| Natureza | Tratamento |
|---|---|
| Confirmado pelo usuário | Direção expressiva; praticidade mobile; títulos fortes; construtoras espaçosas/lotes compactos; cadastro e troca de logo por Dev, Proprietário e administradores da construtora |
| Herdado do produto | Rotas, visibilidade por permissões existentes, campos/validação de lotes, fase separada de status e edição sequencial |
| Proposta UX deste pacote [ASSUMPTION] | Valores dos tokens, ações textuais nos cards, reflow, gestão de logo online e limites propostos |
| Fora desta entrega | Redesenho interno de membros, vistorias, custos, RH e demais módulos; novas buscas, métricas, tema escuro, fila offline nova |

## Information Architecture

| ID/superfície | Entrada → saída | Referência/fluxo |
|---|---|---|
| S0 SigoLayout | Shell e drawer/lateral atuais → mesmos destinos autorizados e contexto construtora/obra | Nos quatro mocks; J0 |
| S1 Minhas Construtoras | `/` → `/construtora/:id` | Mocks construtoras desktop/mobile; J1 |
| S2 Mapa de Lotes | `/construtora/:id/obra/:obraId/lotes` → edição, Novo Lote ou vistorias | Mocks lotes desktop/mobile; J2/J4 |
| S3 Novo Lote | Ação existente Novo Lote → retorno pelo fluxo atual | Especificado pelas tabelas, sem imagem própria; J3 |
| S4 Atualizar lote | Ação do card → bottom sheet existente → card de origem | Especificado pelas tabelas, sem imagem própria; J2 |
| S5 Gerenciar logo | Ação independente autorizada no card ou gestão da construtora no Painel Dev → seleção/prévia/confirmação → origem | Especificado pelas tabelas, sem imagem própria, conforme aceito pelo usuário; J5 |

Rotas de S1–S4 são herança, não proposta de arquitetura. Vistorias preserva `/construtora/:id/obra/:obraId/lotes/:loteId/validacoes`; a primeira entrega cobre a entrada e o retorno, sem redesenhar seu conteúdo. Nenhum item de menu decorativo dos mocks vira destino. Painel Dev continua restrito e os vazios de S1 distinguem dev/usuário comum.

## Voice and Tone

Português brasileiro direto. Conservar títulos Minhas Construtoras, Mapa de Lotes e Novo Lote. Ações: Acessar construtora, Atualizar lote, Vistorias, Criar Lote, Salvar Alterações, Gerenciar logo. Nome e contexto reais em vez de slogans gerados.

Status apresentados: No prazo, Atrasado, Paralisado, Concluído; nunca nomes internos como noPrazo. Nome vazio: Campo obrigatório. Nenhum lote cadastrado nesta obra não equivale a falha de carregamento. Usuário sem construtoras: Você não pertence a nenhuma construtora. Fale com o administrador. Não apresentar erro técnico cru como orientação final.

Só anunciar resultado conhecido. Em resultado de gravação incerto: Não foi possível confirmar todas as alterações. Confira os dados antes de tentar novamente. A frase não afirma que nada foi salvo. Não exibir Sincronizado nem Salvo offline com base somente no conteúdo do cache.

## Component Patterns

| Componente | Comportamento e diferença do atual |
|---|---|
| SigoLayout | Mesmos destinos, hierarquia e autorização. Drawer fecha ao selecionar destino; foco volta ao acionador no fechamento sem navegação. Item ativo sem depender só da cor. Rótulos de sidebar existentes permanecem |
| ConstrutoraCard | Acessar construtora conserva destino atual. Área principal é um único alvo sem paradas duplicadas no teclado; ação visual não é botão aninhado. Gerenciar logo, quando autorizado, é alvo separado que não dispara navegação. CNPJ só quando existe |
| LoteCard | Atualizar lote abre edição existente; corpo pode manter atalho atual sem duplicar semântica. Vistorias é alvo independente. Ordem nome, fase, status, ações; não deduzir progresso ou status a partir da fase |
| ActionButton | Enter/espaço conforme Material; ocupado conserva rótulo e impede reenvio simultâneo. Ações não dependem de hover. Falha habilita nova tentativa quando segura, sem criar retry automático de gravação |
| DataSurface | Lista ordenada conforme dados atuais; nenhuma ordenação/busca nova. Scroll preserva leitura. Formulário mantém nome obrigatório e seletores existentes; edição não passa a editar nome |
| StatusFeedback | Mensagem anunciável sem roubar foco; vazio, erro, carregamento e dado são distintos. Badge de status é informativo, não filtro |
| FormField | Rótulo persistente, erro associado. Seletores mantêm opções e valor atual; fase desconhecida deve continuar legível sem coerção silenciosa. Arquitetura verificará suporte ao valor já salvo |
| DetailOverlay | Bottom sheet existente para lote, rolagem com teclado; antes do envio, fechar descarta somente edições locais, sem salvamento automático; durante envio e em resultado incerto segue a política de saída abaixo. Foco inicial no título/campo e retorno ao acionador; não mover foco durante envio |
| LogoEditor | Selecionar imagem → prévia local com nome de arquivo e estado “Selecionada, ainda não salva” → Salvar logo → confirmação. Antes do envio, Cancelar descarta seleção local; trocar seleção não publica. Anunciar troca de seleção sem roubar foco. Sem remoção nesta entrega. Ações de gestão para Dev, Proprietário e administradores da construtora |

As tabelas de S3, S4 e S5 foram aceitas pelo usuário como referência suficiente, sem novos mocks. A ação de logo no Painel Dev adota o mesmo LogoEditor e não amplia outros fluxos do painel.

## State Patterns

| Superfície | Estados e resposta obrigatória |
|---|---|
| S0 shell | Contexto carregando não libera atalhos; item ativo/foco visível; acesso negado conserva o tratamento de proteção existente. Offline não revela rotas escondidas nem cria permissões |
| S1 construtoras | Carga anunciada; dados com nome/CNPJ; vazio comum orienta procurar administrador; vazio dev preserva ação de gerenciamento existente. Erro distinto do vazio. Ausência/falha da imagem usa iniciais e mantém nome. Não anunciar catálogo completo quando a fonte não comprovar |
| S2 lotes | Carga, dados, vazio e erro separados. Offline/cache não recebe selo de atualização sem metadados; sem dados não afirmar inexistência se leitura falhou. Quatro status com texto/ícone. Sem permissão herda proteção atual |
| S3 Novo Lote | Inicial com fase/status padrão atuais; nome inválido impede envio e recebe erro. Envio impede duplicação. Falha conserva entradas em sessão; sucesso segue retorno atual somente com conclusão informada pela operação. Não prometer criação offline nem retry automático |
| S4 Atualizar lote | Inicial com dados existentes; envio, conclusão e falha. Fase e status são duas operações: falha após primeira não vira sucesso integral nem “nada salvo”. Manter escolhas para consulta/correção. Se há certeza por campo, mostrar o resultado por campo; se não, indicar confirmação incompleta. Não introduzir atomicidade/rollback em UX |
| S5 Gerenciar logo | Logo atual ou iniciais; seleção local e prévia; arquivo inválido com motivo; envio com progresso disponível ou indicador indeterminado; confirmação; falha comprovadamente anterior à publicação conserva publicada e prévia identificada para correção. Offline bloqueia envio com orientação de conexão. Acesso revogado impede publicação e não anuncia sucesso. Resultado incerto oferece Verificar logo atual e Fechar, sem afirmar preservação da logo anterior ou habilitar reenvio |

Os metadados atuais de leitura de lotes não comprovam frescor/pendência. A aparência não pode converter cache em confirmação remota. Nesta entrega não se adicionam política de expiração, fila de sincronização, novas permissões de lotes nem transação entre fase e status. Eventuais lacunas técnicas que impeçam feedback verdadeiro devem ser explicitadas na arquitetura antes de estimar implementação.

### Logo — proposta operacional

[ASSUMPTION] Seleção PNG ou JPEG de até 5 MB, sem crop obrigatório, conteúdo ajustado com contain e sem recolorir a empresa. Arquivo maior/formato diferente recebe motivo antes de enviar. Dimensões, tratamento seguro e armazenamento serão definidos pela arquitetura; não inferir suporte atual, pois o modelo consultado não contém logo.

Upload exige conexão; prévia fica local antes do envio. A interface mantém a imagem anteriormente conhecida nos cards enquanto aguarda confirmação, sem prometer que o servidor continua nesse estado. Confirmada a publicação, atualiza o card. Falha de carregamento usa iniciais com nome intacto. Primeiras letras de até duas palavras do nome, ou primeira letra quando houver uma só; nomes vazios usam ícone de empresa. A inicial é decorativa para leitores de tela.

O editor mostra “Logo de [nome da construtora]” e CNPJ quando disponível em prévia, envio e resultado. O alvo é o da abertura e permanece estável; trocar de contexto exige fechar e abrir outro editor, sem transportar a seleção. A publicação revalida autorização para essa mesma construtora; administrar outra empresa não concede acesso ao alvo.

**Permissão confirmada:** Dev pelo Painel Dev, Proprietário e administradores da construtora podem cadastrar/trocar. Admin de obra ou outros membros não recebem essa capacidade apenas por seu papel na obra. Gerenciar logo aparece no card para Proprietário/admin da construtora; no Painel Dev é ação contextual da construtora já selecionada, sem criar outro cadastro. A arquitetura deve vincular esses termos aos papéis reais e aplicar a mesma autorização na gravação. Sem remover logo e sem novo caminho de cadastro de construtora.

### Saída durante envio e confirmação incerta

Antes de submeter S3/S4/S5, Cancelar, Fechar ou Voltar descarta somente alterações locais. Após submeter, não prometer cancelamento da gravação: enquanto a operação é acompanhada, desabilitar nova submissão, nova seleção de arquivo, Cancelar e fechamento incidental por Esc, voltar, barreira ou arraste; anunciar Salvando alterações/Salvando logo e o motivo do bloqueio. Isso não garante impedir fechamento do aplicativo, navegador ou interrupção do sistema.

O bloqueio não é indefinido: se a operação terminar sem confirmação, a conexão impedir acompanhamento ou ocorrer timeout reconhecido, passar a **resultado incerto**, sem tempo fixo de UX e sem tratar timeout como prova de falha. Oferecer Fechar com o aviso “Fechar não cancela a operação enviada; o resultado ainda precisa ser confirmado”. Não repetir a operação automaticamente. Falha comprovada anterior à escrita/publicação permite corrigir e tentar novamente; uma resposta perdida não recebe essa garantia.

Para lotes, resultado incerto/possivelmente parcial mantém escolhas identificadas enquanto o formulário está aberto; Fechar libera navegação. Ao reencontrar o lote, confrontar dados disponíveis sem alegar que cache prova confirmação remota. Não reenviar a tentativa incerta nem anunciar reversão por ter fechado. Se houver evidência por campo, indicar qual resultado é conhecido; arquitetura deve definir a observabilidade necessária antes da implementação.

Para logo, **Verificar logo atual** consulta evidência autoritativa de publicação da mesma construtora, não o card em cache. Estados: Verificando logo atual; resultado conhecido com logo publicada identificada; ou “Ainda não foi possível confirmar a troca”. Manter prévia local/nome de arquivo separados do estado publicado. Confirmada a nova imagem, atualizar o card; comprovada a não publicação da tentativa, permitir nova tentativa explícita. Se apenas a imagem antiga estiver visível e a tentativa puder continuar pendente, manter incerteza e não liberar novo envio. Fechar continua disponível; ao reabrir a gestão dessa construtora, retomar verificação antes de nova publicação. A arquitetura define como obter evidência e acompanhar tentativa pendente; o contrato não inventa storage, API, rollback ou cancelamento real.

## Interaction Primitives

Toque/clique têm alvos de `{spacing.touch-min}`. Teclado percorre navegação → conteúdo → ações na ordem visual; Shift+Tab inverte, Enter/espaço acionam controles, Esc fecha overlays antes do envio; durante envio e incerteza aplica-se a política explícita acima. Não permitir que Vistorias ou Gerenciar logo também acione o card.

Foco usa tokens `{colors.focus-light}`, `{colors.focus-sidebar}` e `{colors.focus-header}`; hover não muda posição. Campo incorreto recebe associação de erro e foco na primeira tentativa inválida. Notificações não removem o contexto. Redução de movimento é respeitada; nenhuma animação é indispensável. Não acrescentar atalhos globais ou gestos ocultos.

## Accessibility Floor

Metas verificáveis, sem declaração de conformidade: texto normal ≥4,5:1, grandes/indicadores essenciais ≥3:1; alvo mínimo de 48 unidades lógicas; ícones acionáveis com nome; status com texto e ícone; logo não substitui nome; foco visível/restaurado em overlays.

Verificar larguras lógicas 320, 390, 800, 801, 1280 e 1440; texto em 100%, 130% e 200%. Nome com 80 caracteres e fase com 60 não pode perder conteúdo, esconder botões ou causar rolagem horizontal. Reflow pode aumentar altura e reduzir colunas. Leitor de tela deve identificar construtora/lote e destino de cada ação sem repetir a identidade decorativa. Teclado e áreas seguras não cobrem o botão final do formulário.

## Responsive & Platform

Até 800 unidades lógicas inclusive: drawer, coluna única e título `{typography.page-mobile}`; acima de 800 unidades lógicas: lateral herdada e `{typography.page-desktop}`, grid dependente da área útil. Compactação de lotes usa `{spacing.lot-padding}` e `{spacing.lot-gap}`; não reduz alvos. Construtoras usam `{spacing.constructor-padding-mobile}`/`{spacing.constructor-padding-desktop}`.

Nome/status em linhas separadas quando necessário. Atualizar lote e Vistorias empilham na mesma ordem quando não cabem. Novo Lote pode passar para linha própria. Formulários e LogoEditor usam coluna única rolável; overlay de logo proposto como diálogo desktop e sheet mobile, sem novo destino global. Lote conserva o bottom sheet atual nos dois formatos.

## Key Flows

Protagonistas abaixo são fictícios, usados como cenários de aceite; não constituem pesquisa nem novos perfis de permissão.

### J0 — Navegar no contexto existente

1. Carla abre o menu no telefone; no desktop usa a lateral.
2. Escolhe um destino atualmente permitido no contexto de obra.
3. **Clímax:** destino correto abre com a mesma obra e indicação de localização.
4. Falha: se acesso foi revogado, recebe proteção existente; o novo visual não libera o conteúdo. Fechar o drawer sem navegar devolve foco ao menu.

### J1 — Escolher construtora

1. Carla abre Minhas Construtoras e aguarda a lista.
2. Reconhece nome, logo/iniciais e CNPJ, quando disponível.
3. **Clímax:** Acessar construtora abre a empresa correta pelo destino atual.
4. Falha: logo indisponível mantém nome/iniciais; erro de lista não vira vazio. Lista vazia mostra orientação adequada ao acesso existente.

### J2 — Identificar e atualizar lote

1. Ana abre Mapa de Lotes da obra e distingue nome, fase e status.
2. Escolhe Atualizar lote, altera fase/status nos seletores e salva.
3. **Clímax:** conclusão informada pela operação fecha o sheet e permite reconhecer o lote alterado; foco volta ao acionador.
4. Falha: se uma gravação falhar, não anunciar sucesso integral. Manter escolhas, indicar confirmação incompleta e evitar retry automático; cache não prova resultado remoto.

### J3 — Cadastrar lote

1. Ana usa Novo Lote; informa nome e escolhe fase/status inicial.
2. Campo vazio recebe erro associado e permanece no formulário.
3. **Clímax:** envio concluído pelo fluxo atual retorna à lista, onde o novo lote é reconhecível.
4. Falha: entradas permanecem em sessão, sem declarar cadastro confirmado ou pendência offline inexistente.

### J4 — Abrir vistorias do lote

1. Paulo localiza o lote pelo nome e contexto da obra.
2. Aciona Vistorias sem abrir simultaneamente a edição.
3. **Clímax:** chega à rota existente com o lote correto; voltar permite reencontrar o contexto.
4. Falha: destino sem acesso segue a regra atual; não criar autorização nem redesenhar o módulo de vistorias.

### J5 — Cadastrar ou trocar logo

1. Carla, administradora da construtora, abre Gerenciar logo no card; Otávio, Proprietário, usa a mesma entrada. Davi, Dev, seleciona a construtora no Painel Dev e abre sua gestão de logo.
2. Seleciona arquivo válido, confere a construtora alvo, nome do arquivo e prévia “Selecionada, ainda não salva”; cancelar antes do envio descarta apenas a seleção.
3. Salva com conexão, acompanha envio e não navega por acionamento acidental do card.
4. **Clímax:** confirmação substitui a imagem do card pela logo selecionada mantendo nome e proporção; cada pessoa retorna à origem, card ou Painel Dev.
5. Falha: arquivo inválido ou falha comprovada antes da publicação conserva a logo anterior; resposta perdida leva a Verificar logo atual, podendo fechar com aviso sem cancelar a tentativa. Revogação de acesso impede nova publicação, mas não prova o resultado de uma operação anterior.
