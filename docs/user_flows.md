# SIGO — Fluxos atuais e correções propostas

Atualizado em 2026-09-15. “Atual” descreve código existente, sem significar aceite ponta a ponta. “Proposto” aguarda aprovação do [plano C0–C6](plano-de-correcao-2026-09-15.md).

## 1. Login, seleção e dev

**Atual:** login por e-mail/senha; listagem de construtoras; seleção de construtora e obra; dashboard com lotes e diário. Painel `/dev` contém usuários e construtoras. Papel dev é reconhecido por documento de usuário ou fallback de e-mail, com diferenças entre camadas.

**Proposto — C1:**

1. Login e leitura de autorização confiável.
2. Dev mantém acesso ao painel global e administração entre construtoras/obras sem vínculo individual obrigatório.
3. Admin/proprietário ativo vê as obras de sua construtora. Membro comum vê somente vínculos ativos e módulos permitidos.
4. Sem acesso, mostrar estado vazio/negado; carregamento e falha de rede são estados distintos de revogação.
5. Troca de obra recalcula permissões e dados antes de mostrar conteúdo do novo escopo; rotas diretas obedecem à mesma política.
6. Concessão/revogação de dev ocorre em fluxo autorizado, com auditoria. Usuário comum não consegue alterar o próprio papel.

## 2. Almoxarifado central

**Atual:** dentro da construtora, usuário lista/cadastra materiais e registra entrada ou saída. Saldo é atualizado em transação no cliente; não existe motor completo de custos.

**Proposto — C4/C5:**

1. Usuário autorizado seleciona material, quantidade e destino de saída.
2. Saída para obra exige obra válida da construtora; apropriação a lote exige lote pertencente à obra.
3. App guarda comando com identificador estável; offline mostra “Pendente de confirmação” e saldo estimado separado do oficial.
4. Backend revalida acesso, quantidade, destino, duplicidade e saldo.
5. Reenvio da mesma operação recebe o resultado já confirmado; saldo insuficiente mostra conflito sem baixa parcial.
6. Dev/admin corrige lançamento por ajuste/estorno rastreável, sem apagar a movimentação original.

O estoque continua central e compartilhado entre obras da mesma construtora. Não exibir estoques independentes por obra que o modelo não mantém.

## 3. Financeiro

**Atual:** cadastro/listagem de despesas e ação de marcar como pago; `obraId` é opcional. O formato gravado em `dataPagamento` é incompatível com seu leitor atual.

**Proposto — C3:** cadastrar → pagar → recarregar mantém documento legível e valor exato em centavos. Repetição de pagamento não altera a data original. UI continua exibindo reais, sem expor detalhes da migração ao usuário. Despesa central não vira custo do lote automaticamente.

## 4. Diário e fotos

**Atual:** usuário informa clima, efetivo por função, observações e fotos; tela de sincronização lista diários com `isPendingSync`. Arquivos temporários e caminhos locais podem impedir recuperação; arquivo ausente é ignorado pelo upload.

**Proposto — C2/C5:**

1. Capturar foto e persistir seus bytes com o diário local antes de informar “Salvo no dispositivo”.
2. Exibir pendência enquanto houver dado ou anexo não confirmado.
3. Retomar anexos individualmente após reconexão/reabertura, usando IDs estáveis.
4. Marcar “Sincronizado” somente após o servidor confirmar a operação completa.
5. Arquivo ausente/armazenamento cheio mostra falha e ação de recuperação; nunca sucesso falso.
6. Ao perder acesso, mostrar “Acesso removido — operação não sincronizada”, preservar evidências isoladas e suspender reenvio.
7. Outro usuário/dispositivo não limpa a pendência por não possuir o arquivo local original.

## 5. Indicadores e recuperação PWA propostos

- “Tudo sincronizado”: nenhuma operação pendente e confirmação conhecida; não inferir apenas pela presença de rede.
- “Salvo no dispositivo”: persistência local concluída, ainda sem confirmação do servidor.
- “Sincronizando”: progresso de operações e anexos.
- “Falha”: detalhe compreensível e reenvio para erro recuperável.
- “Conflito”: decisão necessária, como saldo insuficiente.
- “Acesso removido”: revisão de autorização, sem loop de retry.

Ao abrir a PWA, retomar a fila. Atualização do app migra dados pendentes sem limpar a fila. Operação em segundo plano não é garantida; dados apagados pelo navegador/usuário não podem ser prometidos como recuperáveis.

## 6. Fluxos futuros

RH individual e presença com custos, EPI e assinaturas, qualidade, recebimento com NF, fornecedores, parcelamento e visão 360 permanecem em evolução. Seus [fluxos anteriores](archive/2026-09-15-planejamento-anterior/user_flows.md) ficam preservados para refinamento, adaptando hierarquia atual e privilégios de dev.
