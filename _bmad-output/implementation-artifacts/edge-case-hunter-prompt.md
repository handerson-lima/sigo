
# Edge Case Hunter Review

**Goal:** You are a pure path tracer. Never comment on whether code is good or bad; only list missing handling.
When a diff is provided, scan only the diff hunks and list boundaries that are directly reachable from the changed lines and lack an explicit guard in the diff.
When no diff is provided (full file or function), treat the entire provided content as the scope.
Ignore the rest of the codebase unless the provided content explicitly references external functions.
A brief secondary deletion check runs as Step 4 when the diff removes code.
A claims check runs as Step 5.

**Inputs:**
- **content** — Content to review, or a path to read it from: diff, full file, or function
- **also_consider** (optional) — Areas to keep in mind during review alongside normal edge-case analysis
- **claims_file** — Path to the spec this change was built from. Do NOT read it before Step 5: the path tracing in Steps 2–3 must finish before the claims are seen.

**MANDATORY: Execute steps in the Execution section IN EXACT ORDER. DO NOT skip steps or change the sequence. When a halt condition triggers, follow its specific instruction exactly. Each action within a step is a REQUIRED action to complete that step.**

**Your method is exhaustive path enumeration — mechanically walk every branch, not hunt by intuition. Report ONLY paths and conditions that lack handling — discard handled ones silently. Do NOT editorialize or add filler. Do not assign severity labels, rankings, or priority levels.**


## EXECUTION

### Step 1: Receive Content

- Take the content to review from the parent message that launched you — inline, or by reading the file it points to (never from this instruction file)
- If no content is supplied, or it is empty, unreadable, or cannot be decoded as text, return `[{"location":"N/A","trigger_condition":"Input empty or undecodable","guard_snippet":"Provide valid content to review","potential_consequence":"Review skipped — no analysis performed"}]` and stop
- Identify content type (diff, full file, or function) to determine scope rules

### Step 2: Exhaustive Path Analysis

**Walk every branching path and boundary condition within scope — report only unhandled ones.**

- If `also_consider` input was provided, incorporate those areas into the analysis
- Walk all branching paths: control flow (conditionals, loops, error handlers, early returns) and domain boundaries (where values, states, or conditions transition). Derive the relevant edge classes from the content itself — don't rely on a fixed checklist. Examples: missing else/default, unguarded inputs, off-by-one loops, arithmetic overflow, implicit type coercion, race conditions, timeout gaps
- Consider implicit branches: the diff special-cases or changes the handling of one or more members of a fixed set of values — enums, status codes, sentinels, type tags, flags, value ranges. The rest of the set is implicit branches (e.g. the diff changes the `RED` and `YELLOW` cases of a `RED`/`YELLOW`/`GREEN` enum; `GREEN` is the implicit branch)
- Consider handle lifetime: when the changed code re-checks, re-fetches, or re-validates something it already held — a handle, index, id, pointer — the re-check exists because an intervening call can invalidate it. Identify that call, what it does to the thing held, and what the changed code silently skips when the re-check fails
- For each call site the diff adds or changes — in test files as well as production code — read the callee's declaration and check the call against it: argument count, order, types, and defaults. Report any mismatch
- For each path: determine whether the content handles it
- Collect only the unhandled paths as findings — discard handled ones silently

### Step 3: Validate Completeness

- Revisit every edge class from Step 2 — e.g., missing else/default, null/empty inputs, off-by-one loops, arithmetic overflow, implicit type coercion, race conditions, timeout gaps
- Add any newly found unhandled paths to findings; discard confirmed-handled ones

### Step 4: Deletion Check

If the diff removed or replaced meaningful code (ignore pure renames and whitespace): load `references/deletion-check.md` and follow it.

### Step 5: Claims Check

Load `references/claims-check.md` and follow it.

### Step 6: Present Findings

Output all findings as a single JSON array following the Output Format specification exactly.


## OUTPUT FORMAT

Return ONLY a valid JSON array of objects. Each edge-case finding contains exactly these four fields:

```json
[{
  "location": "file:start-end (or file:line when single line, or file:hunk when exact line unavailable)",
  "trigger_condition": "one-line description (max 15 words)",
  "guard_snippet": "minimal code sketch that closes the gap (single-line escaped string, no raw newlines or unescaped quotes)",
  "potential_consequence": "what could actually go wrong (max 15 words)"
}]
```

No extra text, no explanations, no markdown wrapping. An empty array `[]` is valid when nothing is found. Deletion findings from Step 4 and claim findings from Step 5, if any, go in the same array with the extra fields defined in `references/deletion-check.md` and `references/claims-check.md`.


## HALT CONDITIONS

