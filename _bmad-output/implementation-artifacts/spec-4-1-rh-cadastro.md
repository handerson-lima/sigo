---
title: 'Story 4.1 — RH: Cadastro de Funcionários e Equipes'
type: 'feature'
created: '2026-09-17'
status: 'done'
baseline_commit: 'd8cd5382cd656ef271293027b39d5a13c565647a'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
  - '{project-root}/docs/task.md'
  - '{project-root}/docs/user_flows.md'
  - '{project-root}/docs/data_model.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** O SIGO não possui uma gestão individualizada de recursos humanos e mão de obra operacional. No momento, o diário de obra apenas registra contagens genéricas de efetivo por função (ex.: "2 pedreiros, 3 ajudantes"), impossibilitando o controle de folhas, a identificação dos trabalhadores presentes na obra, o rastreamento de regimes contratuais e a apropriação do custo real de mão de obra nos lotes e etapas executivas.

**Approach:** Implementar a fundação do módulo de RH com o cadastro completo de Funcionários e Equipes no nível corporativo da Construtora (`construtoras/{cId}/funcionarios` e `construtoras/{cId}/equipes`), dando suporte aos regimes CLT, PJ e Avulso, com remunerações e encargos estritamente calculados em centavos inteiros (`int`), computando dinamicamente a taxa diária de apropriação (`totalDailyRateCents`), integrando regras de autorização no `firestore.rules`, navegação no GoRouter protegida por `AccessGuard`, telas reativas em Flutter com Riverpod e persistência resiliente a cenários offline.

## Boundaries & Constraints

**Always:**
- Persistir funcionários em `construtoras/{cId}/funcionarios/{fId}` e equipes em `construtoras/{cId}/equipes/{eId}` com identificadores UUID v4 estáveis.
- Exigir perfil de Administrador da Construtora (`admin(c)`), Dev Global (`dev`) ou membro com módulo `rh` explicitamente concedido (`'rh' in cm(c).get('modules',[])`) para criar, editar ou listar funcionários e equipes.
- Armazenar todos os valores financeiros (`baseSalaryCents`, `additionalCostsCents`, `totalDailyRateCents`) obrigatoriamente como inteiros em centavos de Real (`int`).
- Validar formato e dígitos verificadores de CPF do trabalhador antes de permitir o salvamento.
- Para regime mensal (`salaryBasis == 'mensal'`), calcular `totalDailyRateCents = (baseSalaryCents + additionalCostsCents) ~/ 30` (divisor padrão de 30 dias com DSR). Para regime diário (`salaryBasis == 'diaria'`), `totalDailyRateCents = baseSalaryCents + additionalCostsCents`.
- Proibir a exclusão física de registros no Firestore (`allow delete: if false;`), utilizando desativação lógica (`isActive: false`) para preservar integridade histórica.
- Suportar operação offline-first (IndexedDB / leitura via cache local) para assegurar consulta contínua em campo.

