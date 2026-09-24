# Reconciliação — docs/

**Veredito de cobertura:** boa — o PRD absorve fielmente o núcleo de `docs/` (autorização/dev global, estoque central, centavos/idempotência, offline honesto, C0–C6 e limite de produção), mas amplia o escopo de módulos além do que os planos de 15/09 autorizavam e omite algumas restrições operacionais registradas na implantação.

## Lacunas

1. **Decisão D8 (credenciais de seed) ausente.** `docs/decisoes.md` D8 exige `GOOGLE_APPLICATION_CREDENTIALS` sem fallback e reprovação na CI (`no-secrets`) para o seed cloud; nem o `prd.md` nem o `addendum.md` (§2, §4) registram essa restrição de segurança — embora o addendum referencie `spec-hardening-credenciais-seed` no §10 sem detalhar a decisão.
2. **Runtime/plataforma de build omitido.** `docs/implantacao-c0-c6.md` ("Validação reproduzível") fixa Functions em Node 20, Node 24/Java 21 para ferramentas e `functions/node_modules/firebase` 12.19.0, com aviso de não publicar `flutter build web` sem o preparador. O addendum §1 só declara Flutter/Firebase e não carrega essas restrições de build.
3. **Aceite manual de navegador real pendente.** `docs/implantacao-c0-c6.md` ("Aceite manual pendente") e `docs/validacao-c0-c6.md` (pendências) registram Safari móvel e Chrome Android como validação não executada / pré-requisito de deploy. O PRD §8 não lista esse item entre as Open Questions nem o trata como bloqueador.
4. **Precedência `modules` vs. perfil não explicitada.** `docs/politica.md` §3 define que `modules` controla só os módulos centrais de membros comuns, enquanto admin/proprietário derivam de `isAdmin`/`isOwner`. O PRD (FR-3, FR-5, FR-38) enuncia o fail-closed, mas não a regra de precedência por perfil.
5. **Fontes de direção de produto não referenciadas.** `docs/presentation_summary.md` ("interface Flutter voltada ao uso em celular", "operação offline é objetivo em implementação") e `docs/implantacao-c0-c6.md` não aparecem na lista de insumos do `prd.md` §0 nem no addendum, apesar de `presentation_summary.md` orientar o alvo mobile e o tom de maturidade dos módulos.

## Conflitos

1. **Escopo de módulos (divergência de rodada).** `docs/implementation_plan.md` §1, `docs/presentation_summary.md` ("Evolução futura") e `docs/validacao-c0-c6.md` (pendências: "Módulos: RH, EPI, Qualidade | Fora do escopo desta rodada"; "Custo médio completo, parcelamento financeiro | Fora do escopo") colocam RH, EPI, qualidade, compras/NF, fornecedores e Visão 360 como evolução futura. O PRD §6.1 os lista como **In Scope** do MVP. `docs/task.md` já move RH/EPI para entregues (Epics 4/5), reduzindo o conflito a Compras/NF, Fornecedores, Validação/Qualidade e Visão 360 — mas o desalinhamento com os planos de 15/09 permanece.
2. **Membro comum × financeiro.** `docs/politica.md` §2 (perfil 4) e `docs/plano-de-correcao-2026-09-15.md` §3 dizem "financeiro sem acesso nesta rodada" para o membro comum; o PRD (Glossário, FR-5, FR-48) admite `financeiro` como módulo atribuível e não reproduz essa exclusão.
3. **Estoque central × Admin da obra.** `docs/politica.md` §2 (perfil 3) e o plano §3 restringem o admin da obra a estoque central "somente com permissão explícita"; o PRD FR-4 e o addendum AD-4 listam `estoque` como módulo de obra sem explicitar essa condição.
4. **Fila offline de RH/EPI × dívida técnica.** O PRD FR-91 inclui `chamada` entre as operações offline e a NFR de §4.10 promete EPI "offline via fila"; o addendum §11 registra "Fila offline para RH (Epic 4 retro)" e "E2E de anexos fotográficos e PDFs sob conectividade intermitente" como dívida **aberta**, não validada.
5. **Responsividade e testes offline (Epics 6/7).** O PRD §6.2 declara "Testes offline e de integridade (Epic 6)" e "Responsividade formal (Epic 7)" como **backlog/out of scope**; `docs/validacao-c0-c6.md` e `docs/task.md` C6 registram responsividade verificada e C5 offline **ACEITOS em desenvolvimento**.

## Cobertura OK

- **Decisões D1–D7** refletidas: dev global sem vínculo (FR-2), estoque central (FR-47), caminhos `construtoras/{cId}/obras/{oId}` preservados (Glossário), Web/PWA mobile-first (FR-90), matriz `isActive`/`modules`/`isAdmin`/`isOwner` (FR-3, FR-5), C0–C6 restritos a desenvolvimento (PRD §6, addendum §7), `globalRole` só via servidor (FR-7, FR-10).
- **Limite de produção** consistente: `docs/politica.md` §5, plano §6 e `docs/task.md` correspondem ao aviso do PRD §5, §6.2 e §8 OQ-9.
- **Pendências de evidência** de `docs/decisoes.md` e `docs/politica.md` §4 mapeadas como OQ-6/7/8 (identidade de devs, regras de produção, volume legado).
- **Integridade financeira e de estoque**: centavos, `schemaVersion`, leitura de legado, idempotência por `operationId`, abertura reconciliada, correção por estorno (FR-44–FR-53, addendum §6) cobrem plano §§3–4 e `data_model.md` §3.
- **Offline honesto e anexos**: estados da fila, `authorization_rejected`, isolamento por conta, sinais de sincronização e não-recuperação de dados apagados pelo usuário (FR-56–FR-59, FR-90–FR-94) espelham `user_flows.md` §4–5 e `data_model.md` §3.
- **Hierarquia e vínculos**: drill-down Loteamento→Quadra→Lote→Setor→Equipe, deep link, ACL por nó e migração de vínculos por obra (FR-17–FR-20, OQ-1, addendum AD-9, §11) cobrem `data_model.md` §1 e os Epics 8–11.
