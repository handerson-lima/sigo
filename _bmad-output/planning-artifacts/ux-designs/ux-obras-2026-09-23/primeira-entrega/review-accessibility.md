# Validação de acessibilidade — primeira entrega

Data: 2026-09-23. Revisão documental solicitada pelo usuário, lente de acessibilidade do Reviewer Gate de bmad-ux. Sem alterações nos contratos ou implementação.

## Escopo e limites

Lidos DESIGN.md, EXPERIENCE.md, HANDOFF.md e .working/contrast-refinement.md; inspecionados com view_image os quatro PNGs promovidos em mockups/. Conferidos alvos, reflow, teclado/foco, contraste, estados, formulários e gestão de logo. Os contratos prevalecem sobre os estudos visuais. Novos mocks de formulários não são exigidos: o usuário aceitou as tabelas.

PNG não comprova dimensão lógica de toque, ordem de foco, anúncio assistivo ou reflow a 200%. Não foi executado aplicativo, teste de teclado, leitor de tela ou certificação de conformidade. Metas usadas são as do próprio pacote.

## Achados

| ID | Severidade | Localização | Evidência e consequência | Correção proposta |
|---|---|---|---|---|
| A1 | Média | DESIGN.md, Components/LogoEditor; EXPERIENCE.md, Component Patterns/LogoEditor e J5 | A seleção é confirmada somente por “prévia local” e “confere prévia”. A regra geral de mensagens anunciáveis cobre feedback, mas falta a informação textual que distingue qual arquivo foi selecionado e que ele ainda não foi publicado. Uma implementação pode mostrar apenas uma imagem nova sem permitir a quem usa leitor de tela conferir a seleção antes de Salvar logo. | Especificar texto/nome acessível com nome do arquivo selecionado e estado “Selecionada, ainda não salva”, distinguindo da logo atual. Anunciar a troca de seleção sem roubar foco; manter seleção identificável após erro. Incluir essa observação no aceite de logo/leitor de tela. Não requer reconhecimento do conteúdo da imagem nem descrição manual da marca. |
| A2 | Baixa | .working/contrast-refinement.md, linhas focus-header/focus-header-dark | A tabela chama o dourado de focus-header, embora o token atual colors.focus-header seja branco. O texto de DESIGN.md rejeita corretamente dourado para esse uso; a evidência isolada permanece ambígua e pode induzir cópia do par reprovado. | Renomear as duas linhas douradas como candidato rejeitado; registrar o foco aprovado branco sobre os dois extremos do cabeçalho: 8,63:1 e 5,75:1. |

Nenhum bloqueio estético identificado. A1 é uma lacuna pontual no contrato de seleção já incluído no escopo; A2 é coerência da evidência.

## Evidências satisfatórias e verificação futura

- Alvos mínimos de 48 unidades lógicas estão especificados em ambas as densidades. Altura livre, quebra de nome/fase/ações e mínimos de card limitados à largura disponível evitam exigir o arranjo rígido dos PNGs. A matriz 320/390/800/801/1280/1440 e 100/130/200% cobre os pontos críticos definidos pelo pacote.
- Ações independentes, ausência de botão aninhado, nomes assistivos/contexto do lote, foco visível e restaurado, primeira entrada inválida e mensagens sem roubar foco estão definidos. Material 3 é a base herdada, não precisa ser reespecificado integralmente.
- Pares registrados de status e ação cumprem as metas documentais. Recálculo complementar sRGB opaco: erro #DC2626/branco 4,83:1 e erro/fundo #F8FAFC 4,62:1; texto secundário #475569/branco 7,58:1 e sobre fundo 7,24:1; borda #64748B/fundo 4,55:1. Esses cálculos não medem raster nem estados futuros.
- Os mocks móveis contêm sombras de texto e arranjos laterais apertados; os contratos já exigem removê-las e permitir empilhamento/reflow. Não são novos achados. Busca fictícia e marca provisória também já têm correção explícita.
- Progresso possui indicador e rótulo; falhas têm motivo e entradas preservadas; status é texto/ícone, não cor isolada. Confirmar os anúncios e a operação real de seleção de arquivo, modal, envio e retorno de foco durante a futura implementação, conforme UX06/UX07/UX10.

## Verificação das correções

Verificação focal em 2026-09-23, preservando os achados originais acima. Não constitui nova revisão integral nem teste do aplicativo.

- **A1 — resolvido no planejamento.** DESIGN.md/LogoEditor agora exige nome do arquivo e “Selecionada, ainda não salva”. EXPERIENCE.md/LogoEditor exige anúncio da troca sem roubar foco, S5 mantém prévia identificada em falha e a recuperação distingue arquivo local de publicação. J5 e HANDOFF.md/UX10 incorporam a conferência e o anúncio. A execução assistiva será verificada na implementação.
- **A2 — resolvido.** .working/contrast-refinement.md identifica os dois pares dourados como candidatos rejeitados e registra o foco branco aprovado sobre os extremos azul escuro (8,63:1) e azul claro (5,75:1), consistente com colors.focus-header em DESIGN.md.
