# Gate adversarial independente

Data: 2026-09-23. Artefato: ARCHITECTURE-SPINE.md após RC1–RC3. Revisão documental por construção de unidades independentes; sem implementação/testes.

**Veredito: ajustar dois contratos antes do fechamento.** Autoridade, CAS entre operações diferentes, expiração transacional e separação recibo/ponteiro estão definidos. RC1–RC3 foram incorporados. Permanecem os pontos abaixo.

## A-1 — Recuperação do candidato imutável antes do commit não está vinculada

**Severidade:** média. **Local:** AD-8/AD-9; serviço de finalização e processamento Storage.

Unidade A escolhe caminho determinístico por operação para o candidato, grava com precondição de inexistência e retorna erro se já existir. Unidade B repete finalize da mesma operação após resposta perdida, obedecendo identidade/fingerprint. Se a primeira execução gravou o objeto e caiu antes do commit, a operação ainda é pending; todos os retries encontram objeto existente e falham até expirar. Ambas seguem a criação imutável e a regra explícita de retornar recibo quando já publicado, mas o caso pré-commit não está resolvido. Duas finalizações simultâneas também atingem essa lacuna.

**Ajuste mínimo:** fixar que precondição de inexistência falhada não rejeita automaticamente operação; localizar candidato vinculado à mesma operação e validar identidade/hash/geração antes de reutilizar, ou usar candidatos exclusivos por execução com regra determinística para escolher o único que entra na transação e coletar os demais. Consulta transacional de estado terminal deve impedir uma execução perdedora de mudar published para erro. Incluir teste crash depois da escrita Storage e antes do commit, com finalize simultâneo.

## A-2 — Prazo de operação não define quem produz o terminal observável

**Severidade:** média. **Local:** AD-9; getConstrutoraLogoOperation e expiração/coleta.

Unidade A implementa get como leitura pura: retorna pending e expiresAt até outro processo gravar expired. Unidade B implementa UI que somente consulta, bloqueando novo envio até terminal autoritativo, como exige AD-9. Se upload/finalize nunca ocorrer e o processo de expiração não existir ou não estiver programado (o spine descreve a transição mas não vincula executor/frequência), o prazo passa sem desbloquear a interface. O cron de coleta pode legitimamente considerar somente terminais, também obedecendo o texto.

**Ajuste mínimo:** atribuir expiração transacional a get/start/finalize quando o prazo estiver vencido, com disputa segura contra commit, e reservar scheduler para abandono sem consultas; ou fixar executor periódico e limite de atraso de terminal. O relógio cliente nunca cria a certeza de expiração. Testar pending abandonada, prazo vencido, consulta do ator revogado e corrida get-expire/finalize.

## Observação de integração não bloqueante — deleção/recriação de construtora

AD-7 protege campos em create/update e AD-8 exige existência do pai. As regras legadas permitem delete do Dev. A spec deve explicitar se IDs de construtora nunca podem ser reutilizados: exclusão do pai não equivale a eliminar subcoleções/operações e uma nova construtora com mesmo ID/revisão zero pode reencontrar tentativa antiga. Alternativa é tombstone/identidade de encarnação ou impedir reutilização. Não é proposta de redesign do fluxo de exclusão; é precondição a registrar para o CAS operar sobre o mesmo alvo lógico.

## Itens sem novo achado

- Mesmo ator/alvo, inclusive troca de conta: transporte actorUid e comparação obrigatória agora fixados.
- Permissão por construtora e proteção de writes Dev: gates explícitos.
- Publicação e expiração disputam a mesma operação; coleta exclui operações abertas e versão corrente.
- Cache de catálogo/imagem e fonte autoritativa: RC2 atendido.
- Routing adjacente: preservação explícita, sem refatoração incidental.

## Conclusão após correções

Releitura do spine atualizado em 2026-09-23: A-1 resolvido em AD-8 por candidato determinístico vinculado à operação, verificação de geração/hash/fingerprint/processamento, reutilização segura e retorno do recibo terminal. A-2 resolvido em AD-9 por expiração transacional nos endpoints e job horário responsável por abandono/coleta. A observação de deleção/recriação foi convertida em invariante explícito de não reutilização do ID e retenção de recibos.

Também conferidas as restrições de dois documentos nas Storage Rules: staging usa operação mais grant fixado pelo servidor; versões privadas usam os dois documentos de autoridade, sem terceira leitura do ponteiro. O cliente consome somente a versão corrente; versões antigas não se tornam públicas.

**Veredito final deste gate: aprovado documentalmente, sem novos bloqueios relevantes identificados.** Permanecem os testes de concorrência, crash/retomada, expiração e segurança definidos pelo pacote para a implementação futura. Esta conclusão não declara testes executados nem validação do ambiente de produção.
