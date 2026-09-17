---
title: 'Story 4.2 — RH: Lista de Chamada Diária'
type: 'feature'
created: '2026-09-17'
status: 'done'
baseline_commit: '8f132729b1286eb2839b2aee6aa8f1a87a4ec517'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-4-1-rh-cadastro.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-3-1-crud-projetos-lotes.md'
  - '{project-root}/docs/data_model.md'
  - '{project-root}/docs/user_flows.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O SIGO atualmente não possui um mecanismo ágil para registro de presença e alocação de mão de obra no canteiro de obras. O diário de obras apenas anota quantitativos gerais de efetivo (ex: "4 pedreiros"), sem identificar nominalmente quais profissionais compareceram, se cumpriram expediente integral ou parcial, e em quais frentes/lotes atuaram. Além disso, a digitação repetitiva diária dos mesmos lotes para as equipes gera atrito operacional para os encarregados, inviabilizando a correta apropriação dos custos de mão de obra (Story 4.3).

**Approach:** Implementar a **Lista de Chamada Diária** vinculada ao escopo da obra (`construtoras/{cId}/obras/{oId}/chamadas/{chId}`), com foco em máxima usabilidade móvel para encarregados em campo. O módulo permitirá:
1. Apontamento rápido de presença/falta/meio-período para funcionários da construtora alocados na obra ou por equipe.
2. Persistência e memorização automática do "Lote Atual" por equipe/obra para evitar retrabalho diário.
3. Ação com 1 toque para "Marcar Todos Presentes" no lote padrão da equipe.
4. Rateio percentual entre múltiplos lotes para trabalhadores divididos entre diferentes frentes.
5. Imposição estrita de invariantes de chamada: falta = 0% de apropriação; presente = exatamente 100%; meio-período = exatamente 50%.
6. Proteção por `firestore.rules` com proibição de hard delete e tolerância a operações em canteiro com conectividade intermitente.

## Boundaries & Constraints

**Always:**
- Persistir as chamadas no caminho hierárquico da obra: `construtoras/{cId}/obras/{oId}/chamadas/{chId}`.
- Exigir perfil de Administrador (`admin(c)`), Administrador da Obra (`obraAdmin(c,o)`), Dev Global (`dev`) ou membro com módulo `rh` concedido (`rh(c)` ou `'rh' in member.modules`).
- Utilizar formato de data ISO `yyyy-MM-dd` no campo `date` para indexação, ordenação cronológica e prevenção de duplicidade.
- Validar as invariantes matemáticas de alocação antes de permitir a persistência:
  - Se `status == 'falta'`: `allocations` deve ser vazia e a soma de porcentagem deve ser 0%.
  - Se `status == 'presente'`: a soma das porcentagens de alocação entre os lotes DEVE ser exatamente 100%.
  - Se `status == 'meio-periodo'`: a soma das porcentagens de alocação entre os lotes DEVE ser exatamente 50%.
- Memorizar o "Lote Atual" por equipe no armazenamento local/preferências para sugerir automaticamente na próxima chamada.
- Impedir duplicidade de trabalhadores na mesma chamada.
- Proibir exclusão física no Firestore (`allow delete: if false;`), utilizando exclusão/cancelamento lógico (`status: 'cancelada'`) se necessário.
- Garantir alvos de toque generosos (mínimo 48x48dp) para operação em smartphones ou tablets sob luz solar e luvas de proteção.

