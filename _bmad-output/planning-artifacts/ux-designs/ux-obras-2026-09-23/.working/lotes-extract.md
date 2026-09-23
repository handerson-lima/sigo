# Cards de lotes — extração e proposta

Extração local somente leitura, 2026-09-23. Novas decisões são hipóteses para discussão; nenhum código alterado.

## Evidências

- `app/lib/src/features/lotes/domain/lote.dart:5`: quatro status: noPrazo, atrasado, paralisado, concluido. Linhas 13–31: id, construtoraId, obraId, name, phase, status, responsavelId opcional e createdAt. Não há foto, percentual, prazo, área, custo nem nome do responsável nesse modelo.
- `app/lib/src/features/lotes/domain/lote.dart:41`: fases temporárias Plantas, Fundação, Estrutura, Alvenaria, Acabamento e Entregue; fase é texto customizável, não medição de avanço físico.
- `app/lib/src/features/lotes/presentation/lotes_list_screen.dart:20`: Mapa de Lotes dentro de obra, Novo Lote; carga, erro e vazio. Linhas 36–48: grid quadrado com extensão máxima 200 e espaçamento 16. Linhas 60–69: fundo inteiro por status (verde/vermelho/laranja/azul claros).
- `app/lib/src/features/lotes/presentation/lotes_list_screen.dart:76`: tocar abre edição em bottom sheet. Linhas 95–121: nome, fase truncada, ícone Vistorias e status.name literal; nenhum KPI.
- `app/lib/src/features/lotes/presentation/lotes_list_screen.dart:155`: fase e status são gravados sequencialmente. Se fase salvar e status falhar, o resultado pode ser parcial. Linhas 206–261: seletores e Salvar Alterações, mais Vistorias de Qualidade do Lote.
- `app/lib/src/features/lotes/data/lote_repository.dart:17`: lote pertence a construtora/obra. Linha 29: leitura via cachedList; linhas 45–69: criar e atualizar campos diretamente. A interface de lista não recebe metadados de frescor/pendência para declarar sincronização.
- `app/lib/src/features/lotes/presentation/add_lote_screen.dart:37`: cria nome, fase e status; linha 74: identificação aceita texto como Casa 1, sem campos separados de quadra/número.
- `app/lib/src/features/lotes/presentation/obra_lotes_provider.dart:6`: provider recebe escopo construtora/obra.
- `app/lib/src/features/obras/presentation/obra_dashboard_screen.dart:146`: entrada Lotes e Setores; linhas 278–302: resumo da obra agrupa lotes pela fase. Obra é contexto agregador; lote é unidade operacional. Não promover métricas agregadas da obra a atributos do lote.
- `app/lib/src/routing/app_router.dart:424`: rota de vistorias do lote; linha 555: detalhe de custos em módulo próprio. Não há autorização do usuário para inserir custo no card.

## Proposta [ASSUMPTION]

Card claro com faixa curta azul e detalhe dourado de marca; nome/identificação dominante, fase em linha própria e badge textual com ícone para status. Dourado não comunica atraso, paralisação, seleção ou conclusão. Corpo orienta à edição existente, com rótulo Atualizar lote; Vistorias é ação independente e visível. Sem foto obrigatória, logo por lote, barra percentual, cronograma ou responsável sem resolução de nome.

Telefone: coluna única, altura pelo conteúdo, ações de toque separadas. Desktop: grid responsivo de cards mais largos, ordem consistente de informações e rodapé alinhado quando o conteúdo permitir. Nenhuma ação depende de hover. Nome e fase longos refluem. Visual expressivo vem da composição e marca, sem pintar todo o card com status.

Status exibidos: No prazo, Atrasado, Paralisado, Concluído. Ícones propostos: relógio, alerta, pausa e check. Cores semânticas atuais são referência; pares finais precisam validação de contraste e tokens antes do handoff. Fase e status são independentes: Entregue não altera automaticamente status.

## Lacunas

Validar anatomia com usuário; decidir se atualização de fase/status ou consulta de vistorias é a tarefa predominante. Permissões por ação, feedback de cache/sincronização e falhas parciais precisam especificação antes da implementação. Fotografias e métricas não foram solicitadas nem incorporadas. Mock dos lotes ainda não produzido.
