---
id: SPEC-remodelagem-loteamentos-sem-geometria
companions:
  - data-contracts.md
  - architecture-diagrams.md
sources: []
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate. Source documents listed in frontmatter are for traceability — consult them only if you need narrative rationale or prose color this contract intentionally omits.

# Remodelagem da Criação e Gestão de Loteamentos Sem Geometria

## Why

A criação de loteamentos baseada em extração e revisão geométrica de polígonos (GeoJSON e Canvas) adicionava complexidade operacional incompatível com o fluxo real da construtora, que trabalha com pranchas arquitetônicas em PDF e relações dimensionais de quadras e lotes. Remodelar o módulo para um modelo cadastral e dimensional sem geometria acelera o cadastro via importação de PDFs e geração manual em massa, além de entregar visualização executiva em cards com percentual de conclusão das etapas e atribuição prática de equipes e funcionários.

## Capabilities

- **CAP-1**
  - **intent:** Administradores podem criar loteamentos, quadras e lotes manualmente, tanto individualmente quanto gerando múltiplos itens em massa a partir da quantidade desejada e das medidas padrão.
  - **success:** Ao informar quantidade de lotes e medidas padrão (frente e profundidade), o sistema calcula automaticamente a área do terreno, permite ajustar exceções antes da gravação e cria no Firestore o loteamento, as quadras, os lotes e suas cinco etapas padrão.
- **CAP-2**
  - **intent:** Administradores podem importar um PDF de lote único, um PDF multipágina ou múltiplos arquivos PDF em um mesmo rascunho — mantendo o suporte a arquivos DXF e DWF — para extrair dados do loteamento, quadra, lote, medidas e quadro de áreas sem geometria.
  - **success:** Ao enviar a prancha PDF de um lote arquitetônico, o backend preenche automaticamente no rascunho tabular o loteamento, localização, proprietário, responsável técnico, quadra, lote, logradouro, dimensões, área do terreno, área construída e índices urbanísticos opcionais.
- **CAP-3**
  - **intent:** Usuários podem revisar e editar os dados extraídos em uma tela tabular, escolher entre criar um novo loteamento ou mesclar em um loteamento existente, e utilizar um lote extraído como modelo para gerar os demais lotes da mesma quadra.
  - **success:** Na tela de revisão tabular, o usuário aciona a geração complementar de lotes da quadra copiando as medidas do lote extraído para o intervalo informado e consolida todos os lotes e suas cinco etapas no Firestore sem passar por canvas geométrico.
- **CAP-4**
  - **intent:** Usuários visualizam os lotes de uma quadra em formato de card (`LoteSummaryCard`) apresentando medidas resumidas, percentual de conclusão das etapas e alocações de equipes ou funcionários.
  - **success:** Na listagem de lotes da quadra, cada card exibe identificação, logradouro, dimensões, área do terreno, área construída, barra e percentual de conclusão das cinco etapas (0% a 100%), indicadores individuais das etapas e botão de acesso rápido à atribuição.
- **CAP-5**
  - **intent:** Ao clicar no card de um lote, o usuário acessa a tela de detalhes completos do lote (`LoteDetailScreen`) contendo toda a ficha técnica, as alocações e o controle interativo das cinco etapas.
  - **success:** Clicar em um card abre `LoteDetailScreen` com todas as medidas principais e campos opcionais extraídos do PDF e permite alterar o status ou percentual de qualquer etapa, recalculando imediatamente o progresso exibido no card e no detalhe do lote.
- **CAP-6**
  - **intent:** Administradores podem atribuir ou remover equipes e funcionários da construtora diretamente a partir do card do lote ou da tela de detalhes do lote, com vínculo geral ou por etapa.
  - **success:** Ao selecionar uma equipe ativa ou um funcionário ativo do módulo de RH no seletor rápido de atribuição, o vínculo é persistido no lote e exibido imediatamente no card da quadra e na tela de detalhes.

## Constraints

- Polígonos GeoJSON (`geometry`) e os componentes visuais de mapa (`LoteamentoCanvasScreen` e `GeojsonCanvasWidget`) não devem mais ser utilizados na criação, revisão ou persistência de `loteamentos`, `quadras`, `lotes` e `loteamentos_drafts`.
- O upload de arquivos `.dxf` e `.dwf` deve ser mantido na importação para evolução futura, convertendo sua saída exclusivamente para o contrato tabular definido em `data-contracts.md`.
- Índices urbanísticos secundários, recuos e metadados de carimbo provenientes de PDF devem permanecer sempre opcionais na criação e edição manual, sendo preenchidos automaticamente quando detectados na importação.
- Toda criação de lote (manual individual, manual em massa ou consolidação de rascunho importado) deve criar atomicamente suas cinco etapas padrão (`Muro`, `Cinza/1ª`, `Cinza/2ª`, `Cinza/3ª`, `Branca/Acabamento`) respeitando o limite de 500 operações por `WriteBatch` do Firestore.
- O percentual de conclusão, o mapa resumido das etapas e os resumos de equipes e funcionários vinculados devem ser mantidos desnormalizados no documento `lotes/{id}` para evitar consultas em cascata ao renderizar a grade de cards da quadra.

## Non-goals

- Renderização de plantas interativas, mapas georreferenciados, edição vetorial ou validação espacial de polígonos.
- Alteração nas regras de cálculo salarial, diárias ou fechamento de chamadas diárias do módulo de RH.

## Success signal

- Um administrador consegue cadastrar um loteamento completo tanto gerando dezenas de lotes manualmente em massa com suas medidas quanto importando pranchas PDF de projetos arquitetônicos, visualiza todos os lotes da quadra em cards com barra de progresso das etapas, abre a ficha técnica completa ao clicar no card e atribui equipes ou funcionários em poucos cliques.
