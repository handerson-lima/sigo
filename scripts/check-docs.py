#!/usr/bin/env python3
"""Doc-check do SIGO.

Fala (exit != 0) se a narrativa dos docs contradizer a validação ACEITO em
desenvolvimento dos pacotes C0–C6 (docs/validacao-c0-c6.md).

Regras:
- docs/task.md não pode afirmar que C0–C6 "aguardam aprovação" ou
  "permanecem abertos".
- deferred-work.md não pode afirmar que C0–C6 são "não autorizados".
- Coerência básica: task.md deve apontar a validação; a validação deve
  continuar registrando ACEITO.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

TASK = ROOT / "docs" / "task.md"
DEFERRED = ROOT / "_bmad-output" / "implementation-artifacts" / "deferred-work.md"
VALIDACAO = ROOT / "docs" / "validacao-c0-c6.md"

VETADAS_TASK = ("aguardam aprovação", "permanecem abertos")
VETADA_DEFERRED = "não autorizados"


def main() -> int:
    erros = []

    for path in (TASK, DEFERRED, VALIDACAO):
        if not path.is_file():
            erros.append(f"arquivo ausente: {path.relative_to(ROOT)}")
    if erros:
        for e in erros:
            print(f"ERRO: {e}")
        return 1

    task = TASK.read_text(encoding="utf-8")
    deferred = DEFERRED.read_text(encoding="utf-8")
    validacao = VALIDACAO.read_text(encoding="utf-8")

    task_lower = task.casefold()
    deferred_lower = deferred.casefold()

    for frase in VETADAS_TASK:
        if frase in task_lower:
            erros.append(
                f"docs/task.md contém frase vetada sobre C0–C6: {frase!r}"
            )

    if VETADA_DEFERRED in deferred_lower:
        erros.append(
            "deferred-work.md afirma C0–C6 "
            f"{VETADA_DEFERRED!r} (contradiz a validação ACEITO em dev)"
        )

    if "aceito" not in validacao.casefold():
        erros.append(
            "docs/validacao-c0-c6.md não registra mais status ACEITO "
            "(fonte da coerência C0–C6 alterada)"
        )

    if "validacao-c0-c6" not in task_lower:
        erros.append(
            "docs/task.md não referencia docs/validacao-c0-c6.md "
            "(narrativa C0–C6 sem coerência com a validação)"
        )

    if erros:
        for e in erros:
            print(f"ERRO: {e}")
        return 1

    print("doc-check OK: narrativa C0–C6 coerente com validacao-c0-c6.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
