# SIGO — Plano de correções aprovado

Data: 2026-09-15
Status: **implementação de C0–C6 e matriz aprovada pelo usuário em 2026-09-15**
Escopo: estabilização do sistema existente, com implementação e validação em desenvolvimento.

## 1. Decisões e limites

**Confirmado:** manter os privilégios de dev. Não remover o painel nem exigir vínculo por obra para administração global. Proteger a concessão desse papel é parte da correção.

**Aprovado:** manter estoque central por construtora, caminhos e IDs atuais; estabilizar Web/PWA; tornar uniforme a matriz de acesso descrita abaixo. Não recriar o projeto, migrar para outra plataforma ou desenvolver RH/EPI/qualidade nesta rodada.

Não há evidência sobre regras atualmente publicadas, quantidade de dados reais ou identidades dos devs legítimos. O inventário de migração verificará esses pontos sem assumir que todos os documentos com `globalRole=dev` são confiáveis, pois esse campo está vulnerável à autoatribuição.

## 2. Evidências e mudanças de planejamento

| Antes | Planejamento atualizado | Motivo |
|---|---|---|
| Fundação/login ainda no backlog | Reconhecer implementação e exigir validação | Há código funcionalmente estruturado, mas teste padrão falha |
| Proibição de bypass global | Dev global mantido e atribuição protegida | Decisão expressa do usuário |
| `projects`, `active`, `allowedModules` | `construtoras/.../obras`, `isActive`, `modules` | Nomes presentes nos modelos e repositórios |
| Estoque concebido por obra | Preservar estoque central por construtora | Evitar migração estrutural desnecessária |
| Garantias offline descritas como prontas | Funcionalidade parcial; C5 entrega e valida recuperação | Código usa arquivos nativos e ignora anexos ausentes |
| Novos módulos como próxima etapa | Estabilização C0–C6 antes de expansão | Segurança e integridade são dependências dos demais módulos |

Evidências: [regras](../firestore.rules), [Storage](../storage.rules), [Functions](../functions/src/index.ts), [estoque](../app/lib/src/features/almoxarifado/data/almoxarifado_repository.dart), [financeiro](../app/lib/src/features/financeiro/data/financeiro_repository.dart), [diário](../app/lib/src/features/diario/data/diario_repository.dart), [teste atual](../app/test/widget_test.dart).

## 3. Matriz de acesso aprovada

| Perfil | Usuários e vínculos | Dados de obra | Estoque central | Financeiro central | Arquivos |
|---|---|---|---|---|---|
| Dev confiável | Administração global, inclusive papéis via servidor | Acesso global de suporte | Global | Global | Global conforme operação autorizada |
| Admin/proprietário ativo da construtora | Perfis mínimos e vínculos da própria construtora; nunca conceder dev | Todas as obras da construtora | Administrar na construtora | Administrar na construtora | No próprio escopo |
| Admin ativo da obra | Gestão restrita aos vínculos da obra, sem elevar privilégios de construtora | Módulos da própria obra | Só com permissão explícita central | Sem acesso automático | Da obra autorizada |
| Membro ativo comum | Próprio perfil e próprios vínculos | Módulos explicitamente permitidos | Exige módulo central `estoque` | Sem acesso nesta rodada | Conforme módulo e obra |
| Sem autorização | Nenhum acesso operacional | Negado | Negado | Negado | Negado |

A permissão de obra regular exige vínculo ativo na construtora e na obra. Admin/proprietário da construtora e dev são exceções explícitas ao vínculo individual de obra. O campo `modules` proposto no vínculo da construtora controlará módulos centrais para membros comuns; hoje esse campo não existe nesse modelo. Backfill deverá explicitar quem conserva acesso ao estoque, sem concessão geral silenciosa. Nomes dos módulos serão normalizados com mapeamento dos valores encontrados no inventário.

Dev continua podendo administrar e corrigir operações por comandos auditados. Não será necessário liberar gravação direta arbitrária de saldos/histórico para conservar essas capacidades.

## 4. Pacotes de execução

### C0 — Base de validação e inventário

- Substituir o teste do contador por testes de inicialização/roteamento com providers e Firebase isolados.
- Configurar Emulator Suite e testes de Rules/Functions, sem dependência de produção.
- Registrar reprodução dos defeitos e criar cenários de regressão nos pacotes correspondentes.
- Preparar inventário de formatos de datas, quantidades, perfis, claims, URLs, vínculos e documentos legados. Obter a lista confiável de devs com responsável autorizado antes da migração de privilégios.
- Registrar versões de schema e relatório de simulação das migrações. O workspace atual não contém repositório Git; definir versionamento antes de publicar alterações.

**Aceite:** testes úteis executáveis localmente, defeitos reproduzidos sem alterar produção e mapa de compatibilidade pronto para revisão.
**Esforço relativo:** pequeno/médio. **Dependência:** aprovação deste plano.

### C1 — Segurança e preservação dos privilégios de dev

