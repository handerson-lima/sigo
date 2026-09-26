---
stepsCompleted: [1, 2, 3]
inputDocuments: [
  "_bmad-output/specs/spec-importacao-dxf/SPEC.md",
  "_bmad-output/planning-artifacts/architecture/architecture-obras-2026-09-26/ARCHITECTURE-SPINE.md",
  "_bmad-output/ux/ux-importacao-dxf/DESIGN.md",
  "_bmad-output/ux/ux-importacao-dxf/EXPERIENCE.md"
]
---

# obras - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for obras, decomposing the requirements from the PRD, UX Design if it exists, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: O sistema deve permitir que o usuário faça o upload de um arquivo DXF para iniciar o processamento em background.
FR2: O sistema deve processar a geometria do DXF (Point-in-Polygon) no backend, gerando um rascunho em formato GeoJSON armazenado na coleção `loteamentos_drafts` no Firestore.
FR3: O sistema deve identificar lotes ambíguos ou sem identificação clara durante o processamento, sinalizando-os com status `ambiguo` no rascunho GeoJSON.
FR4: O sistema deve renderizar o rascunho para o usuário final, permitindo que ele visualize a planta geográfica na UI, resolva as ambiguidades identificadas e aprove o rascunho.
FR5: O sistema deve atualizar o status do rascunho para aprovado no Firestore após as resoluções do usuário na interface.
FR6: Após aprovação do rascunho, o sistema executará as inserções em lote (batch writes) nas coleções de produção (`loteamentos`, `quadras`, `lotes`) de maneira assíncrona (background), finalizando com a exclusão do rascunho.

### NonFunctional Requirements

NFR1: O parsing do DXF e os cálculos matemáticos complexos de Point-in-Polygon NUNCA devem ocorrer no cliente web para não bloquear a thread principal em interfaces Flutter.
NFR2: As inserções de produção não devem ser executadas no front-end para contornar limites transacionais (máximo 500 writes do Firestore) e previnir interrupções parciais se o usuário fechar a interface.
NFR3: A persistência final dos dados nas coleções da base de dados raiz de produção deve seguir um modelo relacional flat, sem aninhamento, utilizando Foreign Keys.
NFR4: A comunicação entre UI e Backend via Firestore deve utilizar rigorosamente o formato de GeoJSON, expandido apenas com as propriedades de dados tipo, nome e status.

### Additional Requirements

- O backend deve ser implementado através de Cloud Functions em Python (Gen 2; 3.11+).
- Devem ser incluídas as bibliotecas `ezdxf` e `shapely` no ambiente da Cloud Function.
- O Cloud Storage será acionado via gatilho de OnFinalize.
- O workflow contará com trigger OnUpdate acionado quando um rascunho é aprovado.
- As rotas renderizadas para a revisão na interface (UI) devem seguir as diretrizes do pacote de navegação GoRouter.

### UX Design Requirements

UX-DR1: Implementar Canvas contínuo com "fundo infinito", permitindo manipulação da planta através de Pan & Zoom (arrastar o clique e scroll do mouse).
UX-DR2: Renderizar os polígonos GeoJSON no canvas adotando um estilo por status: alerta laranja/amarelo para "ambiguo" (c/ pulso dinâmico), neutro para base válida e verde sucesso para lotes recentemente corrigidos pelo usuário.
UX-DR3: Criar um Painel Lateral (Side Panel) direito acoplado para abrigar a digitação da identificação correta (ex: "Lote 14") de lotes acionados via clique no canvas, além de botões "Salvar" e "Ignorar".
UX-DR4: Otimizar o workflow por teclado centrado: ao selecionar um lote no mapa, o input numérico/texto lateral deve ganhar foco automático, aceitando a confirmação da edição diretamente com o toque da tecla ENTER.
UX-DR5: Incorporar um Chip Dinâmico ou Barra de Status na interface (superior) exibindo dinamicamente o contador regressivo de "X Lotes Ambíguos" pendentes de revisão.
UX-DR6: Desabilitar bloqueando o acionamento do Botão Principal "Aprovar Definitivamente" caso exista um ou mais lotes com sinal de ambíguo e habilitar na superação destas pendências.

