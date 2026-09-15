# SIGO - Sistema Inteligente de Gestão de Obra

## Visão Geral
O nosso sistema é uma plataforma moderna e móvel (desenhada para funcionar diretamente no celular de quem está no canteiro), criada para resolver os maiores gargalos da construção de casas populares: a desconexão entre o que acontece na obra e o controle financeiro do escritório.

A plataforma garante **rastreabilidade, redução de desperdícios e alta confiabilidade nas auditorias**, permitindo a continuidade das principais operações em locais sem internet, com sincronização posterior quando a conexão for restabelecida, através da instalação como PWA (Progressive Web App).

---

## Os 6 Pilares do Sistema (Módulos)

### 1. Gestão por Lote (Visão 360º)
O coração do sistema. O projeto é dividido por "Casas" (Lotes). O gestor tem um painel central onde clica em uma casa específica e vê exatamente quanto ela custou até o momento, quais documentos estão aprovados, quem trabalhou nela e qual a porcentagem de conclusão. 

### 2. Controle de Estoque (Almoxarifado Central)
Acaba com o sumiço de materiais e centraliza o recebimento.
- **Como funciona:** Toda entrada de material (cimento, areia, etc) é registrada no Almoxarifado Central da obra. A saída de material é feita via requisição, destinando as quantidades exatas para cada Lote (Casa).
- **O Diferencial:** Na entrada, o aplicativo exige a foto da nota fiscal e do material, carimbando com GPS e horário. Na saída para o Lote, o sistema calcula automaticamente o custo daquela requisição cruzando a quantidade com o preço médio do material no almoxarifado.

### 3. Gestão Financeira (Contas a Pagar)
Integração perfeita entre quem compra e quem paga.
- **Como funciona:** Quando o recebimento de material é confirmado, o backend gera uma ou mais parcelas da "Conta a Pagar" global, desvinculada de um lote específico.
- **O Diferencial:** O escritório financeiro acompanha os vencimentos, enquanto o sistema ADM mostra separadamente a obrigação global da compra e os custos apropriados a cada Casa conforme os materiais são entregues aos lotes.

### 4. Controle de Qualidade e Cronograma (Validação)
Garante que a obra segue as regras técnicas e está pronta para o financiamento (ex: Caixa Econômica).
- **Como funciona:** Checklists digitais guiam o mestre de obras na inspeção de cada etapa (Fundação, Alvenaria, Cobertura).
- **O Diferencial:** A etapa só é dada como concluída mediante uma foto com carimbo de GPS e Horário, além de uma assinatura digital na tela do celular, criando um histórico íntegro e rastreável para auditorias de bancos e fiscais.

### 5. Gestão de Pessoas (RH)
Controle da folha de pagamento e presença no canteiro.
- **Como funciona:** O mestre de obras faz a "Lista de Chamada" diária pelo celular em segundos. O sistema memoriza em qual Lote (Casa) cada equipe está trabalhando de forma persistente, evitando retrabalho diário, mas permitindo ratear o dia do funcionário em múltiplas casas se necessário.
- **O Diferencial:** O aplicativo calcula o custo real de cada trabalhador (salário base + encargos trabalhistas) e divide essa diária proporcionalmente entre os lotes informados na chamada daquele dia, sem o gestor financeiro precisar fazer contas no Excel.

### 6. Segurança do Trabalho (Controle de EPI)
Protege a empresa contra processos trabalhistas.
- **Como funciona:** Registro digital da entrega de Capacetes, Botas, Luvas, etc.
- **O Diferencial:** **Dupla Confirmação.** O funcionário assina com o dedo diretamente na tela do celular do almoxarife confirmando que recebeu o equipamento novo. O sistema gera um registro digital íntegro e auditável, com identificação, versão do termo e timestamps; sua utilização formal seguirá as políticas jurídica e trabalhista da empresa.

---

## Por que essa solução é diferente?
1. **Feito para o Canteiro (Mobile-First):** Botões grandes, interface limpa e rápida. O mestre de obras não precisa de um computador.
2. **Operação Desconectada:** A obra continua mesmo sem sinal. O app armazena as operações críticas localmente e consolida tudo no servidor assim que o celular reencontrar rede.
3. **Auditoria Georreferenciada:** Nenhuma aprovação ou recebimento de material é feito "no escuro". As fotos registram metadados de *quando* e *onde* as coisas aconteceram, adicionando uma forte camada de transparência baseada nas capacidades de geolocalização do dispositivo.
