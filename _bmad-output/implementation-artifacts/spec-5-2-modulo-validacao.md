---
title: 'Story 5.2 — Módulo Validação: Templates de Inspeção e Checklists de Lote com Evidências Fotográficas'
type: 'feature'
created: '2026-09-18'
status: 'ready-for-dev'
baseline_commit: '44ab2f1'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/specs/spec-5-2-modulo-validacao/SPEC.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-epic-5/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
  - '{project-root}/docs/data_model.md'
  - '{project-root}/docs/task.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:**
No canteiro de obras, o controle de conformidade e qualidade física dos lotes e unidades construtivas é realizado frequentemente de maneira assistemática ou informal (anotações em pranchetas, fotos avulsas em WhatsApp ou mensagens sem contexto). Esse modelo acarreta graves falhas:
1. **Divergência de Padrões Construtivos:** Cada encarregado ou engenheiro avalia a obra por critérios próprios, gerando disparidades de acabamento e segurança entre diferentes lotes e obras da mesma construtora.
2. **Falta de Prova Material de Não-Conformidade:** Quando um defeito ou não-conformidade é detectado, a ausência de registro formalizado com fotos datadas e localizadas dificulta a exigência de retrabalho ou a aplicação de penalidades contratuais a empreiteiros.
3. **Riscos de Entrega com Vícios Ocultos:** A inexistência de um checklist conclusivo por lote antes da entrega impede que a diretoria e a fiscalização auditem se todas as etapas técnicas (fundação, alvenaria, instalações, acabamentos) foram rigorosamente inspecionadas e aprovadas.

**Approach:**
Implementar o **Módulo de Validação e Qualidade**, estruturado em:
1. **Catálogo Corporativo de Templates de Validação (`validacao_templates`):** Cadastro no escopo da Construtora (`construtoras/{cId}/validacao_templates/{tId}`) contendo título, disciplina técnica (ex.: Estrutura, Alvenaria, Instalações Elétricas, Instalações Hidráulicas, Pintura e Acabamento), itens de verificação com descrição técnica e controle de versionamento incremental (`version`).
2. **Vistorias e Checklists por Lote (`validacoes`):** Subcoleção vinculada a cada lote da obra (`construtoras/{cId}/obras/{oId}/lotes/{lId}/validacoes/{vId}`). A vistoria fixa o `templateId` e o `templateVersion` vigente no momento da inspeção, assegurando que alterações futuras de critérios corporativos não adulterem vistorias passadas.
3. **Registro de Respostas e Não-Conformidades:** Para cada item do checklist, o avaliador define o status (`conforme`, `nao_conforme`, `nao_se_aplica`). Havendo não-conformidade, a inclusão de descrição de observação e anexação de evidência fotográfica torna-se obrigatória para conclusão.
4. **Evidências com Metadados e Storage Privado:** As imagens capturadas são enviadas para `construtoras/{cId}/obras/{oId}/validacao/{lId}/{vId}/{fotoId}.jpg`, contendo metadados auditáveis (identificação do lote, carimbo de data/hora ISO-8601 e UID do inspetor).
5. **Máquina de Estados de Validação do Lote:** A vistoria assume os status determinísticos: `pendente` (em preenchimento), `aprovado` (100% dos itens conformes ou N/A), `reprovado` (presença de não-conformidade) e `reaberto` (quando o lote passa por correções e é submetido a re-inspeção).

---

## Boundaries & Constraints

**Always:**
- Salvar templates corporativos em `construtoras/{cId}/validacao_templates/{tId}` e vistorias em `construtoras/{cId}/obras/{oId}/lotes/{lId}/validacoes/{vId}`.
- Ao criar uma nova versão de template, incrementar o campo `version` (ex.: 1 -> 2) mantendo integridade com as vistorias já existentes.
- Cada vistoria DEVE conter o snapshot de itens avaliados com a respectiva versão do template utilizada (`templateVersion`).
- Exigir obrigatoriamente descrição e pelo menos 1 evidência fotográfica para qualquer item marcado como `nao_conforme`.
- Restringir o acesso a usuários autorizados com o módulo `validacao` em `allowedModules`, administradores da obra (`obraAdmin`), administradores gerais (`admin`) ou `dev_roles`.
- Proibir estritamente a exclusão física (hard delete) de vistorias concluídas no Firestore (`allow delete: if false;`).
- Suportar operação offline via `OperationQueue` com sincronização resiliente de vistorias e imagens.