### FR Coverage Map

FR1: Epic 1 - Upload do arquivo via front-end.
FR2: Epic 2 - Extração e gravação do rascunho GeoJSON no backend.
FR3: Epic 2 - Algoritmo de identificação e marcação de ambiguidades no GeoJSON.
FR4: Epic 1 (Escuta/Visualização Inicial) e Epic 3 (Resolução interativa no Canvas).
FR5: Epic 3 - Mutação de status "aprovado" acionada pela UI.
FR6: Epic 4 - Execução dos batches flat no backend e limpeza.

## Epic List

### Epic 1: Upload e Monitoramento de Rascunho (Flutter UI)
O usuário consegue submeter o arquivo físico do loteamento (DXF) e acompanhar visualmente o estado de carregamento contínuo ("Processando Geometria") até que o rascunho seja retornado pelo backend para visualização.
**FRs covered:** FR1, FR4 (parcial)

### Epic 2: Processamento Geométrico Assíncrono (Backend Python)
O arquivo enviado é traduzido perfeitamente de CAD para um modelo geográfico navegável no backend de forma assíncrona, com áreas problemáticas analisadas, isoladas e devolvidas como um Rascunho Imutável.
**FRs covered:** FR2, FR3

### Epic 3: Revisão e Resolução Interativa de Ambiguidades (Flutter UI)
O usuário visualiza o loteamento em um Canvas responsivo, localiza lotes problemáticos visualmente e os corrige rapidamente através do Painel Lateral utilizando atalhos de teclado, até destravar a aprovação final.
**FRs covered:** FR4 (parcial), FR5

### Epic 4: Consolidação e Persistência Flat (Backend Python)
O loteamento revisado e aprovado pela interface torna-se definitivo e consultável no sistema de forma performática através de batches nas coleções flat de produção, extinguindo o rascunho temporário.
**FRs covered:** FR6

## Epic 1: Upload e Monitoramento de Rascunho (Flutter UI)

O usuário consegue submeter o arquivo físico do loteamento (DXF) e acompanhar visualmente o estado de carregamento contínuo ("Processando Geometria") até que o rascunho seja retornado pelo backend para visualização inicial.

### Story 1.1: Componente de Upload de Arquivo DXF

As a Analista de Projetos,
I want enviar um arquivo de loteamento no formato .dxf através da interface web,
So that o sistema receba os dados brutos e possa iniciar sua conversão.

**Acceptance Criteria:**

**Given** que o usuário acessa a tela de Importação de Loteamento
**When** ele arrasta e solta um arquivo `.dxf` (ou utiliza o botão de seleção de arquivo) e clica em enviar
**Then** o aplicativo Flutter realiza o upload do arquivo diretamente para o bucket designado no Cloud Storage
**And** a interface sinaliza visualmente a progressão ou a conclusão imediata do envio do arquivo físico.

### Story 1.2: Listener de Processamento e Sala de Espera (Animação)

As a Analista de Projetos,
I want visualizar que a geometria do arquivo está sendo ativamente processada,
So that eu saiba que o sistema não travou e aguarde com segurança a geração do rascunho.

**Acceptance Criteria:**

**Given** que o upload do arquivo DXF foi recém-concluído
**When** o sistema aguarda a geração do rascunho (ouvindo o documento correspondente na coleção `loteamentos_drafts` no Firestore)
**Then** a UI exibe a animação contínua "Processando Geometria..." (micro-interação) sem realizar polling agressivo
**And** assim que o snapshot do documento GeoJSON é recebido via stream do Firestore, a tela transiciona automaticamente injetando os dados na próxima etapa (Canvas de Revisão).

## Epic 2: Processamento Geométrico Assíncrono (Backend Python)

O arquivo enviado é traduzido perfeitamente de CAD para um modelo geográfico navegável no backend de forma assíncrona, com áreas problemáticas analisadas, isoladas e devolvidas como um Rascunho Imutável.

