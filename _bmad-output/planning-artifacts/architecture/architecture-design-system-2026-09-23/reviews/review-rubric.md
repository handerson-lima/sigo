# Gate de arquitetura — good-spine rubric

Data: 2026-09-23. Revisão independente documental, sem implementação ou testes.

**Veredito: aprovado para finalizar o planejamento, com dois ajustes editoriais opcionais; nenhum achado crítico ou alto.** A aprovação não libera build antes da spec nem atesta a implantação.

## Cobertura do checklist

| Critério | Resultado |
|---|---|
| Pontos reais de divergência | Cobertos: fronteira de componentes, tokens, densidade/reflow, dono do inset, tema global, rotas herdadas, resultado parcial de lote, autoridade e publicação de logos |
| ADs executáveis | Os onze ADs fixam limites verificáveis. AD-7 explicita a necessidade de eliminar grants sobrepostos e bootstrap do cliente; AD-8/9 fixam CAS, identidade, transações, expiração, tombstones e coleta |
| Deferred sem licença para divergência | Limites quantitativos têm valores propostos; ajustes exigem coordenação cliente/servidor/UX. Infraestrutura tem gate antes da ativação. A próxima spec deve fechar calibrações antes do build, conforme o próprio documento |
| Brownfield | Preserva Flutter/Riverpod/Firebase, shell e contexto, gravações sequenciais e rotas existentes. Declara conflito da arquitetura de routing adjacente sem ratificá-la como pai incompatível |
| Capacidades da UX | Mapa cobre UX01–UX11. HANDOFF exige logo, erros/timeout, autorização e atualização do card; todos têm regras correspondentes. Regressão, teclado e reflow estão presentes |
| Operação e ambiente | AD-11 cobre ambientes, runtime/binário, IAM, rollout, logs, métricas e rollback; política quantitativa e recursos são gates explícitos, não lacunas silenciosas |
| Evidência tecnológica | Stack pinado e fonte técnica local identificada. Dependência nova Sharp é proposta; runtime efetivo permanece como verificação obrigatória. A revisão especializada de atualidade é responsável pela validação externa |
| Herança | Ausência de pai explicitada. Documento não altera arquitetura adjacente nem artefatos UX existentes |

## Achados menores

### R1 — Proveniência mista em AD-5

- **Severidade:** baixa.
- **Evidência:** AD-5 inteiro está marcado `[ADOPTED]`, embora o UUID fixo durante a tentativa seja uma proposta de adaptação do código atual, e não capacidade existente. Preservar gravação sequencial e feedback honesto vem da UX; o mecanismo de identidade é derivação técnica.
- **Impacto:** um leitor pode confundir a identidade estável de tentativa com funcionalidade já implementada. A abertura do documento e a expressão “adaptação dos repositórios” reduzem esse risco.
- **Tratamento:** autofix opcional: marcar o mecanismo do UUID como `[ASSUMPTION]` dentro da regra, preservando a classificação das restrições adotadas. Não requer nova decisão do usuário.

### R2 — Explicitar o intervalo operacional da coleta na spec

- **Severidade:** baixa.
- **Evidência:** AD-9 proíbe coleta antes de 24 horas e AD-11 exige monitorar coleta; o acionamento e intervalo não estão fixados.
- **Impacto:** isso não quebra segurança nem publicação, mas pode deixar uma implementação com coleta apenas manual e outra com execução agendada, produzindo custos/pendências diferentes.
- **Tratamento:** deferir explicitamente à spec sob o responsável backend/operação, junto dos prazos já listados. O contrato de segurança de coleta permanece fechado; não é necessário definir a agenda no spine de feature.

## Limites

Foram lidos o spine atualizado, o checklist do skill, `evidence/logo-recon.md` e HANDOFF da primeira entrega. Não foram realizados testes, alterações de código, implantação nem certificação independente das versões publicadas. Questões de segurança adversarial e atualidade tecnológica têm revisores próprios neste gate.