- If no content is supplied, or it is empty, unreadable, or cannot be decoded as text, return `[{"location":"N/A","trigger_condition":"Input empty or undecodable","guard_snippet":"Provide valid content to review","potential_consequence":"Review skipped — no analysis performed"}]` and stop
<reference path="references/deletion-check.md">
# Deletion Check

Secondary pass for the Edge Case Hunter — runs only when the diff removed meaningful code. Subordinate to the edge-case pass; findings are usually few or none.

For each chunk of removed or replaced code (ignore pure renames and whitespace), ask: did it carry behavior or a contract that the change neither re-established nor intentionally retired? Add a finding for any resulting regression, orphaned reference, or newly-dead code. Skip anything already covered by your edge-case findings.

Append each finding to the same JSON array as the edge-case findings, with the four standard fields plus:

- `kind`: `"deletion"`
- `confidence`: `"high"`, `"medium"`, or `"low"` — these are inferences; rate them

For a deletion finding the standard fields read as: `location` = the removed item; `trigger_condition` = the behavior or contract it enforced; `guard_snippet` = where or how to re-establish it; `potential_consequence` = the regression or orphan.

Add nothing if nothing qualifies.
</reference>
<reference path="references/claims-check.md">
# Claims Check

Final pass for the Edge Case Hunter. Read the claims file named in the message that launched you now, for the first time; the path tracing is finished and the claims cannot steer it retroactively.

It is the spec the change was built from. Read only its `## Intent` and `## Tasks & Acceptance` sections — the claims live there; ignore the rest of the file. The spec is the change's own account of itself: testimony, not evidence — a claim repeated in a code comment is still the same claim, not confirmation. Extract each checkable claim — what the change does, what it preserves, ordering, arithmetic, and parity with existing code ("exactly as X does") — then try to falsify each one against the code you have already traced. Where your trace is not enough to decide, read the code that decides it: the compared-to function, the actual callee, the state the claim assumes.

Append one finding per falsified claim to the same JSON array, with the four standard fields plus:

- `kind`: `"claim"`
- `confidence`: `"high"`, `"medium"`, or `"low"`

For a claim finding the standard fields read as: `location` = where the code contradicts the claim; `trigger_condition` = the claim, quoted or tightly paraphrased; `guard_snippet` = what the code actually does; `potential_consequence` = what goes wrong for someone who believed the claim.

Verified claims produce nothing. Add nothing if nothing is falsified.
</reference>

## CONTENT SOURCE

"Review content:" in the message that launched you gives the content itself or a path to read it from. Read the file when it is a path; either way that is the content under review, and this instruction file never is.


claims_file (leave unread until your instructions call for it): 
---
title: 'Infraestrutura Segura para Gestão de Logos'
type: 'feature'
created: '2026-09-23'
status: 'in-review'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
baseline_revision: '4ab8840df46244d3114a859f7d695ac33c374bd6'
---

<intent-contract>

## Intent

**Problem:** O sistema permite a gestão de logotipos de construtoras, porém não possui regras seguras no backend (Firestore e Storage) para governar o upload (validação de tamanho, tipo de arquivo) e processamento adequado para prevenir ataques via imagens maliciosas ou muito grandes.

**Approach:** Implementar no `firestore.rules` permissões adequadas, adicionar no `storage.rules` regras rigorosas de upload (limite de 2 MiB, apenas JPEG/PNG/WEBP), e criar uma Cloud Function (`onFinalize` trigger no Storage) que processa as imagens via `sharp`, removendo metadados nocivos, garantindo limite seguro, e salvando o resultado tratado.

## Boundaries & Constraints

**Always:** Manter a proteção no servidor (limites de tamanho no Storage e sanitização na Cloud Function). Apenas administradores da construtora podem enviar ou atualizar o logotipo. Proteger contra loops de trigger (a função não deve processar arquivos já processados).

**Never:** Não confiar na validação client-side para restrições de tamanho ou tipo. Não permitir o armazenamento de metadados nocivos (EXIF, localização).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Upload de arquivo acima de 2 MiB | Arquivo > 2 MiB e `request.auth.uid` admin | Rejeitado por regras de storage | Firebase Storage retorna "Permission denied" |
| Upload de arquivo não-imagem | Arquivo tipo application/pdf, etc. | Rejeitado por regras de storage | Firebase Storage retorna "Permission denied" |
| Upload válido de logo | Imagem válida (<= 2 MiB, jpeg/png/webp) | Storage trigger processa com `sharp`, elimina EXIF e ressalva limpo | N/A |
| Upload por usuário sem privilégios | Usuário não admin tenta alterar logo | Rejeitado (Firebase Rules) | Firebase Storage retorna "Permission denied" |

</intent-contract>

## Code Map

