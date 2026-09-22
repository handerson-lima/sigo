#!/usr/bin/env python3
"""Doc-check do SIGO.

Fala (exit != 0) se a narrativa dos docs contradizer a validação ACEITO em
desenvolvimento dos pacotes C0–C6 (docs/validacao-c0-c6.md).

Regras:
- docs/task.md não pode afirmar que C0–C6 "aguardam aprovação" ou
  "permanecem abertos" (variantes sem acento/pleonasmo também são vetadas).
- deferred-work.md não pode afirmar, no bloco de status C0–C6, que os
  pacotes são "não autorizados".
- Coerência básica: task.md deve apontar a validação; a validação deve
  registrar ACEITO (e não "NÃO ACEITO").

--self-test: reexecuta os vetos contra uma cópia temporária e exige
exit 0 no estado limpo e exit 1 nos casos negativos.
"""

import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

TASK = ROOT / "docs" / "task.md"
DEFERRED = ROOT / "_bmad-output" / "implementation-artifacts" / "deferred-work.md"
VALIDACAO = ROOT / "docs" / "validacao-c0-c6.md"

VETADAS_TASK = (
    "aguardam aprovação",
    "permanecem abertos",
    "seguem abertos",
    "aguardando aprovação",
    "aguardando aprovacao",
)
VETADA_DEFERRED = "não autorizados"
VETADAS_TASK_FOLD = (
    "aguardam aprovacao",
    "permanecem abertos",
    "seguem abertos",
    "aguardando aprovacao",
)
VETADA_DEFERRED_FOLD = "nao autorizados"


def _fold(text: str) -> str:
    norm = unicodedata.normalize("NFD", text.casefold())
    return "".join(ch for ch in norm if unicodedata.category(ch) != "Mn")


def _sections_mentioning_c0(deferred: str) -> str:
    """Concatena seções cujo heading cita C0/C0–C6 (independente do acento)."""
    parts = []
    current = []
    current_is_c0 = False
    for line in deferred.splitlines() + ["## "]:
        if line.startswith("## "):
            if current_is_c0:
                parts.append("\n".join(current))
            heading_fold = _fold(line)
            current_is_c0 = "c0" in heading_fold
            current = [line]
        else:
            current.append(line)
    return "\n".join(parts)


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
    task_fold = _fold(task)
    deferred_c0 = _sections_mentioning_c0(deferred)
    deferred_fold = _fold(deferred_c0)
    validacao_lower = validacao.casefold()

    for frase in VETADAS_TASK:
        if _fold(frase) in task_fold:
            erros.append(
                f"docs/task.md contém frase vetada sobre C0–C6: {frase!r}"
            )
    for frase in VETADAS_TASK_FOLD:
        if frase in task_fold and frase not in {_fold(f) for f in VETADAS_TASK}:
            erros.append(
                f"docs/task.md contém variante vetada sobre C0–C6: {frase!r}"
            )

    if (
        _fold(VETADA_DEFERRED) in deferred_fold
        or VETADA_DEFERRED_FOLD in deferred_fold
    ):
        erros.append(
            "deferred-work.md (seções C0–C6) afirma pacotes "
            f"{VETADA_DEFERRED!r} (contradiz a validação ACEITO em dev)"
        )

    if "não aceito" in validacao_lower or "nao aceito" in _fold(validacao):
        erros.append(
            "docs/validacao-c0-c6.md registra status NÃO ACEITO "
            "(fonte da coerência C0–C6 alterada)"
        )
    elif "aceito" not in validacao_lower:
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


def self_test() -> int:
    """Roda o check real e exige exit 1 com frases vetadas reintroduzidas."""
    ok = main()
    if ok != 0:
        print("SELF-TEST FALHOU: estado limpo deveria ser exit 0")
        return 1

    negatives = [
        (TASK, "Todos os pacotes C0–C6 aguardam aprovação e permanecem abertos."),
        (VALIDACAO, "Status geral: **NÃO ACEITO**"),
        (
            DEFERRED,
            "## Correções C0–C6 — status (negativo self-test)\n\n"
            "Pacotes C0–C6 não autorizados neste plano.",
        ),
    ]
    for path, block in negatives:
        original = path.read_text(encoding="utf-8")
        try:
            path.write_text(original + "\n" + block + "\n", encoding="utf-8")
            code = main()
            if code == 0:
                print(f"SELF-TEST FALHOU: caso negativo em {path} deveria ser exit 1")
                return 1
            print(f"self-test negativo OK ({path.name})")
        finally:
            path.write_text(original, encoding="utf-8")

    again = main()
    if again != 0:
        print("SELF-TEST FALHOU: restauração não voltou a exit 0")
        return 1
    print("self-test OK")
    return 0


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        sys.exit(self_test())
    sys.exit(main())
