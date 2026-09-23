# Reconciliação brownfield — omissões concretas

Data: 2026-09-23. Conferidos ARCHITECTURE-SPINE.md, evidence/ui-recon.md, logo-recon.md, technology-check.md e código citado abaixo. Sem implementação ou alteração do spine. Os pontos são lacunas do contrato de integração, não pedido de refatoração adjacente.

## RC-1 — Retirada do bootstrap exige mudança também no provider Flutter

**Evidência:** `app/lib/src/features/authentication/data/user_repository.dart:59–99`, `trustedDevProvider`, tenta gravar `dev_roles/{uid}` quando o documento está ausente/inativo e o e-mail contém `dev` ou o perfil tem `globalRole=dev`. AD-7 só identifica regras/provisionamento como fronteira dessa retirada; o seed não aponta esse adaptador de autenticação.

**Consequência:** após regras server-only, o cliente continua tentando provisionamento proibido, com reads adicionais, erros/logs e dependência implícita de fallback. A integração deve retirar explicitamente esse write/fallback e manter o provider como leitor da autoridade confiável. Preservar `adminCreateUser` e `setDevRole` server-side existentes; não reconstruir o fluxo administrativo.

## RC-2 — Cache da imagem e atualização do catálogo são contratos distintos

**Evidência:** `app/lib/src/features/construtoras/presentation/user_construtoras_provider.dart:9–19` usa FutureProvider.autoDispose; `data/construtora_repository.dart:54–116` lê catálogo uma vez e persiste pelo cache `construtoras/$userId/$dev`. Não há stream de construtoras. AD-10 manda invalidar cache de bytes na publicação, mas não fixa atualização do modelo/provider que carrega o ponteiro da logo.

**Consequência:** invalidar somente imagem pode deixar card apontando à revisão anterior até recriar o provider. Especificar que confirmação/consulta de publicação atualiza referência do modelo e invalida/refaz catálogo e cache de leitura correspondente para o mesmo ator/tenant. Se refresh falhar, não substituir recibo confirmado por modelo antigo nem apresentar cache como confirmação. Essa integração também cobre retorno do Painel Dev; sem exigir conversão geral de FutureProvider para stream.

## RC-3 — Identidade persistida do ator não aparece no contrato de transporte

**Evidência:** AD-8 exige `actorUid` imutável e teste de troca de conta. A tabela API mínima omite `actorUid` das três chamadas. `functions/src/index.ts:16–22` já oferece proteção opcional no wrapper: compara `data.actorUid` a `context.auth.uid` quando enviado.

**Consequência:** sobretudo na primeira chamada, se sessão mudar entre criação da tentativa e envio e o servidor ainda não tiver operação, ele poderá criar a tentativa sob o novo usuário (caso também autorizado), contrariando o ator persistido. Fixar envio do `actorUid` esperado nas chamadas e comparação obrigatória com autenticação antes de qualquer criação, junto da guarda local de sessão. Isso não aceita autoridade do parâmetro; usa-o exclusivamente como precondição de identidade. Operações já existentes continuam exigindo correspondência de ator/alvo.

## Limites da reconciliação

Não foi encontrada incompatibilidade adicional nas gravações sequenciais dos lotes, autoridade `manager`, modelo opcional de logo ou preservação do routing adjacente. AD-5 já reconhece a adaptação necessária para UUID por tentativa, confirmação por etapa e cache sem recibo; não inventar atomicidade no repositório atual. As regras ainda não satisfazem o protocolo, mas AD-7 registra essa migração e seus gates; não é omissão adicional. Não foram executados testes.
