---
title: 'Story 5.7 — Gestão e Atribuição de Proprietário (Owner) da Construtora: Governança, Proteção de Titularidade e Identificação Visual'
type: 'feature'
created: '2026-09-19'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/specs/spec-5-7-gestao-proprietario-owner/SPEC.md'
  - '{project-root}/docs/data_model.md'
  - '{project-root}/docs/implementation_plan.md'
  - '{project-root}/firestore.rules'
  - '{project-root}/functions/src/index.ts'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:**
No sistema SIGO, a estrutura de papéis foi planejada com o perfil `owner` (Proprietário/Sócio) para representar o titular da construtora com poderes irrestritos e proteção contra destituição arbitrária por administradores delegados (`isAdmin: true`).
Contudo, existem quatro limitações que impedem seu uso na prática:
1. **Validação rígida na Cloud Function `setMembership` / `setConstrutoraRole`:** A lista de papéis válidos está travada em `['admin', 'member', 'operario']`. O envio de `role: 'owner'` gera erro imediato. Além disso, a flag `isOwner` apenas reutiliza o valor anterior (`isOwner: existing?.isOwner === true`), impossibilitando a concessão do papel a qualquer novo usuário.
2. **Criação Desvinculada de Construtora:** No painel do Desenvolvedor (`dev_construtoras_list_screen.dart`), uma nova construtora é gravada apenas como documento da coleção `construtoras`, sem associar o proprietário inicial.
3. **Ausência do papel nos formulários:** O dropdown de atribuição de cargo nos diálogos de membros e do dev só lista "Membro comum/Operário" e "Administrador".
4. **Omissão no modelo e na UI de Membros:** O modelo `Membro` ignora `isOwner`, e o componente `membros_screen.dart` exibe membros apenas como "Administrador" ou "Operário", não evidenciando quem é o proprietário.

**Approach:**
1. **Ajuste na Cloud Function de Membros (`functions/src/index.ts`):**
   - Expandir a lista de papéis aceitos para incluir `'owner'` em nível de construtora: `['admin', 'member', 'operario', 'owner']`.
   - Se `role === 'owner'` ou `d.isOwner === true`:
     - Exigir obrigatoriamente que o chamador seja `dev` ativo (`a.dev`).
     - Se o chamador for admin comum tentando definir `owner`, falhar com `permission-denied: 'Apenas dev altera proprietário'`.
     - Gravar no documento do membro: `{ role: 'owner', isAdmin: true, isOwner: true }`.
   - Manter a salvaguarda existente: se o membro alvo já for `isOwner`, apenas um `dev` pode alterar ou revogar seu vínculo.
2. **Atualização do Modelo de Domínio (`app/lib/src/features/construtoras/domain/membro.dart`):**
   - Adicionar os campos `final bool isOwner` e `final String role`.
   - Mapear a partir do Firestore: `isOwner: data['isOwner'] == true || data['role'] == 'owner'`.
3. **Aprimoramento da Tela de Membros (`membros_screen.dart`):**
   - No `ListTile`, exibir ícone destacado (ex.: `Icons.stars_rounded` com cor dourada/primária) para o proprietário.
   - No subtítulo, renderizar `"Proprietário"` quando `membro.isOwner == true`.
4. **Formulários de Atribuição (`add_membro_dialog.dart` e `user_details_screen.dart`):**
   - Incluir a opção `Proprietário` (`owner`) no dropdown de papéis.
   - Em `AddMembroDialog`, verificar se o usuário atual é dev ou proprietário para exibir essa opção.
5. **Criação de Construtora (`dev_construtoras_list_screen.dart`):**
   - Permitir informar opcionalmente o e-mail do proprietário inicial ao cadastrar a construtora, já provisionando o vínculo de `owner` via transação ou chamada à Function.
6. **Testes Automatizados:**
   - Teste unitário e de integração no backend (`functions/test/integration.cjs` e `unit.cjs`).
   - Teste de interface Flutter para o diálogo e listagem de membros com status de proprietário.

---

## Boundaries & Constraints

