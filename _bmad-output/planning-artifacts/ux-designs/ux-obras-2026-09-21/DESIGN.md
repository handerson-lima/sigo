---
name: SIGO Gestão de Membros
description: Evolução da tela Gestão de Membros para permitir que adm e owner atribuam operário à obra.
status: in-progress
updated: 2026-09-21
colors:
  surface-base: '#F8FAFC'
  surface-raised: '#FFFFFF'
  ink-primary: '#0F172A'
  ink-secondary: '#475569'
  ink-disabled: '#94A3B8'
  accent: '#0F766E'
  accent-strong: '#115E59'
  border-hairline: '#E2E8F0'
  owner-bg: '#FEF3C7'
  owner-border: '#F59E0B'
  owner-ink: '#92400E'
  admin-bg: '#EFF6FF'
  admin-border: '#BFDBFE'
  admin-ink: '#1E40AF'
  pending-bg: '#FFF7ED'
  pending-border: '#FDBA74'
  pending-ink: '#9A3412'
  danger: '#DC2626'
typography:
  title:
    note: 'Flutter Material — titleLarge 20 semibold para SigoTopBar; titleMedium 16 para nome/email do membro'
  body:
    note: 'Flutter Material — bodyMedium 14 para subtítulos (cargo, obra); bodySmall 12 para badges e metadados'
  meta:
    note: 'Flutter Material — labelSmall 11 bold para chips Pendente/Proprietário/Ativo/Inativo'
rounded:
  sm: 8px
  md: 12px
  lg: 16px
spacing:
  '1': 4px
  '2': 8px
  '3': 12px
  '4': 16px
  '5': 24px
  '6': 32px
components:
  - ListTile com CircleAvatar por papel
  - Chip de papel (Proprietário/Administrador/Operário/Pendente)
  - BottomSheet de detalhe do membro
  - Dialog Atribuir à obra (seletor de obra + papel + módulos)
  - SigoLayout + SigoTopBar + SigoSidebar
---

## Brand & Style

A Gestão de Membros é ferramenta de trabalho da construtora, não vitrine. Segue a identidade já em uso no SIGO: fundo claro `surface-base`, cartões brancos, tipografia Material nativa, um único acento verde-petróleo para ação primária e sincronização. Papel do membro é comunicado por cor de avatar + chip, nunca só por cor.

O tom é operacional e auditável: cada linha mostra quem é, qual o vínculo na construtora e quais obras atende. Nada de gamificação, nada de ilustração decorativa.

## Colors

- **Base (`#F8FAFC`)** é o fundo do `SigoLayout`. Mantém contraste com listas longas de membros em mobile e desktop.
- **Acento (`#0F766E`)** é exclusivo para ação primária: Conceder Acesso, Confirmar atribuição, Sincronizado. Nunca para badges de papel.
- **Owner (`#FEF3C7` / borda `#F59E0B` / texto `#92400E`)** identifica Proprietário. Avatar `Icons.stars_rounded` em âmbar — padrão já existente em `membros_screen.dart`.
- **Admin (`#EFF6FF` / borda `#BFDBFE` / texto `#1E40AF`)** identifica Administrador. Avatar `Icons.admin_panel_settings`.
- **Operário** usa avatar neutro `Icons.person` sem fill colorido — reduz ruído quando a maioria da lista é operacional.
- **Pendente (`#FFF7ED` / borda `#FDBA74` / texto `#9A3412`)** para `access_requests pending`. Prefixo ⏳ + `Pendente · Cargo`.
- **Perigo (`#DC2626`)** só para Remover da obra / Desativar da construtora, sempre com confirmação.
- Evitar: novos matizes por obra, gradientes, badge vermelho para erro de rede (erro usa `body` + retry, não fill).

## Typography

Tipografia é a nativa do Material via Flutter — sem fonte customizada nesta etapa.