**Never:**
- Nunca permitir salvar uma chamada com soma de rateio de um trabalhador presente divergente de 100% (ou 50% para meio período).
- Nunca atribuir lotes ou porcentagens de trabalho para colaboradores com status `falta`.
- Nunca permitir salvar uma chamada sem ao menos um trabalhador apontado.
- Nunca realizar exclusão física (`delete`) de registros de chamada no Firestore.
- Nunca bloquear o encarregado no canteiro se a internet oscilar: usar persistência offline e feedback local imediato.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| **Chamada Padrão de Equipe (1 Toque)** | Encarregado seleciona Data `2026-09-17`, Equipe `Alvenaria`, Lote `Casa 10`. Clica em "Marcar Todos Presentes". | Todos os 5 membros da equipe recebem `status: presente` e `allocations: [{ lotId: 'lote-10', percentage: 100 }]`. Resumo: 5 presentes. Botão Salvar ativo. | N/A |
| **Trabalhador Faltou** | Encarregado clica no botão `[Falta]` no card do colaborador João. | O status do João passa para `falta`, suas alocações são zeradas/esvaziadas. Resumo atualizado: 4 presentes, 1 falta. | N/A |
| **Trabalhador em Meio-Período** | Encarregado clica no botão `[Meio-Período]` no card da Maria. | O status da Maria passa para `meio-periodo` e a alocação no lote padrão é automaticamente ajustada para 50%. | N/A |
| **Rateio em Múltiplos Lotes** | Trabalhador Pedro trabalhou meio dia no Lote 10 e meio dia no Lote 12. Encarregado clica em "Dividir Lotes". | Abre Bottom Sheet de Rateio. Usuário define Lote 10 (50%) e Lote 12 (50%). Soma fecha em 100%. Card exibe chips dos dois lotes. | Validador visual em tempo real |
| **Tentativa de Salvar com Rateio Inválido** | Usuário configura rateio manual somando 80% (ou 120%) para trabalhador presente. | Indicador do card exibe alerta vermelho: "Soma das alocações deve ser 100% (atual: 80%)". Botão "Salvar Chamada" é desabilitado. | Bloqueio síncrono com feedback visual explícito |
| **Memorização de Lote Atual** | Equipe Alvenaria teve chamada salva hoje no Lote 15. | Ao abrir uma nova chamada para a mesma equipe amanhã, o dropdown de Lote Padrão já vem pré-selecionado como "Lote 15". | Fallback para seleção manual caso lote não exista mais |
| **Edição / Retificação de Chamada** | Gestor abre chamada de data anterior para corrigir a presença de um operário. | Tela carrega dados históricos. Ao alterar e salvar, o registro atualiza `updatedAt`, grava `status: 'retificada'` e preserva trilha. | Feedback de sucesso via SnackBar |
| **Acesso Não Autorizado** | Usuário sem perfil admin e sem módulo `rh` tenta acessar a rota de chamadas da obra. | `AccessGuard` bloqueia a navegação e redireciona para `AccessDeniedScreen`. `firestore.rules` rejeita leituras/escritas. | Bloqueio de rota e segurança de banco |

</frozen-after-approval>

## Data Model & Schema

### 1. Entidade `ChamadaDiaria`
Armazenada em: `construtoras/{cId}/obras/{oId}/chamadas/{chId}`
```dart
class ChamadaDiaria {
  final String id;
  final String construtoraId;
  final String obraId;
  final String date; // Formato YYYY-MM-DD
  final String? teamId; // ID opcional da equipe associada
  final String? teamName; // Nome denormalizado da equipe
  final String createdByUid; // UID do encarregado/usuário que lançou
  final String? defaultLotId; // Lote padrão memorizado/utilizado
  final String status; // 'confirmada' | 'retificada' | 'cancelada'
  final String? observacoes; // Notas gerais do expediente
  final List<ApontamentoTrabalhador> workers;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion; // 1
}
```

### 2. Entidade `ApontamentoTrabalhador`
Representa a presença e alocação de um profissional específico na data:
```dart
enum PresencaStatus {
  presente,
  falta,
  meioPeriodo,
}

class ApontamentoTrabalhador {
  final String workerId;
  final String workerName;
  final String workerRole;
  final PresencaStatus status;
  final List<AlocacaoLote> allocations;

  int get totalPercentage =>
      allocations.fold(0, (sum, item) => sum + item.percentage);

  bool get isValidAllocation {
    switch (status) {
      case PresencaStatus.falta:
        return totalPercentage == 0;
      case PresencaStatus.meioPeriodo:
        return totalPercentage == 50;
      case PresencaStatus.presente:
        return totalPercentage == 100;
    }
  }
}
```

### 3. Entidade `AlocacaoLote`
Rateio proporcional do trabalhador em um lote específico da obra:
```dart
class AlocacaoLote {
  final String lotId;
  final String lotName; // Nome/código denormalizado do lote (ex: "Lote 14")
  final int percentage; // Porcentagem inteira (ex: 100, 50, 25)
}
```

## Security Rules (`firestore.rules`)

Adicionar o match sob `construtoras/{c}/obras/{o}`:
```javascript
match /chamadas/{ch} {
  allow read: if dev() || admin(c) || obraMember(c, o);
  allow create: if (dev() || admin(c) || obraAdmin(c, o) || rh(c))
    && request.resource.data.id == ch
    && request.resource.data.construtoraId == c
    && request.resource.data.obraId == o
    && request.resource.data.date is string
    && request.resource.data.date.matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
    && request.resource.data.workers is list
    && request.resource.data.workers.size() > 0
    && request.resource.data.schemaVersion == 1;
  allow update: if (dev() || admin(c) || obraAdmin(c, o) || rh(c))
    && request.resource.data.id == resource.data.id
    && request.resource.data.construtoraId == resource.data.construtoraId
    && request.resource.data.obraId == resource.data.obraId;
  allow delete: if false;
}
```

