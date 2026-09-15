# SIGO — preparação de implantação C0–C6

Status: somente desenvolvimento autorizado. Nenhum deploy ou alteração de dados de produção foi executado.

## Validação reproduzível

- Flutter instalado e dependências de `app/pubspec.lock`; Node 24 para ferramentas, Java 21 para emuladores. Functions declara runtime Node 20; validar esse runtime em homologação antes da publicação.
- `cd functions && npm ci && npm test`
- `npm run test:emulators` inicia Auth/Firestore/Storage no projeto `demo-sigo` e executa os testes de handlers e Rules. Os handlers são invocados em processo; o transporte HTTP de callable exige ensaio separado.
- `npm run test:browser` usa Chrome instalado e testa IndexedDB.
- `cd app && flutter analyze && flutter test`
- `tool/build_pwa.sh --dart-define=SIGO_EMULATORS=true` gera a PWA isolada; em seguida `cd ../functions && npm run test:pwa`.
- O preparador da PWA exige `functions/node_modules/firebase` 12.19.0, versão compatível com FlutterFire fixada no lock. Inclui os scripts locais e CanvasKit no cache. Não publicar `flutter build web` sem executar o preparador.
- O build demo aponta para 127.0.0.1. Em dispositivo físico, definir `SIGO_EMULATOR_HOST` com o endereço da máquina de ensaio e usar origem HTTPS confiável para PWA.

## Inventário e migração

`cd functions && npm run build && node scripts/migration.cjs scripts/migration-fixture.json` produz inventário sem acessar serviços. A entrada contém `documents` (path/data), `identities`, `verifiedDevs` e `evidence`. Revisar o relatório antes de aplicar. Datas de vencimento ambíguas, valores inválidos e vínculos sem campos obrigatórios ficam em revisão.

A opção `--apply-demo` exige projeto `demo-*` e hosts explícitos de Auth/Firestore em loopback; arquivos exigem também Storage local. Não existe caminho de escrita em produção neste script. O ensaio testa repetição por recibos, abertura de estoque, centavos e preservação de pendências. A API administrativa local remove tokens, pois a versão do emulador acumula tokens quando metadados são atualizados. Essa particularidade não comprova comportamento do Storage real.

## Sequência para uma futura publicação

1. Versionar o conjunto de código e obter backup/export verificável. Registrar projeto, regras publicadas, versão de cliente e contagens de documentos/objetos. Não usar este workspace sem versionamento como referência de rollback.
2. Confirmar UIDs dos devs legítimos com responsável autorizado. Provisionar `dev_roles/{uid}.isActive=true` por ferramenta administrativa controlada, mantendo uma conta de recuperação. Não promover com base em e-mail, claims ou `users.globalRole` legados. Testar duas contas dev antes de fechar permissões.
3. Ensaiar em homologação com cópia saneada: matriz completa, transporte callable HTTP, runtime Node 20, logs e quotas; Chrome e Safari móvel, conexão instável e atualização com fila pendente.
4. Preparar janela coordenada: clientes antigos gravam saldos/pagamentos diretamente e são incompatíveis com Rules finais. Avisar e permitir sincronização/exportação das pendências antigas antes da troca. Não apagar IndexedDB nem caminhos de recuperação.
5. Implantar leitores compatíveis e Functions; converter datas/centavos e saldos por lote com reconciliação de totais e recibos. Normalizar módulos somente com autorização explícita de cada vínculo. Registrar diferenças e pausar em caso de divergência.
6. Verificar objetos de cada diário, tamanho/hash e vínculo; trocar URLs por referências privadas. Só depois revogar todos os tokens antigos. Testar uma URL antiga sem autenticação (negada) e a leitura autenticada autorizada (permitida) no Storage real. Conferir CORS da origem publicada para `getData`.
7. Publicar cliente preparado, índices e Rules finais de forma coordenada. Confirmar dev global, usuário comum, revogado, duas construtoras e operações idempotentes com contas de ensaio. Não distribuir build com `SIGO_EMULATORS=true`.
8. Monitorar rejeições, latência, fila e divergências de saldo. Registrar versões e resultados do aceite. A aprovação de produção será solicitada sobre esse conjunto concreto após as etapas preparatórias aplicáveis.

## Recuperação

- Pausar os comandos afetados e conservar recibos/auditoria. Comparar saldos e eventos antes de qualquer correção; usar ajuste/estorno auditado com motivo e evidência.
- Restaurar cliente/Functions compatíveis com as Rules seguras. Nunca reabrir autoatribuição de dev ou gravação direta de saldos como rollback.
- Pendências locais permanecem no usuário que as criou. Falha de quota não significa salvamento; não limpar dados do navegador antes de recuperar os originais. Arquivos removidos pelo navegador/usuário não são recuperáveis pelo servidor.
- Permissões revogadas encerram o retry automático. Revisão administrativa deve decidir a resolução sem declarar sincronizado um comando rejeitado.
- Service worker instala pacote completo, aguarda fechamento das abas antigas e conserva IndexedDB. Uma atualização que falha mantém a versão anterior.

## Aceite manual pendente

Safari móvel real: instalar PWA, autenticar, abrir obra/módulos, registrar com fotos offline, fechar/reabrir, atualizar com pendências, voltar à rede, conferir único efeito e anexos; repetir com quota limitada, troca de conta e revogação. Anotar modelo/iOS, versões e evidência. Não há validação de Safari móvel nesta máquina.
