---
route: 'oneshot'
status: 'done'
date: '2026-09-23T17:02:00-03:00'
---

## Intent
<frozen-after-approval>
Modificar o `FuncionarioFormScreen` para aceitar `funcionarioId` (opcional). Na inicialização, a tela usa esse ID para buscar os dados do funcionário no backend/repositório (via lista já carregada ou buscando no provider) e preencher o formulário, resolvendo o erro da rota ao passar o ID do funcionário.
</frozen-after-approval>

## Implementation Notes
- Adicionar `final String? funcionarioId;` no construtor de `FuncionarioFormScreen`.
- No `build` da tela, se `initialFuncionario` for nulo mas `funcionarioId` não, buscar o funcionário da lista fornecida por `funcionariosStreamProvider(construtoraId)`.
- Se a lista estiver carregando, exibir indicador de progresso.
- Ao obter o funcionário, inicializar os controladores de texto apenas uma vez.
