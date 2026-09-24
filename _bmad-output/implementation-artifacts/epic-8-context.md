# Epic 8 Context: Visibilidade dos vínculos

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Dar visibilidade completa dos vínculos a admin e owner da construtora: a lista de membros mostra cada pessoa com cargo e contagem de obras (`Operário · 2 obras`), pendentes no topo, filtros e busca para localizar alguém rápido, e um detalhe com o vínculo da construtora mais as obras vinculadas — para o gestor decidir corretamente quem atribuir, remover ou trocar nos epics seguintes, sem tela de atribuição às cegas.

## Stories

- Story 8.1: Lista com Cargo · N obras
- Story 8.2: Filtros e busca
- Story 8.3: Detalhe do membro

## Requirements & Constraints

- Rota `/construtora/:cId/membros` restrita a admin/owner (`AccessGuard(adminOnly:true)`); operário nunca acessa.
- Lista: pendentes no topo (`Pendente · Cargo`) e ativos abaixo com subtitle `Cargo · N obras`; avatar e chip por papel (owner âmbar com estrelas, admin azul, operário neutro, pendente laranja); papel nunca comunicado só por cor.
- Filtros `Todos / Por obra / Pendentes` mais busca local por email/displayName; estados vazios explícitos em pt-br (`Nenhum membro encontrado.`, `Nenhuma obra ativa`).
- Detalhe do membro: bloco vínculo construtora (cargo, status, desde quando), bloco obras vinculadas (`ObraVinculoRow`) e ações; sem obras mostra `Nenhuma obra vinculada — Atribuir`; membro inativo mostra aviso de pré-requisito com atalho `Ativar`.
- Epic somente leitura — nenhuma escrita de vínculo aqui; leitura pode usar cache Firestore.
- Acessibilidade: leitor anuncia nome, cargo, N obras e status; chips com rótulo semântico; `textScale` até 1.3x sem quebrar trailing; alvos ≥48dp; foco trap em dialog com `Esc` fecha.
- Responsivo Mobile + Web PWA em `SigoLayout`: detalhe como BottomSheet arrastável (mobile) / Dialog 480px (desktop); microcopy pt-br operacional.

## Technical Decisions

- Agregação no cliente (sem `collectionGroup`): base `Todos` = `watchMembros(c)` + `watchPendingRequests(c)`; `Por obra` = um `watchObraMembers(c,o)` por obra ativa + junção em memória `uid→[obras]`; busca filtra email/displayName localmente.
- Novos caminhos de leitura e providers: `watchObraMembers`, `watchObrasDoMembro`, `obrasDaConstrutoraProvider(c)`, `membrosProvider(c)`, `obraMembersProvider((c,o))`; padrão `StreamProvider.autoDispose.family`.
- Papel legado `member` lido como `Operário`; `owner` nunca é papel de obra.
- Revogação efetiva avaliada por vínculo ativo na construtora (gate `active(cm)`); documentos órfãos são inócuos.
- Datas de vínculo toleram formato legado na leitura; auditoria permanece só no servidor, sem UI.
- Preparação para mutações dos epics 9–10: após qualquer mutação futura invalidar `membrosProvider` + `obraMembersProvider`; pull-to-refresh como fallback.

## UX & Interaction Patterns

- `MemberRow`: avatar 40px por papel, nome/email em 1 linha, subtitle `Cargo · N obras`, trailing chip + chevron; tap abre detalhe (pendente não abre detalhe — tap mostra info do pedido).
- `RoleChip` com tokens fixos por papel (âmbar/azul/neutro/laranja), sempre ícone + texto.
- Detalhe em BottomSheet mobile / Dialog desktop com três blocos: Vínculo construtora, Obras vinculadas (`ObraVinculoRow`: nome, papel obra, status), Ações (gatilhos de atribuição/gestão ficam para epics 9–10).
- Filtro segmented + busca no header; estados de loading com skeleton, erro com retry, vazio com mensagem pt-br.
- Acessibilidade: semântica por linha, foco trap + `Esc`/`Enter` em dialogs, contraste Material.

## Cross-Story Dependencies

- 8.1 entrega a lista base que sustenta os filtros/busca de 8.2 e o tap para o detalhe de 8.3; o contador `N obras` depende da agregação por obra ativa.
- O detalhe de 8.3 (bloco de obras + entrada `Atribuir` + aviso de pré-requisito inativo) é pré-requisito das Stories 9.1/9.2 (atribuição) e 10.1–10.3 (gestão do vínculo).