- `storage.rules` -- Adição de rules match para `construtoras/{c}/logos/{filename}` com limites estritos (tamanho `<= 2MB`, `image/*`) e controle de acesso restrito a administradores.
- `firestore.rules` -- Regras de permissão sobre os metadados ou referências do logo, garantindo que o logo possa ser modificado apenas pelo `admin(c)`.
- `functions/package.json` -- Adição da dependência `sharp` e `@types/sharp` (se necessário) para processamento de imagens.
- `functions/src/index.ts` -- Nova Cloud Function de Storage (ex: `processLogoUpload`) para interceptar novos uploads de logos, utilizar o `sharp` para redimensionar (se necessário) e limpar metadados, prevenindo execuções cíclicas infinitas checando metadados/contentType.

## Tasks & Acceptance

**Execution:**
- [x] `storage.rules` -- Adicionar match para `construtoras/{c}/logos/{filename}` permitindo create e update apenas para admin(c), limitando tamanho `request.resource.size <= 2 * 1024 * 1024` e `request.resource.contentType.matches('image/(jpeg|png|webp)')`. -- Restringe payloads pesados e tipos inválidos diretamente na borda.
- [x] `firestore.rules` -- Adicionar permissão (se não houver) para gerenciar o documento ou URL de logo na coleção da construtora, restrito a `admin(c)`. (Atualização da chave `logoUrl` em construtoras ou documento dedicado). -- Assegura autoridade e privilégios.
- [x] `functions/package.json` -- Adicionar `sharp` nas dependencies e `@types/sharp` nas devDependencies, rodar `npm install`. -- Traz suporte nativo robusto a manipulação de imagens (Node).
- [x] `functions/src/index.ts` -- Implementar Cloud Function ouvindo eventos `functions.storage.object().onFinalize`. Identificar o path (logo de construtoras). Baixar a imagem, processar com `sharp` (remover metadados, opcional limite max 10 megapixels), e fazer upload de volta com metadado extra marcando como "processada" para evitar looping eterno. -- Transforma uploads raw perigosos em artefatos seguros para visualização e proxy.

**Acceptance Criteria:**
- Given um upload de imagem > 2MiB num bucket protegido, when as regras avaliarem, then será rejeitado nativamente antes mesmo de disparar Cloud Functions.
- Given um upload válido de imagem 1.5MiB por admin, when o trigger executar, then o arquivo final gravado terá os metadados (EXIF) raspados e constará metadados customizados de processamento.

## Verification

**Commands:**
- `cd functions && npm install && npm run build` -- expected: Sem erros de build ou tipos.

## Auto Run Result

Status: blocked
Blocking condition: no subagents



Review content: 
diff --git a/firestore.rules b/firestore.rules
index 3dc3838..a7b1d06 100644
--- a/firestore.rules
+++ b/firestore.rules
@@ -40,7 +40,7 @@ service cloud.firestore {
   match /construtoras/{c} {
    allow read: if dev() || member(c);
    allow create: if dev() && request.resource.data.id == c;
-   allow update: if admin(c) && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['name','cnpj','address','updatedAt']);
+   allow update: if admin(c) && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['name','cnpj','address','logoUrl','updatedAt']);
    allow delete: if dev();
    match /construtora_members/{uid} { allow read: if signed() && (request.auth.uid == uid || admin(c)); allow write: if dev(); }
    match /commands/{id} { allow read: if dev() || (signed() && resource.data.actor == request.auth.uid); allow write: if dev(); }
diff --git a/functions/package-lock.json b/functions/package-lock.json
index 625e18c..9ddfdf1 100644
--- a/functions/package-lock.json
+++ b/functions/package-lock.json
@@ -7,10 +7,12 @@
       "name": "functions",
       "dependencies": {
         "firebase-admin": "^12.1.0",
-        "firebase-functions": "^5.0.0"
+        "firebase-functions": "^5.0.0",
+        "sharp": "^0.35.4"
       },
       "devDependencies": {
         "@firebase/rules-unit-testing": "5.0.2",
+        "@types/sharp": "^0.31.1",
         "firebase": "12.19.0",
         "firebase-tools": "15.30.1",
         "playwright": "1.63.0",
@@ -80,6 +82,16 @@
         "@electric-sql/pglite": "0.3.16"
       }
     },
+    "node_modules/@emnapi/runtime": {
+      "version": "1.11.3",
+      "resolved": "https://registry.npmjs.org/@emnapi/runtime/-/runtime-1.11.3.tgz",
+      "integrity": "sha512-Xz4Tpyki7XyrpbUK1jR1AhdAdaXyhhY4lZ3neLodmhpuWfy2PAQN5B46sAiU4liOXGLkHypn/qU+jvfWSCYYLA==",
+      "license": "MIT",
+      "optional": true,
+      "dependencies": {
+        "tslib": "^2.4.0"
+      }
+    },
     "node_modules/@fastify/busboy": {
       "version": "3.2.2",
       "resolved": "https://registry.npmjs.org/@fastify/busboy/-/busboy-3.2.2.tgz",
@@ -2501,6 +2513,554 @@
         "hono": "^4"
       }
     },
