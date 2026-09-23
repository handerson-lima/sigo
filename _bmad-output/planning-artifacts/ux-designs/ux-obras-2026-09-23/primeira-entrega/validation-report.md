# Validação do pacote UX — SIGO, primeira entrega

Data de geração: 2026-09-23T17:20:55-03:00

O pacote delimita a primeira entrega e oferece contrato de UX para arquitetura. A validação identificou sete achados: um alto, quatro médios e dois baixos; nenhum crítico. R1 e L1 tratam de aspectos do mesmo problema e foram mantidos nos relatórios de origem.

As sete correções foram incorporadas e rastreadas em .working/resolution-log.md. Os revisores de acessibilidade e permissões verificaram seus ajustes; o coordenador conferiu R1/R2. Os vereditos abaixo preservam o resultado da revisão inicial, sem atribuir retrospectivamente nova nota. Revisão documental e cálculos de pares de cores não substituem testes da implementação.

## Contratos

- [DESIGN.md](DESIGN.md)
- [EXPERIENCE.md](EXPERIENCE.md)
- [HANDOFF.md](HANDOFF.md)

## Categorias — revisão inicial

- **Cobertura de fluxos: strong.** S0–S5 e J0–J5 cobrem o recorte, com protagonistas, passos, resultado e falhas.
- **Completude de tokens: strong.** Cores, tipografia, medidas e componentes definidos; caminhos de tokens resolvidos.
- **Cobertura de componentes: strong.** Nove componentes têm contrato visual e comportamental correspondente.
- **Cobertura de estados: adequate.** Achado inicial R1: saída durante gravação precisava de regra explícita; política corrigida em EXPERIENCE.
- **Referências visuais: strong.** Quatro mocks e duas variantes oficiais da logo vinculados; tabelas de formulários aceitas pelo usuário.
- **Concisão e especificação: strong.** Escopo delimitado e documentos complementares, sem desenho prematuro de infraestrutura.
- **Disciplina de herança: adequate.** Achado inicial R2: margem por lado versus total era ambígua; texto corrigido, mantendo breakpoint existente.
- **Estrutura: strong.** Seções canônicas presentes; critérios e encaminhamento mantidos em HANDOFF.

## Achados e resolução

Todos os itens abaixo têm correção documental aplicada; evidência detalhada no [registro de resolução](.working/resolution-log.md).

### Altos (1)

**L1 — Cancelamento durante envio (Permissões/erros)**
Local: EXPERIENCE — Saída durante envio e confirmação incerta; HANDOFF UX10. Correção aplicada: Distinguir seleção local, envio acompanhado, falha comprovada e resultado incerto. Fechar depois de resultado incerto não cancela publicação.

### Médios (4)

**R1 — Saída durante gravação (Contrato)**
Local: EXPERIENCE — S3/S4/S5 e política de saída; HANDOFF UX08/UX10. Correção aplicada: Definir Esc/voltar/barreira/arraste, bloqueio transitório e saída após perda de acompanhamento; sem promessa de rollback.

**A1 — Identificação acessível da seleção (Acessibilidade)**
Local: DESIGN — LogoEditor; EXPERIENCE — LogoEditor/J5; HANDOFF UX10. Correção aplicada: Exibir nome de arquivo e Selecionada, ainda não salva; anunciar sem roubar foco.

**L2 — Recuperação de resultado incerto (Permissões/erros)**
Local: EXPERIENCE — Verificar logo atual; HANDOFF UX10. Correção aplicada: Consultar estado publicado autoritativo, não cache; manter incerteza quando necessário e impedir reenvio da tentativa ainda desconhecida.

**L3 — Identidade da construtora alvo (Permissões/erros)**
Local: DESIGN — LogoEditor; EXPERIENCE — Logo operacional; HANDOFF UX09. Correção aplicada: Mostrar nome/CNPJ, manter alvo estável e revalidar autorização para a mesma construtora.

### Baixos (2)

**R2 — Margens ambíguas (Contrato)**
Local: DESIGN — Layout & Spacing. Correção aplicada: Definir 16/32 unidades lógicas por lado, sem duplicar padding do shell e da tela.

**A2 — Evidência de foco do cabeçalho (Acessibilidade)**
Local:  .working/contrast-refinement.md. Correção aplicada: Marcar dourado como candidato rejeitado para cabeçalho; registrar branco aprovado sobre os dois extremos.

## Relatórios e limites

- [Contrato: oito categorias](review-rubric.md)
- [Acessibilidade](review-accessibility.md)
- [Permissões e erros da logo](review-logo-permissions.md)
- [Polimento editorial](.working/editorial-review.md)

A arquitetura deve viabilizar persistência de logo, autorização na gravação, consulta autoritativa e observabilidade dos resultados. Isso é dependência de implementação, não infraestrutura já existente. Conteúdo dos mocks é ilustrativo e os contratos prevalecem. Não foi executado aplicativo, leitor de tela ou teste funcional nesta rodada.
