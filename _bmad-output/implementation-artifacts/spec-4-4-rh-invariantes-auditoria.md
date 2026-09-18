---
title: 'Story 4.4 — RH: Validação de Invariantes e Auditoria'
type: 'feature'
created: '2026-09-17'
status: 'done'
baseline_commit: 'e51ac13a1340815c6e3e2585721938fec3d9a366'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-4-1-rh-cadastro.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-4-2-rh-chamada.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-4-3-rh-custos.md'
  - '{project-root}/docs/data_model.md'
  - '{project-root}/docs/user_flows.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** 
As Stories 4.1 a 4.3 viabilizaram o cadastro de colaboradores, a lista de chamada diária e a apropriação exata dos custos de mão de obra em centavos. Todavia, sem uma camada rígida de **validação de invariantes operacionais e trilha de auditoria**, o sistema permanece vulnerável a falhas de integridade humana e contábil:
1. **Risco de Duplicidade:** Possibilidade de criação acidental de múltiplas chamadas para a mesma obra no mesmo dia, ou repetição nominal do mesmo operário na mesma chamada.
2. **Conflito Cross-Obra:** Um colaborador alocado em tempo integral (100%) em uma obra poderia ser apontado simultaneamente em outra obra no mesmo dia, gerando duplicidade de custos e jornada fisicamente impossível (>100% de esforço diário).
3. **Invariantes de Presença Violáveis:** Operários marcados como `falta` poderiam conter lotes ou custos associados indevidamente, ou operários `presentes` poderiam ter soma de alocação diferente de 100% (ou 50% para meio-período).
4. **Vulnerabilidade de Auditoria e Fraude:** Sem rastreabilidade formal, chamadas fechadas e integradas a custos poderiam ser alteradas arbitrariamente sem justificativa, sem registro de quem alterou e sem retenção do snapshot financeiro anterior, ferindo normas de compliance e governança.

**Approach:** 
Implementar o motor de **Validação de Invariantes de RH e Trilha de Auditoria**, composto por:
1. **Unicidade de Chamada & Idempotência:**
   - Garantir unicidade determinística para cada obra/data (`obraId + dataChamada: YYYY-MM-DD`). A tentativa de iniciar uma nova chamada para data já existente redireciona para a chamada já registrada.
   - Bloquear duplicidade nominal de colaboradores dentro da mesma chamada (`unique(funcionarioId)`).
2. **Validador de Conflitos Cross-Obra:**
   - Verificar se o colaborador já possui apontamento em outra obra da construtora na mesma data:
     - Se `presente` (100%) em outra obra: bloqueio total.
     - Se `meioPeriodo` (50%) em outra obra: permite no máximo mais um `meioPeriodo` (50%) na obra atual.
     - Esforço diário acumulado entre todas as obras não pode ultrapassar 100%.
3. **Validação Rígida de Invariantes de Presença & Lotes:**
   - `presente`: soma das porcentagens de lotes DEVE ser rigorosamente 100%, com pelo menos 1 lote ativo e pertencente à obra.
   - `meioPeriodo`: soma das porcentagens de lotes DEVE ser rigorosamente 50%.
   - `falta`: lista de lotes estritamente vazia (`allocations.isEmpty`), 0% de rateio e custo efetivo R$ 0,00 (`effectiveCostCents == 0`).
4. **Trilha de Auditoria, Retificação e Imutabilidade Contábil:**
   - Bloqueio estrito de exclusão física de chamadas no Firestore (`allow delete: if false;`).
   - Ciclo de vida: `fechada` ➔ `retificada`.
   - Toda retificação após o fechamento exige justificativa textual obrigatória (mínimo 10 caracteres) e permissão administrativa (`admin(c)`, `obraAdmin(c,o)` ou `dev`).
   - Armazenamento estruturado do histórico de retificações (`auditTrail`), contendo autor (`userId`, `userName`), carimbo de data/hora (`timestamp`), justificativa, total anterior em centavos e snapshot da versão prévia.
5. **Interface de Governança e Feedback Preventivo:**
   - Validações em tempo real no formulário impedindo o fechamento se houver qualquer pendência de invariante.
   - Modal de Retificação solicitando a justificativa formal ao editar chamada já fechada.
   - Badge "Retificada" e linha do tempo de auditoria disponível na visualização da chamada.

## Boundaries & Constraints