+    "node_modules/@img/colour": {
+      "version": "1.1.0",
+      "resolved": "https://registry.npmjs.org/@img/colour/-/colour-1.1.0.tgz",
+      "integrity": "sha512-Td76q7j57o/tLVdgS746cYARfSyxk8iEfRxewL9h4OMzYhbW4TAcppl0mT4eyqXddh6L/jwoM75mo7ixa/pCeQ==",
+      "license": "MIT",
+      "engines": {
+        "node": ">=18"
+      }
+    },
+    "node_modules/@img/sharp-darwin-arm64": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-darwin-arm64/-/sharp-darwin-arm64-0.35.4.tgz",
+      "integrity": "sha512-Uhfl4V4lhP2nbUVF9+hyH1+luj86f1gUFeo8ALYxFoULoU+G87D43BfeMP8XHsk9boxAnCY/bf2EHwhA7MuGsA==",
+      "cpu": [
+        "arm64"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "darwin"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-darwin-arm64": "1.3.3"
+      }
+    },
+    "node_modules/@img/sharp-darwin-x64": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-darwin-x64/-/sharp-darwin-x64-0.35.4.tgz",
+      "integrity": "sha512-hWniXY3bG5qKpkKrAwPe4y+VTPmf086YQAnkxWh7uA1YrlRouWGa0M0Mxj3ZjnXFkv7/TD1bTy9lGUK26vRvWw==",
+      "cpu": [
+        "x64"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "darwin"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-darwin-x64": "1.3.3"
+      }
+    },
+    "node_modules/@img/sharp-freebsd-wasm32": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-freebsd-wasm32/-/sharp-freebsd-wasm32-0.35.4.tgz",
+      "integrity": "sha512-lIsKw/BU+kjB4eZjxrYrZmwOJYi3Ajrv66iAlBmUPyKc3HpnloevB1g3wxGD9P/5BbQ1brBGl65VRRrCvQDEqA==",
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "freebsd"
+      ],
+      "dependencies": {
+        "@img/sharp-wasm32": "0.35.4"
+      },
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-darwin-arm64": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-darwin-arm64/-/sharp-libvips-darwin-arm64-1.3.3.tgz",
+      "integrity": "sha512-suTBPTDGrI9WodccaDdwZItTSaBYASlBk1NSfElSHrUfzu3szG6lvIF58+WiFvnfzuK8ZBFS5zE00PxqxnRiPg==",
+      "cpu": [
+        "arm64"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "darwin"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-darwin-x64": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-darwin-x64/-/sharp-libvips-darwin-x64-1.3.3.tgz",
+      "integrity": "sha512-FVJZ5mITMobmXIz/hPDTw0EintTW5H3WfrxwLqEqjiIihlu+hVRyGrFQ60xl0Lxn7Bt3zdpevPaQi0HEzqz9fw==",
+      "cpu": [
+        "x64"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "darwin"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linux-arm": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linux-arm/-/sharp-libvips-linux-arm-1.3.3.tgz",
+      "integrity": "sha512-3rbU4vqXXc3hY/OiXdl52xZvT0F1yEngWfvqudtPJg/KkyiaQw2DRsFrNzpmLvfavbwOq3qXn36GP8obHRULQA==",
+      "cpu": [
+        "arm"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linux-arm64": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linux-arm64/-/sharp-libvips-linux-arm64-1.3.3.tgz",
+      "integrity": "sha512-0DaL0A6Xu6sQSQFwe4iVCrKWU2cCTItnRsYsCdxAMm9NF6twAA9BKnoqy4hqz4+azQ0JHuA26qiUKsf1XJ/v5A==",
+      "cpu": [
+        "arm64"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linux-ppc64": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linux-ppc64/-/sharp-libvips-linux-ppc64-1.3.3.tgz",
+      "integrity": "sha512-cdn1OvUBwsXhbC0zSzJnNzf5MZ/mTrobawDvNXBTxe8VtqKAm0sRuEY2Evzovb/w9JMk4TvRxqt1mekSuJz64w==",
+      "cpu": [
+        "ppc64"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linux-riscv64": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linux-riscv64/-/sharp-libvips-linux-riscv64-1.3.3.tgz",
+      "integrity": "sha512-HjPVx7yKz+0lqdhDlTw1tt90wamBoxhiXpvl1XZpJLiHH4RCJ5yDTqH+VlYPv2fwFs89JFw4c1IexYOcQUi4IQ==",
+      "cpu": [
+        "riscv64"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linux-s390x": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linux-s390x/-/sharp-libvips-linux-s390x-1.3.3.tgz",
+      "integrity": "sha512-neWLh+3yCNThxnfy3c4BbVBeGgt9aftno+XbT56iK28RgeDs3UOFWviLWlUu0bArYVYJaFDK+RRohbicUNCm8Q==",
+      "cpu": [
+        "s390x"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linux-x64": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linux-x64/-/sharp-libvips-linux-x64-1.3.3.tgz",
+      "integrity": "sha512-4vKmvAst9nrowcqquKFAyZJUDolUaIp8uRiN0mWFguJ1IplC9/pitXtlnnlU4aa/eJw3J7i67V+pwUL+wZGdsA==",
+      "cpu": [
+        "x64"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linuxmusl-arm64": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linuxmusl-arm64/-/sharp-libvips-linuxmusl-arm64-1.3.3.tgz",
+      "integrity": "sha512-Y9kQaLMuNoB0bPYOOdcZMaseNrFpPodIWWMrx+CZyydf2xn68j9WYc6sWWRrDwNkzCQjKYfc68L7jKjGlHMibw==",
+      "cpu": [
+        "arm64"
+      ],
+      "libc": [
+        "musl"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-libvips-linuxmusl-x64": {
+      "version": "1.3.3",
+      "resolved": "https://registry.npmjs.org/@img/sharp-libvips-linuxmusl-x64/-/sharp-libvips-linuxmusl-x64-1.3.3.tgz",
+      "integrity": "sha512-fj8Mv0HHfD1Rr+4I68+3agJynxDWtBFgicTbSOb9Bke6pIwzGcJ+RX/yHjmiEGFMCavY/dxvem7MyNaJF+wDiw==",
+      "cpu": [
+        "x64"
+      ],
+      "libc": [
+        "musl"
+      ],
+      "license": "LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-linux-arm": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linux-arm/-/sharp-linux-arm-0.35.4.tgz",
+      "integrity": "sha512-7OAS8gI0EReKGVN2HssHlM6umJgxF5VI3xN0p9FA91p/YO+ou5hiNghLdZ5BEHztwaaK5+bLKRf8x/o2L2nk9A==",
+      "cpu": [
+        "arm"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linux-arm": "1.3.3"
+      }
+    },
+    "node_modules/@img/sharp-linux-arm64": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linux-arm64/-/sharp-linux-arm64-0.35.4.tgz",
+      "integrity": "sha512-De4jpEnAU8Hd5oT0j1G3uL4ZvTuipVMn7YC6vPaJhy6/7EwEae0SVAoBrUMYQbkLGDm85taVWwuPc1a44LTzCQ==",
+      "cpu": [
+        "arm64"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linux-arm64": "1.3.3"
+      }
+    },
+    "node_modules/@img/sharp-linux-ppc64": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linux-ppc64/-/sharp-linux-ppc64-0.35.4.tgz",
+      "integrity": "sha512-2oYZJeIl4kCcMGk4ouZVjnkCtFrpQFlNEtJ6GbxzhHQchwH0NH/qEb9ykmOl29dqwMq+JhFdZn+1ak2FKhI9fQ==",
+      "cpu": [
+        "ppc64"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linux-ppc64": "1.3.3"
+      }
+    },
+    "node_modules/@img/sharp-linux-riscv64": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linux-riscv64/-/sharp-linux-riscv64-0.35.4.tgz",
+      "integrity": "sha512-cPbNChoRURAWdebDIHSenxRpgEdy7JkPydSnUxRm9VvKD7m0/xVaR/8Fzlu81pk5nHEvHH87UZUA7cTtwnbJSA==",
+      "cpu": [
+        "riscv64"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linux-riscv64": "1.3.3"
+      }
+    },
+    "node_modules/@img/sharp-linux-s390x": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linux-s390x/-/sharp-linux-s390x-0.35.4.tgz",
+      "integrity": "sha512-RY0JFY8Fd6RonCBtHz+DvadaPkXDSI1AUn6yWL9TipqkZ1vY8w8evqdgyDFnkm4/K1ve1TvZiaePP5oSd4+WVQ==",
+      "cpu": [
+        "s390x"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linux-s390x": "1.3.3"
+      }
+    },
+    "node_modules/@img/sharp-linux-x64": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linux-x64/-/sharp-linux-x64-0.35.4.tgz",
+      "integrity": "sha512-9qvvEAuk8k89TfWUoX2htWjbAMX8p+NxCppjpcg5k6xMsjhBQPTsoIh36h9Qde4WRuGpJeYnOjdosDn/cnv+OA==",
+      "cpu": [
+        "x64"
+      ],
+      "libc": [
+        "glibc"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linux-x64": "1.3.3"
+      }
+    },
+    "node_modules/@img/sharp-linuxmusl-arm64": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linuxmusl-arm64/-/sharp-linuxmusl-arm64-0.35.4.tgz",
+      "integrity": "sha512-KB5jxpfWQTr0nc3xdHtWChdbifHrBGsd2SM62Eyxrl8afikm+f5qGBU75SJIZBT/S1MC8XyacdlXBMSWq6OURA==",
+      "cpu": [
+        "arm64"
+      ],
+      "libc": [
+        "musl"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linuxmusl-arm64": "1.3.3"
+      }
+    },
+    "node_modules/@img/sharp-linuxmusl-x64": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-linuxmusl-x64/-/sharp-linuxmusl-x64-0.35.4.tgz",
+      "integrity": "sha512-f+eZJZIQNEEd26RPSW+76chwOf1XtA2Y/O+5ocVyLliHkeih3e+jhLVBdNTd2rS3IbNXK8+ug93Vf5ZXtF5Lxg==",
+      "cpu": [
+        "x64"
+      ],
+      "libc": [
+        "musl"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "os": [
+        "linux"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-libvips-linuxmusl-x64": "1.3.3"
+      }
+    },
+    "node_modules/@img/sharp-wasm32": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-wasm32/-/sharp-wasm32-0.35.4.tgz",
+      "integrity": "sha512-zQnl4Kwp7Q6NHsENtU2T/00Zi+w3AQNwz3+UaTyVBy2FpXrzXzGjndpK61onhZjRtRpQXxCTeqw19bVyXOh7jA==",
+      "license": "Apache-2.0 AND LGPL-3.0-or-later AND MIT",
+      "optional": true,
+      "dependencies": {
+        "@emnapi/runtime": "^1.11.3"
+      },
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-webcontainers-wasm32": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-webcontainers-wasm32/-/sharp-webcontainers-wasm32-0.35.4.tgz",
+      "integrity": "sha512-ESfNkywmCfPNyaZjxooddJQiQ+l/nTpGEOGthxiLnIHXC/CmcBixnfwUleX9mCz9ovrUUvKMap/pm8RYbzfwaA==",
+      "cpu": [
+        "wasm32"
+      ],
+      "license": "Apache-2.0",
+      "optional": true,
+      "dependencies": {
+        "@img/sharp-wasm32": "0.35.4"
+      },
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-win32-arm64": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-win32-arm64/-/sharp-win32-arm64-0.35.4.tgz",
+      "integrity": "sha512-iNdlBX9gLVvqe2I3uIJSIKTq6wckP/DYxZtcqxm09x5Gi24DnFBmPAWZmr60ZyYMG0xlzo6goG3670ar+RXvRw==",
+      "cpu": [
+        "arm64"
+      ],
+      "license": "Apache-2.0 AND LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "win32"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-win32-ia32": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-win32-ia32/-/sharp-win32-ia32-0.35.4.tgz",
+      "integrity": "sha512-kqRsbaa5CS6KHlpxnN7WhE6vAAugXyZButpRdvDWetlv6Qv4N9WTcrWzF7tXfB9T7MsoadqdI8hmwLq6UlLvtw==",
+      "cpu": [
+        "ia32"
+      ],
+      "license": "Apache-2.0 AND LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "win32"
+      ],
+      "engines": {
+        "node": "^20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
+    "node_modules/@img/sharp-win32-x64": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/@img/sharp-win32-x64/-/sharp-win32-x64-0.35.4.tgz",
+      "integrity": "sha512-XtmnYhBcrORsJ4XJngyzr/EWP0hRZLAZRFaApdKuviyqF78+ylxh2y06ZmtULAMOnObJ3ucpN0AcwSWnMowTRg==",
+      "cpu": [
+        "x64"
+      ],
+      "license": "Apache-2.0 AND LGPL-3.0-or-later",
+      "optional": true,
+      "os": [
+        "win32"
+      ],
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      }
+    },
     "node_modules/@inquirer/ansi": {
       "version": "1.0.2",
       "resolved": "https://registry.npmjs.org/@inquirer/ansi/-/ansi-1.0.2.tgz",
@@ -3804,6 +4364,16 @@
         "@types/node": "*"
       }
     },
