---
id: SPEC-5-1-modulo-epi
companions:
  - ../implementation-artifacts/spec-5-1-modulo-epi.md
sources:
  - ../planning-artifacts/architecture/architecture-epic-5/ARCHITECTURE-SPINE.md
  - ../implementation-artifacts/epic-5-context.md
  - ../implementation-artifacts/spec-4-1-rh-cadastro.md
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate.

# Story 5.1 — Módulo EPI: Catálogo, Eventos de Entrega e Termos de Responsabilidade

## Why

A construção civil exige rigoroso cumprimento das normas trabalhistas e de segurança (especialmente a NR-6), com fornecimento obrigatório e rastreável de Equipamentos de Proteção Individual (EPIs). Atualmente, no SIGO, não há catálogo centralizado com controle de validade de Certificados de Aprovação (C.A.) nem registro imutável das entregas vinculadas aos colaboradores cadastrados (Story 4.1). A falta de termos digitais assinados e de rastreamento do ciclo de vida dos equipamentos gera passivos trabalhistas graves, expõe a integridade física dos trabalhadores e impede auditorias de compliance em canteiro.

## Capabilities

- **CAP-1**
  - **intent:** Gerenciar o catálogo corporativo de EPIs da construtora com controle de Certificado de Aprovação (C.A.) e vida útil estimada.
  - **success:** O sistema permite cadastrar e editar EPIs com nome, fabricante, categoria de proteção, número do C.A., data de validade do C.A. e periodicidade de troca em dias, emitindo alertas visuais de C.A. vencido ou a vencer em até 30 dias.

- **CAP-2**
  - **intent:** Registrar eventos operacionais imutáveis de movimentação de EPI (entrega, substituição, devolução e descarte) por colaborador na obra.
  - **success:** Cada evento grava de forma auditável e indelével o `funcionarioId` (Epic 4), `epiId`, número do C.A., quantidade, motivo, data/hora e identificador do responsável pela entrega.

- **CAP-3**
  - **intent:** Gerar e colher assinatura do Termo de Responsabilidade e Guarda de EPI digital com hash de integridade e auditoria.
  - **success:** O sistema gera o termo consolidando os itens entregues, colhe a assinatura manuscrita eletrônica do colaborador (ou confirmação via PIN/foto), gera o hash SHA-256 do documento e arquiva o arquivo assinado no Storage privado com registro na coleção `audit/`.

- **CAP-4**
  - **intent:** Disponibilizar painel de controle e conformidade de EPIs por colaborador e por obra na interface Flutter.
  - **success:** Encarregados e técnicos de segurança consultam rapidamente quais EPIs estão ativos em posse de cada funcionário, status de validade, data prevista para troca e pendências de assinatura de termos.

## Constraints

- **Imutabilidade Contábil e Legal:** Registros de eventos de entrega e devolução de EPI não podem ser excluídos fisicamente (`allow delete: if false;`).
- **Integridade de C.A.:** Não permitir a entrega de itens cujo C.A. esteja expirado no Ministério do Trabalho sem justificativa e autorização explícita de responsável de segurança (`admin` ou `obraAdmin`).
- **Vínculo com RH:** Toda entrega deve referenciar um colaborador válido e ativo cadastrado em `construtoras/{cId}/funcionarios/{fId}`.
- **Autorização e RBAC:** Acesso restrito a usuários com permissão no módulo `epi`, gestores da obra ou perfil `dev`.
- **Resiliência Offline:** Suporte a registro de entrega e coleta de assinatura na fila offline (`OperationQueue` / IndexedDB) para operação em locais de canteiro sem cobertura de sinal de internet.

## Non-goals

- Integração com baixa contábil e movimentação física de estoque do Almoxarifado nesta primeira fatia (o controle físico de estoque de materiais do Epic 3 permanece focado em insumos de construção; a interligação de baixa de estoque de EPI fica postergada).
- Certificação digital ICP-Brasil A1/A3 ou integração com Gov.br (adota-se assinatura eletrônica em canvas touch/mouse com registro criptográfico SHA-256 e trilha de auditoria SIGO).

## Success signal

- Cadastro de EPI com C.A. funcional, entrega registrada para colaborador existente na obra, termo digital assinado e arquivado no Storage com hash SHA-256, visualização em tempo real do status de proteção no perfil do colaborador, 100% dos testes unitários e de integração aprovados, e `flutter analyze` com zero warnings.
