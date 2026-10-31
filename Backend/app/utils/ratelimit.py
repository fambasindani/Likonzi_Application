"""Limitation de débit (rate limiting) sans dépendance externe.

Fenêtre glissante en mémoire, thread-safe, dimensionnée pour une instance
unique. En production multi-nœuds, brancher Redis/MySQL via `verifier()`.

Usage dans une vue ::

    ratelimit.verifier("login", identifiant=email)
"""
from __future__ import annotations

import threading
import time
from collections import deque

from flask import has_request_context, request

from ..exceptions import ApiError

_lock = threading.Lock()
_fenetres: dict[str, deque[float]] = {}


class RateLimitExceeded(ApiError):
    """429 avec l'en-tête `Retry-After` imposé par la RFC 6585."""

    def __init__(self, nom: str, retry_after: int) -> None:
        super().__init__(
            "Trop de tentatives. Réessayez plus tard.",
            status=429,
            code="rate_limited",
            errors={"detail": [f"Limite « {nom} » atteinte."]},
            headers={"Retry-After": str(max(retry_after, 1))},
        )
        self.retry_after = retry_after


def _cfg_int(nom: str, defaut: int) -> int:
    from flask import current_app, has_app_context

    if not has_app_context():
        return defaut
    try:
        return int(current_app.config.get(nom, defaut))
    except (TypeError, ValueError):
        return defaut


def _actif() -> bool:
    from flask import current_app, has_app_context

    if not has_app_context():
        return True
    return bool(current_app.config.get("RATE_LIMIT_ENABLED", True))


def _ip() -> str:
    if not has_request_context():
        return "0.0.0.0"
    en_tete = request.headers.get("X-Forwarded-For", "")
    ip = en_tete.split(",")[0].strip() or request.remote_addr or "0.0.0.0"
    return ip[:45]


def tenter(
    nom: str,
    *,
    identifiant: str | None = None,
    max_tentatives: int | None = None,
    fenetre: int | None = None,
) -> None:
    """Enregistre une tentative et lève `RateLimitExceeded` si la fenêtre est saturée.

    La clé combine le nom de la règle, l'adresse IP et un identifiant métier
    (e-mail par exemple) : un attaquant ne peut donc pas bloquer les autres
    comptes depuis la même adresse. Une authentification réussie appelle
    `reinitialiser()`.
    """
    if not _actif():
        return

    max_tentatives = max_tentatives or _cfg_int("RATE_LIMIT_MAX", 10)
    fenetre = fenetre or _cfg_int("RATE_LIMIT_WINDOW_SEC", 300)

    cle = f"{nom}|{_ip()}|{(identifiant or '').lower()}"
    maintenant = time.time()

    with _lock:
        trace = _fenetres.setdefault(cle, deque())
        # Purge des occurrences hors fenêtre.
        while trace and maintenant - trace[0] > fenetre:
            trace.popleft()
        if len(trace) >= max_tentatives:
            retry_after = int(trace[0] + fenetre - maintenant) + 1
            raise RateLimitExceeded(nom, retry_after)
        trace.append(maintenant)


def reinitialiser(nom: str, identifiant: str | None = None) -> None:
    """Remet le compteur à zéro (appelé après une authentification réussie)."""
    cle = f"{nom}|{_ip()}|{(identifiant or '').lower()}"
    with _lock:
        _fenetres.pop(cle, None)


def purger() -> None:
    """Vide tous les compteurs (utile en tests)."""
    with _lock:
        _fenetres.clear()


def statistiques() -> dict[str, int]:
    with _lock:
        return {cle: len(trace) for cle, trace in _fenetres.items() if trace}