**Never:**
- Nunca permitir exclusão de uma vistoria aprovada ou reprovada.
- Nunca alterar o conteúdo ou itens de uma vistoria retroativamente após sua finalização.
- Nunca permitir concluir uma vistoria com status `aprovado` se houver itens marcados como `nao_conforme`.
- Nunca permitir a aprovação sem preenchimento de todos os itens obrigatórios do checklist.

---

## I/O & Edge-Case Matrix

| Cenário | Entrada / Estado | Saída Esperada | Tratamento de Erro |
|---|---|---|---|
| **Criação de Template de Validação** | Construtora cria template "Inspeção de Alvenaria" com 5 itens | Documento criado em `validacao_templates` com `version: 1` e status `ativo`. | Validação de campos obrigatórios (título, itens) |
| **Atualização de Template Existente** | Modificação de itens do template | Sistema grava atualização incrementando `version` (ex.: de 1 para 2). | Preservação de versões anteriores |
| **Início de Vistoria de Lote** | Engenheiro seleciona Lote 12 e template "Alvenaria" (v1) | Vistoria iniciada com status `pendente`, copiando estrutura de itens com `templateVersion: 1`. | Lote deve existir na obra |
| **Aprovação Total de Checklist** | Todos os itens assinalados como `conforme` ou `nao_se_aplica` | Vistoria finalizada com status `aprovado`. Lote exibe selo verde de conformidade na disciplina. | Bloqueio se houver item não respondido |
| **Item Não Conforme sem Foto** | Item marcado como `nao_conforme`, campo de foto em branco | Sistema bloqueia a finalização da vistoria alertando: "Foto de evidência obrigatória para itens não conformes". | Validação síncrona na UI e regras no Firestore |
| **Item Não Conforme com Foto e Justificativa** | Foto anexada + descrição "Fissura na junção viga-pilar" | Vistoria finalizada com status `reprovado`. Itens pendentes de retrabalho listados em destaque. | Upload seguro da evidência no Storage |
| **Reabertura de Vistoria Reprovada** | Encarregado reporta que o retrabalho foi executado | Vistoria transiciona para status `reaberto`, permitindo reavaliação dos itens não-conformes. | Manutenção do histórico do apontamento original |
| **Tentativa de Deleção de Vistoria** | Usuário tenta deletar registro de vistoria | Operação rejeitada pelas regras de segurança (`allow delete: if false;`). | Erro de permissão do Firestore |

---

## Data Models & Firestore Topology

### 1. Template de Validação (`validacao_templates`)
Path: `construtoras/{cId}/validacao_templates/{templateId}`
```json
{
  "id": "tpl_alvenaria_01",
  "construtoraId": "cId",
  "titulo": "Checklist de Alvenaria e Vedações",
  "disciplina": "alvenaria",
  "version": 1,
  "ativo": true,
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "itens": [
    {
      "id": "item_1",
      "titulo": "Prumo e alinhamento das paredes",
      "descricao": "Verificação com régua de nível e prumo de face nos cantos",
      "obrigatorio": true,
      "requerFotoSeReprovado": true
    },
    {
      "id": "item_2",
      "titulo": "Amarração de ferragens e tela eletrossoldada",
      "descricao": "Fixação correta na interface pilar/alvenaria",
      "obrigatorio": true,
      "requerFotoSeReprovado": true
    }
  ]
}
```