+    "node_modules/@types/sharp": {
+      "version": "0.31.1",
+      "resolved": "https://registry.npmjs.org/@types/sharp/-/sharp-0.31.1.tgz",
+      "integrity": "sha512-5nWwamN9ZFHXaYEincMSuza8nNfOof8nmO+mcI+Agx1uMUk4/pQnNIcix+9rLPXzKrm1pS34+6WRDbDV0Jn7ag==",
+      "dev": true,
+      "license": "MIT",
+      "dependencies": {
+        "@types/node": "*"
+      }
+    },
     "node_modules/@types/tough-cookie": {
       "version": "4.0.5",
       "resolved": "https://registry.npmjs.org/@types/tough-cookie/-/tough-cookie-4.0.5.tgz",
@@ -5434,6 +6004,15 @@
         "npm": "1.2.8000 || >= 1.4.16"
       }
     },
+    "node_modules/detect-libc": {
+      "version": "2.1.2",
+      "resolved": "https://registry.npmjs.org/detect-libc/-/detect-libc-2.1.2.tgz",
+      "integrity": "sha512-Btj2BOOO83o3WyH59e8MgXsxEQVcarkUOpEYrubB0urwnN10yQ364rsiByU11nZlqWYZm05i/of7io4mzihBtQ==",
+      "license": "Apache-2.0",
+      "engines": {
+        "node": ">=8"
+      }
+    },
     "node_modules/discontinuous-range": {
       "version": "1.0.0",
       "resolved": "https://registry.npmjs.org/discontinuous-range/-/discontinuous-range-1.0.0.tgz",
@@ -9816,6 +10395,55 @@
       "integrity": "sha512-E5LDX7Wrp85Kil5bhZv46j8jOeboKq5JMmYM3gVGdGH8xFpPWXUMsNrlODCrkoxMEeNi/XZIwuRvY4XNwYMJpw==",
       "license": "ISC"
     },
