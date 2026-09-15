# SIGO — Sistema Inteligente de Gestão de Obra

Resumo atualizado em 2026-09-15.

## Produto

Plataforma de gestão de construtoras e obras, com interface Flutter voltada ao uso em celular. Organiza obras e lotes, movimentações de materiais, despesas e registros diários do canteiro.

## Base já implementada

- Login, perfis e painel global de desenvolvedor.
- Construtoras, obras, vínculos de usuários e lotes.
- Almoxarifado central por construtora, com entradas e saídas.
- Despesas e registro de pagamento.
- Diário de obra com clima, efetivo por função, observações e fotos.

Esses módulos têm código existente e precisam de estabilização e aceite integrado. O dev continuará com privilégios globais, conforme decisão do usuário.

## Próxima etapa proposta

Proteger atribuição de privilégios, aplicar permissões consistentes, isolar arquivos, corrigir pagamentos, garantir movimentações sem duplicidade e concluir a persistência/sincronização de fotos na Web/PWA. A execução aguarda aprovação do [plano de correções](plano-de-correcao-2026-09-15.md).

## Evolução futura

Compras com notas fiscais e parcelas, custo médio e apropriação por lote, RH e presença, EPI, qualidade e visão 360. Ainda não devem ser apresentados como recursos entregues.

A operação offline confiável é um objetivo em implementação: a fila e a recuperação de anexos precisam ser validadas antes de prometer continuidade completa sem internet.
