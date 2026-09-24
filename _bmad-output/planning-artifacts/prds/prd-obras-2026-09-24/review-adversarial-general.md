# Revisão Adversarial — PRD: SIGO Obras

**Artefato:** `prd.md` + `addendum.md` (prd-obras-2026-09-24)
**Revisor:** adversarial general
**Veredito:** o documento é competente como *catálogo de estado* do brownfield e fraco como *PRD*. Ele descreve o que já existe com precisão incomum, mas quase não define requisitos que um time a jusante possa construir e verificar. A maior parte do risco não está no que falta — está no que o texto afirma sem poder sustentar.

---

## Risco único mais grave para o time a jusante

**[CRITICAL] A raiz canônica da estrutura é ambígua (Loteamento vs. Obra) e está explicitamente em aberto, mas UX, arquitetura e histórias dependem dela como espinha dorsal.**
Local: §3 Glossário linhas 147–153; §4.3 FR-17–FR-20; addendum §3 (linhas 35–46); §9 OQ-1 (linha 719).

O Glossário decreta que "Obra" foi "consolidado na raiz (**Loteamento**) da Hierarquia Estrutural" (linha 153), mas o addendum ainda modela os módulos em `construtoras/{cId}/obras/{oId}/...` (diário, chamada, members) **e** em paralelo `.../loteamentos/{lId}/quadras/{qId}/lotes/...` (addendum linhas 35–46). O próprio PRD admite em OQ-1 que a migração dos vínculos por obra para nós da árvore está em aberto (linha 719). Não existe, portanto, resposta para: onde um vínculo "da obra X" mora? O drill-down (FR-17–20) navega Loteamento→…→Equipe, mas diário/chamada/financeiro ainda pertencem a `obras/{oId}`. O time de UX não sabe qual é a tela raiz; a arquitetura não sabe qual árvore é a autoritativa; as histórias de "atribuir operário" (FR-31) e "atribuir equipe" (FR-96) não sabem contra qual coleção escrever. Se downstream escolher a raiz errada, o retrabalho é total. Este não é um detalhe de implementação — é a decisão de produto mais estrutural do PRD e ela está deferida.

---

## Findings

### Escopo e natureza do documento

**[CRITICAL] O "MVP" já está construído; o PRD não deixa trabalho construível para histórias.**
Local: §0 linha 17; §6 linha 651; §6.1 linhas 653–670; §6.2 linhas 672–680.
O §6 afirma que "os módulos abaixo têm código implementado e validado em desenvolvimento" e §6.1 lista 15 áreas de produto (praticamente o produto inteiro) como "In Scope". Se tudo já existe e está validado, o que se espera que o time de stories *implemente*? O que sobra — implantação, testes offline, responsividade — está em §6.2 Out of Scope. Um PRD cujo escopo in-scope é "o que já foi feito" e cujo in-scope real é out-of-scope não direciona nenhuma história de valor. O documento precisa decidir: é *baseline de comportamento congelado* (então não é PRD de MVP) ou é *especificação de trabalho novo* (então o in-scope precisa ser o delta, não o inventário).

**[HIGH] "Brownfield" é usado como escudo para não priorizar.**
Local: §6 linhas 649–651; §5 linhas 634–647.
A narrativa brownfield justifica listar 11 módulos como um único MVP, mas nenhum critério de priorização, sequenciamento ou corte real é oferecido. §5 (Non-Goals) e §6.2 (Out of Scope) misturam categoriais distintas — visão de produto ("não é portal do comprador") com dívida de lançamento ("implantação não autorizada") com evolução ("custo médio"). O leitor não consegue distinguir o que o produto *rejeita por identidade*, o que *falta por bloqueio* e o que *ficou para depois*.

**[MEDIUM] Título ainda não confirmado e status "draft" enquanto se autoproclama fonte única.**
Local: linhas 2–9.
"*Working title — confirm.*" e `status: draft`, apesar de §0 declarar que o PRD "consolida, em uma única fonte de requisitos de produto". Fonte única de verdade que ainda não sabe o próprio nome não inspira congelamento.

### Métricas de sucesso

**[CRITICAL] As métricas medem ausência de defeito e higiene de engenharia, não valor de produto.**
Local: §7 linhas 686–702.
SM-1 ("zero operação declarada sincronizada sem aceite"), SM-2 ("zero divergência de centavos"), SM-3 ("100% dos vínculos gravados por função") e SM-7 ("cobertura de testes e `flutter analyze` limpo") são gates de teste e conformidade cumpridos por construção — não outcomes de negócio. Nenhuma métrica responde "a construtora perdeu menos material?", "o custo por lote passou a bater com a realidade?", "quantos pagamentos duplicados foram evitados?", "qual a redução de retrabalho de qualidade?". São anti-métricas apresentadas como métricas primárias.

