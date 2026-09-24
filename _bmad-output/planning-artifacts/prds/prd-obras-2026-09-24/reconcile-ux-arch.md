# Reconciliação — UX/Arquitetura

O PRD e o addendum cobrem bem o núcleo server-authoritative (AD-1, AD-6..AD-9), a Hierarquia Estrutural de 5 níveis e as jornadas nomeadas principais, mas a camada de UX da primeira entrega (tom/estética, acessibilidade verificável, política de resultado incerto e não-objetivos de tela) e o rastreio AD→FR ficaram parcialmente fora ou distorcidos.

## Lacunas

1. **Acessibilidade verificável reduzida a `textScale 1.3x`.** O PRD só fixa alvos ≥48dp e papel não-só-por-cor (§4.5 NFR; §4.4 FR-25; §4.6 FR-62). Ficam de fora contraste mínimo (≥4,5:1 normal / ≥3:1 grande), reflow em 320/390/800/801/1280/1440, texto em 100/130/**200%**, nome com 80 e fase com 60 caracteres sem rolagem horizontal, foco visível/restaurado e Esc-antes-do-envio. *Origem: `ux-obras-2026-09-23/primeira-entrega/EXPERIENCE.md` (Accessibility Floor; Interaction Primitives) e `DESIGN.md` (Colors, Typography).*

2. **Não-objetivos de tela da primeira entrega ausentes.** O PRD §5 não registra: sem busca/KPI no shell; sem percentual, foto, custo ou responsável no `LoteCard`; sem atomicidade/rollback no UX de lote; sem redesenho dos módulos herdados; nenhuma nova fila de sincronização. *Origem: `primeira-entrega/HANDOFF.md` (Escopo e Limites) e `EXPERIENCE.md` (Foundation; State Patterns).*

3. **Tom/estética não são requisitos.** O PRD não trata da direção expressiva azul profundo `#0D47A1`→azul vivo `#1565C0`/dourado, de "construtoras espaçosas / lotes compactos", de "nada de gamificação, nada de ilustração decorativa", de "sem sombras em texto/halos" nem da obrigatoriedade da marca oficial (`sigo_logo_light.png` / `sigo_logo_dark.png`, não redesenhar). O addendum §9 cobre só parcialmente. *Origem: `ux-obras-2026-09-21/DESIGN.md` (Brand & Style) e `primeira-entrega/DESIGN.md` (Brand & Style; Elevation & Depth).*

4. **Política de "resultado incerto" e "Verificar logo atual" sem requisito verificável.** O PRD apenas cita o edge "CAP-3" em UJ-3 e o genérico FR-27. Falta o contrato de: não prometer cancelamento, bloquear saídas incidentais só enquanto acompanha o envio, tolerar gravação parcial fase/status (duas operações, não atômicas), oferecer `Fechar` com aviso e `Verificar logo atual` pela fonte autoritativa. *Origem: `primeira-entrega/EXPERIENCE.md` (Saída durante envio e confirmação incerta; Logo — proposta operacional; S4).*

5. **Jornadas com protagonistas omitidas.** J0 (Carla navega o shell), J3 (Ana cadastra lote) e J4 (Paulo abre vistorias do lote) não têm UJ equivalente. Pior: §4.11 (`FR-72..FR-74`) referencia "Realiza UJ-3" para vistorias, mas UJ-3 é "Ana identifica e atualiza um lote" — referência incorreta. *Origem: `primeira-entrega/EXPERIENCE.md` (Key Flows J0, J3, J4).*

6. **Rastreio AD→FR incompleto no PRD.** AD-4 (conjuntos canônicos por escopo: obra `diario|lotes|estoque`; construtora `estoque`) e AD-2 (com `obraId` exige `obraAdmin`; sem `obraId` exige `admin(c)`) não aparecem como requisitos/FRs, existindo apenas no `addendum.md §2`. *Origem: `architecture-obras-2026-09-21/ARCHITECTURE-SPINE.md` (AD-2, AD-4) e `addendum.md §2`.*

7. **Semântica de leitor de tela para membros não exigida.** O PRD não exige que cada `MemberRow` anuncie `nome, cargo, N obras, status`, nem `semanticsLabel` em chips, nem anúncio de erro via `liveRegion`, nem foco trap/ordem de teclado no dialog. *Origem: `ux-obras-2026-09-21/EXPERIENCE.md` (Accessibility Floor; Interaction Primitives).*

## Conflitos

1. **Filtro "Por obra" × "Por nó".** PRD `FR-29` define `Todos | Por nó | Pendentes`; UX 2026-09-21 e AD-5 dizem `Todos | Por obra | Pendentes` e nomeiam `watchObraMembers`/agregação por obra. A renomeação canônica para nó (Epic 11) não foi propagada ao addendum §2 (AD-5). *Fontes: `prd.md §4.5 FR-29` × `ux-obras-2026-09-21/EXPERIENCE.md` e `addendum.md §2 AD-5`.*

2. **Dois tokens de ação primária.** Gestão de Membros usa acento verde-petróleo `#0F766E` para ação; a primeira entrega usa azul `#1565C0`. O addendum §9 canoniza o azul, deixando o contrato de cor de ação do módulo de membros sem resolvedor. *Fontes: `ux-obras-2026-09-21/DESIGN.md` (Colors) × `primeira-entrega/DESIGN.md` (Colors) e `addendum.md §9`.*

3. **Limite de upload da logo (2 MiB × 5 MB).** O PRD assume 2 MiB atribuindo-o ao "contrato da primeira entrega" (`§4.4 NFR`, OQ-2, Assumptions), mas o pacote de primeira entrega fixa **5 MB**. A atribuição de origem do 2 MiB não corresponde ao artefato citado. *Fontes: `prd.md §4.4 / §8 OQ-2` × `primeira-entrega/HANDOFF.md` e `primeira-entrega/EXPERIENCE.md`.*

4. **Três modelos de rota/hierarquia coexistem.** Epic 11 propõe `/loteamentos/:lId/quadras/...` com subcoleções estritas; o addendum §3 ainda lista `hierarquia_members/{uid}` plano e `obras/{oId}/members`; a primeira entrega usa `/construtora/:id/obra/:obraId/lotes`. As rotas do Epic 11 não levam o prefixo `/construtora/:cId`. *Fontes: `architecture-epic-11-drill-down/ARCHITECTURE-SPINE.md` (AD-1, AD-2) × `addendum.md §3` × `primeira-entrega/EXPERIENCE.md` (IA S1–S2).*

5. **Escopo do vínculo: nó × obra.** O PRD descreve atribuição a "nó da Hierarquia Estrutural" (`FR-31..FR-38`), enquanto o spine 2026-09-21 e seus AD-2/AD-3/AD-9 exigem `obraId` e `obras/{o}/members`. A migração está como OQ-1, mas os artefatos ainda divergem na linguagem de requisito. *Fontes: `prd.md §4.5` × `architecture-obras-2026-09-21/ARCHITECTURE-SPINE.md` (AD-2, AD-3, AD-9).*

6. **Preservação da logo em falha.** PRD `FR-27` afirma de forma ampla que "em falha comprovada a logo anterior é preservada"; a primeira entrega restringe a garantia a "falha comprovadamente anterior à publicação" e proíbe afirmar preservação em resultado incerto. *Fontes: `prd.md §4.4 FR-27` × `primeira-entrega/EXPERIENCE.md` (S5 Gerenciar logo).*

## Cobertura OK

- **Server-authoritative e integridade:** AD-1, AD-6, AD-7, AD-8, AD-9 refletidos em `FR-7`, `FR-39`, `FR-10`/`FR-36`, `FR-35`, `FR-37`; sem fila offline para vínculo e revogação imediata por gate de vínculo ativo.
- **Hierarquia de 5 níveis com deep link e ACL por nó:** `FR-17..FR-20`, alinhados a AD-3 do spine de drill-down.
- **Honestidade de sincronização:** `FR-56`, `FR-57`, `FR-94` e Non-Goal §5 ("não promete recuperação/segundo plano") reproduzem fielmente a UX de estado.
- **Papéis e autorização:** `FR-2..FR-10`, `FR-15`, `FR-35`, `FR-37` cobrem Dev/Proprietário/Admin da construtora/Admin da obra/Membro comum e fail-closed.
- **Jornadas nomeadas centrais:** UJ-1 (Carla/Carneiro), UJ-3 (Ana), UJ-4 (Otávio), UJ-5 (Davi), UJ-6 (Marcos), UJ-7 (Rita), UJ-8 (Otávio) presentes com clímax e edge cases.
- **Não-objetivos de produto:** §5 cobre portal comprador, folha/eSocial, SEFAZ/SPED/Open Finance, nota fiscal/retenções, custo médio, tema escuro, fontes externas e remoção de logo.
- **Acessibilidade base:** alvos ≥48dp e status nunca só por cor estão em `FR-25` e `FR-62`; acessibilidade do seletor de escopo é citada em §4.2 (embora sem critério verificável).
