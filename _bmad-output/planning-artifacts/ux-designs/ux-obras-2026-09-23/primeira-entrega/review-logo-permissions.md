# Validação — permissões e erros da logo

Data: 2026-09-23. Revisão documental de DESIGN.md, EXPERIENCE.md e HANDOFF.md; sem implementação. Escopo: cadastro/troca da logo por Dev no Painel Dev, Proprietário e administradores da construtora, sem remoção.

## L1 — Alta — Cancelamento promete preservação sem distinguir envio iniciado

**Local:** EXPERIENCE.md, Component Patterns/LogoEditor (linha 57), State Patterns/S5 (70), Interaction Primitives (84); HANDOFF.md, UX10.

**Evidência:** “Cancelar conserva logo publicada” e “cancelar/falhar preserva publicada” são absolutos, enquanto S5 admite resultado incerto. A única regra de fechamento durante operação é “Esc fecha overlays quando não invalida uma operação pendente”; não define Cancelar, voltar, barreira ou arrastar o sheet depois de Salvar. Uma publicação pode ter concluído sem a confirmação chegar; fechar não permite prometer que a logo antiga foi preservada.

**Ajuste UX:** separar três momentos: antes do envio, Cancelar descarta somente a seleção local; durante envio, desabilitar Cancelar, nova seleção e fechamento incidental e informar “Salvando logo”; em resultado incerto, permitir “Fechar” com mensagem explícita de que fechar não cancela a publicação. Falha confirmada anterior à publicação preserva a logo antiga; incerteza não recebe essa garantia. Registrar no aceite os caminhos voltar/Esc/barreira/arrastar, sem escolher mecanismo técnico de cancelamento ou rollback.

## L2 — Média — Resultado incerto não tem recuperação verificável definida

**Local:** EXPERIENCE.md, State Patterns/S5 (70), Logo — proposta operacional (78) e J5; HANDOFF.md, UX10.

**Evidência:** S5 pede “conferir logo atual”, mas o pacote também mantém a imagem antiga no card até confirmação e não define ação de consulta nem resultado dessa conferência. Conferir o mesmo card ainda desatualizado pode levar o usuário a concluir que a troca não ocorreu e reenviar. O aceite UX10 só contempla confirmação/falha, sem verificação de resultado incerto.

**Ajuste UX:** definir ação “Verificar logo atual” que consulta o estado publicado da mesma construtora, com carregando, confirmação e impossibilidade de confirmar. Enquanto não houver evidência suficiente, exibir “Ainda não foi possível confirmar a troca”, sem habilitar reenvio como recuperação automática nem tratar a imagem em cache como prova. Manter prévia identificada separadamente; depois de resultado conhecido, atualizar o card ou oferecer nova tentativa conforme o resultado. Arquitetura define como obter a evidência, não a UX. Acrescentar cenário de aceite de perda de resposta após salvar.

## L3 — Média — Editor não exige identificação visível da construtora alvo

**Local:** DESIGN.md, Components/LogoEditor; EXPERIENCE.md, Logo — proposta operacional (80) e J5.

**Evidência:** o editor especifica prévia de 120, logo atual e botões, mas não nome/CNPJ da construtora. As entradas incluem lista com várias empresas e Painel Dev; “construtora já selecionada” define a origem sem exigir que essa identidade continue visível dentro do diálogo. Isso deixa o usuário sem confirmação do alvo justamente antes de publicar uma alteração.

**Ajuste UX:** título “Logo de {nome da construtora}”, CNPJ quando disponível para diferenciar empresas, e manutenção desse contexto em prévia, envio e mensagens. O alvo permanece o da abertura; mudança de contexto exige sair e abrir outro editor, sem transportar a seleção. Tornar explícito no aceite que autorização é revalidada para essa construtora antes de publicar e que ser admin de outra empresa não libera a ação. As regras de papel já estão corretas; não é necessário criar papel ou permissão adicional.

## Itens conferidos sem novo achado

A entrada do Dev está restrita ao Painel Dev; admin de obra não ganha capacidade de logo; publicação depende de autorização na operação; não há remoção; PNG/JPEG até 5 MB e operação online estão identificados como proposta; dimensões e tratamento seguro foram corretamente remetidos à arquitetura. Prévia versus publicação, fallback por iniciais e retorno ao card/Painel Dev já constam do contrato. Não há necessidade de ampliar este review para outros módulos.

## Verificação das correções

Verificação focal em 2026-09-23, confrontando DESIGN/LogoEditor, EXPERIENCE/“Saída durante envio e confirmação incerta”, contexto operacional/J5, HANDOFF/UX09–UX10 e `.working/resolution-log.md`. Achados originais acima preservados como histórico.

| ID | Resultado | Evidência da correção |
|---|---|---|
| L1 | Resolvido no contrato UX | Cancelar limita-se à seleção anterior ao envio; durante acompanhamento, saídas incidentais e reenvio ficam bloqueados. Timeout/resposta perdida oferece Fechar com aviso de que não cancela a operação. A garantia de preservação limita-se à falha comprovada anterior à publicação. |
| L2 | Resolvido no contrato UX | Verificar logo atual exige evidência autoritativa, contempla carregamento/resultado conhecido/incerteza e não aceita cache ou mera imagem antiga como prova. Reenvio depende do resultado; reabertura retoma verificação. |
| L3 | Resolvido no contrato UX | Editor mostra nome/CNPJ, mantém alvo estável e não transporta seleção entre empresas; UX09 exige revalidar autorização na mesma construtora e cobre admin de outra empresa. |

Nenhuma lacuna remanescente identificada nos três achados. A viabilização da consulta/observabilidade permanece corretamente atribuída à arquitetura; esta verificação não comprova implementação nem execução de testes.