- Impedir criação/alteração de `globalRole`, IDs e outros campos de autorização pelo próprio usuário comum; permitir apenas uma lista explícita de campos pessoais.
- Centralizar validação de dev confiável nas Rules, Functions e UI. Proteger também revogação e promoção feitas por dev; auditoria de ator, alvo e resultado.
- Migrar o fallback de e-mail para UID/papel controlado pelo servidor. Identificar e provisionar devs legítimos, comprovar login e poderes com testes, e somente então retirar o fallback. Não confiar automaticamente em papéis existentes.
- Aplicar matriz acima com `isActive`, `modules`, `isAdmin` e `isOwner` consistentes. Claims antigas não prevalecem sobre vínculo revogado.
- Adequar consultas `collectionGroup` de `members` e `construtora_members`, índices e regras, com leitura restrita aos vínculos permitidos.
- Restringir leitura de perfis globais a dados necessários e autoridades pertinentes.
- Endpoints administrativos validam entradas, escopo e papéis. Resolver a sobrescrita de claims de uma construtora sobre outra e a recuperação de criação parcial Auth/Firestore.
- Uniformizar guarda de rotas e dashboard; dev e admin autorizado não podem ser barrados pela exigência indevida de membership individual.

**Aceite:** usuário comum não vira dev nem admin; acesso por URL/API é negado sem permissão; inativo ou token com claim antigo não acessa dados; dev legítimo cria usuários, gerencia construtoras/vínculos e acessa os escopos previstos sem membership; admin comum nunca concede dev. Testar duas construtoras, duas obras, ausência de campos e consultas de descoberta.
**Esforço relativo:** grande. **Dependência:** C0. **Risco:** bloqueio de contas/consultas durante migração; mitigar por ensaio e verificação prévia do dev de recuperação.

### C2 — Isolamento e integridade de arquivos

- Substituir a regra global de Storage por autorização de construtora/obra/módulo, com exceção dev confiável.
- Validar caminho, tipo e tamanho; impedir troca de IDs e sobrescrita indevida de evidências confirmadas.
- Adaptar upload/download do cliente à nova política; usar referências privadas ou acesso temporário autorizado.
- Inventariar `photoUrls` e tokens de download já emitidos. Mudança de Rules sozinha não é critério suficiente de revogação desses links; testar sua invalidação após migração para referências privadas.
- Registrar anexos por ID estável, integridade e estado, permitindo retomada sem multiplicar arquivos após falha parcial.

**Aceite:** membro de A não lê/escreve arquivos de B; permissão revogada bloqueia novo acesso; dev mantém acesso de suporte; fotos existentes autorizadas continuam acessíveis após conversão; links legados tratados conforme relatório; upload inválido rejeitado.
**Esforço relativo:** médio/grande. **Dependência:** C1 e inventário C0. **Risco:** quebra de fotos existentes; migração em etapas com validação dos objetos antes de invalidar os links antigos.

### C3 — Datas e precisão financeira

- Corrigir desserialização de `dataPagamento`: aceitar ISO legado, Timestamp e nulo, com testes; tratar outros campos de data de forma consistente.
- Definir Timestamp para instantes e contrato explícito de data civil para vencimento, evitando mudança de dia por fuso horário.
- Adicionar `valorEmCentavos` inteiro e versão de schema; converter valores legados por regra decimal documentada. Leitor prioriza o campo novo sem somar ambos.
- Gerar relatório de arredondamentos e totais antes/depois. Valores inválidos vão para revisão, sem conversão silenciosa para zero.
- Registrar pagamento por comando autorizado e idempotente, com timestamps e auditoria; fechar alteração direta dos campos consolidados após atualizar o cliente.

**Aceite:** cadastrar, pagar, recarregar e listar funciona com documentos antigos e novos; datas não mudam indevidamente de dia; totais reconciliam em centavos; repetição de pagamento não reaplica efeito nem altera sua data original.
**Esforço relativo:** médio. **Dependência:** C0 para correção de leitura; C1 para comando e política final.

### C4 — Estoque central confiável

- Mover consolidação para Function transacional. Cliente envia comando com `operationId`, quantidade e destino; servidor calcula e autoriza.
- Escopar idempotência por construtora/ator/operação, armazenando hash do payload e resultado na mesma transação do saldo e histórico. Mesmo ID com conteúdo diferente é rejeitado.
- Validar quantidade positiva/finita, escala, material e pertencimento de obra/lote à construtora. Saída para obra exige obra válida; lote é obrigatório quando a operação declara apropriação ao lote.
- Material novo inicia com saldo zero; saldo inicial legado precisa de reconciliação e evento explícito de abertura, sem inventar movimentações históricas.
- Migrar quantidades para representação inteira com escala explícita; preservar e reconciliar saldo atual. Não inferir custos médios ausentes a partir de dados inexistentes.
- Bloquear gravação direta de saldo e alteração/remoção do histórico confirmado, inclusive por fluxos administrativos; oferecer estorno/ajuste auditado ao dev/admin com motivo e evidência. Impedir reversão duplicada e saldo inválido.
- Manter estoque central: saída da obra A reduz o saldo central compartilhado, mas não altera destino/histórico de B nem dados de outra construtora.

