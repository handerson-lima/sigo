# Reconhecimento — protocolo de logos

Data: 2026-09-23. Extrato para Winston; planejamento, sem implementação. As escolhas abaixo são candidatas arquiteturais; o documento principal fixa o contrato definitivo.

## Evidências locais

- `functions/src/index.ts:9–14`: `authority.admin = dev ativo || manager(construtora_member)`; `obraAdmin` é mais amplo e não serve para gerenciar logos.
- `functions/src/contracts.ts`: `manager` exige vínculo ativo e flags `isAdmin/isOwner` ou `role=admin/owner`.
- `firestore.rules:20–22`: grant recursivo `allow read, write: if dev()` impede proteção por deny específico.
- `firestore.rules:24–30`: criação de `dev_roles` aceita e-mail contendo `dev` ou `users.globalRole=dev`. Esse bootstrap permite autoatribuição incompatível com a autoridade requerida.
- `firestore.rules`, construtora: update comum já limitado a `name,cnpj,address,updatedAt`; `commands` permite escrita direta de Dev.
- `storage.rules`: grants existentes restritos a caminhos de obras; não há catchall de escrita Storage.
- `functions/package.json`: Firebase Admin/Functions; nenhum decodificador de imagem instalado.
- `app/lib/src/features/construtoras/domain/construtora.dart`: modelo sem logo.
- `app/lib/src/sync/read_cache.dart`: cache por usuário; não é recibo de operação nem cache autenticado de imagens.
- Pacote UX primeira-entrega: HANDOFF UX09/UX10; EXPERIENCE S5/J5, autorização e resultado incerto.

## Protocolo candidato

1. Cliente cria e persiste `operationId` por usuário/construtora antes de iniciar. Endpoint idempotente cria operação isolada em `construtoras/{c}/logo_operations/{hash(uid,operationId)}` com ator, hash do pedido, revisão esperada, hash dos bytes, tamanho, MIME, prazo e caminho staging decidido pelo servidor.
2. Repetição do mesmo identificador/pedido retorna operação existente; payload diferente é conflito. Retry técnico mantém identidade/bytes. Seleção diferente exige nova operação depois de resultado terminal suficiente.
3. Upload staging create-only, ator e operação correspondentes, aberta/não expirada; sem update/delete. MIME e tamanho preliminares nas regras. [ASSUMPTION] PNG/JPEG, até 5 MiB (5.242.880 bytes); alinhar texto da interface ao limite.
4. Backend lê geração exata, verifica hash/tamanho reais, decodifica e reencoda imagem com limite de pixels e retirada de metadados. Decoder e limites são dependência nova a selecionar/verificar; não presumir suporte existente.
5. Backend grava versão publicada imutável sem token público antes do commit. Transação Firestore revalida autoridade atual, operação aberta/prazo e revisão esperada; grava ponteiro, revisão incrementada, recibo terminal e auditoria protegida atomicamente. IO Storage nunca dentro do callback transacional.
6. CAS de revisão evita substituição silenciosa entre administradores. Conflito terminal mantém versão vencedora e exige nova confirmação. Objeto gravado antes de commit fracassado é órfão, não publicação.
7. Retry pós-commit retorna recibo; retry pré-commit pode reutilizar objeto validado verificando geração/hash. Não sobrescrever caminho de imagem corrente.

Construtora recebe `logo` opcional: caminho, geração, hash, MIME, bytes, dimensões, revisão, data/ator de publicação. Ausência equivale a revisão zero/iniciais, sem backfill obrigatório. Operação possui estados não terminais explícitos e terminais `published`, `rejected`, `conflict`, `expired`; falha transitória não equivale a rejeição se publicação puder continuar.

## Incerteza, expiração e leitura

- Verificação online consulta a operação e a publicação corrente separadamente. Uma tentativa pode ter publicado e já ter sido substituída; ponteiro atual sozinho não prova resultado da tentativa.
- Timeout mantém envio bloqueado; Fechar não cancela. Reabertura retoma operação persistida antes de liberar nova publicação. Cache/imagem antiga não confirma falha.
- Ator revogado pode receber somente recibo sanitizado da própria tentativa por endpoint autenticado, sem caminho/imagem/dados atuais da empresa. Autoridade revogada impede nova publicação.
- Expiração é transição transacional terminal, anterior à coleta; finalize exige estado aberto e prazo válido. Tombstone/recibo impede recriação de operação expirada. Coleta nunca apaga objeto corrente ou revive operação terminal; retenção exata a fixar.
- Leitura de imagem autenticada por Dev ativo ou membro ativo da construtora; sem URL permanente com token compartilhável. Namespace publicado não admite client create/update/delete.
- Cache por usuário/construtora/revisão/geração; invalidar na publicação, logout e revogação conhecida. Falha conserva iniciais/nome. Upload online separado da fila offline geral.

## Menor mudança de regras viável — gate de rollout

Preservar leitura ampla Dev e permissões legadas onde não interferirem no novo contrato. Particionar grant recursivo de escrita por coleção raiz, excluindo `construtoras` e `dev_roles`; em tenants, declarar grants explícitos equivalentes aos legados, sem catchall que alcance `logo_operations`. Proteger `logo`/revisão em create e update de construtora inclusive para Dev; manter update comum restrito aos campos atuais. Subcoleção de operações é server-only.

`dev_roles` deve ser server-only para escrita; retirar bootstrap por e-mail/globalRole do cliente. Primeiro Dev provisionado por operador confiável via Admin SDK fora do app; alterações seguintes pelo `setDevRole` existente, autorizado por Dev ativo. Conferir necessidades de bootstrap do ambiente antes do rollout.

Auditoria global atual permite writes Dev e não serve como evidência imutável. Usar recibo/auditoria dedicada protegida dentro do namespace de operações, gravada na mesma transação do ponteiro; auditoria global pode ser espelho operacional, nunca prova exclusiva.

O particionamento precisa de matriz de regressão para ações legadas do Painel Dev e demais tenants; grants sobrepostos são aditivos. Nenhum deny específico compensa um allow amplo remanescente. Não remover indiscriminadamente permissões Dev existentes sem mapear substituições.

## Verificações mínimas de implementação futura

Testar Dev/owner/admin ativos, membro comum, admin somente de obra, outro tenant, vínculo revogado, bootstrap indevido, write direto inclusive Dev, operação adulterada, MIME falso, hash divergente, imagem inválida/excesso de pixels, timeout antes/depois de commit, repetição idempotente, dois administradores concorrentes, expiração concorrente com finalize/coleta, troca de conta, cache antigo e regressão das ações Dev legadas. As regras e o protocolo são gates antes de disponibilizar a UI de logo.
