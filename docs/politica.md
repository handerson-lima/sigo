# Política de acesso e privilégios — Epic 0

Vigência das fontes: 15/09/2026 @90e550d (`90e550d33a11c40791f99583052d333d38986006`)
Registro de decisões: [decisoes.md](decisoes.md) — leitura apenas; D1–D7 e Pendências de 0-1 permanecem intactos
Story: 0-2 definir-politica | Destino: `docs/politica.md` novo (decisão humana DESTINO=A, 22/09/2026)

Esta política operationaliza D1–D7 para quem implementa C1, regras e UI. Toda cláusula abaixo é referência a decisão ou seção já aprovada; nenhuma cláusula cria decisão nova e o histórico congelado (`docs/archive/`) não é reaberto. Texto em pt-br, alinhado ao vocabulário de papéis do plano §3.

## 1. Escopo

Cobre somente **acesso e privilégios**: papéis, escopos, regras de privilégio, pendências de evidência e limite de produção (decisão humana ESCOPO-POLÍTICA=A, 22/09/2026). Custo, evidências e retenção de dados ficam fora desta política e permanecem na evolução futura (`docs/task.md`, seção "Evolução futura — fora de C0–C6").

A política orienta a implementação de C1 (autorização), a coerência entre Rules, Functions e UI, e as guards de rota/vínculo. A matriz literal detalhada permanece em `docs/plano-de-correcao-2026-09-15.md` seção 3 e será consolidada pela Story 0-4; aqui ela é referenciada, não duplicada como se fosse decisão nova.

**Base:** D5, D6, D7 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 e seção 6 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d; `docs/data_model.md` seção 2 @90e550d.

## 2. Papéis e escopos

Cinco perfis, com vocabulário conforme `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d (D5). Escopos abaixo são resumos rastreáveis; a matriz literal é a do plano §3:

1. **Dev confiável** — administração global, inclusive papéis via servidor; acesso global de suporte em dados de obra, estoque, financeiro e arquivos conforme operação autorizada. Não exige vínculo individual de obra.
   *Base:* D1 e D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 1 e seção 3 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d.
2. **Admin/proprietário ativo da construtora** — perfis mínimos e vínculos da própria construtora; nunca concede dev; todas as obras da construtora; administra estoque, financeiro e arquivos no próprio escopo. Dispensa membership em cada obra da própria construtora.
   *Base:* D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d; `docs/data_model.md` seção 2 @90e550d.
3. **Admin ativo da obra** — gestão restrita aos vínculos da obra, sem elevar privilégios de construtora; sem acesso automático ao financeiro central; estoque central somente com permissão explícita; arquivos da obra autorizada.
   *Base:* D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d.
4. **Membro comum (ativo)** — próprio perfil e próprios vínculos; módulos explicitamente permitidos no escopo correspondente; estoque central exige módulo central `estoque`; financeiro sem acesso nesta rodada; arquivos conforme módulo e obra.
   *Base:* D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d; `docs/data_model.md` seção 2 @90e550d.
5. **Sem autorização** — nenhum acesso operacional; dados de obra, estoque, financeiro e arquivos negados.
   *Base:* D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d.

**Base (seção):** D1 e D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d; `docs/data_model.md` seção 2 @90e550d.

## 3. Regras de privilégio

- **Dev global confirmado.** O desenvolvedor global é mantido e preservado, sem exigir vínculo por obra para administração global; a proteção da concessão desse papel é parte da correção. Autoatribuições de `globalRole=dev` não são confiáveis e identidades de devs legítimos não são inferidas.
  *Base:* D1 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 1 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d; `docs/data_model.md` seção 2 @90e550d.
- **Servidor autoritativo para `globalRole`.** O papel global só é escrito e alterado por fluxo administrativo confiável no servidor (Functions auditadas); o cliente comum não cria, altera nem apaga autorização própria e edita apenas campos pessoais permitidos. A migração do fallback legado de e-mail para UID preserva e testa o acesso dos devs legítimos antes da retirada do fallback; claims antigas não reativam vínculo revogado.
  *Base:* D7 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 1 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d; `docs/data_model.md` seção 2 @90e550d.
- **Módulos fail-closed.** Perfis consistem via `isActive`, `modules`, `isAdmin` e `isOwner`. Campos ou `modules` ausentes, ilegíveis ou vazios não concedem acesso implicitamente (vazio = sem acesso); nomes legados de módulo serão normalizados com mapeamento no inventário, sem concessão geral silenciosa.
  *Base:* D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d; `docs/data_model.md` seção 2 @90e550d.
- **Exceções ao vínculo individual de obra.** A permissão de obra regular exige vínculo ativo na construtora e na obra. **Dev confiável** e **admin/proprietário da construtora** são exceções explícitas a esse vínculo individual; a guarda deve ser única e uniforme entre Rules, Functions e UI.
  *Base:* D1 e D5 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 3 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d.

**Base (seção):** D1, D5, D7 — [decisoes.md](decisoes.md).

## 4. Pendências de evidência

Bloqueios de evidência formalizados nesta política (decisão humana COLETA=A, 22/09/2026). O inventário real continua em 0-3/C0; aqui os itens ficam visíveis como bloqueios e **nunca aparecem como resolvidos ou definidos**:

| bloqueio | status | efeito |
|---|---|---|
| identidade dos desenvolvedores legítimos | `pendente-evidência` | bloqueia migração do fallback de e-mail e etapas dependentes de privilégio |
| regras de produção atualmente publicadas | `pendente-evidência` | bloqueia qualquer afirmação sobre regras vigentes em produção |
| volume real e dados legados (quantidades, saldos, anexos) | `pendente-evidência` | bloqueia conclusão sobre migração e volume legado |

Status e motivação espelham a seção Pendências de [decisoes.md](decisoes.md) (0-1); sem inventário não há conclusão. Nenhum destes itens pode ser marcado como definido por presença de código ou tela.

**Base:** Pendências — [decisoes.md](decisoes.md) seção Pendências; `docs/plano-de-correcao-2026-09-15.md` seção 1 @90e550d; `docs/data_model.md` seção 4 @90e550d.

## 5. Limite de produção

Esta política e a aprovação vigente autorizam implementação e validação de C0–C6 e da matriz **em ambiente de desenvolvimento**, mantendo dev global, estoque central e dados existentes. C0–C6 são categorias de inventário, correção e aceite restritas ao desenvolvimento. **Implantação em produção não é autorizada por este escopo** e deve ser apresentada separadamente, com simulação, impactos, devs verificados e plano de recuperação.

**Base:** D6 — [decisoes.md](decisoes.md); `docs/plano-de-correcao-2026-09-15.md` seção 6 @90e550d; `docs/implementation_plan.md` seção 5 @90e550d; `docs/data_model.md` seção 4 @90e550d.