**[HIGH] Nenhuma métrica tem linha de base, meta numérica, janela de medição ou instrumentação.**
Local: §7 linhas 686–702.
SM-5 "Adoção de campo" sem % alvo nem período; SM-6 "Tempo para fechar a chamada" sem valor de partida nem alvo de redução. Sem baseline e meta, nenhuma delas é avaliável; são declarações de intenção.

**[MEDIUM] As "counter-metrics" repetem princípios em vez de medir trade-offs.**
Local: §7 linhas 698–702.
SM-C1 ("número de telas") e SM-C3 ("redução de fricção") não têm instrumentação nem definição operacional. São slogans ("não otimizar amplitude", "não abrir atalhos") travestidos de contrapeso. Contrapeso sem número não contrapesa nada.

**[MEDIUM] Cobertura de rastreio de métricas é parcial e assimétrica.**
Local: §7 linhas 686–702.
SM-5 valida só FR-54/FR-62; SM-7 valida "todos os FRs de módulo" vagamente. EPI (FR-67–70), Validação (FR-71–74), Fornecedores (FR-75–78) e grande parte de Compras não têm métrica alguma. Metade do produto não tem como ser considerada bem-sucedida.

### Personas e jornadas

**[HIGH] As personas não dirigem decisão e são inconsistentes entre §2.1, §2.3 e os FRs.**
Local: §2.1 linhas 31–42; §2.3 linhas 56–133.
§2.3 admite que "Personas são cenários de aceite, não pesquisa de usuário" — o que levanta a pergunta: por que doze "jobs"? Pior: os protagonistas das jornadas não existem em §2.1. Ana (UJ-3, UJ-10), Davi (UJ-5), Marcos (UJ-6), Rita (UJ-7) e Paulo (UJ-11) nunca aparecem na lista de JTBD. A lista mistura perfis de autorização (Dev, Owner, Admin) com ofícios operacionais (Almoxarife, Encarregado) sem critério. Se as personas não mudam nenhum FR nem nenhum NFR de forma rastreável, são decoração.

**[MEDIUM] "Funcionário/colaborador" aparece sob "Jobs To Be Done" mas é declarado não-usuário.**
Local: §2.1 linha 42.
Um item que "não é usuário operacional do sistema" não tem um job to be done. Isso é preenchimento.

**[MEDIUM] Non-Users é majoritariamente óbvio ou redundante com segurança.**
Local: §2.2 linhas 44–50.
"Usuário anônimo / não autenticado — nenhum acesso operacional" é apenas a definição de autenticação, já coberta por FR-1/FR-5. "Cliente final", "Corretor" e "Órgãos externos" reafirmam §5. Non-users só têm valor quando uma decisão próxima poderia pender para incluí-los; aqui listam-se exclusões que ninguém disputaria.

### Testabilidade dos requisitos

**[CRITICAL] Grande parte dos FRs não tem consequência testável; usam "Realiza UJ-N" no lugar de aceite.**
Local: §4 inteiro — ex.: FR-1 (183–188), FR-12 (228–229), FR-17 (249–254), FR-21 (279–280), FR-22 (282–283), FR-31 (329–334), FR-32 (337), FR-62 (486–487), FR-70 (521–522), FR-85 (594–595).
"Membro comum não vê a ação de criação" (FR-22) e "pendências visíveis antes de fiscalização" (FR-70) não são verificáveis sem critério. Vários FRs simplesmente não têm o bloco "Consequences (testable)" — são afirmações. Um PRD cujo critério de aceite é uma referência narrativa a uma jornada não pode alimentar QA nem stories de forma não ambígua.

**[HIGH] Consequências "testáveis" que não são testáveis.**
Local: FR-2 (191), FR-3 (194), FR-5 (200), FR-26 (304 "metadados nocivos removidos" — quais?), FR-60 (481 "divisor configurável" — qual default?), FR-98 (467 "quando disponível" — critério de fallback?). Termos como "uniforme", "nocivo" e "quando disponível" não geram casos de teste.

**[MEDIUM] Requisitos circulares ou autocontidos.**
Local: FR-43 (385) "informando obra e, quando houver apropriação, lote obrigatório" + consequência "Saída sem apropriação é permitida" — a condição e a exceção descrevem a mesma coisa, sem definir o gatilho de "haver apropriação". FR-25 (296 "status nunca por cor isolada") é critério de UX embutido em FR funcional.

### Contradições internas e escopo que está dentro e fora ao mesmo tempo

**[HIGH] Offline é promessa central da visão, mas seu testar está fora do MVP e a abrangência da fila contradiz o addendum.**
Local: §1 linha 23; §4.15 FR-91 (621); §6.2 linha 675; addendum §5 (69–76) e §7 C5 (96).
FR-91 afirma que operações offline críticas incluem "diário, estoque, chamada, financeiro", mas o addendum §5 e o C5 descrevem a fila como escopo de "diário, anexos e PWA offline". Enquanto isso, os "Testes offline e de integridade (Epic 6)" estão explicitamente fora do MVP (§6.2). O compromisso "o offline nunca mente" (linha 23) fica simultaneamente in-scope como requisito e out-of-scope como verificação — e com dois escopos de fila conflitantes.

