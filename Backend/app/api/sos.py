"""SOS « minute de grâce » — `/api/v1/sos`."""
from __future__ import annotations

from flask import Blueprint

from ..services import sos_service
from ..utils.decorators import current_user, login_required
from ..utils.payload import payload
from ..utils.responses import created, ok

sos_bp = Blueprint("sos", __name__)


@sos_bp.get("/sos")
@login_required
def etat():
    """État du SOS actif (pour relancer le compte à rebours côté client)."""
    return ok(data=sos_service.etat(current_user().id))


@sos_bp.get("/sos/veille")
@login_required
def veille():
    """Diagnostic de la tâche de fond qui envoie les SOS à l'échéance."""
    return ok(data=sos_service.etat_veille())


@sos_bp.post("/sos")
@login_required
def programmer():
    """Lance le décompte. Corps : `duree_minutes` (5-60), `latitude`, `longitude`."""
    sos = sos_service.programmer(current_user(), payload())
    return created(
        data={"actif": True, "sos": sos.to_dict()},
        message=f"SOS programmé : envoi dans {sos.duree_minutes} min.",
    )


@sos_bp.post("/sos/annuler")
@login_required
def annuler():
    """Annule le SOS avant l'échéance (fausse alerte, personne prévenu)."""
    sos = sos_service.annuler(current_user())
    return ok(data={"actif": False, "sos": sos.to_dict()}, message="SOS annulé.")


@sos_bp.post("/sos/envoyer")
@login_required
def envoyer():
    """Envoie le SOS immédiatement (sans attendre l'échéance)."""
    sos = sos_service.envoyer_maintenant(current_user())
    return ok(data={"actif": False, "sos": sos.to_dict()}, message="SOS envoyé.")


@sos_bp.post("/sos/cloturer")
@login_required
def cloturer():
    """« Je vais bien » : lève le SOS et prévient les amis du rétablissement."""
    sos = sos_service.cloturer(current_user())
    return ok(data={"actif": False, "sos": sos.to_dict()}, message="SOS levé.")