### 2. Vistoria de Lote (`validacoes`)
Path: `construtoras/{cId}/obras/{oId}/lotes/{loteId}/validacoes/{validacaoId}`
```json
{
  "id": "val_lote12_alv_001",
  "construtoraId": "cId",
  "obraId": "oId",
  "loteId": "lote12",
  "templateId": "tpl_alvenaria_01",
  "templateTitulo": "Checklist de Alvenaria e Vedações",
  "disciplina": "alvenaria",
  "templateVersion": 1,
  "status": "aprovado",
  "inspetorUid": "uid_123",
  "inspetorNome": "Eng. Roberto",
  "dataVistoria": "Timestamp",
  "dataFinalizacao": "Timestamp",
  "observacoesGerais": "Alvenaria em perfeito estado de acordo com o projeto executivo.",
  "itensRespondidos": [
    {
      "itemId": "item_1",
      "titulo": "Prumo e alinhamento das paredes",
      "status": "conforme",
      "observacao": "Conforme tolerância de 2mm",
      "fotos": []
    },
    {
      "itemId": "item_2",
      "titulo": "Amarração de ferragens e tela eletrossoldada",
      "status": "conforme",
      "observacao": null,
      "fotos": []
    }
  ],
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

---

## Security Rules & RBAC

```javascript
// firestore.rules

// Templates corporativos de validação
match /construtoras/{cId}/validacao_templates/{templateId} {
  allow read: if isMember(cId) || isDev();
  allow create, update: if (isAdmin(cId) || isDev());
  allow delete: if false; // Proibido exclusão física de templates
}

// Vistorias de qualidade por lote
match /construtoras/{cId}/obras/{oId}/lotes/{loteId}/validacoes/{validacaoId} {
  allow read: if isObraMember(cId, oId) || isDev();
  allow create: if (hasObraModule(cId, oId, 'validacao') || isObraAdmin(cId, oId) || isAdmin(cId) || isDev());
  allow update: if (hasObraModule(cId, oId, 'validacao') || isObraAdmin(cId, oId) || isAdmin(cId) || isDev());
  allow delete: if false; // Imutabilidade de histórico de qualidade
}
```

---

## Storage & Watermark

- **Caminho das Evidências:** `construtoras/{cId}/obras/{oId}/validacao/{loteId}/{validacaoId}/{fotoId}.jpg`.
- **Regras de Storage:** Acesso restrito a membros autorizados da obra ou `dev_roles`.
- **Watermark / Metadados:** Cada imagem salva registra ou sobrepõe metadados de auditoria:
  - Identificador da Obra e Lote (`Lote: 12 - Obra: Residencial Alpha`);
  - Timestamp ISO-8601 da captura;
  - UID / Nome do Inspetor.

---

## Estrutura de Código no Flutter

```text
app/lib/src/features/validacao/
  domain/
    validacao_template.dart      # Template corporativo e ChecklistTemplateItem
    validacao_vistoria.dart      # Vistoria, ItemRespondido e Enum ValidacaoStatus
  data/
    validacao_repository.dart    # Streams e operações Firestore (templates e vistorias)
  presentation/
    templates_list_screen.dart   # Gestão corporativa de modelos de inspeção
    template_form_dialog.dart    # Cadastro/edição de template com itens
    lote_validacoes_screen.dart  # Lista de vistorias do lote e status consolidado
    validacao_form_screen.dart   # Execução interativa do checklist e captura de fotos
```

---

## Roteamento (`app_router.dart`)

1. `/construtora/:cId/validacao/templates`: Gestão de templates corporativos da construtora.
2. `/construtora/:cId/obra/:oId/lotes/:loteId/validacoes`: Histórico de vistorias do lote.
3. `/construtora/:cId/obra/:oId/lotes/:loteId/validacoes/nova`: Iniciar nova vistoria com seleção de template.
4. `/construtora/:cId/obra/:oId/lotes/:loteId/validacoes/:validacaoId`: Visualizar / preencher vistoria do lote.

</frozen-after-approval>
