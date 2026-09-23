# Resolução da revisão de arquitetura

Revisão documental; nenhuma implementação, instalação, teste de aplicativo ou implantação.

| Origem | Achado | Resolução |
|---|---|---|
| Reconciliação UX RUX-1 | Grade poderia divergir no telefone | AD-3 exige uma coluna até 800 inclusive |
| Reconciliação código RC-1 | Bootstrap Dev também existe no cliente | AD-7 retira write/fallback do provider e mantém leitura confiável |
| Reconciliação código RC-2 | Cache de bytes não atualiza catálogo | AD-10 atualiza modelo, provider e cache do mesmo ator/tenant |
| Reconciliação código RC-3 | Troca de sessão na primeira chamada | AD-8 e API exigem actorUid esperado comparado à autenticação |
| Rubrica | UUID estável é proposta; executor de coleta indefinido | Hipótese marcada em AD-5; backend com job horário em AD-9 |
| Adversarial A-1 | Crash após gravar candidato bloqueia retry | AD-8 fixa candidato determinístico, verificação e reutilização |
| Adversarial A-2 | Pending vencido sem terminal observável | Endpoints terminalizam vencimento; job cobre abandono |
| Adversarial, integração | Recriação do mesmo tenant | AD-9 proíbe reutilização de IDs e preserva recibos |
| Realidade RC1 | Storage pode exigir três documentos | Staging operação + grant; leitura Dev/membro, ponteiro resolvido no cliente |
| Realidade RC2 | Node 20 perto do descomissionamento | AD-11 propõe Node 22 antes de ativar, condicionado à compatibilidade |

Os limites de imagem e de tempo são hipóteses explícitas, com condição de calibração na spec. Regras, runtime e ambiente são gates da implementação futura; não foram alterados. O pacote de UX e os documentos anteriores permanecem preservados nesta etapa de arquitetura.
