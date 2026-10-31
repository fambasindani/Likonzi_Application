"""Partages d'objets reçus — `/api/v1/partages`.

Un partage donne accès à un objet (et à ses images) sans en transférer la
propriété : le destinataire peut consulter l'objet et ses preuves, le
propriétaire reste le seul à pouvoir changer son statut.
"""
from __future__ import annotations

from flask import Blueprint, request

from ..services import objet_service
from ..utils.decorators import current_user, login_required, require_permission
from ..utils.payload import query_int
from ..utils.responses import no_content, ok, paginated

partages_bp = Blueprint("partages", __name__)


@partages_bp.get("")
@login_required
@require_permission("objets.lire")
def recus():
    """Objets transmis à l'utilisateur (police et amis)."""
    page = query_int("page", 1) or 1
    per_page = query_int("per_page", 20) or 20
    non_lus = str(request.args.get("non_lues", "")).lower() in {"1", "true", "yes"}
    items, total = objet_service.partages_recus(
        current_user(), page=page, per_page=per_page, non_lus=non_lus
    )
    return paginated([p.to_dict() for p in items], page, per_page, total)


@partages_bp.get("/non-lus")
@login_required
@require_permission("objets.lire")
def non_lus():
    _, total = objet_service.partages_recus(current_user(), page=1, per_page=1, non_lus=True)
    return ok(data={"non_lus": total})


@partages_bp.post("/<int:partage_id>/lu")
@login_required
@require_permission("objets.lire")
def marquer_lu(partage_id: int):
    partage = objet_service.marquer_partage_lu(partage_id, current_user())
    return ok(data=partage.to_dict(), message="Partage marqué comme lu.")


@partages_bp.delete("/<int:partage_id>")
@login_required
@require_permission("objets.lire")
def retirer(partage_id: int):
    from ..exceptions import NotFoundError
    from ..extensions import db
    from ..models import Partage

    partage = db.session.get(Partage, partage_id)
    if partage is None or partage.id_destinataire != current_user().id:
        raise NotFoundError("Partage introuvable.")
    db.session.delete(partage)
    db.session.commit()
    return no_content("Partage retiré.")
