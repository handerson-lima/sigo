# SIGO — Backlog atualizado

Data: 2026-09-22. Fonte de escopo: [planejamento](implementation_plan.md). Critérios completos: [plano de correção](plano-de-correcao-2026-09-15.md).

Os pacotes C0–C6 foram **aprovados e validados em desenvolvimento** com resultado **ACEITO** ([validação C0–C6](validacao-c0-c6.md)). A implantação em produção é assunto **separado**: segue pendente de autorização e é apresentada com simulação, devs verificados e plano de recuperação (ver [preparação de implantação](implantacao-c0-c6.md)). `[x]` nos itens C0–C6 significa critério demonstrado em ambiente de desenvolvimento, **não** deploy de produção.

## Inventário do que já existe

- [x] Projeto Flutter com Riverpod/GoRouter e Firebase integrado.
- [x] Login, perfis, painel dev e Functions administrativas.
- [x] Telas e repositórios de construtoras, obras, membros e lotes.
- [x] Almoxarifado central com materiais e movimentações básicas.
- [x] Financeiro básico e marcação de pagamento.
- [x] Diário de obra com fotos e listagem de pendências.
- [x] Atualizar planejamento para preservar dev global e refletir o código.
- [x] Aceite funcional integrado dos módulos existentes (ACEITO em dev — [validação](validacao-c0-c6.md)).

## C0 — Validação e inventário

- [x] Substituir teste de contador por teste útil com providers/dependências isolados.
- [x] Configurar emuladores e testes de Rules/Functions.
- [x] Inventariar schemas, claims, devs confiáveis, vínculos, saldos e anexos legados.
- [x] Preparar simulações de migração e definir versionamento antes da publicação.

## C1 — Autorização com dev preservado

- [x] Proteger `globalRole` e demais campos de autorização contra autoatribuição.
- [x] Uniformizar reconhecimento confiável de dev em Rules, Functions e UI.
- [x] Preservar acesso de dev legítimo antes de migrar fallback por e-mail.
- [x] Aplicar matriz de perfis, `isActive`, módulos de obra e módulos centrais.
- [x] Validar descoberta de construtoras/obras, índices e consultas de grupo.
- [x] Tratar claims antigas/múltiplas construtoras e criação parcial Auth/Firestore.
- [x] Restringir perfis globais e auditar administração; testar tentativa de elevação.
- [x] Validar dev sem membership e admin/proprietário dentro da construtora.

## C2 — Arquivos

- [x] Autorizar Storage por escopo/módulo e preservar exceção dev.
- [x] Validar caminhos, conteúdo, tamanho e proteção de evidências confirmadas.
- [x] Migrar leitura/upload para referências privadas com compatibilidade.
- [x] Inventariar e tratar URLs/tokens legados sem quebrar fotos válidas.
- [x] Testar isolamento entre construtoras e revogação.

## C3 — Financeiro

- [x] Aceitar Timestamp, ISO legado e nulo nos campos apropriados.
- [x] Preservar data civil de vencimento ao padronizar instantes.
- [x] Migrar valores para centavos com versão e reconciliação.
- [x] Registrar pagamento idempotente autorizado no servidor.
- [x] Testar criação, pagamento, reenvio e leitura de documentos antigos/novos.

## C4 — Estoque

- [x] Implementar Function transacional de movimentação central.
- [x] Guardar ID/hash/resultado idempotente junto ao saldo e histórico.
- [x] Validar quantidade, escala, material e destino obra/lote.
- [x] Reconciliar saldos legados e registrar abertura explícita quando necessário.
- [x] Migrar quantidades para inteiros com escala.
- [x] Bloquear alteração direta de saldo/histórico; implementar correção auditada.
- [x] Testar concorrência, reenvio, payload divergente e destinos indevidos.

## C5 — Diário e Web/PWA offline

- [x] Persistir blobs e fila IndexedDB antes de confirmar salvamento local.
- [x] Adaptar fotos web sem depender de arquivos/diretórios nativos.
- [x] Retomar anexos por IDs estáveis e só concluir operação integralmente.
- [x] Tratar arquivo ausente como falha; recuperar pendências legadas no dispositivo de origem.
- [x] Isolar cache/fila por usuário, construtora, obra e módulo.
- [x] Revalidar autorização, tratar conflitos e suspender retries por revogação.
- [x] Integrar comandos C3/C4 e separar estimativa local de saldo confirmado.
- [x] Preservar fila/anexos ao reabrir ou atualizar PWA; validar Chrome/Safari móvel.
- [x] Testar falha parcial, sessão expirada, quota, duas abas e troca de conta.

## C6 — Aceite e preparação de implantação

- [x] Resolver nove itens informativos e executar análise, testes e build web.
- [x] Validar regressão dev e fluxos existentes, incluindo responsividade.
- [x] Ensaiar migrações e reconciliar saldos, valores, perfis e fotos.
- [x] Preparar publicação coordenada e recuperação sem reabrir vulnerabilidades.
- [x] Registrar evidências e atualizar sprint status por aceite.
- [ ] Apresentar implantação de produção separadamente, após resultado revisável (produção segue pendente de autorização).

## Evolução futura — fora de C0–C6

Já entregues (Epics 4 e 5 — não são mais evolução futura): RH individual, equipes, chamada e custo de mão de obra versionado; EPI com catálogo, termos, assinaturas e eventos auditáveis.

Ainda futuros:

- [ ] Compras/NF multi-itens, fornecedores, rateio e parcelas.
- [ ] Custo médio, snapshots e apropriação financeira por lote.
- [ ] Qualidade, cronograma, checklists e evidências por etapa.
- [ ] Documentos e visão 360 de lotes.
- [ ] Refinar políticas de custo, evidências, retenção e acesso a dados sensíveis para esses módulos.

Os critérios detalhados antigos permanecem no [arquivo histórico](archive/2026-09-15-planejamento-anterior/README.md); deverão ser adaptados ao modelo atual antes da execução.

## Aceite 0-1

- Aceite 0-1: aprovado em 21/09/2026 — D1-D7 transcritos das 3 fontes vigentes de 15/09/2026 para docs/decisoes.md.

## Aceite 0-2

- Aceite 0-2: aprovado em 22/09/2026 — política de acesso e privilégios criada em docs/politica.md, ancorada em D1-D7 e nas fontes de 15/09/2026, sem decisão nova.

## Change Log

- 2026-09-21: 0-1 aprovado (aceite final humano); diff: docs/decisoes.md novo (7 decisões + Pendências).
- 2026-09-22: 0-2 aprovado; diff: docs/politica.md novo (escopo, 5 perfis, regras de privilégio, 3 pendências como bloqueio, limite de produção) + docs/task.md Aceite 0-2.
- 2026-09-22: reconciliação C0–C6 com docs/validacao-c0-c6.md (ACEITO em dev); produção segue pendente; RH/EPI movidos de "Evolução futura" para entregues (Epics 4/5).
