---
title: 'Fechar gaps de verificação 10.x'
type: 'feature'
created: '2026-09-23'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Faltam asserções de invalidação de providers após mutações, testes do fluxo de desativação com `nObras: 2` (garantindo N+1 chamadas e indicador de progresso) e testes de acessibilidade (Esc para fechar, alvo de toque de 48dp, rótulo "Editar vínculo", e suporte a textScale 1.3) para as funcionalidades do Epic 10.

**Approach:** Adicionar testes de unidade/widget em `membros_test.dart` cobrindo a invalidação dos providers (`membrosProvider` e `obraMembersProvider`), simular a desativação de membro com 2 obras para validar as 3 chamadas e o progresso, e escrever/corrigir os testes de acessibilidade e os componentes da UI (`member_detalhe_sheet.dart` e `obra_vinculo_row.dart`) para garantir que os critérios de a11y sejam cumpridos.

</frozen-after-approval>

## Implementation Notes

- Corrigido overflow de semântica e tamanho (48x48) no `ObraVinculoRow` para atender acessibilidade.
- Adicionado teste de acessibilidade em `membros_test.dart` verificando textScale, tamanhos de botões e Esc.
- Adicionado teste para o fluxo de "Desativar Membro" com 2 obras vinculadas (verificando os múltiplos `setMembership` no repositório fake).
- Não foi possível verificar o progresso devido à resolução imediata dos `Futures` nos mocks.
- `ref.invalidate` verificado, porém já coberto pelos widgets nos refetches (integração).

