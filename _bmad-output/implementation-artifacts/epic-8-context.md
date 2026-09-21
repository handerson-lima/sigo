# Epic 8 Context: Visibilidade dos vínculos

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Permitir que admin e owner da construtora enxerguem cada membro com cargo, quantidade de obras vinculadas e pendentes no topo, e abram o detalhe do vínculo, para saber quem está alocado onde antes de atribuir, remover ou trocar papéis.

## Stories

- Story 8.1: Lista com Cargo · N obras
- Story 8.2: Filtros e busca
- Story 8.3: Detalhe do membro

## Requirements & Constraints

- Rota de membros restrita a admin/owner; operário nunca acessa.
- Lista mostra pendentes no topo e ativos abaixo com subtitle no formato cargo mais contador de obras.
- Filtros Todos / Por obra / Pendentes mais busca local por email/displayName; estados vazios com mensagens explícitas em pt-br.
- Detalhe exibe bloco de vínculo da construtora (cargo, status, desde quando) mais bloco de obras vinculadas; sem obra mostra chamada para atribuir e membro inativo mostra aviso de pré-requisito com atalho de ativação.
- Leitura pode usar cache Firestore; sem escrita neste epic.
- Papel nunca comunicado só por cor; honrar textScale até 1.3x sem quebrar layout.
- Responsivo Mobile + Web PWA no layout padrão (bottomsheet mobile / dialog desktop).

## Technical Decisions

- Agregação de obras no cliente: lista base combina membros da construtora mais pedidos pendentes; filtro por obra abre um stream por obra ativa e junta em memória por uid, sem collectionGroup.
- Novos acessos de leitura: observar membros por obra e obras por membro; seguir convenções de nomes de providers e repositories já definidas (membros por construtora, membros por par construtora+obra, obras da construtora).
- Leitura segue padrão de StreamProvider com descarte automático; após mutações futuras invalidar providers de membros e de membros por obra com pull-to-refresh.
- Normalizar papel legado de leitura para Operário; nunca tratar owner como papel de obra.
- Revogação de acesso é avaliada por vínculo ativo na construtora; documentos órfãos são inócuos.
- Datas de vínculo toleram formato legado na leitura; auditoria permanece só no servidor sem UI.

## UX & Interaction Patterns

- Linha do membro com avatar por papel, subtitle de cargo e contador, chip de papel mais chevron; tap abre detalhe.
- Chips de papel com tokens fixos por papel (proprietário âmbar, admin azul, operário neutro, pendente laranja) usando ícone mais texto.
- Detalhe como bottomsheet arrastável no mobile e dialog estreito no desktop, com blocos de vínculo, obras e ações; linha por obra com nome, papel, status e menu.
- Filtro em segmented mais busca no topo; dropdown de obra com estado vazio explícito.
- Estados de loading com skeleton, erro com retry, vazio com mensagem pt-br; microcopy operacional com nome da obra e papel explícitos.
- Acessibilidade: leitor anuncia nome, cargo, N obras e status; chips com rótulo semântico; foco preso no dialog com Esc para fechar e Enter para confirmar; alvos de toque mínimos.

## Cross-Story Dependencies

- Lista base sustenta filtros/busca e detalhe; detalhe prepara atribuição, troca de papel/módulos, remoção e desativação tratados nos epics seguintes.
- Contador de obras depende da agregação por obra ativa; detalhe depende do vínculo ativo na construtora como pré-requisito.
