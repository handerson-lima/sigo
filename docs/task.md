# SIGO — Backlog atualizado

Data: 2026-09-15. Fonte de escopo: [planejamento](implementation_plan.md). Critérios completos: [plano para aprovação](plano-de-correcao-2026-09-15.md).

`[x]` nesta seção de inventário significa código/documento encontrado, não aceite de produção. Todos os pacotes C0–C6 aguardam aprovação e permanecem abertos.

## Inventário do que já existe

- [x] Projeto Flutter com Riverpod/GoRouter e Firebase integrado.
- [x] Login, perfis, painel dev e Functions administrativas.
- [x] Telas e repositórios de construtoras, obras, membros e lotes.
- [x] Almoxarifado central com materiais e movimentações básicas.
- [x] Financeiro básico e marcação de pagamento.
- [x] Diário de obra com fotos e listagem de pendências.
- [x] Atualizar planejamento para preservar dev global e refletir o código.
- [ ] Aceite funcional integrado dos módulos existentes.

## C0 — Validação e inventário

- [ ] Substituir teste de contador por teste útil com providers/dependências isolados.
- [ ] Configurar emuladores e testes de Rules/Functions.
- [ ] Inventariar schemas, claims, devs confiáveis, vínculos, saldos e anexos legados.
- [ ] Preparar simulações de migração e definir versionamento antes da publicação.

## C1 — Autorização com dev preservado

- [ ] Proteger `globalRole` e demais campos de autorização contra autoatribuição.
- [ ] Uniformizar reconhecimento confiável de dev em Rules, Functions e UI.
- [ ] Preservar acesso de dev legítimo antes de migrar fallback por e-mail.
- [ ] Aplicar matriz de perfis, `isActive`, módulos de obra e módulos centrais.
- [ ] Validar descoberta de construtoras/obras, índices e consultas de grupo.
- [ ] Tratar claims antigas/múltiplas construtoras e criação parcial Auth/Firestore.
- [ ] Restringir perfis globais e auditar administração; testar tentativa de elevação.
- [ ] Validar dev sem membership e admin/proprietário dentro da construtora.

## C2 — Arquivos

- [ ] Autorizar Storage por escopo/módulo e preservar exceção dev.
- [ ] Validar caminhos, conteúdo, tamanho e proteção de evidências confirmadas.
- [ ] Migrar leitura/upload para referências privadas com compatibilidade.
- [ ] Inventariar e tratar URLs/tokens legados sem quebrar fotos válidas.
- [ ] Testar isolamento entre construtoras e revogação.

## C3 — Financeiro

- [ ] Aceitar Timestamp, ISO legado e nulo nos campos apropriados.
- [ ] Preservar data civil de vencimento ao padronizar instantes.
- [ ] Migrar valores para centavos com versão e reconciliação.
- [ ] Registrar pagamento idempotente autorizado no servidor.
- [ ] Testar criação, pagamento, reenvio e leitura de documentos antigos/novos.

## C4 — Estoque

- [ ] Implementar Function transacional de movimentação central.
- [ ] Guardar ID/hash/resultado idempotente junto ao saldo e histórico.
- [ ] Validar quantidade, escala, material e destino obra/lote.
- [ ] Reconciliar saldos legados e registrar abertura explícita quando necessário.
- [ ] Migrar quantidades para inteiros com escala.
- [ ] Bloquear alteração direta de saldo/histórico; implementar correção auditada.
- [ ] Testar concorrência, reenvio, payload divergente e destinos indevidos.

## C5 — Diário e Web/PWA offline

- [ ] Persistir blobs e fila IndexedDB antes de confirmar salvamento local.
- [ ] Adaptar fotos web sem depender de arquivos/diretórios nativos.
- [ ] Retomar anexos por IDs estáveis e só concluir operação integralmente.
- [ ] Tratar arquivo ausente como falha; recuperar pendências legadas no dispositivo de origem.
- [ ] Isolar cache/fila por usuário, construtora, obra e módulo.
- [ ] Revalidar autorização, tratar conflitos e suspender retries por revogação.
- [ ] Integrar comandos C3/C4 e separar estimativa local de saldo confirmado.
- [ ] Preservar fila/anexos ao reabrir ou atualizar PWA; validar Chrome/Safari móvel.
- [ ] Testar falha parcial, sessão expirada, quota, duas abas e troca de conta.

## C6 — Aceite e preparação de implantação

- [ ] Resolver nove itens informativos e executar análise, testes e build web.
- [ ] Validar regressão dev e fluxos existentes, incluindo responsividade.
- [ ] Ensaiar migrações e reconciliar saldos, valores, perfis e fotos.
- [ ] Preparar publicação coordenada e recuperação sem reabrir vulnerabilidades.
- [ ] Registrar evidências e atualizar sprint status por aceite.
- [ ] Apresentar implantação de produção separadamente, após resultado revisável.

## Evolução futura — fora de C0–C6

- [ ] Compras/NF multi-itens, fornecedores, rateio e parcelas.
- [ ] Custo médio, snapshots e apropriação financeira por lote.
- [ ] RH individual, equipes, chamada e custo de mão de obra versionado.
- [ ] EPI com catálogo, termos, assinaturas e eventos auditáveis.
- [ ] Qualidade, cronograma, checklists e evidências por etapa.
- [ ] Documentos e visão 360 de lotes.
- [ ] Refinar políticas de custo, evidências, retenção e acesso a dados sensíveis para esses módulos.

Os critérios detalhados antigos permanecem no [arquivo histórico](archive/2026-09-15-planejamento-anterior/README.md); deverão ser adaptados ao modelo atual antes da execução.

## Aceite 0-1

- Aceite 0-1: pendente — D1-D7 transcritos das 3 fontes vigentes de 15/09/2026 para docs/decisoes.md, aguardando aceite final do build em 21/09/2026.

## Change Log

- 2026-09-21: 0-1 pendente de aceite final; diff: docs/decisoes.md novo (7 decisões + Pendências).
