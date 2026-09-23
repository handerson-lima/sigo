# SIGO — Pacote de UX da primeira entrega

Status: pacote de UX consolidado e validado documentalmente; DESIGN.md e EXPERIENCE.md finalizados para esta primeira entrega. Apenas design e planejamento, sem código alterado. Este recorte complementa o planejamento global; não substitui Gestão de Membros.

## Escopo e decisões

| Entrega | Inclui | Limite |
|---|---|---|
| Tema e shell | Paleta expressiva, tipografia forte, espaçamento, foco, navegação atual adaptada | Mesmos destinos/permissões; não redesenhar cada módulo |
| Construtoras | Cards espaçosos, nome, CNPJ existente, logo/iniciais, acesso | Sem busca, KPI ou cadastro novo de empresa |
| Lotes | Cards compactos, fase/status distintos, Atualizar lote e Vistorias | Sem percentual, foto, custo ou nova regra de acesso |
| Formulários de lote | Novo Lote e edição de fase/status com novo visual, reflow e feedback verdadeiro | Sem mudar persistência, criar fila ou prometer atomicidade |
| Logo da construtora | Cadastro e troca confirmados pelo usuário; Dev pelo Painel Dev, Proprietário e admins da construtora | Sem remoção; modelo/storage/autorização ainda precisam de arquitetura |

Contraste da imagem, presença tipográfica e densidade diferenciada são decisões do usuário. Hexadecimais, medidas e formato/limite de arquivo são calibração proposta [ASSUMPTION]. PNG/JPEG até 5 MB e envio online são baseline de UX para viabilização técnica, não capacidades existentes. Não há pendência bloqueante de UX identificada; a viabilidade técnica dos contratos será tratada na arquitetura.

## Referências de execução

- [DESIGN.md](DESIGN.md): tokens, anatomia, responsividade e quatro imagens promovidas.
- [EXPERIENCE.md](EXPERIENCE.md): S0–S5, J0–J5, estados, acessibilidade e política confirmada para logo.
- [Cobertura Pass1](.working/coverage.md) e [reconciliação](.working/reconcile-inputs.md).
- [Evidência de contraste](.working/contrast-refinement.md).
- [Validação consolidada](validation-report.html), [versão Markdown](validation-report.md) e [correções aplicadas](.working/resolution-log.md).

Os quatro mocks ilustram construtoras/lotes desktop/telefone. Novo Lote, Atualizar lote e Gestão da logo serão orientados pelas tabelas, escolha confirmada pelo usuário. Imagens contêm dados fictícios e controles sem escopo: retirar busca, preservar menus reais e substituir texto SIGO pela logo oficial. Restrições detalhadas em DESIGN.md.

## Critérios de aceite para a futura implementação

| ID | Evidência esperada |
|---|---|
| UX01 Marca | Sidebar/cabeçalho/ações correspondem aos tokens; logo oficial sem distorção; dourado separado de status. Texto ≥4,5:1 e controles essenciais ≥3:1 no render final |
| UX02 Herança | Destinos, contexto construtora/obra e visibilidade existentes permanecem; regra de shell ≤800 drawer/>800 sidebar, incluindo limites de 800/801 unidades lógicas |
| UX03 Construtora | Card espaçoso mostra nome completo, CNPJ quando presente e logo/iniciais; ação abre a construtora correta; falha da imagem não remove nome |
| UX04 Lote | Card compacto mostra nome/fase e um dos quatro status legíveis; ações independentes levam à edição/vistorias do lote correto, sem duplo disparo |
| UX05 Reflow | Larguras de 320/390/800/801/1280/1440 unidades lógicas e escala de texto de 100/130/200%; nome com 80 e fase com 60 caracteres sem cortar conteúdo/ações, causar rolagem horizontal ou reduzir alvos abaixo de 48 unidades lógicas |
| UX06 Teclado | Navegação lógica, ações por teclado, foco visível e restaurado ao fechar overlays; sem interação exclusiva de hover; leitor de tela diferencia ações e status |
| UX07 Estados | Cada S0–S5 apresenta estados aplicáveis da matriz; erro não vira vazio, cache não vira sincronizado; formulários mantêm entradas em falha |
| UX08 Gravação lote | Envio não duplica; fase salva/status falhou não exibe sucesso integral; nenhuma nova fila, atomicidade ou retry automático é presumido; saídas incidentais bloqueadas apenas enquanto acompanha o envio, com Fechar disponível ao reconhecer resultado incerto e aviso de que não cancela gravação |
| UX09 Logo/acesso | Dev no Painel Dev, Proprietário e admins da construtora podem gerenciar; demais papéis não recebem ação nem publicação autorizada. Editor mantém nome/CNPJ e alvo estável; revalidar autorização para essa construtora na publicação, inclusive contra admin de outra empresa, não só esconder botão |
| UX10 Logo/resultado | Seleção mostra arquivo e “Selecionada, ainda não salva”, anunciados sem roubar foco. Cancelar antes do envio preserva publicação; durante envio bloqueia saídas incidentais/duplicação. Timeout ou resposta perdida libera Fechar com aviso de operação não cancelada e Verificar logo atual pela fonte autoritativa; imagem antiga em cache não prova falha. Reenvio só após resultado suficiente. Confirmação atualiza card; sem remoção |
| UX11 Regressão | Novo Lote mantém campos e validações atuais; edição mantém fase/status; entrada em Vistorias e demais módulos conserva regras. Aplicação do tema não quebra texto, erro, seleção ou ações das telas herdadas |

Critérios descrevem verificações futuras; não são testes executados. Nenhuma conformidade de interface implementada é declarada.

## Handoff para arquitetura

Winston deve mapear os tokens para o tema e componentes Material, verificar impacto do tema em telas herdadas e definir migração visual. Para logo, definir modelo, armazenamento, autorização dos papéis confirmados, validação segura e confirmação de publicação; preservar logo anterior em falha. Conferir quais resultados de persistência de lote são observáveis para feedback verdadeiro, sem decidir transação por aparência.

Dependências técnicas não resolvidas não justificam inventar API, metadados de cache, permissões ou storage. Se inviabilizarem um critério, registrar impacto e voltar à decisão de escopo antes de implementar. Pendências de membros/custos/épico5 fora do recorte não bloqueiam esta entrega. Próximo passo: arquitetura com Winston via bmad-architecture; depois decompor histórias e planejar a implementação. Nenhuma implementação foi iniciada.
