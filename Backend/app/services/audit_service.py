"""Journalisation d'audit — s'exécute dans la même transaction que l'action auditée."""
from __future__ import annotations

from typing import Any

from flask import has_request_context, request

from ..extensions import db
from ..models import AuditLog


def _contexte_requete() -> tuple[str | None, str | None]:
    if not has_request_context():
        return None, None
    ip = request.headers.get("X-Forwarded-For", "").split(",")[0].strip() or request.remote_addr
    ua = request.headers.get("User-Agent")
    return (ip[:45] if ip else None), (ua[:500] if ua else None)


def audit(
    action: str,
    entite: str,
    entite_id: int | None = None,
    description: str | None = None,
    avant: dict[str, Any] | None = None,
    apres: dict[str, Any] | None = None,
    user_id: int | None = None,
) -> AuditLog:
    """Ajoute une entrée d'audit (persistée par le `commit` du service appelant).

    Pour un événement sans écriture métier (ex. connexion), le service appelle
    `db.session.commit()` juste après pour la persister.
    """
    ip, ua = _contexte_requete()
    entry = AuditLog(
        user_id=user_id,
        action=action[:50],
        entite=entite[:100],
        entite_id=entite_id,
        description=description,
        valeurs_avant=avant,
        valeurs_apres=apres,
        ip_address=ip,
        user_agent=ua,
    )
    db.session.add(entry)
    return entry