### Story 2.1: Gatilho OnFinalize e Extração de Geometria Bruta

As a Arquitetura de Importação,
I want reagir automaticamente ao upload do DXF no Cloud Storage e ler suas entidades CAD,
So that eu possa ter os polígonos brutos (lotes, quadras e textos) carregados na memória da Cloud Function.

**Acceptance Criteria:**

**Given** que um arquivo `.dxf` foi salvo no Cloud Storage pela UI
**When** a Cloud Function Python (Gen 2) é acionada via trigger `OnFinalize`
**Then** o arquivo deve ser lido e parseado usando a biblioteca `ezdxf`
**And** os blocks e geometrias associadas às Quadras e Lotes devem ser isolados em estruturas de dados em memória, prontos para cálculos.

### Story 2.2: Algoritmo Espacial Point-in-Polygon

As a Arquitetura de Importação,
I want cruzar espacialmente a geometria plana extraída,
So that o sistema saiba exatamente quais polígonos de lote pertencem e estão contidos dentro de quais quadras.

**Acceptance Criteria:**

**Given** as geometrias limpas extraídas do `ezdxf` na memória
**When** a lógica utiliza a biblioteca `shapely` para processar a topologia
**Then** cada polígono classificado como "Lote" deve passar por um teste Point-in-Polygon contra as "Quadras"
**And** o resultado deve ser uma hierarquia em memória mapeando corretamente os relacionamentos espaciais entre eles.

### Story 2.3: Heurística de Ambiguidades e Persistência do Rascunho (GeoJSON)

As a Arquitetura de Importação,
I want parear os textos com os polígonos e gerar o objeto final no banco,
So that o Flutter possa renderizar o mapa GeoJSON completo e focar a atenção do usuário nos lotes defeituosos.

**Acceptance Criteria:**

**Given** os Lotes e Quadras estruturados espacialmente na memória
**When** o algoritmo tentar associar as strings de texto (ex: números dos lotes) aos seus respectivos polígonos de lote
**Then** lotes sem identificador interno válido ou textos ambíguos devem receber a propriedade estendida `"status": "ambiguo"`
**And** lotes parseados com sucesso devem receber um status neutro/valido
**And** o payload completo deve ser rigorosamente serializado como GeoJSON
**And** o arquivo final deve ser persistido como um único documento na coleção `loteamentos_drafts` no Firestore, finalizando a execução da função.

## Epic 3: Revisão e Resolução Interativa de Ambiguidades (Flutter UI)

O usuário visualiza o loteamento em um Canvas responsivo, localiza lotes problemáticos visualmente e os corrige rapidamente através do Painel Lateral utilizando atalhos de teclado, até destravar a aprovação final.

### Story 3.1: Canvas Interativo e Renderização Estilizada de Polígonos

As a Analista de Projetos,
I want navegar livremente pela planta do loteamento gerada pelo backend,
So that eu encontre visualmente e com clareza as áreas problemáticas da importação.

**Acceptance Criteria:**

**Given** que o documento GeoJSON do rascunho foi carregado pela UI
**When** a tela de Revisão é exibida
**Then** um componente de Canvas contínuo (fundo infinito) deve ser renderizado permitindo navegação fluida por arrasto (Pan) e rolagem (Zoom)
**And** todos os polígonos contidos no GeoJSON devem ser pintados na tela
**And** polígonos com propriedade `"status": "ambiguo"` devem ser renderizados com cor de Alerta (Laranja/Amarelo) e animação de pulso, enquanto os demais permanecem Neutros (Cinza).

### Story 3.2: Fluxo Rápido de Correção via Painel Lateral e Teclado

As a Analista de Projetos,
I want selecionar um lote ambíguo e identificar seu número rapidamente usando atalhos,
So that eu possa resolver dezenas de ambiguidades sequenciais em poucos segundos, sem uso intensivo do mouse.

**Acceptance Criteria:**

