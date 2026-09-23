# Extrato complementar — marca e cards

Extração fornecida pelo agente extract_brand; logo inspecionada e amostrada pelo coordenador. Caminhos de código relativos à raiz do projeto.

- app/lib/main.dart:54–55: ColorScheme.fromSeed(seedColor: Colors.blue), Material 3. Seed #2196F3; primary renderizada não extraída.
- sigo_sidebar.dart:146: #0F172A; itens ativos amber[700], fundo amber[900] com alpha .2 (linhas 516–535). sigo_layout.dart:29,58: #F8FAFC.
- Logo sigo_logo_light.png: símbolo dourado tonal e palavra escura; versão dark com palavra branca. Amostra raster opaca frequente #FCA906 (4214 pixels), depois #FCAA06 (3194). Não é cor oficial plana.
- watermark_service.dart:98: #00B4D8, ciano distinto do tema; não presumir que ambos os azuis são intercambiáveis.
- construtoras_list_screen.dart:54–87: grid max 300, aspect 3/2, gaps 16, elevation 4, nome em duas linhas e CNPJ opcional; clique abre /construtora/id; sem logo, papel ou KPIs.
- construtora.dart:8–12: id/name/cnpj/createdAt/isActive; não há propriedade de logo. Inclusão de marca da empresa é proposta com dependências futuras, não capacidade atual.
- Repository: usuário comum recebe memberships ativos, dev lista todas; botão de painel dev é externo ao card. Não presumir gestão de empresa em todos os cards.

Direção confirmada pelo usuário: usar cor da logo + azul do projeto na nova paleta; cards mais interessantes, talvez logo da empresa. Propostas action-blue #1565C0, proporção de cores, fallback por iniciais, composição e fluxo de seleção são hipóteses. Não implementar.