+    "node_modules/sharp": {
+      "version": "0.35.4",
+      "resolved": "https://registry.npmjs.org/sharp/-/sharp-0.35.4.tgz",
+      "integrity": "sha512-n++8XWcj+jCOr2IOl7h8LbKnGBDY4aPbmprMONBNFdn0ImXqpGVv5zliDs0V9HbmbCQLpbuo2ej9rAoOQTvMDA==",
+      "license": "Apache-2.0",
+      "dependencies": {
+        "@img/colour": "^1.1.0",
+        "detect-libc": "^2.1.2",
+        "semver": "^7.8.5"
+      },
+      "engines": {
+        "node": ">=20.9.0"
+      },
+      "funding": {
+        "url": "https://opencollective.com/libvips"
+      },
+      "optionalDependencies": {
+        "@img/sharp-darwin-arm64": "0.35.4",
+        "@img/sharp-darwin-x64": "0.35.4",
+        "@img/sharp-freebsd-wasm32": "0.35.4",
+        "@img/sharp-libvips-darwin-arm64": "1.3.3",
+        "@img/sharp-libvips-darwin-x64": "1.3.3",
+        "@img/sharp-libvips-linux-arm": "1.3.3",
+        "@img/sharp-libvips-linux-arm64": "1.3.3",
+        "@img/sharp-libvips-linux-ppc64": "1.3.3",
+        "@img/sharp-libvips-linux-riscv64": "1.3.3",
+        "@img/sharp-libvips-linux-s390x": "1.3.3",
+        "@img/sharp-libvips-linux-x64": "1.3.3",
+        "@img/sharp-libvips-linuxmusl-arm64": "1.3.3",
+        "@img/sharp-libvips-linuxmusl-x64": "1.3.3",
+        "@img/sharp-linux-arm": "0.35.4",
+        "@img/sharp-linux-arm64": "0.35.4",
+        "@img/sharp-linux-ppc64": "0.35.4",
+        "@img/sharp-linux-riscv64": "0.35.4",
+        "@img/sharp-linux-s390x": "0.35.4",
+        "@img/sharp-linux-x64": "0.35.4",
+        "@img/sharp-linuxmusl-arm64": "0.35.4",
+        "@img/sharp-linuxmusl-x64": "0.35.4",
+        "@img/sharp-webcontainers-wasm32": "0.35.4",
+        "@img/sharp-win32-arm64": "0.35.4",
+        "@img/sharp-win32-ia32": "0.35.4",
+        "@img/sharp-win32-x64": "0.35.4"
+      },
+      "peerDependenciesMeta": {
+        "@types/node": {
+          "optional": true
+        }
+      }
+    },
     "node_modules/shebang-command": {
       "version": "2.0.0",
       "resolved": "https://registry.npmjs.org/shebang-command/-/shebang-command-2.0.0.tgz",
diff --git a/functions/package.json b/functions/package.json
index 522d6db..70be4d3 100644
--- a/functions/package.json
+++ b/functions/package.json
@@ -22,10 +22,12 @@
   "main": "lib/index.js",
   "dependencies": {
     "firebase-admin": "^12.1.0",
-    "firebase-functions": "^5.0.0"
+    "firebase-functions": "^5.0.0",
+    "sharp": "^0.35.4"
   },
   "devDependencies": {
     "@firebase/rules-unit-testing": "5.0.2",
+    "@types/sharp": "^0.31.1",
     "firebase": "12.19.0",
     "firebase-tools": "15.30.1",
     "playwright": "1.63.0",
diff --git a/functions/src/index.ts b/functions/src/index.ts
index 0691671..2d9314a 100644
--- a/functions/src/index.ts
+++ b/functions/src/index.ts
@@ -328,3 +328,29 @@ export const finalizeDiario = callable('finalizeDiario', async (d, uid) => {
     tx.create(command, {payloadHash: h, result, actor: uid, at: stamp()}); audit(tx, uid, 'finalizeDiario', ref.path); return result;
   });
 });
