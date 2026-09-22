---
title: '9.1 Atribuir operário à obra'
type: 'feature'
created: '2026-09-22'
status: 'done'
route: 'dispatch'
baseline_commit: '5f0b0c9ac8e2b9821186b06d03c79569d4508484'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Adm/owner visualiza o membro ativo na construtora no detalhe (8.3), mas o botão "Atribuir à obra" está desabilitado, impossibilitando alocar o operário em uma obra com seus respectivos módulos de acesso.

**Approach:** Habilitar o fluxo de atribuição no `MemberDetalheSheet` para membros ativos abrindo `AtribuirObraDialog`: permitir selecionar uma obra ativa da construtora (filtrando as já vinculadas ativas), manter o papel fixado em "Operário", módulos padrão `[diario]`, exibir resumo dinâmico ao vivo e chamar `setMembership` via repositório, exibindo SnackBar de confirmação e atualizando o estado local e contadores.

## Boundaries & Constraints

**Always:**
- Apenas membros ativos na construtora podem ser atribuídos; para membros inativos (`isActive == false`), o botão "Atribuir à obra" permanece desabilitado com o aviso `Ative na construtora primeiro`.
- Papel atribuído nesta história é estritamente `operario` (role: `operario`). Nunca enviar `owner` com `obraId`.
- Módulos padrão pré-selecionados: `[diario]`. Módulos adicionais permitidos: `lotes`, `estoque`.
- O botão de confirmação ("Confirmar atribuição") deve permanecer desabilitado enquanto nenhuma obra válida for selecionada ou quando não houver obras ativas disponíveis.
- Resumo dinâmico em tempo real exibido no diálogo: `{Nome/Email} será Operário em {Obra} com acesso a {Módulos}` (UX-DR4).
- Toda mutação passa por `setMembership{construtoraId, obraId, userId, role: 'operario', modules, isActive: true}` via Cloud Functions; a UI nunca grava diretamente na subcoleção `members`.
- Após atribuição bem-sucedida, exibir SnackBar `Atribuído a {obra} como Operário.` e invalidar os providers (`membrosProvider`, `obraMembersProvider`, `obrasVinculadasProvider`, `contagemObrasPorMembroProvider`, `memberDetalheProvider`).
- Normalização na leitura de membro de obra: `member` vira `Operário`.
- Acessibilidade: diálogos com rótulos semânticos, foco inicial, suporte a fechar via tecla Esc e suporte a escala de fonte `textScale` de até 1.3x sem overflow.

