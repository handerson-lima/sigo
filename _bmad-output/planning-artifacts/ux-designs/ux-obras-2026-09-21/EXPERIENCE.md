---
name: SIGO Gestão de Membros
description: Comportamento e fluxos da Gestão de Membros com atribuição de operário à obra.
status: in-progress
updated: 2026-09-21
sources:
  - docs/user_flows.md
  - docs/data_model.md
  - app/lib/src/features/construtoras/presentation/membros_screen.dart
  - app/lib/src/features/construtoras/presentation/add_membro_dialog.dart
  - functions/src/index.ts
  - functions/src/contracts.ts
---

## Foundation

- Form-factor: **Mobile + Web PWA** (decisão do usuário). Herda `SigoLayout`: mobile com drawer, desktop `>800px` com sidebar + topbar. Sem superfície nova.
- Sistema visual: Material Flutter nativo; identidade em `{DESIGN.md}` (cores por papel, chips, dialogs). Este documento é dono do comportamento; visual vive em `DESIGN.md`.
- Escopo autorizado: tela restrita a **admin da construtora e owner/proprietário** via `AccessGuard(adminOnly:true)` — `isAdmin || isOwner`. Operário nunca vê esta rota.
- Contratos backend (já existentes, sem mudança): `setMembership`/`setConstrutoraRole` em `functions/src/index.ts:46-108`; `authority`/`manager` em `contracts.ts:30`; `firestore.rules:99` bloqueia escrita direta — tudo passa pela Function. Papel obra válido: `admin | member | operario`; `owner` em obra é rejeitado.
- Pré-requisito: vínculo ativo na construtora obrigatório antes de vincular à obra (`failed-precondition`).

## Information Architecture

```
Gestão de Membros (/construtora/:cId/membros)
├── Lista (pending no topo + ativos)
│   ├── Filtro: [Todos | Por obra | Pendentes] + busca [ASSUMPTION]
│   └── MemberRow: avatar, nome/email, Cargo · N obras, chip, chevron
├── Detalhe do membro (BottomSheet mobile / Dialog desktop)
│   ├── Bloco 1 — Vínculo construtora: cargo, status, desde quando
│   ├── Bloco 2 — Obras vinculadas: lista ObraVinculoRow + [Atribuir à obra]
│   └── Bloco 3 — Ações: Atribuir à obra, Trocar cargo construtora [ASSUMPTION], Remover/Desativar
├── Atribuir à obra (Dialog)
│   ├── Obra* (dropdown só obras ativas da construtora)
│   ├── Papel na obra* (Operário | Admin da obra; default Operário)
│   ├── Módulos (chips diario/lotes/estoque; default diario; vazio = sem acesso)
│   └── Confirmar → setMembership {construtoraId, obraId, role, modules}
└── Gerir vínculo obra (overflow por linha)
    ├── Trocar papel / módulos
    └── Remover da obra (confirm destructive → setMembership isActive:false)
```

Nova leitura necessária: `obras/{o}/members` por membro e por obra. Hoje só existe `watchMembros` (construtora) — criar `watchObraMembers(obraId)` + `watchObrasDoMembro(uid)`. [ASSUMPTION: agregação no cliente; sem collectionGroup novo nesta etapa.]

## Voice and Tone

Microcopy pt-br, direta, com nome da obra e papel sempre explícitos. Voz operacional do SIGO (ver `docs/user_flows.md`).

- Títulos: `Gestão de Membros`, `Detalhe de {email}`, `Atribuir à obra`, `Remover de {obra}?`
- CTA: `Convidar Membro`, `Atribuir à obra`, `Confirmar atribuição`, `Remover da obra`, `Cancelar`
- Sucesso: `Atribuído a {obra} como {papel}.`, `Removido de {obra}.`, `Acesso concedido com sucesso!` (já existente)
- Erro mapeado: `Sem permissão para gerir vínculo.` → `Você não tem permissão para alterar este vínculo.`; `Vínculo ativo na construtora obrigatório.` → `Ative o membro na construtora antes de atribuir à obra.`; `Papel inválido.` → `Papel inválido para obra. Use Operário ou Admin da obra.`
- Vazio: `Nenhuma obra vinculada — Atribuir` / `Nenhum membro encontrado.`

