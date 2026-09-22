# Epic 10 Context: Gestão do vínculo

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Permitir que admin e owner da construtora alterem vínculos existentes de membros: trocando o papel (Operário↔Admin da obra) e os módulos de acesso de um vínculo obra, removendo o membro de uma obra específica (desativando o vínculo), trocando o cargo na construtora (operário↔admin, sem opção owner sem `trustedDev`) e desativando/removendo da construtora com remoção simultânea de N obras vinculadas. Toda mutação passa pela Cloud Function `setMembership`/`setConstrutoraRole`; revogação é imediata via gate `active(cm)` sem cascata transacional no backend.

## Stories

- Story 10.1: Trocar papel/módulos na obra
- Story 10.2: Remover da obra
- Story 10.3: Trocar cargo na construtora e desativar

## Requirements & Constraints

- Apenas admin ou owner da construtora podem executar estas ações.
- Toda mutação passa por `setMembership`/`setConstrutoraRole` (httpsCallable). Nenhuma escrita direta no Firestore da camada cliente.
- Papel de obra válido: `operario` ou `admin`. Nunca enviar `owner` com `obraId`.
- Módulos canônicos para obra: `diario`, `lotes`, `estoque`; normalizar legados (`rdo→diario`, `almoxarifado→estoque`). Módulos `[]` = sem acesso (fail-closed).
- Remoção de obra desativa apenas o vínculo obra (`isActive: false`); histórico (diários lançados) é preservado.
- Desativação da construtora é N `setMembership{obraId, isActive:false}` + `setMembership{isActive:false}` na construtora — sem transação atômica no backend; docs órfãos são inócuos enquanto gate `active(cm)` vigorar.
- Trocar `owner` na construtora exige flag `trustedDev`; UI oculta a opção sem esse flag.
- Erros mapeados pt-br: `permission-denied→Você não tem permissão.`; `failed-precondition→Ative na construtora primeiro.`; `Papel inválido→Use Operário ou Admin da obra.`; sem conexão → `Sem conexão — tente novamente`.
- Leitura usa cache Firestore; escrita de vínculo exige rede (sem fila offline).
- Após mutação invalidar `membrosProvider` + `obraMembersProvider`.
- Acessibilidade: alvos ≥48dp; papel nunca só por cor; contraste Material; foco trap em dialogs; `Esc` fecha; `textScale` até 1.3x sem truncar CTAs.
- Responsivo mobile (<800px) + web (≥800px) em `SigoLayout`.

## Technical Decisions

- Paradigma Layered Riverpod MVVM: UI → providers → `ObraMembersRepository`/`MembrosRepository` → `httpsCallable` → Functions → Firestore.
- Cada mutação bem-sucedida invalida `membrosProvider(cId)` + `obraMembersProvider((cId, obraId))`. Pull-to-refresh disponível como fallback.
- `ObraVinculoRow` — overflow com opções `Trocar papel/módulos` e `Remover da obra`; visível apenas para admin/owner.
- Trocar papel/módulos: abre dialog pré-preenchido com papel e módulos atuais → chama `setMembership{obraId, role, modules}`.
- Remover da obra: `ConfirmDestructiveDialog` explicitando consequência → `setMembership{obraId, isActive:false}`.
- Trocar cargo construtora: `setConstrutoraRole{role}` sem opção `owner` (exceto `trustedDev`). Exige `obraId` ausente.
- Desativar construtora com N obras: confirm listando N obras → N chamadas `setMembership{obraId, isActive:false}` + 1 `setMembership{isActive:false}` (construtora); UI espera todas resolverem com indicador de progresso.
- Detecção offline antes de disparar CF (pré-check igual ao pattern do Epic 9).
- Estrutura de arquivos principais herdada do Epic 9:
  - `app/lib/src/features/obras/data/obra_members_repository.dart`
  - `app/lib/src/features/construtoras/data/membros_repository.dart`
  - `app/lib/src/features/construtoras/presentation/widgets/` (dialogs e rows)
  - `app/test/features/construtoras/membros_test.dart`

## UX & Interaction Patterns

- **ObraVinculoRow overflow:** menu com `Trocar papel` e `Remover da obra`; gatilhado pelo ícone de overflow na linha da obra no detalhe do membro.
- **Trocar papel/módulos:** dialog com papel atual pré-selecionado (`Operário`/`Admin da obra`) e chips de módulos pré-marcados conforme vínculo atual; resumo ao vivo; Confirmar envia `setMembership` com novos valores.
- **Remover da obra:** `ConfirmDestructiveDialog` com texto `Remover {email} de {obra}? Ele perde acesso imediato; diários preservados.` → após confirmação linha some, contador decrementa, snackbar `Removido de {obra}.`
- **Trocar cargo construtora:** bloco vínculo construtora no detalhe; dropdown `operario`/`admin` (sem `owner` sem `trustedDev`); confirmação inline ou dialog.
- **Desativar construtora:** confirmação destructiva listando N obras afetadas; execução sequencial ou paralela das N+1 chamadas; snackbar de conclusão.
- **Feedback de sucesso:** SnackBar pt-br; após remoção obra a linha desaparece da lista; após desativação membro sai da lista de ativos.
- **Estado vazio obras:** `Nenhuma obra vinculada — Atribuir` (mantido do Epic 9).
- **Fluxo de erro:** dialog permanece aberto exibindo mensagem mapeada; nenhum auto-close em erro.

## Cross-Story Dependencies

- Depende das Stories 8.3 (Detalhe do Membro — estrutura `ObraVinculoRow` + bloco vínculo construtora) e 9.1/9.2 (infraestrutura `ObraMembersRepository`, `AtribuirObraDialog`, tradução de erros).
- Story 10.1 e 10.2 usam o mesmo `ObraVinculoRow` — implementar overflow na mesma story ou garantir que 10.1 entregue o componente extensível.
- Story 10.3 acessa `setConstrutoraRole` (Functions já existente); verificar flag `trustedDev` no provider de auth atual antes de implementar a UI.
