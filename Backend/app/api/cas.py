"""Dossiers (`cas`) et interventions — `/api/v1/cas`, `/api/v1/interventions`."""
from __future__ import annotations

from flask import Blueprint, request

from ..services import cas_service, preuve_service
from ..utils.decorators import current_user, login_required, require_permission
from ..utils.payload import payload, query_int
from ..utils.responses import created, no_content, ok, paginated

cas_bp = Blueprint("cas", __name__)
interventions_bp = Blueprint("interventions", __name__)


# --------------------------------------------------------------------------- dossiers


@cas_bp.post("")
@login_required
@require_permission("cas.creer")
def creer():
    cas = cas_service.creer(payload(), current_user())
    return created(data=cas.to_dict(), message="Dossier ouvert.")


@cas_bp.get("")
@login_required
@require_permission("cas.lire")
def lister():
    page, per_page = query_int("page", 1) or 1, query_int("per_page", 20) or 20
    items, total = cas_service.lister(
        current_user(),
        page=page,
        per_page=per_page,
        statut=request.args.get("statut"),
        priorite=request.args.get("priorite"),
        type_cas=request.args.get("type_cas"),
        id_commissariat=query_int("id_commissariat"),
        q=request.args.get("q"),
    )
    return paginated([c.to_dict(with_details=False) for c in items], page, per_page, total)


@cas_bp.get("/<int:cas_id>")
@login_required
@require_permission("cas.lire")
def detail(cas_id: int):
    cas = cas_service.recuperer(cas_id, current_user())
    data = cas.to_dict()
    data["interventions"] = [
        i.to_dict() for i in cas_service.lister_interventions(cas)
    ]
    preuves, _ = preuve_service.lister(
        current_user(), entite_type="cas", entite_id=cas.id, per_page=100
    )
    data["preuves"] = [p.to_dict(with_uploadeur=False) for p in preuves]
    return ok(data=data)


@cas_bp.patch("/<int:cas_id>")
@login_required
@require_permission("cas.maj")
def modifier(cas_id: int):
    cas = cas_service.recuperer(cas_id, current_user())
    return ok(
        data=cas_service.modifier(cas, payload(), current_user()).to_dict(),
        message="Dossier mis à jour.",
    )


@cas_bp.post("/<int:cas_id>/cloturer")
@login_required
@require_permission("cas.cloturer")
def cloturer(cas_id: int):
    cas = cas_service.recuperer(cas_id, current_user())
    return ok(
        data=cas_service.cloturer(cas, payload(), current_user()).to_dict(),
        message="Dossier clôturé.",
    )


@cas_bp.delete("/<int:cas_id>")
@login_required
@require_permission("cas.supprimer")
def supprimer(cas_id: int):
    cas = cas_service.recuperer(cas_id, current_user())
    cas_service.supprimer(cas, current_user())
    return no_content("Dossier supprimé (suppression douce).")


# ---------------------------------------------------------------------- interventions


@cas_bp.post("/<int:cas_id>/interventions")
@login_required
@require_permission("interventions.creer")
def creer_intervention(cas_id: int):
    cas = cas_service.recuperer(cas_id, current_user())
    intervention = cas_service.creer_intervention(cas, payload(), current_user())
    return created(data=intervention.to_dict(), message="Intervention enregistrée.")


@cas_bp.get("/<int:cas_id>/interventions")
@login_required
@require_permission("interventions.lire")
def lister_interventions(cas_id: int):
    cas = cas_service.recuperer(cas_id, current_user())
    items = cas_service.lister_interventions(cas)
    return ok(data=[i.to_dict() for i in items], meta={"total": len(items)})


@interventions_bp.get("")
@login_required
@require_permission("interventions.lire")
def mes_interventions():
    """Interventions visibles par l'utilisateur (son périmètre de dossier)."""
    from ..extensions import db
    from ..models import Intervention

    page, per_page = query_int("page", 1) or 1, query_int("per_page", 20) or 20
    query = (
        db.session.query(Intervention)
        .join(Intervention.cas)
    )
    query = cas_service.scope_cas(query, current_user())
    total = query.count()
    items = (
        query.order_by(Intervention.date_intervention.desc())
        .offset((max(page, 1) - 1) * per_page)
        .limit(min(max(per_page, 1), 100))
        .all()
    )
    return paginated([i.to_dict() for i in items], page, per_page, total)


@interventions_bp.get("/<int:intervention_id>")
@login_required
@require_permission("interventions.lire")
def detail_intervention(intervention_id: int):
    intervention = cas_service.recuperer_intervention(intervention_id, current_user())
    return ok(data=intervention.to_dict())


@interventions_bp.patch("/<int:intervention_id>")
@login_required
@require_permission("interventions.maj")
def modifier_intervention(intervention_id: int):
    intervention = cas_service.recuperer_intervention(intervention_id, current_user())
    return ok(
        data=cas_service.modifier_intervention(intervention, payload(), current_user()).to_dict(),
        message="Intervention mise à jour.",
    )