## UI/UX: Lançamento Rápido no Celular/Tablet

### 1. Cabeçalho de Expediente e Seleção
- **Seletor de Data:** Card tátil com calendário (`DatePickerDialog`), padrão na data de hoje.
- **Filtro de Equipe:** Dropdown com equipes da construtora + opção "Todos os Colaboradores".
- **Lote Padrão com Memorização:** Dropdown com lotes da obra. Ao escolher, o app guarda a seleção em cache local para pré-preenchimento futuro.
- **Botão Rápido de Ação em Massa:** Botão elevado "Marcar Todos Presentes" no lote padrão selecionado.

### 2. Cards de Trabalhadores Táteis
- **Dados:** Avatar com iniciais, Nome do Trabalhador em negrito, Cargo e Equipe.
- **Controle de Presença (Segmented Button Tátil):**
  - `[Presente]` (Fundo Verde quando ativo).
  - `[1/2 Período]` (Fundo Amarelo quando ativo).
  - `[Falta]` (Fundo Vermelho quando ativo).
- **Indicador de Lote(s):** Chip exibindo o lote alocado (ex: `Lote 10 (100%)`).
- **Botão "Rateio / Outro Lote":** Abre o BottomSheet de distribuição entre lotes caso o trabalhador tenha atuado em frentes distintas.

### 3. BottomSheet de Rateio de Lotes
- Adicionar ou remover lotes para o operário.
- Slider / campo numérico para definir a porcentagem de cada lote.
- Barra de validação dinâmica com feedback instantâneo:
  - Verde quando a soma atinge a invariante esperada (100% ou 50%).
  - Vermelho com mensagem instrutiva quando a soma for divergente.

### 4. Barra Inferior Fixa (Sticky Footer)
- Resumo em tempo real: `Total: X | Presentes: Y | Meio: Z | Faltas: W`.
- Botão expansivo "Salvar Chamada" desabilitado se houver qualquer apontamento com rateio inválido.

## Code Map

- `app/lib/src/features/rh/domain/chamada_diaria.dart` -- Entidades `ChamadaDiaria`, `ApontamentoTrabalhador`, `AlocacaoLote` e enum `PresencaStatus` com serialização JSON e validações de invariantes.
- `app/lib/src/features/rh/data/chamada_repository.dart` -- Repositório com streams e operações Firestore para chamadas diárias (`watchChamadas`, `getChamada`, `saveChamada`, `cancelChamada`) e suporte a cache offline.
- `app/lib/src/features/rh/data/lote_persistido_service.dart` -- Serviço para persistir e recuperar o último lote utilizado por equipe na obra (memória operacional).
- `app/lib/src/features/rh/presentation/chamadas_list_screen.dart` -- Tela de histórico de chamadas da obra com filtros por data, status e equipe, com badge de efetivo presente.
- `app/lib/src/features/rh/presentation/chamada_form_screen.dart` -- Interface principal de lançamento diário ágil para mobile/tablet.
- `app/lib/src/features/rh/presentation/widgets/apontamento_worker_card.dart` -- Card tátil de lançamento com segmented buttons e chips de lote.
- `app/lib/src/features/rh/presentation/widgets/rateio_lotes_sheet.dart` -- BottomSheet modal para divisão percentual de lotes.
- `app/lib/src/routing/app_router.dart` -- Adição das rotas:
  - `/construtora/:cId/obra/:oId/rh/chamadas`
  - `/construtora/:cId/obra/:oId/rh/chamadas/nova`
  - `/construtora/:cId/obra/:oId/rh/chamadas/:chId`
- `app/lib/src/common_widgets/sigo_sidebar.dart` -- Adição do item de menu "Chamada Diária" na navegação da obra quando autorizado.
- `firestore.rules` -- Regras de segurança para a subcoleção `chamadas` da obra.
- `app/test/rh_chamada_test.dart` -- Testes unitários de invariantes de alocação, serialização, repositório e testes de widgets da interface de chamada.

## Tasks & Acceptance