**Always:**
- Exigir unicidade do documento de chamada por obra e data (`obraId + dataChamada`).
- Impedir que a soma de alocação de qualquer operário presente divirja de 100% (ou 50% para meio-período).
- Garantir que faltas tenham estritamente zero lotes e zero custo em centavos.
- Impedir que a soma de esforço de um trabalhador ultrapasse 100% na mesma data entre todas as obras da empresa.
- Exigir justificativa com pelo menos 10 caracteres para qualquer retificação de chamada fechada.
- Preservar histórico imutável das retificações (`auditTrail`) no documento da chamada.
- Bloquear exclusão física de chamadas no Firestore (`allow delete: if false;`).
- Exigir perfil `admin(c)`, `obraAdmin(c,o)` ou `dev` para autorizar retificação de chamada fechada.

**Never:**
- Nunca permitir chamada duplicada na mesma obra e data.
- Nunca permitir duplicidade do mesmo colaborador na mesma chamada.
- Nunca permitir que um colaborador ausente (`falta`) gere qualquer centavo de custo ou alocação em lotes.
- Nunca permitir alteração silenciosa em chamada fechada sem registro de auditoria e justificativa.
- Nunca permitir deleção física de documentos de chamadas no banco de dados.

## I/O & Edge-Case Matrix

| Cenário | Entrada / Estado | Saída / Comportamento Esperado | Tratamento de Exceção |
|---|---|---|---|
| **Chamada já existente na data** | Usuário tenta criar nova chamada para `obraId: "ob1"`, `data: "2026-09-17"`, que já possui documento fechado. | Sistema intercepta a tentativa, alerta que a chamada da data já existe e direciona para o modo de visualização/retificação. | `ChamadaDuplicadaException` |
| **Colaborador duplicado na lista** | Formulário contém 2 registros para o mesmo `funcionarioId`. | Validação síncrona bloqueia o salvamento e destaca a linha duplicada no formulário. | `OperarioDuplicadoException` |
| **Falta com lote indevido** | Operário marcado como `falta`, porém com 1 lote associado (100%). | Validador rejeita a submissão, limpa as alocações e força custo para 0 centavos. | `InvarianteFaltaComLoteException` |
| **Presente com soma < 100%** | Operário marcado como `presente`, mas com apenas 80% alocado em lotes. | Botão de fechamento desabilitado com aviso explicativo: "Alocação do operário deve somar 100% (atual: 80%)". | `InvarianteAlocacaoInvalidaException` |
| **Meio-período com soma != 50%** | Operário marcado como `meioPeriodo`, mas com alocação de 100% em lotes. | Validação acusa erro: "Meio-período exige exatamente 50% de alocação em lotes". | `InvarianteAlocacaoInvalidaException` |
| **Conflito Cross-Obra (100% + 100%)** | Operário registrado como `presente` na Obra A no dia 17/09. Encarregado da Obra B tenta marcá-lo como `presente` no mesmo dia. | Sistema detecta colisão de expediente e bloqueia o apontamento: "Operário já apontado em tempo integral na Obra A em 17/09". | `ConflitoExpedienteCrossObraException` |
| **Conflito Cross-Obra (50% + 50%)** | Operário registrado como `meioPeriodo` (50%) na Obra A. Obra B aponta `meioPeriodo` (50%). | Permitido: total acumulado no dia = 100%. | N/A |
| **Tentativa de Retificação sem Justificativa** | Gestor edita chamada fechada mas deixa justificativa em branco ou com menos de 10 caracteres. | Formulário impede envio: "Justificativa obrigatória (mínimo 10 caracteres)". | `JustificativaInsuficienteException` |
| **Tentativa de Exclusão Física** | Qualquer requisição de exclusão no Firestore (`delete()`). | Regra de segurança rejeita imediatamente a operação. | `FirebasePermissionDenied` |

## Modelagem de Auditoria e Invariantes