**Given** que o usuário está visualizando a planta no Canvas
**When** ele clica (seleciona) um polígono marcado como `ambiguo`
**Then** um Painel Lateral de Correção deve abrir (ou deslizar) à direita contendo um campo de texto para o Identificador
**And** o campo de input deve receber foco automático (*autofocus*) imediatamente
**And** ao digitar o valor correto e pressionar a tecla `ENTER`, o lote deve ser atualizado localmente na UI, mudando sua renderização no mapa para a cor "Verde Sucesso" (resolvido).

### Story 3.3: Gestão de Pendências e Gatilho de Aprovação

As a Analista de Projetos,
I want acompanhar exatamente quantos lotes restam corrigir e ser impedido de prosseguir com falhas,
So that eu tenha garantia de que só estou aprovando um loteamento 100% íntegro para a base de produção.

**Acceptance Criteria:**

**Given** que a tela de Revisão está em uso
**When** houver polígonos marcados como `ambiguo` não resolvidos no GeoJSON (state local)
**Then** uma Barra de Status (ou Chip flutuante) superior exibirá um contador regressivo (ex: "12 Lotes Ambíguos")
**And** o botão principal de ação "Aprovar Loteamento Definitivamente" permanecerá desabilitado (cinza)
**And** quando o contador de pendências atingir zero (0), a UI deve celebrar e o botão principal tornar-se habilitado (clicável)
**And** ao clicar no botão habilitado, o sistema gravará o update no documento Firestore alterando seu status para `"aprovado"`.

## Epic 4: Consolidação e Persistência Flat (Backend Python)

O loteamento revisado e aprovado pela interface torna-se definitivo e consultável no sistema de forma performática através de batches nas coleções flat de produção, extinguindo o rascunho temporário.

### Story 4.1: Gatilho OnUpdate e Carregamento do Rascunho Aprovado

As a Arquitetura de Importação,
I want escutar o exato momento em que um usuário aprova um loteamento na interface,
So that a Cloud Function de consolidação seja acionada isoladamente.

**Acceptance Criteria:**

**Given** um documento de rascunho ativo na coleção `loteamentos_drafts`
**When** seu campo `"status"` for atualizado para `"aprovado"` (via UI Flutter)
**Then** uma Cloud Function Python configurada com trigger `OnUpdate` entra em execução
**And** carrega para a memória o documento GeoJSON contendo a estrutura com as propriedades corrigidas pelo usuário.

### Story 4.2: Inserção Flat via Firestore Batch Writes

As a Arquitetura de Importação,
I want separar o GeoJSON aprovado em entidades autônomas de banco de dados,
So that a base final permaneça consultável por relacionamentos ("flat") e nenhuma inserção falhe por limites do servidor.

**Acceptance Criteria:**

**Given** o GeoJSON aprovado estruturado em memória na Cloud Function
**When** o algoritmo preparar a inserção final na base
**Then** um documento central deve ser gerado na coleção raiz `loteamentos`
**And** documentos devem ser gerados na coleção `quadras` portando o ID do loteamento como *Foreign Key*
**And** documentos devem ser gerados na coleção `lotes` portando o ID da quadra e do loteamento como *Foreign Keys*
**And** as inserções devem ser agrupadas usando a API de `Batch Writes` do Firestore
**And** se o total de gravações ultrapassar 500 documentos, o script deve fatiar inteligentemente os batches para respeitar o limite transacional (Firestore 500-write limit).

### Story 4.3: Exclusão Final do Rascunho Temporário (Limpeza)

As a Arquitetura de Importação,
I want excluir o rascunho GeoJSON pesado após o sucesso da inserção,
So that eu previna que a base acumule gigabytes de lixo temporário desnecessário (*tombstones*).

**Acceptance Criteria:**

**Given** que os `batch writes` da Story 4.2 foram "comitados" com sucesso no Firestore
**When** a rotina atingir sua instrução final de encerramento
**Then** o script emitirá o comando de deleção para o documento correspondente na coleção `loteamentos_drafts`
**And** a Cloud Function deverá ser encerrada retornando um status formal de Sucesso (HTTP 200 / Log Info).