## Component Patterns

- **MemberRow (comportamental):** tap abre detalhe; subtitle computa `Cargo · N obras`; pendente não abre detalhe — tap mostra info do pedido.
- **AtribuirObraDialog (comportamental):** obra é required; papel default `Operário`; módulos default `[diario]`; Confirm desabilitado até obra válida; ao confirmar chama `setMembership` com `obraId`; mapeamento UI→role: `Operário→operario`, `Admin da obra→admin`. Nunca envia `owner` com `obraId`.
- **ObraVinculoRow:** exibe `nome obra · papel obra · Ativo/Inativo`; menu overflow só para admin/owner (sempre verdade nesta tela, mas manter gate para reuso futuro no dashboard da obra).
- **Destructive:** remoção exige digitar/confirmar em dialog separado; após sucesso volta para detalhe atualizado, não fecha a Gestão.

## State Patterns

| Estado | Lista | Detalhe | Atribuir |
|---|---|---|---|
| Loading | skeleton/shimmer 3 linhas | spinner no sheet | obras loading no dropdown |
| Vazio | `Nenhum membro encontrado.` | `Nenhuma obra vinculada — Atribuir` | dropdown vazio → `Nenhuma obra ativa` + CTA desabilitado |
| Erro rede | `Erro: {e}` + Retry (padrão atual) | snackbar + Retry | snackbar + mantém dialog aberto |
| Sem permissão | `AccessGuard` nega rota (já existe) | — | `permission-denied` → fecha com snackbar explicativa |
| Pending | seção topo laranja, sem chevron | — | — |
| Pré-condição | — | aviso inline `Ative na construtora primeiro` se `isActive==false` | Confirm bloqueado ou erro `failed-precondition` mapeado |
| Sucesso | refresh providers | atualiza N obras | fecha + snackbar + refresh |
| Offline PWA | lista do cache + badge `Salvo no dispositivo` [ASSUMPTION]; escrita enfileira? Não — atribuição exige confirmação servidor; mostrar `Sem conexão — tente novamente` | — | — |

Fail-closed: `modules` vazio = sem acesso a módulos; nunca assumir `diario` implícito no backend — default é sugestão de UI.

## Interaction Primitives

- Tap → detalhe; long-press sem ação (evitar destructive acidental).
- Dropdown obra com busca quando >10 obras. [ASSUMPTION]
- Segmented papel + chips módulos com feedback imediato; resumo ao vivo: `carneiro@caol.com será Operário em Obra X com acesso a Diário.`
- Pull-to-refresh na lista; invalidar `membrosProvider` + novos `obraMembersProvider` após cada mutação.
- Acessibilidade de toque: alvos ≥48dp; dialog com `Cancelar` sempre visível; destructive fora do caminho do Confirm.

## Accessibility Floor

- Leitor de tela: cada `MemberRow` anuncia `nome, cargo, N obras, status`; chips com `semanticsLabel`; dropdown obra com label `Obra`; erros anunciados via `SnackBar` + `liveRegion`.
- Contraste: pares em `{DESIGN.md}` já atendem Material; nunca comunicar papel só por cor (ícone + texto obrigatórios).
- Navegação teclado (web): foco trap no dialog, `Esc` fecha, `Enter` confirma quando válido; ordem: obra → papel → módulos → confirmar.
- TextScale até 1.3x sem truncar CTA; avatar com `excludeSemantics` quando redundante.

## Responsive & Platform

