---
title: 'Permissão Irrestrita ao Perfil Dev no Firestore'
type: 'bugfix'
created: '2026-09-20'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context:
  - '{project-root}/firestore.rules'
  - '{project-root}/functions/test/security-rules.test.cjs'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O usuário com papel desenvolvedor global (`dev_roles/{uid}.isActive == true`) está enfrentando erro de `permission-denied` ao tentar listar e cadastrar fornecedores, além de necessitar de acesso irrestrito a todas as coleções e documentos do banco de dados do projeto no Firestore.

**Approach:** Atualizar `firestore.rules` para conceder permissão irrestrita de leitura e escrita (`read, write`) para qualquer usuário com perfil `dev()` ativo em todo o banco (`match /{document=**}` e funções base `member`), e validar com testes automatizados na suíte de regras de segurança.

</frozen-after-approval>

## Implementation Notes

- Modificado `firestore.rules`:
  - Atualizada a função helper `member(c)` para incluir `dev() || ...`, assegurando que o desenvolvedor global seja considerado membro válido de qualquer construtora em regras derivadas.
  - Atualizada a função helper `obraMember(c,o)` para incluir `dev() || ...`, assegurando acesso transparente a subcoleções de obras.
  - Adicionado `match /{document=**} { allow read, write: if dev(); }` na raiz do Firestore, garantindo acesso irrestrito de leitura e escrita (inclusive listagens via queries e cadastros de fornecedores) para qualquer usuário com `dev_roles/{uid}.isActive == true`.
- Atualizado `functions/test/security-rules.test.cjs`:
  - Adicionado teste `1.4 Dev ativo tem acesso irrestrito para visualizar e cadastrar fornecedores` cobrindo query de coleção de fornecedores, escrita de documento e leitura direta com credencial de dev.
- Executada a suíte de testes de regras com emuladores via `npm --prefix functions run test:rules` — todos os 19 testes passaram com sucesso (100% de aprovação).
- Executados os testes unitários via `npm --prefix functions test` — 9 testes passaram com sucesso.

## Review Triage Log

- finding: 'Verificar se match /{document=**} relaxa regras para usuários não-dev' | verdict: false | evidence: 'A regra exige expressamente `dev()`, que avalia se o usuário está autenticado e possui `dev_roles/{uid}.isActive == true`. Usuários comuns e não-autenticados continuam 100% submetidos às regras específicas de RBAC, tenant e imutabilidade, conforme validado pelos testes 1.1, 1.2, 2.1 e 2.2.'
- finding: 'Verificar se dev pode realizar queries em subcoleções como fornecedores sem ter documento de construtora_member' | verdict: false | evidence: 'Confirmado pelo teste 1.4 recém-adicionado com `getDocs(collection(devFs, ...))` executando com sucesso no emulador.'