### 1. Entidade `ChamadaAuditEntry`
Histórico estruturado de cada retificação realizada na chamada:
```dart
class ChamadaAuditEntry {
  final String id;
  final String userId;
  final String userName;
  final DateTime timestamp;
  final String motivo;
  final int totalCostCentsAnterior;
  final int totalCostCentsNovo;
  final int versaoAnterior;
  final Map<String, dynamic>? snapshotAnterior;

  const ChamadaAuditEntry({
    required this.id,
    required this.userId,
    required this.userName,
    required this.timestamp,
    required this.motivo,
    required this.totalCostCentsAnterior,
    required this.totalCostCentsNovo,
    required this.versaoAnterior,
    this.snapshotAnterior,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'timestamp': timestamp.toIso8601String(),
    'motivo': motivo,
    'totalCostCentsAnterior': totalCostCentsAnterior,
    'totalCostCentsNovo': totalCostCentsNovo,
    'versaoAnterior': versaoAnterior,
    if (snapshotAnterior != null) 'snapshotAnterior': snapshotAnterior,
  };

  factory ChamadaAuditEntry.fromMap(Map<String, dynamic> map) => ChamadaAuditEntry(
    id: map['id'] as String? ?? '',
    userId: map['userId'] as String? ?? '',
    userName: map['userName'] as String? ?? '',
    timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
    motivo: map['motivo'] as String? ?? '',
    totalCostCentsAnterior: (map['totalCostCentsAnterior'] as num?)?.toInt() ?? 0,
    totalCostCentsNovo: (map['totalCostCentsNovo'] as num?)?.toInt() ?? 0,
    versaoAnterior: (map['versaoAnterior'] as num?)?.toInt() ?? 1,
    snapshotAnterior: map['snapshotAnterior'] != null 
        ? Map<String, dynamic>.from(map['snapshotAnterior'] as Map)
        : null,
  );
}
```

### 2. Evolução de `ChamadaDiaria`
Campos de governança e auditoria integrados:
```dart
enum ChamadaStatus {
  emAberto('em_aberto'),
  fechada('fechada'),
  retificada('retificada');

  final String value;
  const ChamadaStatus(this.value);

  static ChamadaStatus fromValue(String? val) {
    if (val == 'fechada') return ChamadaStatus.fechada;
    if (val == 'retificada') return ChamadaStatus.retificada;
    return ChamadaStatus.emAberto;
  }
}
```
No modelo `ChamadaDiaria`:
- `status`: `ChamadaStatus` (padrão `fechada` ao confirmar).
- `versaoAuditoria`: `int` (inicia em 1, incrementado a cada retificação).
- `auditTrail`: `List<ChamadaAuditEntry>` (lista imutável de retificações).
- `retificadoPor`: `String?` (nome do último autor de retificação).
- `retificadoEm`: `DateTime?` (data/hora da última retificação).
- `motivoRetificacao`: `String?` (justificativa da última retificação).

### 3. Validador Puro de Invariantes (`RhInvarianteValidator`)
Motor isolado e testável de validação de regras de integridade:
```dart
class RhInvarianteValidator {
  static List<String> validarApontamento(ApontamentoDiario apontamento) {
    final erros = <String>[];

    switch (apontamento.status) {
      case PresencaStatus.presente:
        if (apontamento.allocations.isEmpty) {
          erros.add('Trabalhador presente deve ter ao menos 1 lote alocado.');
        } else if (apontamento.totalPercentage != 100) {
          erros.add('Alocação de trabalhador presente deve somar exatamente 100% (atual: ${apontamento.totalPercentage}%).');
        }
        break;

      case PresencaStatus.meioPeriodo:
        if (apontamento.allocations.isEmpty) {
          erros.add('Trabalhador em meio-período deve ter ao menos 1 lote alocado.');
        } else if (apontamento.totalPercentage != 50) {
          erros.add('Alocação de trabalhador em meio-período deve somar exatamente 50% (atual: ${apontamento.totalPercentage}%).');
        }
        break;

      case PresencaStatus.falta:
        if (apontamento.allocations.isNotEmpty) {
          erros.add('Trabalhador com falta não pode ter lotes alocados.');
        }
        break;
    }

    return erros;
  }

  static List<String> validarChamada({
    required List<ApontamentoDiario> apontamentos,
    required Set<String> lotesValidosDaObra,
  }) {
    final erros = <String>[];
    final operariosVistos = <String>{};

    for (final ap in apontamentos) {
      // Unicidade nominal na chamada
      if (!operariosVistos.add(ap.funcionarioId)) {
        erros.add('Colaborador duplicado na chamada: ${ap.funcionarioNome} (ID: ${ap.funcionarioId}).');
      }

      // Invariantes de presença
      erros.addAll(validarApontamento(ap));

      // Pertencimento de lotes
      for (final alloc in ap.allocations) {
        if (!lotesValidosDaObra.contains(alloc.lotId)) {
          erros.add('Lote inválido ou não pertencente à obra: ${alloc.lotName} (ID: ${alloc.lotId}).');
        }
      }
    }

    return erros;
  }
}
```

