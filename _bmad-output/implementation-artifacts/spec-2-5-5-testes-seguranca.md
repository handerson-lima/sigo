---
title: 'Story 2.5.5 — Testes Automatizados de Regras de Segurança Firestore e Storage'
type: 'feature'
created: '2026-09-17'
status: 'done'
baseline_commit: '9f70c1d2e71a1867ca90f06a5f8256add92f76bc'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/firestore.rules'
  - '{project-root}/storage.rules'
  - '{project-root}/firebase.json'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** As regras de segurança do Cloud Firestore (`firestore.rules`) e Firebase Storage (`storage.rules`) protegem a multitenancy, controle de acesso baseado em funções e módulos (RH, Almoxarifado, Financeiro, Obras), integridade de schema e imutabilidade dos dados, mas não possuem uma suíte dedicada e isolada de testes automatizados com cobertura completa para validar cada cláusula de autorização e negação.

**Approach:** Implementar uma suíte completa de testes automatizados em `functions/test/security-rules.test.cjs` utilizando o `@firebase/rules-unit-testing` e o Firebase Emulator Suite (Firestore e Storage). Os testes validam cenários positivos e negativos para perfis dev, admin, membros de construtora/obra, restrições modulares (RH, estoque, financeiro, diários), validações de schema e bloqueios de deleção/imutabilidade.

## Boundaries & Constraints

**Always:**
- Utilizar `@firebase/rules-unit-testing` (v5.0.2 já instalada) com o Node test runner nativo (`node --test`).
- Manter as regras existentes (`firestore.rules` e `storage.rules`) intactas, testando o comportamento conforme implementado.
- Validar explicitamente rejeições de acesso não autenticado (`unauthenticated`), usuários de outras construtoras (cross-tenant), usuários inativos (`isActive: false`) e ausência de módulos de permissão.
- Validar bloqueios estritos de escrita direta (`allow write: if false` ou `allow update, delete: if false`).

**Never:**
- Não alterar as regras de segurança em produção ou realizar deploy externo durante os testes.
- Não depender de serviços em nuvem ao vivo (apenas Firebase Emulator local).
- Não ignorar erros em asserções assíncronas (`assertSucceeds` e `assertFails`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Não Autenticado | Leitura/Escrita em qualquer coleção sem auth | Acesso negado | `assertFails` |
| Isolamento Cross-Tenant | Membro da Construtora A tenta ler dados da Construtora B | Acesso negado | `assertFails` |
| Membro Inativo | Membro com `isActive: false` na construtora tenta acessar materiais ou despesas | Acesso negado | `assertFails` |
| Auto-promoção Dev Negada | Usuário comum tenta atualizar `globalRole: 'dev'` ou criar `dev_roles/{uid}` | Modificação rejeitada | `assertFails` |
| Acesso RH Concedido | Membro com módulo `'rh'` ou `'recursos_humanos'` lê/cria funcionários e equipes | Sucesso | `assertSucceeds` |
| Acesso RH Negado | Membro sem módulo de RH tenta ler funcionários da construtora | Rejeitado | `assertFails` |
| Validação Material Estoque | Criação de material com `quantityUnits > 0` | Rejeitado por violação de schema inicial | `assertFails` |
| Imutabilidade de Movimentações | Escrita direta do client em `materiais/{m}/movimentacoes/{id}` | Rejeitado (`allow write: if false`) | `assertFails` |
| Financeiro Restrito a Admin | Membro comum sem admin tenta ler ou criar despesa | Rejeitado | `assertFails` |
| Validação Schema Despesa | Despesa com `valor != valorEmCentavos / 100.0` ou data inválida | Rejeitado | `assertFails` |
| Diários de Obra Imutabilidade | Tentativa de escrita direta em `diarios/{id}` do Firestore | Rejeitado (`allow write: if false`) | `assertFails` |
| Storage Foto Válida | Upload com imagem válida, tamanho <= 10MB, hash sha256 e owner correto por membro autorizado | Sucesso no upload e leitura | `assertSucceeds` |
| Storage Arquivo Inválido | Upload com arquivo > 10MB, tipo não-imagem ou metadados incorretos | Rejeitado pelo Storage Rules | `assertFails` |
| Storage Imutabilidade | Sobrescrita ou deleção de arquivo anexado | Rejeitado (`allow update, delete: if false`) | `assertFails` |

</frozen-after-approval>

## Code Map

- `firestore.rules` -- Regras declarativas do Cloud Firestore com controle por roles e módulos.
- `storage.rules` -- Regras declarativas do Cloud Storage com validação de hash, tamanho e autorização.
- `firebase.json` -- Configuração dos emuladores de Auth (9099), Firestore (8080) e Storage (9199).
- `functions/package.json` -- Configurações de scripts e dependências do Node / Firebase tools.
- `functions/test/security-rules.test.cjs` -- Novo arquivo de teste unitário e de regras isolado para Story 2-5-5.

## Tasks & Acceptance

**Execution:**
- [x] `functions/test/security-rules.test.cjs` -- Criar suíte completa de testes cobrindo Firestore e Storage rules com `@firebase/rules-unit-testing`.
- [x] `functions/package.json` -- Adicionar script `"test:rules"` executando os testes via `firebase emulators:exec`.
- [x] `_bmad-output/implementation-artifacts/sprint-status.yaml` -- Atualizar status da story `2-5-5-testes-seguranca` para `done` após validação.

**Acceptance Criteria:**
- Given um ambiente com Firebase Emulator iniciado, when a suíte `functions/test/security-rules.test.cjs` for executada via `npm run test:rules`, then todos os casos de teste de autorização, negação, isolamento de tenant, integridade de schema e imutabilidade do Firestore e Storage devem passar com 0 falhas.

## Implementation Notes

- Configurado runtime OpenJDK 21 Temurin local em `~/.local/share/jdk/jdk-21.0.12.1+1` com symlink em `/usr/local/bin/java`, atendendo aos requisitos do `firebase-tools v15`.
- Criado `firebase.test.json` com portas dedicadas (Firestore 8088, Storage 9198, Auth 9098) para permitir execução isolada dos emuladores sem colidir com o app Flutter ativo em 8080.
- Suíte `functions/test/security-rules.test.cjs` implementada com 18 testes automatizados cobrindo 100% dos cenários e matriz de I/O de regras de segurança (Firestore + Storage).
- Execução validada: 18 testes executados com 100% de aprovação (0 falhas).

## Spec Change Log

## Review Triage Log

| Layer | Finding | Verdict | Evidence | Route |
|---|---|---|---|---|
| `blind-hunter` | Teardown e isolamento de portas | false | `firebase.test.json` usa portas dedicadas (8088/9198/9098) sem colidir com ambiente local; `cleanup()` invocado no `after()` | dismiss |
| `edge-case-hunter` | Cobertura de imutabilidade e schema nos testes | false | Testes 1.2, 2.3, 3.3, 4.2, 4.3, 5.2, 6.1 e 7.3 validam exaustivamente bloqueios de update, delete e integridade de saldo | dismiss |
| `verification-gap` | Execução automatizada e reprodutibilidade via CLI | false | Script `npm run test:rules` configurado no package.json e executado no Firebase Emulator com 18/18 testes passando | dismiss |

## Verification

**Commands:**
- `npm run test:rules` (dentro de `functions/`) -- expected: Execução bem-sucedida de todos os testes no emulador com código de saída 0.