- Mobile (<800px): lista full-width; detalhe como `BottomSheet` arrastável; atribuir como dialog full-screen estreito.
- Desktop (≥800px): conteúdo `maxWidth 960px`; detalhe como `Dialog 480px` ou painel lateral `>1200px`; filtro + busca inline no header.
- PWA: mesma codebase Flutter; leitura usa cache Firestore; escrita de vínculo exige rede — sem fila offline nesta etapa (decisão explícita para evitar vínculo fantasma).
- Permissões recalculadas na troca de obra (padrão `docs/user_flows.md` C1).

## Key Flows

### Fluxo 1 — Carla atribui Carneiro à Obra (clímax: vínculo confirmado)

Carla, administradora da CAOL no escritório (web), precisa colocar o operário Carneiro na Obra Residencial X para lançar diário amanhã.

1. Carla abre `Gestão de Membros` — vê `carneiro@caol.com · Operário · 0 obras`.
2. Toca na linha → detalhe mostra vínculo construtora Ativo + `Nenhuma obra vinculada`.
3. Toca `Atribuir à obra` → seleciona `Residencial X`, mantém `Operário`, mantém `diario`.
4. Resumo confirma: `Carneiro será Operário em Residencial X com acesso a Diário.`
5. **Clímax:** toca `Confirmar atribuição` → Function valida `obraAdmin` (Carla é admin) + vínculo construtora ativo → escreve `obras/X/members/carneiroUid {isAdmin:false, modules:[diario], isActive:true}` → snackbar `Atribuído a Residencial X como Operário.` Lista atualiza para `1 obra`.
6. Carneiro entra no app mobile e vê Residencial X (leitura `obraMember` já liberada em `firestore.rules:95`).

Variação Owner: Otávio, proprietário, faz o mesmo fluxo — autorizado por `isOwner` em `authority`. UX idêntica; auditoria guarda ator diferente.

### Fluxo 2 — Carla remove Carneiro da obra (clímax: acesso revogado sem perder histórico)

Obra X acabou para Carneiro; ele vai para Obra Y.

1. No detalhe, Carla abre overflow em `Residencial X` → `Remover da obra`.
2. Dialog: `Remover carneiro@caol.com de Residencial X? Ele perde acesso imediato; diários lançados são preservados.`
3. **Clímax:** confirma → `setMembership {obraId:X, isActive:false}` → linha some do bloco, contador volta a `0 obras`, snackbar `Removido de Residencial X.`
4. Tentativa de Carneiro abrir X mostra `Acesso removido` (padrão `docs/user_flows.md` §5), sem retry infinito.

### Fluxo 3 — Erro pré-condição (membro inativo)

José, operário desativado na construtora, não pode ser atribuído.

1. Adm tenta atribuir → backend retorna `failed-precondition`.
2. UI mantém dialog aberto + mensagem `Ative o membro na construtora antes de atribuir à obra.` + botão `Ativar` (atalho para reativar). [ASSUMPTION]

## Perguntas abertas

1. Trocar cargo na construtora (operário↔admin) entra neste detalhe ou segue só no convite? Proposto: entra (menu no bloco 1).
2. Remover da construtora desvincula de todas as obras em cascata (backend) ou exige remover obra a obra? Proposto: cascata com confirmação explícita. [ASSUMPTION — validar em `bmad-architecture`.]
3. Módulos por obra: quais valores canônicos? Proposto: `diario, lotes, estoque` (espelha `current_permissions_provider`); normalizar via `normalizeRawModules`. [ASSUMPTION]
4. Auditoria visível na UI (quem atribuiu quando) ou só log servidor? Proposto: só servidor nesta etapa.
5. Filtro `Por obra` é dropdown global ou segunda aba? Proposto: segmented + dropdown obra quando filtrado.

## Próximos passos sugeridos

- `bmad-architecture`: definir `watchObraMembers`, mapeamento `operario↔member`, cascata de remoção, auditoria.
- `bmad-create-epics-and-stories` / `bmad-sprint-planning`: fatiar em histórias (lista com N obras → detalhe → atribuir → remover → trocar papel).
- `bmad-build`: implementar com `bmad-qa-generate-e2e-tests` cobrindo `admin atribui operario` e `owner atribui operario`.