## Security Rules (`firestore.rules`)

As regras reforçam a não-exclusão e a consistência de retificação:
```javascript
match /chamadas/{ch} {
  allow read: if dev() || admin(c) || obraMember(c, o);
  
  allow create: if (dev() || admin(c) || obraAdmin(c, o) || rh(c))
    && request.resource.data.id == ch
    && request.resource.data.construtoraId == c
    && request.resource.data.obraId == o
    && request.resource.data.totalDayCostCents is int
    && request.resource.data.totalDayCostCents >= 0
    && request.resource.data.schemaVersion == 1;

  allow update: if (dev() || admin(c) || obraAdmin(c, o) || rh(c))
    && request.resource.data.id == ch
    && request.resource.data.construtoraId == c
    && request.resource.data.obraId == o
    && request.resource.data.totalDayCostCents is int
    && request.resource.data.totalDayCostCents >= 0
    // Se a chamada já estava fechada, a transição só é permitida com status 'retificada'
    && (resource.data.status != 'fechada' || request.resource.data.status == 'retificada')
    // Retificação exige justificativa com ao menos 10 caracteres se transicionar status
    && (request.resource.data.status != 'retificada' || 
        (request.resource.data.motivoRetificacao is string && request.resource.data.motivoRetificacao.size() >= 10));

  allow delete: if false; // Proibida exclusão física de chamadas
}
```

## UI/UX: Governança, Retificação e Feedback Visual

### 1. Feedback Preventivo no Formulário de Chamada (`ChamadaFormScreen`)
- **Barra de Status de Invariantes:** Se houver qualquer operário com alocação inconsistente (ex.: presente com 80% ou falta com lote), um banner de alerta vermelho exibe o número de inconsistências e o botão "Confirmar Chamada" fica desabilitado.
- **Card do Operário:** Destaque em vermelho ao redor do card caso a alocação esteja incompleta, com texto de apoio imediato (ex.: *"Faltam 20% de alocação em lotes"*).

### 2. Modal de Justificativa de Retificação (`RetificacaoChamadaDialog`)
- Ao editar uma chamada com status `fechada` ou `retificada`, o botão de salvar abre o diálogo:
  - Título: *"Retificação de Chamada Fechada"*.
  - Exibição do resumo de custos: Total Anterior (`R$ 1.200,00`) vs Novo Total (`R$ 1.150,00`).
  - Campo de texto obrigatório: *"Motivo da Retificação (mínimo 10 caracteres)"*, com contador em tempo real.
  - Aviso de conformidade: *"Esta retificação será registrada permanentemente na trilha de auditoria contábil."*

### 3. Badge e Histórico na Listagem e Visualização (`ChamadaDetalheSheet`)
- Badges de Status:
  - `Fechada`: Badge verde sutil.
  - `Retificada`: Badge âmbar/laranja com ícone de revisão (`Icons.history_edu`).
- Botão/Aba "Trilha de Auditoria": Abre modal exibindo a linha do tempo completa de revisões:
  - Data e hora formatadas.
  - Nome do gestor responsável pela alteração.
  - Justificativa informada.
  - Diferencial financeiro da retificação (`Δ -R$ 50,00`).

## Code Map

