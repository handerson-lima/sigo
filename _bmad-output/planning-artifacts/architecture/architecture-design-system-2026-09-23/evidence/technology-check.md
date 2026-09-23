# Verificação técnica — 2026-09-23

Brownfield: preservar versões resolvidas; nenhuma dependência foi instalada ou atualizada. Referências remotas confirmam capacidades, não a configuração efetiva do projeto em produção.

| Tecnologia | Evidência local | Verificação de adequação |
|---|---|---|
| Flutter 3.47.2 / Dart 3.13.2 | SDK local bin/cache/flutter.version.json; revisão coincide com app/.metadata | [ThemeExtension em ThemeData](https://api.flutter.dev/flutter/material/ThemeData/extensions.html) permite tokens específicos junto do tema Material |
| Riverpod 3.4.3 / go_router 18.0.1 | app/pubspec.lock | [Riverpod](https://pub.dev/packages/flutter_riverpod), [go_router](https://pub.dev/packages/go_router): pacotes vigentes; reutilizar estado e navegação existentes |
| firebase_storage 13.6.0 | app/pubspec.lock | [Versão publicada](https://pub.dev/packages/firebase_storage); [upload Flutter](https://firebase.google.com/docs/storage/flutter/upload-files) suporta bytes e acompanhamento; upload concluído não equivale a publicação de metadados da logo |
| image_picker 1.2.3 | app/pubspec.lock | [Pacote oficial](https://pub.dev/packages/image_picker): seleção em mobile/web; não implica que formatos/limites da aplicação já sejam validados |
| cloud_firestore 6.10.0 / cloud_functions 6.5.0 | app/pubspec.lock | [Callables](https://firebase.google.com/docs/functions/callable) recebem contexto autenticado; aplicação precisa validar autoridade por construtora |
| firebase-admin 12.7.0 / firebase-functions 5.1.1 / TypeScript 5.9.3 | functions/package-lock.json | Convenções existentes em functions/src/index.ts; manter baseline de dependências e primeira geração existente neste recorte |
| Node 20 | functions/package.json engines | [Gerenciamento de runtime](https://firebase.google.com/docs/functions/manage-functions) lista Node 20; patch real do runtime e política de suporte devem ser conferidos no rollout |
| sharp 0.35.4 — adição proposta, ausente hoje | Não instalado | [Release oficial](https://sharp.pixelplumbing.com/changelog/v0.35.4/) e [instalação](https://sharp.pixelplumbing.com/install/): requer runtime Node-API v9, por exemplo Node >=20.9.0; verificar binário Linux do deploy em integração |

## Semânticas relevantes ao contrato

- [Regras Firestore sobrepostas](https://firebase.google.com/docs/firestore/security/rules-structure): uma concessão em outro match não é anulada por deny específico. O allow recursivo do Dev atual precisa ser particionado para proteger publicações e operações server-only.
- [Storage Rules](https://firebase.google.com/docs/reference/security/storage) consultam documentos Firestore e metadados do pedido. Isso permite vincular staging à operação/ator, mas não substitui decodificação de bytes no servidor.
- [Precondições de objetos](https://docs.cloud.google.com/storage/docs/request-preconditions) permitem escrever somente quando não existe geração prévia e proteger operações contra uma geração diferente. Não fazem uma transação distribuída Storage/Firestore.
- [Download autenticado Flutter](https://firebase.google.com/docs/storage/flutter/download-files): getData recebe limite de bytes; manter caminhos protegidos em vez de links permanentes portadores de token.
- [Construtor sharp](https://sharp.pixelplumbing.com/api-constructor/) oferece limite de pixels; o servidor ainda deve conferir formato e falhas de decodificação, com recursos limitados.
- [Saída sharp](https://sharp.pixelplumbing.com/api-output/): saída padrão remove metadados e converte para sRGB; explicitar orientação e preservar proporção/transparência sem crop. Não recolorir a marca por opção visual.

## Limites da verificação

Não houve deploy, execução do aplicativo, instalação de sharp ou teste de regras. Região, plano de faturamento, permissões de serviço e runtime efetivo do ambiente remoto não foram consultados. Gates operacionais devem conferir isso antes de ativar logos; não presumir infraestrutura pronta.

## Complemento do reviewer gate

- [Storage Rules](https://firebase.google.com/docs/storage/security/rules-conditions) limita uma avaliação a dois documentos Firestore. Staging usa operação + grant escolhido pelo servidor; leitura de versões usa Dev/membro e o cliente resolve o ponteiro corrente. Versões anteriores continuam privadas até coleta.
- [Calendário de runtime](https://docs.cloud.google.com/functions/docs/runtime-support): Node 20 deprecated em 2026-04-30 e decommission previsto em 2026-10-30. Node 22 está disponível na primeira geração; alvo proposto antes da ativação, sujeito à integração com dependências existentes. O calendário específico complementa a página geral de gerenciamento de Functions.