**Never:**
- Não permitir selecionar ou enviar papel `owner` para vínculo de obra.
- Não permitir atribuição sem obra selecionada.
- Não usar fila offline para atribuição de novos membros (operação online-only; AD-6/NFR2).
- Não criar `collectionGroup` queries.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| HAPPY_PATH atribuição | Membro ativo, clica "Atribuir à obra", seleciona obra ativa, módulos `[diario]`, confirma | Chama `setMembership`, fecha dialog, SnackBar `Atribuído a {obra} como Operário.`, invalida providers e N obras atualiza | Exibe SnackBar com erro caso a Cloud Function falhe |
| Sem obra selecionada | Dialog aberto sem obra escolhida | Botão de confirmar desabilitado; resumo indica seleção pendente | N/A |
| Nenhuma obra ativa | Construtora sem obras ativas ou membro já vinculado a todas | Dropdown exibe `Nenhuma obra ativa`; botão de confirmar desabilitado | N/A |
| Membro inativo | `member.isActive == false` | Botão "Atribuir à obra" desabilitado no `MemberDetalheSheet` | Mantém aviso inline `Ative na construtora primeiro` |
| Resumo dinâmico | Usuário altera obra ou módulos selecionados | Texto do resumo atualiza instantaneamente com nome da obra e módulos ativos | N/A |
| Teclado / Esc | Tecla Esc pressionada no diálogo | Diálogo fecha sem disparar mutação | N/A |
| textScale 1.3 | Escala de texto ampliada para 1.3x | Sem overflow de renderização no dialog ou resumo | N/A |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/obras/data/obra_members_repository.dart` -- **novo**: Repositório com método `setMembership` chamando `FirebaseFunctions.instance.httpsCallable('setMembership')` e provider `obraMembersRepositoryProvider`.
- `app/lib/src/features/construtoras/presentation/widgets/atribuir_obra_dialog.dart` -- **novo**: Diálogo `AtribuirObraDialog` com seleção de obra ativa, checkboxes/chips de módulos (`diario` default), resumo em tempo real e botão de confirmação.
- `app/lib/src/features/construtoras/presentation/member_detalhe_sheet.dart` -- Habilitar o botão `Atribuir à obra` quando o membro estiver ativo (`isActive == true`), abrindo `AtribuirObraDialog.show`.
- `app/lib/src/features/construtoras/presentation/membros_providers.dart` -- Helper para invalidação completa de estado pós-atribuição e lista de obras disponíveis para atribuição (filtrando as já vinculadas ativas).
- `app/test/features/construtoras/membros_test.dart` -- Testes automatizados cobrindo os cenários da matriz de I/O da história 9.1.

## Tasks & Acceptance

**Execution:**
- [x] `app/lib/src/features/obras/data/obra_members_repository.dart` -- criar repositório e provider para chamada segura à Cloud Function `setMembership` -- infraestrutura de dados/mutação.
- [x] `app/lib/src/features/construtoras/presentation/widgets/atribuir_obra_dialog.dart` -- criar widget do diálogo com seleção de obra, módulos padrão `[diario]`, resumo dinâmico e validações -- interface de atribuição.
- [x] `app/lib/src/features/construtoras/presentation/member_detalhe_sheet.dart` -- integrar abertura de `AtribuirObraDialog` ao botão `Atribuir à obra` para membros ativos -- integração do fluxo.
- [x] `app/test/features/construtoras/membros_test.dart` -- adicionar testes de widget para fluxo de atribuição, resumo dinâmico, validação de desabilitação e feedback visual -- cobertura e regressão.

**Acceptance Criteria:**
- Given detalhe de membro ativo na construtora, when toco `Atribuir à obra`, seleciono obra ativa, mantenho `Operário`, módulos default `[diario]`, confirmo, then chama `setMembership{construtoraId, obraId, role: 'operario', modules: ['diario'], isActive: true}` e vejo `Atribuído a {obra} como Operário.` + lista atualiza N obras.
- Given o diálogo de atribuição aberto sem obra selecionada, then botão de confirmar fica desabilitado e o resumo indica a pendência.
- Given membro inativo na construtora, then o botão `Atribuir à obra` permanece desabilitado.

## Implementation Notes

- Criado `ObraMembersRepository` e seu provider `obraMembersRepositoryProvider` para disparar a Cloud Function autoritativa `setMembership`.
- Criado `AtribuirObraDialog` com suporte a seleção de obras ativas (filtrando obras já vinculadas), papel fixo "Operário", seleção de módulos com `[diario]` pré-selecionado, resumo em tempo real e prevenção de overflow via `Wrap`.
- Integrado botão "Atribuir à obra" no `MemberDetalheSheet` apenas para membros ativos (`isActive == true`). Membros inativos mantêm o botão desabilitado.
- Adicionada suíte de testes completa cobrindo todos os cenários da matriz de I/O (HAPPY_PATH, validação de desabilitação sem obra ou sem obras ativas, membro inativo, atualização em tempo real do resumo ao vivo, cancelamento, tratamento de erro do backend e `textScale 1.3`).
- 74 testes executados e aprovados com `flutter analyze` 100% limpo.

## Spec Change Log

## Review Triage Log

- B1 fallback-nome-obra-vazio | verdict: low | evidência: Quando a obra selecionada tiver nome vazio, o fallback garante 'Obra $id' em vez de string vazia na SnackBar. Resolvido com patch imediato.
- B2 fallback-uid-membro-sem-email | verdict: false | evidência: Entidade Membro no Firestore contém apenas email e uid (sem campo nome); fallback para UID quando email vazio está de acordo com o padrão do projeto.
- B3 dialog-dismissible-esc | verdict: low | evidência: showDialog e Dialog do Flutter fecham nativamente via Esc e clique na barreira com Navigator.pop.
- B4 role-operario-invariante | verdict: false | evidência: A UI passa estritamente role: 'operario' para setMembership, respeitando a invariante de não permitir owner em obra.
- B5 invalidacao-completa-providers | verdict: low | evidência: ref.invalidate atualiza membrosProvider, contagemObrasPorMembroProvider, contagemObrasMetaProvider, memberDetalheProvider, obrasVinculadasProvider e obraMembersProvider.
- B6 tipografia-contraste-resumo | verdict: low | evidência: Resumo visual usa Container com surfaceContainerHighest e texto onSurface/primary com tipografia Material 3.
- E1 desmarcar-todos-modulos | verdict: low | evidência: Se todos os módulos forem desmarcados, resumo exibe 'nenhum módulo' e lista vazia é enviada; comportamento esperado.
- E2 dropdown-text-overflow | verdict: low | evidência: DropdownMenuItem usa TextOverflow.ellipsis protegendo nomes extensos de obra.
- E3 obras-ativas-async-error | verdict: low | evidência: Quando obrasAsync entra em erro, exibe mensagem clara e botão de fechar.
- E4 nenhuma-obra-ativa-disponivel | verdict: low | evidência: Quando não há obras ativas não vinculadas, exibe 'Nenhuma obra ativa' e desabilita botão de confirmação.
- E5 prevencao-duplo-submit | verdict: low | evidência: _isSubmitting desabilita botões e seletores enquanto a Cloud Function processa.
- VG1 cobertura-fluxo-happy-path | verdict: low | evidência: Teste de widget cobre abertura, seleção, resumo ao vivo, clique de confirmação e chamada ao repositório.
- VG2 cobertura-erro-backend | verdict: low | evidência: Teste de widget simula falha do repositório e verifica exibição de mensagem de erro sem fechar o diálogo.
- VG3 cobertura-membro-inativo | verdict: low | evidência: Teste de widget valida botão 'Atribuir à obra' desabilitado e presença da microcopy 'Ative na construtora primeiro'.
- VG4 cobertura-textScale-1-3 | verdict: low | evidência: Teste de widget com MediaQuery textScaler 1.3 valida ausência de overflow no diálogo.

**Rejected:** B2, B4 (regras de rejeição: sem defeito real / invariante cumprida).

**Agrupamentos roteados:**
- patch [low] fallback-nome-obra-vazio: B1 (aplicado e validado)
- defer: nenhum

## Design Notes

- Módulos suportados no diálogo:
  - `diario`: rótulo "Diário de Obras" (obrigatório/default)
  - `lotes`: rótulo "Lotes"
  - `estoque`: rótulo "Estoque"
- O resumo dinâmico usa a fórmula: `{Nome/Email} será Operário em {Obra} com acesso a {Módulos}`.
- Ao salvar com sucesso, exibe `SnackBar(content: Text('Atribuído a $obraNome como Operário.'))`.

## Verification

**Commands:**
- `flutter test test/features/construtoras/membros_test.dart` -- expected: All tests pass -- actual: 74/74 All tests passed! (exit code 0)
- `flutter analyze` -- expected: 0 issues found -- actual: No issues found! (exit code 0)
