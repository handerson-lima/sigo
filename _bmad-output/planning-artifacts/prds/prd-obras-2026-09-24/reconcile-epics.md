# Reconciliação — epics.md

**Veredito de cobertura:** Os FRs 1–10, os NFRs 1–6 e as Stories 8.1–11.2 do `epics.md` estão substancialmente representados no PRD (FR‑28..FR‑40, §4.3 e §4.5), mas o escopo operacional "obra" foi reescrito para "nó da Hierarquia Estrutural" sem requisito explícito de compatibilidade/migração, e três itens do input (atribuição de Equipe, responsáveis/papéis por nó e invalidação de providers) ficaram sem FR correspondente.

## Lacunas

1. **Escopo "obra" → "nó da Hierarquia Estrutural" sem requisito de compatibilidade.**
   - *Trecho do input (Additional Requirements):* "Criar ObraMembersRepository + providers obraMembersProvider((c,o)), obrasDaConstrutoraProvider(c), watchObrasDoMembro"; e FR1/FR4/FR7 usam "N obras" / "Atribuir operário à obra" / "Remover membro da obra".
   - *O que falta/está distorcido:* o PRD §4.5 reescreve todo o domínio para "nós da Hierarquia Estrutural" (FR‑28..FR‑36) e delega a ponte a uma Open Question (§8 OQ‑1), sem transformar em requisito a compatibilidade nem a migração dos vínculos por obra. Pior: o `addendum.md` mantém "obra" em AD‑5, AD‑9 e §3, de modo que PRD e addendum divergem entre si sobre a mesma entidade.

2. **Atribuição de Equipe como unidade a um nó.**
   - *Trecho do input:* Epic 9 — "Atribuição na Hierarquia (Loteamento a Equipe)" e descrição "atribui operário/**equipe** em um nível específico (ex: Lote ou **Equipe**)".
   - *O que falta:* o PRD cobre apenas atribuição de membro individual (FR‑31 operário, FR‑32 Admin da obra). Atribuir uma **Equipe** a um nó não aparece como FR de Gestão de Membros; §4.9 (FR‑61) apenas diz que "equipe pode ser alocada a um nó", sem requisito de fluxo, papel ou módulos.

3. **Exibição de responsáveis/papéis por nó no drill-down.**
   - *Trecho do input:* Story 11.2 — "vejo os Setores associados e as Equipes alocadas **And** posso visualizar as responsabilidades e papéis em cada nó."
   - *O que falta:* FR‑17..FR‑20 cobrem listar filhos, deep link/breadcrumbs, leitura autorizada por nó/ancestral e preservação de contexto, mas **não** há requisito/Consequence testável para exibir os responsáveis e seus papéis dentro do nó. A UJ‑9 menciona "vê os responsáveis atribuídos" de passagem, sem virar FR.

4. **Estado "Pendente" do membro tratado apenas como solicitação de acesso.**
   - *Trecho do input:* FR1 — "vejo pendentes no topo (`Pendente · Cargo`)" e UX‑DR2 — "RoleChip — Proprietário/Administrador/Operário/**Pendente**".
   - *O que falta/está distorcido:* o PRD trata pendência como `access_request` gerada por e-mail sem conta (FR‑12/FR‑13) e não modela, em §4.5, o estado de membro recém-adicionado/aguardando ativação que o input expressa como chip de papel "Pendente". São conceitos próximos, mas não equivalentes.

5. **Invalidção de providers e pull-to-refresh após mutação.**
   - *Trecho do input (Additional Requirements):* "Após mutação invalidar membrosProvider + obraMembersProvider; pull-to-refresh."
   - *O que falta:* nenhum FR/NFR do PRD (nem o `addendum.md`) exige refresco explícito da lista após mutação ou gesto de pull-to-refresh; FR‑31/FR‑33 apenas citam "lista atualiza N obras" como consequência implícita.

## Conflitos

1. **Rótulo e mensagem do filtro de vínculos.**
   - *Input:* FR2 — "Filtrar Todos / **Por obra** / Pendentes" e Story 8.2 — "dropdown vazio mostra `Nenhuma obra ativa`".
   - *PRD:* FR‑29 — "filtra Todos / **Por nó** / Pendentes" e "dropdown vazio mostra `Nenhum nó disponível`".
   - Conflito direto de texto de aceite: as duas redações não podem valer simultaneamente sem decisão explícita sobre a terminologia canônica.

2. **Pré-requisito de vínculo ativo: "obra" vs "nó".**
   - *Input:* Additional Requirements — "Pré-requisito vínculo ativo construtora antes de **obra**"; `addendum.md` AD‑9 — "vínculo em **obra**".
   - *PRD:* FR‑37 — "Vínculo ativo na construtora é pré-requisito para vínculo em **nó da Hierarquia Estrutural**".
   - Conflito de nomenclatura/escopo entre PRD e addendum sobre onde o vínculo é efetivamente gravado (obra legada × nó canônico).

## Cobertura OK

- **FR1→FR-28, FR2→FR-29, FR3→FR-30, FR4→FR-31, FR5→FR-32, FR6→FR-33, FR7→FR-34, FR8→FR-35, FR9→FR-36, FR10→FR-39/FR-40/FR-11** — todos presentes e reconhecíveis.
- **NFR1–NFR6** refletidos em §4.5 (NFRs de acessibilidade/responsivo), FR‑7 (escrita server-side), FR‑38 (normalização/fail-closed) e FR‑39 (escrita exige rede, sem fila offline).
- **UX‑DRs 1–7** deliberadamente delegados aos artefatos de UX conforme a §0 do PRD, sem perda de conteúdo no nível de produto.
- **Stories 10.1–10.3** (trocar papel/módulos, remover com confirmação destrutiva, trocar cargo/desativar com N remoções) mapeadas em FR‑33, FR‑34, FR‑35 e FR‑36, incluindo o gate de revogação imediata (FR‑10).
- **Epic 11** (Stories 11.1 e 11.2) coberto por FR‑17..FR‑20, ressalvadas as lacunas 2 e 3 acima.