**Always:**
- Exigir perfil de `dev` global confiável (`dev_roles/{uid}` com `isActive: true`) para conceder ou revogar o status de `isOwner` / `role: 'owner'`.
- Garantir que todo membro com `isOwner: true` também possua `isAdmin: true` para compatibilidade total com regras de segurança legadas.
- Registrar log de auditoria na coleção `/audit` em qualquer operação de alteração de proprietário.
- Manter bloqueio para administradores comuns da construtora tentarem editar ou remover membros com `isOwner: true`.
- Passar com zero warnings no `flutter analyze` e 100% de sucesso nos testes automatizados (`npm test` no backend e `flutter test`).

**Never:**
- Nunca permitir que um usuário não-dev se promova ou promova outro usuário a `owner`.
- Nunca permitir que um administrador comum remova, desative ou rebaixe o papel de um `owner`.
- Nunca permitir que o papel `owner` seja atribuído em subcoleções de obra (`construtoras/{c}/obras/{o}/members`), pois a titularidade da empresa reside no escopo da construtora.

---

## I/O & Edge-Case Matrix

| Cenário | Entrada / Executante | Resultado Esperado | Tratamento de Erro |
|---|---|---|---|
| **Dev atribui papel de Proprietário** | Usuário `dev` chama `setMembership` com `role: 'owner'` | Sucesso. Membro gravado com `role: 'owner'`, `isOwner: true`, `isAdmin: true`. Entrada criada em `/audit`. | N/A |
| **Admin comum tenta atribuir Proprietário** | Usuário `admin(c)` (sem `dev`) tenta passar `role: 'owner'` | Rejeitado. Backend bloqueia a chamada. | Erro `permission-denied: 'Apenas dev altera proprietário'` |
| **Admin comum tenta rebaixar Proprietário existente** | Usuário `admin(c)` tenta alterar `role` de um membro que possui `isOwner: true` para `member` | Rejeitado. Backend identifica que o membro atual é owner e barra a edição. | Erro `permission-denied: 'Apenas dev altera proprietário'` |
| **Dev transfere ou adiciona novo Proprietário** | Usuário `dev` atribui `role: 'owner'` a um novo e-mail | Sucesso. Novo membro passa a ter status de Proprietário e todos os acessos administrativos. | N/A |
| **Visualização na Lista de Membros** | Usuário acessa `membros_screen.dart` | O membro proprietário exibe ícone de estrela e subtítulo "Proprietário". Membros comuns exibem "Operário" e administradores exibem "Administrador". | Renderização de fallback |
| **Criação de Construtora com Dono** | Dev preenche Nome da Construtora e E-mail do Dono no diálogo | Construtora é criada e o dono é imediatamente provisionado como `owner` da construtora. | Validação de e-mail existente |

---

## Data Models & Firestore Topology

### Documento de Membro da Construtora
**Caminho:** `construtoras/{cId}/construtora_members/{userId}`

```json
{
  "userId": "string",
  "construtoraId": "string",
  "email": "string",
  "displayName": "string",
  "role": "owner",
  "isAdmin": true,
  "isOwner": true,
  "isActive": true,
  "modules": ["estoque", "rh", "adm"],
  "joinedAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

---

## Plan de Verificação e Testes

1. **Testes de Backend (Cloud Functions):**
   - Executar `cd functions && npm test`.
   - Adicionar caso de teste: usuário dev atribuindo `role: 'owner'`.
   - Adicionar caso de teste: usuário admin comum recebendo `permission-denied` ao tentar passar `role: 'owner'`.
   - Adicionar caso de teste: usuário admin comum recebendo `permission-denied` ao tentar alterar membro existente com `isOwner: true`.
2. **Testes de Frontend (Flutter):**
   - Executar `flutter analyze` em `/Users/usuario/obras/app`.
   - Adicionar testes de widget para `MembrosScreen` validando a exibição correta dos papéis: "Proprietário", "Administrador" e "Operário".
   - Executar `flutter test` garantindo regressão zero.

</frozen-after-approval>