+
+export const processLogo = functions.storage.object().onFinalize(async (object) => {
+  if (!object.name || !object.name.match(/^construtoras\/[^\/]+\/logos\/[^\/]+$/)) return;
+  if (object.metadata?.processed === 'true') return;
+
+  const bucket = admin.storage().bucket(object.bucket);
+  const file = bucket.file(object.name);
+  const [metadata] = await file.getMetadata();
+
+  if (!metadata.contentType?.startsWith('image/')) return;
+
+  const [buffer] = await file.download();
+  // @ts-ignore
+  const sharp = (await import('sharp')).default || (await import('sharp'));
+  
+  const processedBuffer = await sharp(buffer)
+    .resize({ width: 2000, height: 2000, fit: 'inside', withoutEnlargement: true })
+    .toBuffer();
+
+  await file.save(processedBuffer, {
+    metadata: {
+      contentType: metadata.contentType,
+      metadata: { processed: 'true' }
+    }
+  });
+});
diff --git a/storage.rules b/storage.rules
index e539566..d092b09 100644
--- a/storage.rules
+++ b/storage.rules
@@ -5,7 +5,13 @@ service firebase.storage {
   function dev() { return signed() && firestore.exists(/databases/(default)/documents/dev_roles/$(request.auth.uid)) && firestore.get(/databases/(default)/documents/dev_roles/$(request.auth.uid)).data.get('isActive', false) == true; }
   function cm(c) { return firestore.get(/databases/(default)/documents/construtoras/$(c)/construtora_members/$(request.auth.uid)).data; }
   function om(c,o) { return firestore.get(/databases/(default)/documents/construtoras/$(c)/obras/$(o)/members/$(request.auth.uid)).data; }
+  function admin(c) { return dev() || (signed() && cm(c).get('isActive',false) == true && (cm(c).get('isAdmin',false) == true || cm(c).get('isOwner',false) == true || cm(c).get('role', '') == 'admin' || cm(c).get('role', '') == 'owner')); }
   function access(c,o) { return dev() || (signed() && cm(c).get('isActive',false) == true && (cm(c).get('isAdmin',false) == true || cm(c).get('isOwner',false) == true || (om(c,o).get('isActive',false) == true && (om(c,o).get('isAdmin',false) == true || om(c,o).get('isOwner',false) == true || 'diario' in om(c,o).get('modules',[]) || 'rdo' in om(c,o).get('modules',[]) || 'validacao' in om(c,o).get('modules',[]) || 'qualidade' in om(c,o).get('modules',[]) || 'epi' in om(c,o).get('modules',[]) || 'adm' in om(c,o).get('modules',[]) || 'financeiro' in om(c,o).get('modules',[]) || 'compras' in om(c,o).get('modules',[]) || 'almoxarifado' in om(c,o).get('modules',[]))))); }
+  match /construtoras/{c}/logos/{filename} {
+   allow read: if true;
+   allow create, update: if admin(c) && request.resource.size > 0 && request.resource.size <= 2 * 1024 * 1024 && request.resource.contentType.matches('image/(jpeg|png|webp)');
+   allow delete: if admin(c);
+  }
   match /construtoras/{c}/obras/{o}/diarios/{diary}/{uid}/{attachment} {
    allow read: if access(c,o);
    allow create: if resource == null && access(c,o) && request.auth.uid == uid && request.resource.size > 0 && request.resource.size <= 10 * 1024 * 1024 && request.resource.contentType.matches('image/(jpeg|png|webp)') && request.resource.metadata.keys().hasOnly(['sha256','owner']) && request.resource.metadata.owner == uid && request.resource.metadata.sha256.matches('^[a-f0-9]{64}$');


Do not invoke any skill, and do not spawn subagents of your own — you are the reviewer. If the instruction file is unreadable, report that exact failure and stop. Return your findings as text in your final message; do not route them through any findings-reporting tool the host may offer.