- `titleLarge` 20 semibold: título `Gestão de Membros` no `SigoTopBar`.
- `titleMedium` 16: email ou displayName do membro (trunca com ellipsis em 1 linha).
- `bodyMedium` 14 `ink-secondary`: cargo na construtora + contador de obras (ex.: `Operário · 2 obras`).
- `labelSmall` 11 bold: chips `Proprietário`, `Administrador`, `Ativo`, `Inativo`, `Pendente`.
- Dynamic type / textScale honrado; lista deve aguentar 1.3x sem quebrar trailing.

## Layout & Spacing

Herda `SigoLayout`: desktop `>800px` com `SigoSidebar` + conteúdo `padding 24`; mobile com `SigoTopBar` + drawer + `padding 16`.

- Lista principal: `ListView` de `ListTile` full-width, `16px` vertical entre seções, `8px` entre linhas densas.
- Filtro no topo (em evolução): busca por email/nome + segmented `Todos | Por obra | Pendentes`. [ASSUMPTION]
- Linha do membro: leading `CircleAvatar 40px`, title 1 linha, subtitle 1–2 linhas (`Cargo · N obras`), trailing chip + chevron `>`.
- Detalhe do membro: `BottomSheet` mobile (arrastável, 70% altura) / `Dialog 480px` desktop com 3 blocos: Vínculo construtora, Obras vinculadas, Ações.
- Atribuir à obra: `Dialog` com `DropdownButtonFormField` de obra (só obras ativas da construtora), `SegmentedButton` de papel obra (`Operário | Admin da obra`), `FilterChip`s de módulos (`diario, lotes, estoque`), resumo de permissão e CTA Confirmar.
- Desktop pode exibir detalhe em painel lateral direito em vez de dialog quando largura >1200px. [ASSUMPTION]

## Elevation & Depth

Superfícies planas. Lista sem sombra; `Card` só no resumo do detalhe (`elevation 1`). `BottomSheet`/`Dialog` com elevação nativa do Material. Sem sobreposição de sombras coloridas.

## Shapes

- Avatar: círculo 40px.
- Chips/badges: `r=12px`, borda 1px, padding `8h/4v`.
- Botões: `ElevatedButton` padrão Material (`r=8px`); `FilterChip` para módulos; `SegmentedButton` para papel obra.
- Dialogs: `r=16px`.

## Components

1. **MemberRow** — evolução do `ListTile` atual. Props: avatar por papel, title, subtitle `Cargo · N obras · status`, trailing chip + chevron. Tap abre detalhe.
2. **RoleChip** — mapeia `isOwner→Proprietário`, `isAdmin→Administrador`, default `Operário`; pendente usa variante laranja. Reuso do estilo já em `membros_screen.dart:120-137`.
3. **ObraVinculoRow** — linha por obra: nome obra + papel obra + status + overflow menu (Trocar papel, Remover). Estado vazio: `Nenhuma obra vinculada — Atribuir`.
4. **AtribuirObraDialog** — campos: obra (obrigatório), papel obra (default Operário), módulos (default `diario`; vazio = fail-closed), nota de pré-requisito (vínculo ativo na construtora obrigatório). Erros do backend (`permission-denied`, `failed-precondition`, `Papel inválido`) viram mensagem pt-br + retry.
5. **ConfirmDestructiveDialog** — para Remover da obra / Desativar construtora, com nome do alvo + obra + consequência (perde acesso imediato, diários preservados).

## Do's and Don'ts

- DO mostrar `Operário · 2 obras` no subtitle — resolve a dor atual (lista não diz nada de obra).
- DO desabilitar Confirmar enquanto obra não selecionada; explicar porquê.
- DO fechar o loop: após `setMembership` com `obraId` sucesso → snackbar `Atribuído a {obra} como {papel}` + refresh das duas listas.
- DON'T permitir selecionar `Proprietário` como papel de obra — backend rejeita (`Papel inválido`); nem exibir a opção.
- DON'T expor `uid` cru quando houver email/displayName; `UID:` só como fallback.
- DON'T permitir que operário abra esta tela — rota segue `AccessGuard(adminOnly:true)`.
