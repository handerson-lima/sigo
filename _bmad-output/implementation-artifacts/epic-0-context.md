# Epic 0 Context: Governança e Decisões Iniciais

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Estabelecer a base de governança do SIGO antes da estabilização C0–C6 e das demais epics: registrar as decisões vigentes de forma centralizada e auditável, definir a política de acesso e privilégios, obter as aprovações formais dos termos e consolidar a matriz de acesso que orienta Rules, Functions e UI. Sem este epic, a execução técnica carece de referência autoritativa de escopo e autorização; a matriz e as políticas aqui firmadas alimentam diretamente o pacote de segurança (C1) e a autorização de vínculos dos epics seguintes. Nota de lacuna: o arquivo de epics formalizado cobre apenas Epics 8–10; Goal e Stories deste epic derivam do sprint status, do backlog vigente (docs/task.md) e do registro de decisões — sem PRD ou spine de arquitetura dedicados ao Epic 0.

## Stories

- Story 0.1: registrar-decisoes
- Story 0.2: definir-politica
- Story 0.3: aprovar-termos
- Story 0.4: matriz-acesso

## Requirements & Constraints

- As decisões aprovadas (D1–D7) ficam centralizadas num único registro vigente, sem duplicar nem alterar histórico; o arquivo de planejamento anterior permanece imutável e só de consulta.
- Todo registro de decisão exige: status, motivo, evidência rastreável até o baseline de referência, responsável e data. Pendências sem evidência ficam explícitas como tais — nunca inferir conclusão por presença de código ou tela.
- Restrição de maior risco: desenvolvedor global é confirmado e preservado, sem exigir vínculo por obra para administração global; identidades de devs legítimos não podem ser inferidas e autoatribuições de `globalRole=dev` não são confiáveis.
- A matriz de acesso define papéis (dev confiável, admin/proprietário da construtora, admin da obra, membro comum, sem autorização) com escopos explícitos sobre usuários/vínculos, dados de obra, estoque, financeiro e arquivos; permissão de obra regular exige vínculo ativo na construtora e na obra, com dev e admin/proprietário da construtora como exceções.
- Escopo da aprovação vigente: implementação e validação de C0–C6 e da matriz em ambiente de desenvolvimento, preservando dev global, estoque central e dados existentes. Implantação em produção não é autorizada por este plano e deve ser apresentada separadamente, com simulação, impactos, devs verificados e plano de recuperação.
- Termos/aprovações devem espelhar o estado real do sprint status: atualização de planejamento solicitada, dev global preservado confirmado, plano de correção aprovado, produção não autorizada.
- Pendências abertas que o epic deve manter visíveis (sem inventário não há conclusão): identidade dos desenvolvedores legítimos, regras de produção publicadas, volume real de dados legados.
- Aceite da Story 0.1 já registrado (transcrição das fontes vigentes de 15/09/2026 aprovada em 21/09/2026); demais stories permanecem em backlog.

## Technical Decisions

- Autorização é server-authoritative: campos e papéis globais nunca são gravados nem alterados pelo cliente comum; papel global só via servidor, com migração segura do fallback legado de e-mail para UID.
- Gate de dev confiável (`trustedDev`/`dev_roles`) é a única exceção para operações privilegiadas (ex.: alterar `owner`); a guarda deve ser única e uniforme entre Rules, Functions e UI.
- Perfis consistentes via `isActive`, `modules`, `isAdmin` e `isOwner`; claims antigas não prevalecem sobre vínculo revogado; módulos fail-closed (vazio = sem acesso), com normalização de nomes legados.
- Escrita de autorização/vínculos somente por Functions auditadas no servidor; auditoria de ator, alvo e resultado fica no servidor, sem UI nesta etapa.
- C0–C6 são categorias de inventário, correção e aceite restritas ao desenvolvimento; estabilização e segurança são dependências explícitas de qualquer expansão de módulos.
- Inventário/migração antes de publicar: versionamento de schema, simulação e verificação prévia de conta de recuperação antes de qualquer migração de privilégios.

## Cross-Story Dependencies

- Story 0.1 (done) é a base documental: 0.2, 0.3 e 0.4 consolidam sobre as decisões já registradas, sem reabrir o histórico.
- A matriz de acesso (0.4) é pré-condição de referência para o pacote C1 (autorização) e para as guards de rota/vínculo dos epics de gestão de membros.
- Aprovações do epic (0.3) limitam o alcance dos demais epics: execução em dev autorizada, produção bloqueada até aprovação separada.
- Pendências de evidência (devs legítimos, regras publicadas, dados legados) bloqueiam etapas dependentes de migração/produção fora deste epic.