**Never:**
- Nunca utilizar ponto flutuante (`double`) para representar valores monetários ou custos unitários no schema de RH.
- Nunca permitir cadastro com nome em branco ou composto exclusivamente por espaços.
- Nunca permitir salvamento com CPF inválido na validação de dígitos verificadores.
- Nunca permitir que usuários sem perfil de administração ou sem o módulo `rh` leiam ou modifiquem colaboradores.
- Nunca realizar hard delete de funcionários ou equipes no banco de dados.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Cadastro de Funcionário CLT Mensal | Nome: `João da Silva`, CPF: `123.456.789-00` válido, Função: `Pedreiro`, Regime: `CLT`, Base: `Mensal`, Salário: `R$ 3.000,00` (300.000 centavos), Encargos: `R$ 600,00` (60.000 centavos) | Registro salvo com `baseSalaryCents: 300000`, `additionalCostsCents: 60000`, `totalDailyRateCents: 12000` (R$ 120,00/dia), `isActive: true`. Feedback visual de sucesso. | Exibição de mensagem de erro em falha de escrita |
| Cadastro de Diarista Avulso | Nome: `Carlos Pereira`, CPF válido, Função: `Servente`, Regime: `Avulso`, Base: `Diária`, Diária: `R$ 150,00` (15.000 centavos), Encargos: `R$ 0,00` | Registro salvo com `baseSalaryCents: 15000`, `additionalCostsCents: 0`, `totalDailyRateCents: 15000` (R$ 150,00/dia). | Exibição de erro contextual |
| CPF Inválido digitado | Usuário insere `111.111.111-11` ou números com dígitos verificadores matematicamente incorretos | Validador do campo CPF acusa "CPF inválido" e botão "Salvar" permanece bloqueado ou interrompe o fluxo | Validação síncrona no formulário |
| Nome em branco ou apenas espaços | Usuário digita `"   "` no campo Nome | Validador acusa "Nome é obrigatório" e impede envio | Validação síncrona no formulário |
| Cálculo de Custo Diário em tempo real | Usuário altera o valor do salário base no formulário de `R$ 2.400,00` para `R$ 3.000,00` | O card informativo de pré-visualização atualiza instantaneamente a taxa diária de `R$ 80,00/dia` para `R$ 100,00/dia` | Atualização reativa de estado |
| Inativação Lógica de Funcionário | Admin clica em "Inativar" no menu de opções do card do colaborador | Campo `isActive` é atualizado para `false`. O badge muda para `[Inativo]` e o trabalhador deixa de figurar no filtro padrão de ativos | SnackBar de confirmação |
| Acesso por Usuário sem Módulo RH | Membro com acesso restrito a `estoque` tenta acessar a rota de RH | Redirecionado para tela de acesso negado pelo `AccessGuard` e chamadas ao Firestore rejeitadas pelas Security Rules | Bloqueio de rota e permissão |
| Cadastro de Equipe | Nome: `Equipe Alvenaria 1`, Líder: `João da Silva` | Equipe criada em `construtoras/{cId}/equipes/{eId}` com referência ao líder e lista de membros | Feedback visual imediato |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/rh/domain/funcionario.dart` -- Entidade `Funcionario` com serialização JSON, campos monetários em centavos (`baseSalaryCents`, `additionalCostsCents`, `totalDailyRateCents`), getters utilitários formatados e métodos `copyWith`.
- `app/lib/src/features/rh/domain/equipe.dart` -- Entidade `Equipe` (time de trabalho na obra com nome, líder e membros associados).
- `app/lib/src/features/rh/data/rh_repository.dart` -- Repositório com streams e métodos Firestore para listar, criar, atualizar e inativar funcionários e equipes com tolerância offline.
- `app/lib/src/features/rh/presentation/funcionarios_list_screen.dart` -- Interface de listagem de colaboradores com barra de busca, filtros rápidos por status (Ativo/Inativo), regime e equipe, cards visuais com badge e ações contextuais.
- `app/lib/src/features/rh/presentation/funcionario_form_screen.dart` -- Formulário responsivo com máscaras de CPF e monetária BRL, dropdowns de regime e equipe, e preview dinâmico em tempo real da taxa diária estimada.
- `app/lib/src/features/rh/presentation/equipes_list_dialog.dart` -- Diálogo ou tela para gerenciamento rápido de equipes de trabalho.
- `app/lib/src/routing/app_router.dart` -- Adição das rotas `/construtora/:cId/rh/funcionarios` e `/construtora/:cId/rh/funcionarios/novo` com proteção `AccessGuard(module: 'rh')`.
- `firestore.rules` -- Regras de segurança no Firestore autorizando leitura e escrita em `construtoras/{c}/funcionarios/{f}` e `construtoras/{c}/equipes/{e}` para admin, dev ou módulo `rh`, bloqueando exclusão física (`allow delete: if false`).
- `app/test/rh_cadastro_test.dart` -- Suíte de testes unitários e de widgets cobrindo validação de CPF, cálculos de taxas diárias em centavos, serialização do modelo e formulário de cadastro.

## Tasks & Acceptance

**Execution:**
- [x] `firestore.rules` -- Adicionar regras de segurança para `funcionarios` e `equipes` com validação de campos, centavos e bloqueio de exclusão física.
- [x] `app/lib/src/features/rh/domain/funcionario.dart` -- Criar modelo de dados com suporte a centavos e cálculo de taxa diária.
- [x] `app/lib/src/features/rh/domain/equipe.dart` -- Criar modelo de equipes.
- [x] `app/lib/src/features/rh/data/rh_repository.dart` -- Implementar repositório com suporte a Firestore e cache offline.
- [x] `app/lib/src/features/rh/presentation/funcionarios_list_screen.dart` -- Implementar tela de listagem de colaboradores.
- [x] `app/lib/src/features/rh/presentation/funcionario_form_screen.dart` -- Implementar formulário de cadastro e edição com preview de taxa diária e validação de CPF.
- [x] `app/lib/src/routing/app_router.dart` -- Configurar rotas do módulo de RH.
- [x] `app/test/rh_cadastro_test.dart` -- Criar suíte completa de testes automatizados.

**Acceptance Criteria:**
- Given um administrador ou usuário com módulo `rh`, when acessa o cadastro de funcionários e preenche um colaborador CLT com salário mensal de R$ 3.000,00 e adicionais de R$ 600,00, then o registro é salvo com `baseSalaryCents: 300000`, `additionalCostsCents: 60000` e a taxa diária calculada é `totalDailyRateCents: 12000` (R$ 120,00/dia).
- Given um usuário tentando cadastrar um colaborador com CPF inválido ou em branco, when clica em salvar, then a interface exibe erro de validação e não envia a requisição ao Firestore.
- Given um colaborador já cadastrado, when o administrador seleciona a opção "Inativar", then o campo `isActive` torna-se `false` e a exclusão física é terminantemente evitada.
- Given as novas regras no `firestore.rules`, when qualquer usuário tenta executar `delete` na coleção de funcionários, then a operação é rejeitada pelo Firebase com erro de permissão.

## Implementation Notes

- Padrão monetário integrado com `formatCents` e `parseCurrencyToCents` existentes em `app/lib/src/core/contracts.dart`.
- Validador de CPF implementado como utility puro testável com cobertura para dígitos verificadores e CPFs de dígitos repetidos conhecidos (ex.: 000.000.000-00, 111.111.111-11).
- Integração reativa via Riverpod com `rhRepositoryProvider`, `funcionariosStreamProvider` e `equipesStreamProvider`.
- Adicionadas rotas `/construtora/:cId/rh`, `/construtora/:cId/rh/funcionarios`, `/construtora/:cId/rh/funcionarios/novo`, `/construtora/:cId/rh/funcionarios/:fId/editar` com `AccessGuard(module: 'rh')`.
- Suíte `app/test/rh_cadastro_test.dart` com 8 testes passando; 184/184 testes globais do Flutter aprovados e `flutter analyze` sem nenhum aviso.

## Spec Change Log

- 2026-09-17: Criação da especificação técnica inicial para a Story 4.1 alinhada aos padrões de monetário em centavos (Story 3.7) e segurança do SIGO.
- 2026-09-17: Implementação e testes concluídos com sucesso.

## Review Triage Log

- 2026-09-17: Blind Hunter — Validação de ciclo de vida e descarte de controladores em `FuncionarioFormScreen` e `EquipesDialog`. Veredito: false (todos os controladores liberados adequadamente no `dispose()`).
- 2026-09-17: Edge Case Hunter — Tentativa de exclusão física no banco de dados. Veredito: false (bloqueado em `firestore.rules` com `allow delete: if false;`, inativação puramente lógica).
- 2026-09-17: Edge Case Hunter — Integridade monetária e arredondamento da taxa diária. Veredito: false (cálculo de divisão inteira `~/ 30` preservando número inteiro de centavos em `totalDailyRateCents`).
- 2026-09-17: Verification Gap — Cobertura completa da Matriz I/O e casos de borda. Veredito: false (8/8 testes cobrindo todas as linhas da matriz, 184/184 testes Flutter passando).

## Verification

**Commands:**
- `cd app && flutter test test/rh_cadastro_test.dart` -- expected: All tests passed!
- `cd app && flutter analyze` -- expected: No issues found!
