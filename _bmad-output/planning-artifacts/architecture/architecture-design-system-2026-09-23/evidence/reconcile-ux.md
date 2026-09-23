# Reconciliação do input UX

Data: 2026-09-23. Revisão documental do draft ARCHITECTURE-SPINE.md contra DESIGN.md, EXPERIENCE.md e HANDOFF.md de `ux-designs/ux-obras-2026-09-23/primeira-entrega`. Nenhum código ou teste executado.

## Achado resolvido

**RUX-1 — Resolvido: coluna única até 800 explícita em AD-3.** DESIGN, “Layout & Spacing”, e EXPERIENCE, “Responsive & Platform”, exigem coluna única até 800 inclusive. AD-3 preserva drawer nesse intervalo, mas a regra da grade diz apenas largura útil e mínimos 320/280. Duas implementações conformes ao texto do AD poderiam usar duas colunas em 700/800, contrariando o input. Acrescentar: “Até 800 inclusive, uma coluna; acima de 800, grade conforme largura útil”. Não altera breakpoint, densidade nem escopo. Verificação posterior da versão atual confirmou em AD-3: “uma coluna obrigatória até 800, além de uma coluna no desktop quando necessário”. A omissão inicial foi corrigida.

## Cobertura confirmada

| Input | Cobertura no draft |
|---|---|
| UX01 marca/tokens e UX11 regressão | AD-2/4/11: fonte Material, tokens semânticos, foco dependente do fundo, regressão antes de tema global |
| UX02 navegação/contexto | AD-3/4: 800/801, sidebar 250/72, rotas/guards/destinos/contexto preservados; sem copiar busca/menu ilustrativo |
| UX03 construtora | AD-1/3/10 + DESIGN normativo: densidade, logo/iniciais, nome preservado, ação independente |
| UX04 lote | AD-1/3/5 + EXPERIENCE normativo: densidade própria, ações independentes, fase/status separados |
| UX05/06 reflow e acessibilidade | AD-3 e matriz: altura intrínseca, alvos 48, reflow do header/seletor/formulários, foco/semântica e dimensões de teste; RUX-1 resolvido |
| UX07/08 feedback e escrita lote | AD-5: evidência por etapa, sem cache como recibo, UUID estável, sem transação/fila/retry automático |
| UX09 logo/permissão | AD-6/7: Dev pelo painel; owner/admin construtora pelo card; exclui autoridade somente de obra, alvo fixo e revalidação |
| UX10 logo/resultado | AD-8/9/10: seleção não publica; commit/recibo autoritativos, timeout sem retry cego, retorno sanitizado se revogado, sem remoção |
| Planejamento separado e preservação | Escopo do documento e fontes preservam UX global e Gestão de Membros; sem implementação |

## Refinamentos técnicos compatíveis

- 5 MB era hipótese de UX. AD-10 explicita 5 MiB/5.242.880 bytes como refinamento proposto, texto futuro e calibração conjunta; não é decisão estética aprovada nem capacidade existente.
- Decoder, 16 MP, 1024×1024, TTL lógico/limpeza e recibos são hipóteses técnicas sinalizadas, não requisitos novos de produto. Não acrescentam remoção, crop obrigatório ou cadastro de empresa.
- O contrato continua remetendo a DESIGN/EXPERIENCE para anatomia, ordem de ações, textos, estados S0–S5, saídas incidentais durante envio e variantes de overlay. Não é necessário duplicar essas tabelas no spine. A spec deve conservar esses contratos ao transformar ADs em tarefas.
- Não há requisito de UX esquecido que justifique ampliar redesenho de membros/vistorias/custos ou criar busca, indicadores ou tema escuro.

Conclusão: cobertura consistente; a ambiguidade concreta de responsividade RUX-1 foi corrigida e verificada na versão atual. Nenhuma omissão ou contradição de UX permanece identificada por esta reconciliação.
