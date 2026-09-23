# Revisão editorial — estrutura e redação

Executada por bmad-review, lentes structure e prose, conforme doc_standards do bmad-ux. Público: responsáveis pelo produto, arquitetura e desenvolvimento. Conteúdo: DESIGN.md, EXPERIENCE.md e HANDOFF.md.

## Estrutura

Modelo de referência para os contratos e modelo estratégico para o encaminhamento. Nenhuma alteração estrutural necessária. Preservar ordem canônica, distinção entre decisões/herança/propostas, matrizes de estados, jornadas e critérios de aceite.

Contagens exatas do snapshot antes das correções, obtidas por word_metrics.py: DESIGN 1.623; EXPERIENCE 2.066; HANDOFF 727; total 4.416 palavras. Redução estrutural proposta: zero.

## Redação

| ID | Local | Ajuste aceito |
|---|---|---|
| E1 | EXPERIENCE, arquitetura de informação | Substituir Spine-only por descrição explícita de especificação em tabelas sem imagem própria |
| E2 | HANDOFF, UX05 | Identificar larguras e unidades lógicas, escala de texto, comprimentos de nome/fase e tamanho dos alvos |
| E3 | EXPERIENCE, responsividade | Separar Até 800/acima de 800 e explicitar largura lógica |
| E4 | DESIGN, componentes | Separar largura máxima proposta de 640 e padding de 24 |
| E5 | EXPERIENCE/HANDOFF, limites | Explicitar alvo mínimo de 48 unidades lógicas, PNG/JPEG de até 5 MB e limites de 800/801 |

São correções de clareza; não mudam escopo ou decisões de produto. Ver .working/resolution-log.md para as correções da validação de UX.