**Aceite:** duas saídas concorrentes não negativam saldo; reenvio após confirmação perdida aplica uma única vez; ID repetido com payload diferente falha; IDs de outra construtora são rejeitados; abertura reconcilia com saldo legado; correção administrativa preserva histórico.
**Esforço relativo:** grande. **Dependência:** C0/C1; C3 para contratos monetários compartilhados.
**Fora deste pacote:** recebimento multi-itens com NF, custo médio completo, parcelamento e apropriação financeira automática. Estes continuam em evolução, sem apresentar o estoque como motor de custos já entregue.

### C5 — Diário, anexos e Web/PWA offline

- Introduzir persistência de bytes/blobs adequada ao navegador; desacoplar o fluxo web de `File`, `putFile` e diretórios nativos.
- Persistir operação e anexos duravelmente antes de confirmar salvamento local, inclusive quando há conexão. Falha de upload não pode deixar apenas caminho temporário.
- Fila IndexedDB particionada por usuário/construtora/obra/módulo; caminhos do dispositivo deixam de ser estado compartilhado no Firestore.
- Estados: `pending`, `syncing`, `synced`, `failed`, `conflict`, `authorization_rejected`. IDs estáveis por operação/anexo; retomar upload parcial e confirmação sem duplicar.
- Arquivo ausente causa falha explícita; nunca é ignorado para marcar sucesso. Backend finaliza somente após validar todos os anexos obrigatórios.
- Revalidar autorização no envio; interromper retry quando acesso é revogado. Preservar pendências isoladas sem exposição a outra conta.
- Migrar pendências legadas somente no dispositivo que possui os arquivos. Outro dispositivo não pode limpar a pendência por não localizar um caminho local. Anexo já perdido deve ser sinalizado para recuperação manual, sem promessa de recuperação automática.
- Implementar retomada ao abrir/reconectar, cache do aplicativo e migração de schema que preserve fila e blobs. Não depender de execução contínua em segundo plano.
- Integrar a fila aos comandos críticos de C3/C4 conforme contrato; saldo local pendente é estimativa, sem efeito oficial até aceite do servidor.

**Aceite:** registrar offline, fechar/reabrir, atualizar PWA com pendências e sincronizar sem perda; simular falha no segundo anexo, Storage indisponível, resposta perdida, sessão expirada, revogação, duas abas e troca de conta; exibir falha honesta para quota excedida/arquivo ausente; validar em Chrome e Safari móvel.
**Esforço relativo:** muito grande. **Dependência:** C1/C2, contratos C3/C4. **Risco:** diferenças de persistência entre navegadores; exigir testes reais e comunicar limitação quando dados locais forem removidos pelo navegador/usuário.

### C6 — Aceite, documentação e implantação preparada

- Executar testes de regras, Functions, repositórios, rotas e fluxos críticos; análise estática e build web.
- Resolver os nove itens informativos e substituir o teste obsoleto; validar interface responsiva dos fluxos alterados.
- Ensaiar migração em ambiente isolado, conferir perfis dev, saldos, totais e referências de fotos.
- Preparar sequência de publicação compatível entre cliente, backend, regras e dados: leitores compatíveis primeiro; provisionamento confiável; migrações verificadas; cliente novo; fechamento das escritas legadas de forma coordenada. Se necessário, janela de manutenção evita clientes antigos incompatíveis.
- Recuperação mantém leitura compatível e pausa comandos afetados. Não restaurar regras vulneráveis como estratégia automática de rollback.
- Atualizar status por evidência e registrar roteiro de aceite manual. Implantação em produção fica fora da aprovação desta proposta e será apresentada com resultado concreto e plano de recuperação.

**Aceite:** todos os critérios de C0–C5 demonstrados, dev preservado, nenhuma divergência não explicada de dados, nenhuma pendência marcada como sincronizada indevidamente.
**Esforço relativo:** médio. **Dependência:** C0–C5.

## 5. Ordem, estimativa e entregas

Ordem sugerida: C0 → C1 → C2 → C3 → C4 → C5 → C6. A correção de datas de C3 pode ser antecipada após C0. Os testes acompanham cada pacote; C6 consolida a regressão, não adia a validação.

Os tamanhos são comparativos, não promessa de prazo. C1/C4/C5 concentram esforço; duração dependerá do inventário e dos dados legados. Cada pacote terá entrega revisável e resultados de validação antes do seguinte. Implementação em andamento; evidências e limitações em `docs/validacao-c0-c6.md`.

## 6. O que esta aprovação autoriza

Aprovar este documento autoriza implementar C0–C6 e a matriz proposta em ambiente de desenvolvimento, mantendo dev global, estoque central e dados existentes. A atualização documental já está concluída.

Migração/publicação de produção será apresentada separadamente com simulação, impactos, devs verificados e recuperação. A identidade confiável dos devs será obtida antes da etapa que depende dela. Novos módulos de negócio permanecem fora do escopo.

**Aprovação recebida:** execução autorizada em desenvolvimento; implantação de produção permanece fora deste escopo.
