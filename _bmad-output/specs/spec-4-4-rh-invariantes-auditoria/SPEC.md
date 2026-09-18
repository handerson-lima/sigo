---
id: SPEC-4-4-rh-invariantes-auditoria
companions:
  - ../implementation-artifacts/spec-4-4-rh-invariantes-auditoria.md
sources:
  - ../implementation-artifacts/epic-4-context.md
  - ../implementation-artifacts/spec-4-1-rh-cadastro.md
  - ../implementation-artifacts/spec-4-2-rh-chamada.md
  - ../implementation-artifacts/spec-4-3-rh-custos.md
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate.

# Story 4.4 — RH: Validação de Invariantes e Auditoria

## Why

As Stories 4.1 a 4.3 estruturaram o cadastro de colaboradores, a lista de chamada diária e a apropriação exata de custos de mão de obra em centavos. No entanto, para garantir integridade contábil, jurídica e operacional, o sistema necessita de uma camada rigorosa de **validação de invariantes e trilha de auditoria**. Sem essas regras, poderiam ocorrer inconsistências críticas: chamadas duplicadas no mesmo dia para a mesma obra, alocação simultânea de um colaborador em duas obras diferentes excedendo 100% de expediente, apontamentos de ausência com lotes ou custos indevidos, exclusão física de registros contábeis ou alterações arbitrárias em chamadas já fechadas sem justificativa nem rastreabilidade de autoria.

## Capabilities

- **CAP-1**
  - **intent:** Validar rigidamente as invariantes de presença e alocação de esforço por lote antes de persistir a chamada diária.
  - **success:** A chamada só é gravada se operários presentes somarem exatamente 100% de esforço em lotes válidos, meio-período somar 50% e faltas tiverem zero lotes e custo estritamente zero; qualquer violação resulta em erro explicativo determinístico.

- **CAP-2**
  - **intent:** Prevenir duplicidade de chamadas na mesma obra/data e detectar conflitos de alocação de expediente cross-obra.
  - **success:** Tentativas de registrar nova chamada para obra/data já existente são interceptadas com suporte a edição/retificação; colaboradores já alocados em 100% de expediente em outra obra no mesmo dia são identificados e bloqueados de dupla presença.

- **CAP-3**
  - **intent:** Implementar ciclo de retificação auditado e imutável para chamadas fechadas com justificativa obrigatória e histórico de revisões.
  - **success:** Chamadas com status `fechada` só podem ser retificadas por perfis administrativos (`admin`, `obraAdmin`, `dev`), gerando transição para status `retificada`, gravação do snapshot da versão anterior no histórico de auditoria (`auditHistory`), data, autor e motivo da retificação.

- **CAP-4**
  - **intent:** Disponibilizar na interface elementos visuais de governança, histórico de retificações e validação preventiva no formulário de chamada.
  - **success:** O formulário de chamada impede submissão se houver violações de invariantes com alertas contextuais; a visualização e listagem exibem badge de retificação e diálogo com a linha do tempo das alterações anteriores.

## Constraints

- Proibida exclusão física de chamadas no Firestore (`allow delete: if false;`).
- Toda retificação após o fechamento exige justificativa textual obrigatória (mínimo 10 caracteres).
- Nenhum colaborador ausente pode ter lotes associados ou custo maior que zero centavos.
- O esforço total diário de um colaborador em obras da mesma construtora não pode exceder 100%.
- Apenas usuários autorizados (`admin(c)`, `obraAdmin(c, o)` ou `dev`) têm permissão para retificar chamadas já fechadas.

## Non-goals

- Integração com catracas biométricas ou sistemas de ponto eletrônico portaria 671 nesta história.
- Módulo de advertências disciplinares ou suspensões formais de funcionários.

## Success signal

- Sistema impede qualquer duplicidade de chamada e violação de invariantes, registra histórico completo com justificativa em retificações, conta com 100% de testes automatizados aprovados e análise estática do Flutter zerada.