**Execution:**
- [x] `firestore.rules` -- Adicionar regras de segurança para `chamadas` com validações de schema e bloqueio de deleção física.
- [x] `app/lib/src/features/rh/domain/chamada_diaria.dart` -- Criar modelos de domínio com suporte a invariantes de rateio e validações.
- [x] `app/lib/src/features/rh/data/chamada_repository.dart` -- Implementar repositório Firestore para chamadas diárias.
- [x] `app/lib/src/features/rh/data/lote_persistido_service.dart` -- Implementar serviço de memorização do lote atual por equipe.
- [x] `app/lib/src/features/rh/presentation/widgets/apontamento_worker_card.dart` -- Implementar card tátil de apontamento.
- [x] `app/lib/src/features/rh/presentation/widgets/rateio_lotes_sheet.dart` -- Implementar BottomSheet de rateio entre múltiplos lotes.
- [x] `app/lib/src/features/rh/presentation/chamada_form_screen.dart` -- Implementar formulário ágil de chamada diária.
- [x] `app/lib/src/features/rh/presentation/chamadas_list_screen.dart` -- Implementar listagem e histórico de chamadas.
- [x] `app/lib/src/routing/app_router.dart` e `sigo_sidebar.dart` -- Mapear rotas e menu de navegação da obra.
- [x] `app/test/rh_chamada_test.dart` -- Criar suíte completa de testes automatizados unitários e de interface.

**Acceptance Criteria:**
- Given um encarregado de obra na tela de nova chamada, when clica em "Marcar Todos Presentes" com o Lote 10 selecionado como padrão, then todos os operários da equipe recebem presença com 100% de alocação no Lote 10.
- Given um colaborador marcado como "Falta", when a chamada é processada, then a alocação de lotes é 0% e nenhuma apropriação é atribuída a ele.
- Given um colaborador com status "Meio-Período", when o encarregado aloca lotes, then o sistema exige que a soma das porcentagens seja estritamente 50%.
- Given um encarregado configurando rateio entre múltiplos lotes (ex: Lote 1 e Lote 2), when as porcentagens somam 100%, then o sistema valida o rateio e permite salvar; se a soma diferir de 100%, o botão de salvar permanece bloqueado.
- Given a seleção do Lote Atual para uma equipe em uma chamada salva, when o usuário inicia uma nova chamada no dia seguinte para a mesma equipe, then o lote padrão é pré-carregado automaticamente.
- Given qualquer tentativa de efetuar hard delete na coleção de chamadas via cliente, then as regras do `firestore.rules` rejeitam a exclusão.

## Verification

**Commands:**
- `cd app && flutter test test/rh_chamada_test.dart` -- expected: All tests passed!
- `cd app && flutter analyze` -- expected: No issues found!

## Implementation Notes

- Implementadas as entidades `ChamadaDiaria`, `ApontamentoTrabalhador`, `AlocacaoLote` e o enum `PresencaStatus` com estrita validação de invariantes.
- `LotePersistidoService` implementado para salvar e restaurar o último lote utilizado por equipe na obra com cache em memória e IndexedDB/queueStore resiliente.
- Interface tátil para canteiro desenvolvida com botões rápidos de presença, segmented buttons, bottom sheet com barra dinâmica de progresso e validação de rateio.
- `ChamadasListScreen` criada com filtros rápidos e atalho para criação de chamadas.
- Rotas integradas no `app_router.dart` com proteção por `AccessGuard(module: 'rh')` e navegação incluída no `sigo_sidebar.dart`.
- `firestore.rules` atualizado com o match `/chamadas/{ch}` garantindo autorização de módulo/obra e bloqueando hard delete (`allow delete: if false`).

## Spec Change Log

- 2026-09-17: Criação da especificação técnica da Story 4.2.
- 2026-09-17: Implementação de código, telas, repositórios e suíte de testes. 10/10 testes específicos e 194/194 testes globais aprovados.

## Review Triage Log

- 2026-09-17: Blind Hunter — Validação de resiliência e integridade das regras de banco. Veredito: false (regras de segurança no Firestore bloqueiam delete físico e exigem schema version 1).
- 2026-09-17: Edge Case Hunter — Validação de rateio incorreto ou colaborador ausente com lote alocado. Veredito: false (a entidade de domínio e o botão salvar impedem qualquer persistência de chamada com taxa divergente de 100% no presente, 50% no meio-período ou >0% na falta).
- 2026-09-17: Verification Gap — Cobertura completa da Matriz I/O e edge cases. Veredito: false (10 testes cobrindo todas as linhas da matriz e fluxos de UI, 194/194 testes globais passando e análise estática limpa sem avisos).
