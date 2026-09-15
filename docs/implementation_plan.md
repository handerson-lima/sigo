# SIGO — Planejamento atualizado

Atualizado em 2026-09-15 a partir do código local e da análise técnica. **A atualização documental foi solicitada; a execução das correções aguarda aprovação do usuário.**

## 1. Direção do produto

Sistema de gestão de construtoras e suas obras, com lotes, almoxarifado central, financeiro e diário de obra. A prioridade desta etapa é estabilizar os módulos existentes. RH, EPI, qualidade, compras integradas e visão completa de custos permanecem no backlog de evolução.

**Decisão confirmada pelo usuário:** manter os privilégios globais de dev. A correção de segurança protegerá a atribuição e revogação desse papel, preservando a capacidade administrativa do desenvolvedor.

## 2. Estado observado

| Área | Implementação encontrada | Situação |
|---|---|---|
| Base Flutter | Riverpod, GoRouter, organização por funcionalidade | Implementada; nove ocorrências informativas na análise |
| Login e perfis | Firebase Auth e documentos `users` | Implementados; papel privilegiado editável pelo próprio usuário |
| Painel dev | Usuários, construtoras, vínculos e criação de usuários via Function | Implementado; autorização precisa ser unificada |
| Construtoras/obras/lotes | Telas, repositórios e modelos | Implementados; permissões e consultas precisam de testes |
| Almoxarifado | Materiais por construtora, entradas e saídas em transação no cliente | Parcial; sem idempotência, consolidação confiável de custos ou histórico protegido |
| Financeiro | Despesas por construtora, vínculo opcional à obra, marcação de pagamento | Parcial; incompatibilidade de datas e valores em `double` |
| Diário de obra | Clima, efetivo por função, observações, fotos, tela de pendências | Parcial; risco de perda de fotos e dependência de APIs de arquivo nativas |
| Web/PWA offline | Estrutura web e manifesto; tentativa de sincronização do diário | Fila durável no navegador e recuperação ponta a ponta não demonstradas |
| Backend | Functions `setConstrutoraRole` e `adminCreateUser` | Sem comandos transacionais de estoque/financeiro |
| Testes | Um teste de contador padrão | Falha; não cobre o produto |

Implementado significa presença de código, não aceite funcional ou confirmação de implantação em produção.

## 3. Arquitetura de referência

- Flutter/Dart, Riverpod e GoRouter permanecem.
- Firebase Auth, Firestore, Storage e Cloud Functions permanecem. Usar Functions existentes como base do backend; não introduzir Cloud Run nesta correção.
- Hierarquia atual: `construtoras/{cId}/obras/{oId}`. Preservar IDs e caminhos existentes.
- Almoxarifado central em `construtoras/{cId}/materiais`; saídas identificam a obra e, quando aplicável, o lote de destino. Não migrar o saldo central para estoques por obra nesta etapa.
- Despesas em `construtoras/{cId}/despesas`, com obra opcional. Compra central e custo apropriado ao lote são conceitos distintos.
- Web/PWA mobile-first continua como alvo do planejamento. As pastas Android/iOS existentes não comprovam suporte nativo validado e serão preservadas; a correção não exige sua remoção.
- Modelo atual e migrações propostas: [data_model.md](data_model.md).

## 4. Autorização proposta, preservando dev

O perfil dev continua global, sem exigir vínculo individual em cada construtora/obra para administração. Atualmente esse acesso está distribuído de forma inconsistente entre regras, Functions e UI. O pacote C1 propõe uma política única e cobertura de regressão.

| Perfil | Escopo proposto |
|---|---|
| Dev autorizado | Administração global de usuários, construtoras, vínculos e acesso operacional de suporte entre obras; alterações críticas auditadas |
| Admin/proprietário ativo da construtora | Administração e módulos da própria construtora e suas obras |
| Admin ativo da obra | Administração operacional da própria obra; sem poderes globais ou acesso automático ao financeiro central |
| Membro comum | Vínculos ativos e módulos explícitos no escopo correspondente |
| Não autenticado ou sem autorização vigente | Sem dados operacionais |

Detalhes novos desta matriz estão **propostos para aprovação**, não descritos como já implementados. O acesso de dev dispensa vínculos, mas preserva validações de saldo, idempotência e rastreabilidade das operações.

A definição autoritativa de `globalRole` será mantida no servidor; o usuário comum poderá editar apenas campos pessoais permitidos. A migração da identificação legada por e-mail para identidade confiável deverá preservar e testar o acesso dos devs legítimos antes da retirada do fallback. Claims antigas não poderão reativar um vínculo revogado.

## 5. Sequência proposta

1. **C0 — Base de validação:** testes úteis, emuladores, inventário de compatibilidade e critérios de aceite.
2. **C1 — Autorização:** proteger papel dev; uniformizar vínculo ativo, módulos, consultas e administração.
3. **C2 — Arquivos:** isolar Storage e adaptar leitura/upload à política de autorização.
4. **C3 — Financeiro:** corrigir datas e migrar valores monetários com reconciliação.
5. **C4 — Estoque:** comandos no servidor, idempotência, histórico e preservação de saldos existentes.
6. **C5 — Diário e PWA:** persistência durável de anexos e fila no navegador, retomada e tratamento de falhas.
7. **C6 — Aceite integrado:** regressão de dev e módulos, segurança, concorrência, offline e ensaio de implantação.

C3 pode ser desenvolvido após C0; C2 e C4 dependem da política de C1. C5 depende dos contratos de C1/C2/C4 para sincronizar comandos. A aprovação solicitada cobre C0–C6 como plano; nenhum pacote foi iniciado por esta atualização.

## 6. Critérios de conclusão

- Usuário comum não consegue se promover; dev legítimo mantém suas capacidades globais.
- Dados e arquivos respeitam a matriz aprovada, incluindo revogação.
- Repetição de comando não duplica saldo, histórico ou pagamento; concorrência não cria saldo negativo.
- Pagamentos legados e novos carregam sem erro e valores reconciliam em centavos.
- Arquivo ausente não gera sucesso falso; fila e anexos sobrevivem a reabertura e atualização controlada da PWA.
- Testes significativos, análise estática e build web passam; ensaio manual documentado.
- Migrações são verificáveis, retomáveis e têm recuperação definida sem apagar dados pendentes.

## 7. Referências e controle

- [Plano detalhado para aprovação](plano-de-correcao-2026-09-15.md)
- [Backlog atualizado](task.md)
- [Fluxos atuais e propostos](user_flows.md)
- [Resumo do produto](presentation_summary.md)
- [Sprint status](../_bmad-output/implementation-artifacts/sprint-status.yaml)
- [Planejamento anterior arquivado](archive/2026-09-15-planejamento-anterior/README.md)

Os documentos atuais substituem o plano anterior. Requisitos futuros preservados no arquivo histórico serão refinados antes de implementação, sem serem tratados como funcionalidades entregues.
