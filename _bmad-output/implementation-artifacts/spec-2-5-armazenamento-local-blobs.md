---
title: 'Story 2.5 — Armazenamento Local de Blobs'
type: 'feature'
created: '2026-09-16'
status: 'in-progress'
baseline_commit: '03bf1ab935e5e4279a1cec5c329c299230a8bde9'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
  - '{project-root}/docs/task.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** No ambiente Web/PWA, a captura de fotos e evidências em campo não dispõe de sistema de arquivos nativo convencional (`dart:io` `File` / `Directory`), exigindo que os arquivos binários (blobs) sejam validados por magic bytes, associados a identificadores estáveis e persistidos no IndexedDB antes de confirmar a operação localmente, prevenindo perda de evidências em recargas, fechamento de abas ou perda de sinal.

**Approach:** Padronizar e blindar a camada de processamento e persistência de blobs locais no PWA com validação rigorosa de magic bytes (JPEG, PNG, WebP), limite de 10 MB, cálculo de hash SHA-256 para integridade ponta a ponta, empacotamento serializado na fila IndexedDB e desacoplamento total de APIs nativas de arquivos.

## Boundaries & Constraints

**Always:**
- A validação de arquivos binários deve inspecionar os magic bytes reais (`FF D8` para JPEG, `89 50` para PNG, `RIFF...WEBP` para WebP), nunca confiando apenas na extensão do arquivo.
- Blobs com tamanho zero ou superiores a 10 MB (10.485.760 bytes) devem ser rejeitados imediatamente com mensagem de erro clara.
- Cada anexo recebe um identificador único estável (UUID v4) e tem seu hash SHA-256 calculado no momento da captura local.
- No Web/PWA, fotos e evidências são mantidas em memória (`Uint8List`) e serializadas em base64 dentro do IndexedDB (`sigo-operations`), sem nenhuma chamada a `dart:io` que possa quebrar no navegador.
- Toda operação offline contendo anexos só é confirmada após a gravação atômica completa dos metadados e bytes no IndexedDB.

**Never:**
- Nunca depender de caminhos absolutos do sistema operacional nativo (`/tmp`, `/var`, `C:\`) para referenciar anexos web.
- Nunca concluir a sincronização de uma operação cujo anexo remoto não coincida exatamente em tamanho e hash SHA-256 com o blob local.
- Nunca descartar silenciosamente arquivos ausentes ou pendências legadas; qualquer inconsistência deve orientar recuperação explícita no dispositivo de origem.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Imagem válida (JPEG/PNG/WebP) | Bytes com magic bytes corretos <= 10MB | Anexo aceito, UUID v4 gerado, SHA-256 calculado, serializado na fila | N/A |
| Arquivo de formato não suportado | Bytes de PDF ou executável (.exe / .bin) | Rejeição imediata | Lança `StateError('Use JPEG, PNG ou WebP')` |
| Arquivo acima do limite (>10MB) | Bytes com tamanho > 10 * 1024 * 1024 | Rejeição imediata | Lança `StateError('Foto ausente ou acima de 10 MB')` |
| Arquivo vazio (0 bytes) | `Uint8List(0)` | Rejeição imediata | Lança `StateError('Foto ausente ou acima de 10 MB')` |
| Persistência offline e reabertura | Operação salva com foto; PWA fecha e reabre offline | Bytes do anexo preservados no IndexedDB e recuperáveis | Dados íntegros |

</frozen-after-approval>

## Code Map

- `app/lib/src/features/diario/data/diario_repository.dart` -- Validação de magic bytes, cálculo de SHA-256 e serialização de anexos em `createDiario`.
- `app/lib/src/features/diario/presentation/add_diario_screen.dart` -- Captura web-safe de fotos com `ImagePicker` como `Uint8List` e exibição de preview local sem caminhos nativos.
- `app/lib/src/features/diario/presentation/legacy_recovery.dart` -- Mecanismo de recuperação de arquivos legados com correspondência estrita de nomes.
- `app/lib/src/sync/operation_queue.dart` -- Validação de integridade de tamanho e hash dos anexos durante a sincronização.
- `app/test/blob_storage_test.dart` -- Suite de testes automatizados Dart cobrindo validação de tipos, limites de cota, cálculo de hash e persistência de blobs.
- `functions/test/pwa-browser.cjs` -- Teste Playwright validando persistência de anexo com navegador fechado e reiniciado offline.

## Tasks & Acceptance

**Execution:**
- [ ] `app/lib/src/features/diario/data/diario_repository.dart` -- Auditar e consolidar validação de magic bytes (JPEG, PNG, WebP) e limites de tamanho.
- [ ] `app/test/blob_storage_test.dart` -- Implementar testes unitários cobrindo todos os cenários da matriz de I/O de blobs locais.
- [ ] `functions/test/pwa-browser.cjs` -- Validar preservação de anexo em teste end-to-end de navegador real Playwright.

**Acceptance Criteria:**
- Given fotos capturadas na interface PWA, when forem processadas por `createDiario`, then os formatos são validados por magic bytes e o hash SHA-256 é calculado antes da confirmação local.
- Given um anexo com tamanho maior que 10 MB ou formato inválido, when submetido, then uma exceção descritiva é lançada e a operação não é enfileirada.
- Given o fechamento da aba ou corte de rede com operações pendentes, when o app for recarregado offline, then os bytes dos anexos estão íntegros na fila IndexedDB.

## Implementation Notes

## Spec Change Log

## Review Triage Log
