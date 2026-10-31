"""Temps réel (Socket.IO) : poussée des alertes et notifications aux clients.

Protocole côté client (React Native, `socket.io-client` déjà présent) :

    const socket = io(URL, { auth: { token: accessToken } });

Salles rejointes automatiquement à la connexion :
  * `user:<id>`          — l'utilisateur lui-même
  * `commissariat:<id>`  — la file du commissariat (membres des forces uniquement)

Toutes les fonctions d'émission sont « best effort » : une panne du canal
temps réel ne doit jamais faire échouer la requête HTTP correspondante.
"""
from __future__ import annotations

import logging
from collections.abc import Iterable

from flask import has_app_context, request
from sqlalchemy import event as sa_event
from sqlalchemy.orm import Session as SASession

from .exceptions import UnauthorizedError
from .extensions import db, socketio
from .utils.security import decode_token, is_revoked

logger = logging.getLogger("securite.realtime")

__all__ = [
    "enregistrer_handlers",
    "notifier_utilisateur",
    "notifier_commissariat",
    "notifier_salles",
    "diffuser",
    "salles_de",
    "prevoir",
]

# File d'attente d'émissions : elles ne partent qu'après un `commit` réel,
# jamais sur une transaction qui a été annulée.
_en_attente: list[tuple[list[str], str, dict]] = []


def prevoir(salles: Iterable[str], evenement: str, **donnees) -> None:
    """Programme une émission pour la fin de la transaction courante."""
    salles_liste = list(dict.fromkeys(salles))
    if not salles_liste:
        return
    _en_attente.append((salles_liste, evenement, donnees))


@sa_event.listens_for(SASession, "after_commit")
def _emettre_apres_commit(session) -> None:
    if not _en_attente:
        return
    a_emettre, _en_attente[:] = list(_en_attente), []
    for salles, evenement, donnees in a_emettre:
        notifier_salles(salles, evenement, **donnees)


@sa_event.listens_for(SASession, "after_rollback")
def _oublier_apres_rollback(session) -> None:
    if _en_attente:
        logger.debug("%d émission(s) annulée(s) par rollback", len(_en_attente))
        _en_attente.clear()


# --------------------------------------------------------------------- salles


def salles_de(user) -> list[str]:
    """Salles auxquelles un utilisateur a droit."""
    salles = [f"user:{user.id}"]
    if user.id_commissariat and user.est_policier():
        salles.append(f"commissariat:{user.id_commissariat}")
    return salles


# ------------------------------------------------------------------ émission


def notifier_salles(salles: Iterable[str] | str, evenement: str, **donnees) -> bool:
    """Émet sur une ou plusieurs salles. Renvoie `False` si le canal est indisponible."""
    if not has_app_context():
        logger.debug("Émission ignorée (hors contexte d'application) : %s", evenement)
        return False
    try:
        socketio.emit(evenement, donnees, to=list(salles) if not isinstance(salles, str) else salles)
        return True
    except Exception as exc:
        logger.warning("Échec d'émission Socket.IO (%s) : %s", evenement, exc)
        return False


def notifier_utilisateur(user_id: int, evenement: str, **donnees) -> bool:
    return notifier_salles(f"user:{user_id}", evenement, **donnees)


def notifier_commissariat(commissariat_id: int, evenement: str, **donnees) -> bool:
    return notifier_salles(f"commissariat:{commissariat_id}", evenement, **donnees)


def diffuser(evenement: str, **donnees) -> bool:
    """Broadcast à tous les clients connectés (usage rare : annonces système)."""
    return notifier_salles([], evenement, **donnees)


# ------------------------------------------------------------------ handlers


def enregistrer_handlers(app) -> None:
    """Attache `connect` / `disconnect` à la Socket.IO de l'application."""

    @socketio.on("connect")
    def _connect(auth=None):
        from flask_socketio import join_room

        token = None
        if isinstance(auth, dict):
            token = auth.get("token") or auth.get("access_token")
        token = token or request.args.get("token")
        if not token:
            logger.warning("Connexion Socket.IO refusée : jeton absent.")
            return False

        try:
            claims = decode_token(token, expected_type="access")
            if is_revoked(claims["jti"]):
                raise UnauthorizedError("Jeton révoqué.")
        except UnauthorizedError as exc:
            logger.warning("Connexion Socket.IO refusée : %s", exc.message)
            return False

        from .models import User

        user = db.session.get(User, int(claims["sub"]))
        if user is None or user.deleted_at is not None or not user.est_actif:
            logger.warning("Connexion Socket.IO refusée : compte %s indisponible.", claims["sub"])
            return False

        for salle in salles_de(user):
            join_room(salle)
        logger.info(
            "Socket.IO connecté : user=%s salles=%s", user.id, ",".join(salles_de(user))
        )
        return True

    @socketio.on("disconnect")
    def _disconnect(*_args, **_kwargs):
        logger.debug("Socket.IO déconnecté")

    @socketio.on("ping_client")
    def _ping_client():
        """Keep-alive demandé par le client."""
        return {"ok": True}