**[HIGH] FR-91 (financeiro offline) contradiz FR-39 (escrita de vínculo exige rede) e a ausência de offline em §4.7.**
Local: FR-39 linha 358; FR-91 linha 621.
Se a fila cobre "financeiro", por que §4.7 (Financeiro) não menciona offline e FR-51 exige "data do servidor"? A contradição não é fatal, mas revela que FR-91 foi escrito por agregação, não por desenho.

**[MEDIUM] Non-goal "não gera contas a pagar automaticamente" convive com um módulo de Compras/NF com parcelas e liquidação.**
Local: §5 linha 640; §4.13 FR-79–FR-84; §4.7.
A linha entre "registrar NF e liquidar parcelas" (implementado) e "gerar contas a pagar automaticamente" (non-goal) nunca é traçada. O leitor não sabe se compõe passivo ou não.

**[MEDIUM] FR-99 (custo apropriado na saída) vs. FR-43 (saída sem apropriação permitida) vs. Visão 360 "custo real por lote".**
Local: FR-43 linha 389; FR-99 linha 409; FR-85 linha 595.
Se saídas sem lote são permitidas e não há lote, o custo real por lote fica estruturalmente incompleto, mas §4.14 promete consolidação completa. Não há regra de como o material não apropriado aparece (ou não) na Visão 360.

### Fronteira PRD/addendum e "furniture"

**[HIGH] O PRD viola a própria regra de não carregar detalhe técnico; duplica o addendum.**
Local: §0 linha 15 ("não deve migrar para cá"); §4.15 FR-90–94 (IndexedDB, lease multi-aba, Service Worker); FR-44 (392 `operationId`); FR-98 (467 carimbo nos bytes); §4.3 NFR (271 "rotas compostas por feature via spread no roteador modular"); §11 (738–743) que reproduz addendum §9.
Duas fontes de verdade para o mesmo conteúdo garantem drift. FRs que prescrevem mecanismo (IndexedDB, lease) amarram a arquitetura antes de a arquitetura decidir — o oposto do que §0 promete.

**[LOW] Numeração global de FRs é não sequencial e sinaliza montagem.**
Local: FR-95 (268), FR-96 (363), FR-97 (309), FR-99 (408), FR-100 (501), FR-101 (469).
FRs novos inseridos após seções fechadas sugerem reconciliação tardia; referências cruzadas ("FR-97") ficam frágeis.

**[MEDIUM] As jornadas UJ carregam detalhe de UI que pertence a UX, não ao PRD.**
Local: UJ-1 (60 "snackbar 'Atribuído a {obra} como Operário.'"), UJ-3 (77), UJ-9 (118).
Textos exatos de snackbar, contadores "N nós" e comportamento de F5 são especificação de UX (que o §0 diz já existir) copiada para o PRD. Isso cria uma segunda fonte de verdade de UX e convida conflito com `EXPERIENCE.md`.

### Rastreabilidade, evidência e números

**[MEDIUM] Números apresentados como requisito sem fonte canônica.**
Local: FR-67 (513 "30 dias"), FR-13 (232 "TTL de 7 dias"), addendum §12 (144 "10 MB comprovantes; 2 MiB logo"), OQ-2 (720).
O PRD marca o limite de logo como `[ASSUMPTION]` (2 MiB) enquanto a própria OQ-2 admite divergência entre contrato e UX. Apresentar como requisito um valor que o documento reconhece como não resolvido é o inverso de rigor.

**[HIGH] Afirmações de segurança/confiança não sustentadas por evidência.**
Local: §1 linhas 23–25 ("a fronteira nunca vazar", "dinheiro e histórico exatos e imutáveis"); §8 linha 710; §9 OQ-5 (723), OQ-7 (725).
Não há teste de isolamento multi-tenant, pentest, nem resolução de LGPD (OQ-5 aberta); as regras de produção não estão publicadas (OQ-7). O PRD afirma como propriedade do produto o que é apenas intenção de arquitetura. "Nunca vazar" não é verificável pelo consumidor do PRD.

**[MEDIUM] A "Nota de rigor" promete registrar divergências, mas as divergências críticas estão em OQ e as afirmações conflitantes permanecem no corpo.**
Local: §0 linhas 16–17; §9.
A promessa de não silenciar divergências é boa, mas o corpo continua declarando "consolidado"/"canônico" em pontos que as OQs contradizem (raiz da hierarquia, limite de logo).

---

## Resumo por severidade

- **Critical:** 5 — raiz Loteamento/Obra em aberto; MVP já construído sem delta construível; FRs sem consequência testável; métricas de conformidade como primárias.
- **High:** 9 — personas sem lastro; offline dentro/fora; PRD invade addendum; segurança afirmada sem evidência; frases não testáveis; abrangência de fila contraditória; etc.
- **Medium:** 8.
- **Low:** 1.
