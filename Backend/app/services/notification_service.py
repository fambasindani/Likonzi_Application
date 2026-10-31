"""Notifications internes (table `notifications`) — utilisées par tous les services."""
from __future__ import annotations

from collections.abc import Iterable

from ..extensions import db
from ..models import Notification
from ..realtime import prevoir


def creer_notification(
    id_user: int,
    titre: str,
    message: str,
    *,
    type_notif: str = "systeme",
    id_sender: int | None = None,
    entite_type: str | None = None,
    entite_id: int | None = None,
    lien: str | None = None,
) -> Notification:
    """Ajoute une notification (persistée et poussée par le commit du service appelant)."""
    notif = Notification(
        id_user=id_user,
        id_sender=id_sender,
        type=type_notif,
        titre=titre[:150],
        message=message,
        entite_type=entite_type,
        entite_id=entite_id,
        lien=lien,
    )
    db.session.add(notif)
    # Poussée temps réel : partie automatiquement si la transaction est annulée.
    prevoir(
        [f"user:{id_user}"],
        "notification",
        type=type_notif,
        titre=notif.titre,
        message=message,
        entite_type=entite_type,
        entite_id=entite_id,
        lien=lien,
    )
    return notif


def notifier_groupe(
    destinataires: Iterable[int],
    titre: str,
    message: str,
    **kwargs,
) -> list[Notification]:
    """Notifie plusieurs destinataires (dédoublonnés, zéro destinataire ignoré)."""
    vus: set[int] = set()
    creees: list[Notification] = []
    for id_user in destinataires:
        if not id_user or id_user in vus:
            continue
        vus.add(id_user)
        creees.append(creer_notification(id_user, titre, message, **kwargs))
    return creees
