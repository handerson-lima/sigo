# Decisões vigentes — Epic 0

Vigência: 15/09/2026
Aprovação registrada: maranduteam em 15/09/2026
Fontes vigentes (transcrição exclusiva): `docs/plano-de-correcao-2026-09-15.md`, `docs/implementation_plan.md`, `docs/data_model.md`
Commit de referência (baseline): `90e550d33a11c40791f99583052d333d38986006`
Metadado de aprovação (leitura apenas, sem transcrição): `_bmad-output/implementation-artifacts/sprint-status.yaml` (`approval.correction_plan: approved_by_user`, proposta `docs/plano-de-correcao-2026-09-15.md`, produção não autorizada por este plano)

Este registro centraliza sem duplicar as decisões aprovadas em 15/09/2026. Não altera histórico, regras ou código. O arquivo histórico em `docs/archive/2026-09-15-planejamento-anterior/` permanece imutável e foi consultado apenas.

Restrição de maior risco: desenvolvedor global confirmado. Não exigir vínculo por obra para administração global. Não inferir desenvolvedores legítimos. Não confiar em autoatribuições de `globalRole=dev`.

## Decisões D1-D7

| ID | decisão | status | motivo | evidência | responsável | data |
|---|---|---|---|---|---|---|
| D1 | desenvolvedor global mantido, sem exigir vínculo por obra | aprovado-2026-09-15 | administração global preservada com concessão protegida | `docs/plano-de-correcao-2026-09-15.md` seção 1 @90e550d; `docs/plano-de-correcao-2026-09-15.md` seção 2 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d; `docs/data_model.md` seção 2 @90e550d | maranduteam | 15/09/2026 |
| D2 | estoque central por construtora | aprovado-2026-09-15 | evitar migração estrutural desnecessária | `docs/plano-de-correcao-2026-09-15.md` seção 1 @90e550d; `docs/plano-de-correcao-2026-09-15.md` seção 2 @90e550d; `docs/implementation_plan.md` seção 3 @90e550d; `docs/data_model.md` seção 3 @90e550d | maranduteam | 15/09/2026 |
| D3 | caminhos preservados `construtoras/{cId}/obras/{oId}` | aprovado-2026-09-15 | preservar IDs e caminhos atuais sem coleções paralelas | `docs/plano-de-correcao-2026-09-15.md` seção 1 @90e550d; `docs/plano-de-correcao-2026-09-15.md` seção 2 @90e550d; `docs/implementation_plan.md` seção 3 @90e550d; `docs/data_model.md` seção 1 @90e550d | maranduteam | 15/09/2026 |
| D4 | web/PWA mobile-first | aprovado-2026-09-15 | estabilizar base existente sem nova plataforma | `docs/plano-de-correcao-2026-09-15.md` seção 1 @90e550d; `docs/implementation_plan.md` seção 3 @90e550d; `docs/data_model.md` seção 3 @90e550d | maranduteam | 15/09/2026 |
| D5 | matriz de acesso aprovada | aprovado-2026-09-15 | uniformizar perfis com dev e admin como exceções explícitas | `docs/plano-de-correcao-2026-09-15.md` seção 1 @90e550d; `docs/plano-de-correcao-2026-09-15.md` seção 6 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d; `docs/data_model.md` seção 2 @90e550d | maranduteam | 15/09/2026 |
| D6 | categorias C0-C6 restritas ao ambiente de desenvolvimento | aprovado-2026-09-15 | estabilização e validação antes de produção | `docs/plano-de-correcao-2026-09-15.md` seção 6 @90e550d; `docs/implementation_plan.md` seção 5 @90e550d; `docs/data_model.md` seção 4 @90e550d | maranduteam | 15/09/2026 |
| D7 | papel global só via servidor, com fallback de e-mail para UID | aprovado-2026-09-15 | impedir autoatribuição e migrar identidade com segurança | `docs/plano-de-correcao-2026-09-15.md` seção 1 @90e550d; `docs/implementation_plan.md` seção 4 @90e550d; `docs/data_model.md` seção 2 @90e550d | maranduteam | 15/09/2026 |

Evidências acima usam `@90e550d` como forma curta do baseline `90e550d33a11c40791f99583052d333d38986006`. C0-C6 são categorias de inventário, correção e aceite restritas ao desenvolvimento.

## Pendências

Itens sem evidência nas fontes vigentes. Não inferir conclusão sem inventário e verificação.

| item | status | motivo | evidência | responsável | data |
|---|---|---|---|---|---|
| desenvolvedores legítimos (identidades confiáveis de dev) | pendente-evidência | sem evidência sobre identidades; inventário verificará sem assumir `globalRole=dev` como confiável | sem evidência | TBD | TBD |
| regras de produção atualmente publicadas | pendente-evidência | sem evidência sobre regras publicadas | sem evidência | TBD | TBD |
| volume real e dados legados (quantidades, saldos, anexos) | pendente-evidência | sem evidência sobre quantidade de dados reais | sem evidência | TBD | TBD |
