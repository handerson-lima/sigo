# Extrato das fontes autorizadas

Sem alterações nas fontes. Caminhos relativos ao workspace (não à pasta .working).

| Fonte | Seções úteis | Cobertura |
|---|---|---|
| ../ux-obras-2026-09-21/DESIGN.md | Brand & Style, tokens, Layout & Spacing, Components | Material Flutter; paleta clara/petróleo; escala 4–32; raios 8/12/16; membros |
| ../ux-obras-2026-09-21/EXPERIENCE.md | Foundation, State Patterns, Responsive & Platform, Key Flows | Admin/owner, mobile/PWA, vínculo online, três jornadas nomeadas |
| ../ux-obras-2026-09-21/.memlog.md | decisões | Gestão completa de membros; mobile/PWA; fast path original |
| ../../epics.md | FR1–FR10, NFR1–NFR6, stories 8.1–10.3 | Apenas Épicos 8–10 de membros |
| ../../architecture/architecture-obras-2026-09-21/ARCHITECTURE-SPINE.md | AD-1–AD-9, Deferred | Feature membros, não arquitetura geral |
| ../../architecture/architecture-epic-5/ARCHITECTURE-SPINE.md | Inherited Invariants, AD-1–AD-7, Capability Map | EPI, Validação, ADM, Fornecedores, Parcelas, Custos |

## Pessoas e jornadas

Carla administradora no escritório/web, Otávio proprietário, Carneiro operário mobile e José inativo são personagens das fontes, não pesquisa. Jornadas exatas: Fluxo 1 — Carla atribui Carneiro à Obra (clímax: vínculo confirmado); Fluxo 2 — Carla remove Carneiro da obra (clímax: acesso revogado sem perder histórico); Fluxo 3 — Erro pré-condição (membro inativo).

Capacidades exatas ARQ-5: 5.1 — Módulo EPI; 5.2 — Módulo Validação; 5.3 — Módulo ADM; 5.4 — Fornecedores; 5.5 — Parcelas e Compras; 5.6 — Visão 360º de Custos. Jornadas representativas para essas capacidades são extrapolações explícitas.

## Restrições

Material nativo, superfície clara, cores por papel com texto/ícone; alvos 48dp; foco/teclado; textScale 1.3x em membros. Drawer mobile/sidebar desktop; detalhe sheet/dialog 480px; painel >1200px hipótese local. maxWidth 960px é local, não regra global.

Vínculo exige rede e autoridade servidor, modules vazio nega acesso, owner não é papel de obra, vínculo construtora ativo obrigatório. Alterar owner exige trustedDev. Auditoria membros apenas servidor. Desativação não é cascata transacional.

Épico 5: fila offline operacional, evidências privadas, termos e registros confirmados imutáveis; não conformidade exige foto; checklist preserva versão; valores exatos em centavos; soma parcelas igual documento; custos projetados com consistência eventual; cancelamento/retificação exige justificativa.

## Conflitos e lacunas

Permission-denied fecha diálogo no UX antigo e mantém em story 9.2. Breakpoint >800 versus ≥800. Hipótese antiga de cascata superada por AD-7. Nomes/campos de módulos divergem entre spines; não normalizar globalmente. Stack também diverge, sem relevância para aprovar visual.

Não há arquitetura geral nem inventário total de produto; faltam pesquisa de campo, branding aprovado, referência estética desktop, volumetria, dispositivos específicos e políticas offline por ação. Praticidade mobile e desktop impressionante são confirmados pelo usuário; composição, novos padrões genéricos e personas adicionais são hipóteses.