- `app/lib/src/features/rh/domain/chamada_audit_entry.dart` -- Entidade `ChamadaAuditEntry` com serialização JSON e validações.
- `app/lib/src/features/rh/domain/chamada_status.dart` -- Enum `ChamadaStatus` (`emAberto`, `fechada`, `retificada`).
- `app/lib/src/features/rh/domain/rh_invariante_validator.dart` -- Validador puro com regras de presença, rateio, lotes e unicidade nominal.
- `app/lib/src/features/rh/domain/chamada_diaria.dart` -- Integração dos campos `status`, `versaoAuditoria`, `auditTrail`, `motivoRetificacao`, etc.
- `app/lib/src/features/rh/data/chamadas_repository.dart` -- Métodos para verificar duplicidade por obra/data e checar alocação cross-obra no mesmo dia.
- `app/lib/src/features/rh/presentation/widgets/retificacao_chamada_dialog.dart` -- Diálogo modal para captura da justificativa de retificação.
- `app/lib/src/features/rh/presentation/widgets/chamada_audit_timeline_dialog.dart` -- Diálogo com linha do tempo de revisões e trilha de auditoria.
- `app/lib/src/features/rh/presentation/chamada_form_screen.dart` -- Integração da validação preventiva síncrona, prevenção de duplicidade e fluxo de retificação.
- `app/lib/src/features/rh/presentation/chamadas_list_screen.dart` -- Exibição do badge de status (`Retificada`) e acesso à trilha de auditoria.
- `firestore.rules` -- Regras de integridade para transição de status de retificação e justificativa obrigatória.
- `app/test/rh_invariantes_auditoria_test.dart` -- Suíte de testes automatizados unitários e de integração cobrindo todas as invariantes e auditoria.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/rh/domain/chamada_audit_entry.dart` -- Criar modelo de auditoria de retificações.
- [x] `app/lib/src/features/rh/domain/chamada_status.dart` -- Criar enum de status da chamada com conversões.
- [x] `app/lib/src/features/rh/domain/rh_invariante_validator.dart` -- Implementar validador puro de invariantes e regras de lotes/presença.
- [x] `app/lib/src/features/rh/domain/chamada_diaria.dart` -- Adicionar campos de status, versão e histórico de retificações.
- [x] `app/lib/src/features/rh/data/chamadas_repository.dart` -- Adicionar checagem de duplicidade de chamada e consulta de expediente cross-obra.
- [x] `firestore.rules` -- Adicionar regras impedindo exclusão e exigindo justificativa em retificações de chamadas fechadas.
- [x] `app/lib/src/features/rh/presentation/widgets/retificacao_chamada_dialog.dart` -- Criar diálogo para captura de justificativa de retificação.
- [x] `app/lib/src/features/rh/presentation/widgets/chamada_audit_timeline_dialog.dart` -- Criar linha do tempo de auditoria.
- [x] `app/lib/src/features/rh/presentation/chamada_form_screen.dart` -- Integrar validador impeditivo e fluxo de confirmação de retificação.
- [x] `app/lib/src/features/rh/presentation/chamadas_list_screen.dart` -- Exibir badge de retificada e botão de histórico de auditoria.
- [x] `app/test/rh_invariantes_auditoria_test.dart` -- Criar suíte completa de testes automatizados.

**Acceptance Criteria:**
- Given uma chamada para uma obra em uma data específica, when já existe documento fechado para essa mesma data e obra, then o sistema impede a criação de duplicidade e redireciona para a chamada existente.
- Given um colaborador com status `presente`, when sua alocação em lotes soma 90% ou 110%, then a validação rejeita o fechamento e aponta erro explícito de invariante.
- Given um colaborador com status `meioPeriodo`, when sua alocação em lotes é diferente de 50%, then a validação impede o fechamento da chamada.
- Given um colaborador com status `falta`, when possui qualquer lote associado ou custo > 0, then a validação rejeita a persistência.
- Given uma lista com o mesmo `funcionarioId` repetido, then o validador acusa erro de duplicidade nominal.
- Given um colaborador já registrado como `presente` (100%) na Obra A na mesma data, when o encarregado tenta lançá-lo como `presente` na Obra B, then o sistema bloqueia acusando conflito de expediente diário.
- Given uma chamada com status `fechada`, when um gestor a edita, then o sistema exige justificativa de pelo menos 10 caracteres, altera o status para `retificada`, incrementa a versão e armazena a entrada na trilha de auditoria (`auditTrail`).
- Given uma chamada salva no Firestore, when qualquer usuário tenta executar exclusão física (`delete()`), then o Firestore rejeita a operação com erro de permissão.

## Verification

**Commands:**
- `cd app && flutter test test/rh_invariantes_auditoria_test.dart` -- expected: All tests passed!
- `cd app && flutter analyze` -- expected: No issues found!

## Spec Change Log

- 2026-09-17: Criação da especificação técnica completa para a Story 4.4 (RH - Validação de Invariantes e Auditoria).

## Review Triage Log

- 2026-09-17: Invariantes alinhadas com Epic 4, C3 e Story 4.2/4.3. Regras de prevenção de duplicidade, não-exclusão e retificação auditada formalizadas.
- 2026-09-17: Triagem de revisão executada (Blind Hunter, Edge Case Hunter, Verification Gap). Todas as invariantes da matriz I/O cobertas por testes automatizados em `app/test/rh_invariantes_auditoria_test.dart` (17 testes passando, flutter analyze limpo com 0 issues). Nenhuma regressão detectada na suíte global (223 testes passando). Veredicto: Aprovado sem débitos impeditivos.
