"""Runner pytest : exécute les trois suites de vérification.

Les trois fichiers (`smoke_test.py`, `test_metier.py`, `test_temps_reel.py`)
sont des scripts autonomes avec leur propre bilan. On les lance en sous-processus
pour garder un contexte d'application neuf par suite.

    .venv\\Scripts\\pytest.exe
"""
from __future__ import annotations

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BACKEND = os.path.dirname(HERE)

SUITES = ("smoke_test.py", "test_metier.py", "test_temps_reel.py")


def _lancer(script: str) -> tuple[int, str]:
    proc = subprocess.run(
        [sys.executable, os.path.join(HERE, script)],
        cwd=BACKEND,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=300,
    )
    return proc.returncode, (proc.stdout or "") + (proc.stderr or "")


def test_socle_auth_utilisateurs() -> None:
    code, sortie = _lancer("smoke_test.py")
    assert code == 0, f"Échec de smoke_test.py\n{sortie[-4000:]}"
    assert "  ECHEC" not in sortie, f"Vérifications en échec :\n{sortie}"


def test_domaine_metier() -> None:
    code, sortie = _lancer("test_metier.py")
    assert code == 0, f"Échec de test_metier.py\n{sortie[-4000:]}"


def test_temps_reel_et_rate_limit() -> None:
    code, sortie = _lancer("test_temps_reel.py")
    assert code == 0, f"Échec de test_temps_reel.py\n{sortie[-4000:]}"


def test_lint_propre() -> None:
    """Le lint fait partie de la définition de « terminé »."""
    ruff = os.path.join(BACKEND, ".venv", "Scripts", "ruff.exe")
    if not os.path.isfile(ruff):
        ruff = "ruff"
    proc = subprocess.run(
        [ruff, "check", "app", "run.py", "tests"],
        cwd=BACKEND,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=120,
    )
    assert proc.returncode == 0, f"ruff a trouvé des problèmes :\n{proc.stdout}"
