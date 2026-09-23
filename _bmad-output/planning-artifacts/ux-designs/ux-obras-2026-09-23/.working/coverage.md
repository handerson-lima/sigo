# Pass 1 — cobertura mecânica do rascunho

Não é validação especializada, aprovação do usuário ou conclusão do workflow.

## 1. Fluxos — parcial deliberado

EXPERIENCE Key Flows preserva três nomes do UX de membros com protagonista, passos, clímax e falha. As seis capacidades de ARQ-5 possuem fluxos ilustrativos com nomes exatos e hipótese explícita. Stories 8.1–8.3/9.1–9.2 estão condensadas no Fluxo 1/3; 10.1–10.3 na extensão do Fluxo 2. FR/NFR continuam nas fontes; não há um fluxo separado para cada requisito nem cobertura total do produto. Lacunas: jornada detalhada de cargo/desativação parcial, módulo diário/estoque completo, entrada exata de novas superfícies e navegação global.

## 2. Tokens — conferência estrutural

Cores em hex, typography semântico Material, rounded/spacing dimensionais e components como objeto. Referências apontam aos tokens definidos. Paleta atualizada por pedido do usuário: seed azul extraído, dourado amostrado e azul de ação hipotético; sem dark mode prometido. Metas de contraste e cálculos limitados a pares são explícitos, com limitações de borda e texto disabled. Verificação estrutural automatizada a cargo do agente coordenador, se disponível.

## 3. Componentes — cobertos

14 contratos aparecem nas duas tabelas: ConstrutoraCard, SigoLayout, ActionButton, DataSurface, StatusFeedback, FormField, DetailOverlay, MemberRow, RoleChip, ObraVinculoRow, AtribuirObraDialog, ConfirmDestructiveDialog, EvidenceField, CostSummary. SigoTopBar/SigoSidebar são partes herdadas do shell, não contratos novos. Controles Material internos herdam a biblioteca. Componentes genéricos marcados como hipóteses.

## 4. Estados — cobertos em nível de rascunho

Cada uma das 11 superfícies da matriz IA tem entrada de carga/vazio/foco e falha/offline/permissão na matriz de estados. Estados globais têm regra transversal. Lacunas registradas: elegibilidade offline específica de EPI/ADM/parcelas, recuperação de remoção parcial, resolução final de permission-denied e autorização detalhada de capacidades ARQ-5.

## 5. Referências visuais — cobertura parcial

Após o rascunho fast path, foram geradas duas imagens em `.working/`. O usuário escolheu a direção B expressiva; sua cópia em `mockups/conceito-b-expressivo.png` está vinculada inline nos dois documentos. Seleção de construtora desktop possui referência conceitual raster, sem cobertura completa de estados/interação; demais superfícies e mobile continuam spine-only. Conceito A permanece alternativa histórica, sem orientar os contratos atuais. Não há imports ou wireframes. Documentos seguem in-progress; escolha de direção não aprova conteúdo fictício nem funcionalidades mostradas.

Atualização: seleção de construtora ganhou jornada com protagonista, clímax e falha, componente visual/comportamental e estados. Imagens do logo foram inspecionadas no projeto pelo coordenador, mas não são novos mocks/imports; evidência no extrato de marca.
