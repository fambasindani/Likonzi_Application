"""Objets volés : déclaration, recherche, statuts — `/api/v1/objets`."""
from __future__ import annotations

from flask import Blueprint, request

from ..models import TypeObjet
from ..services import objet_service, preuve_service
from ..utils.decorators import current_user, login_required, require_permission
from ..utils.payload import payload, query_int
from ..utils.responses import created, no_content, ok, paginated

objets_bp = Blueprint("objets", __name__)


@objets_bp.get("/types")
@login_required
def types_objets():
    return ok(
        data=[
            t.to_dict()
            for t in TypeObjet.query.filter(TypeObjet.statut == 1).order_by(TypeObjet.id).all()
        ]
    )


@objets_bp.post("")
@login_required
@require_permission("objets.creer")
def creer():
    objet = objet_service.creer(payload(), current_user())
    return created(data=objet.to_dict(), message="Objet déclaré.")


@objets_bp.get("/recherche")
@login_required
@require_permission("objets.lire")
def rechercher():
    terme = request.args.get("q") or ""
    items = objet_service.rechercher(
        terme,
        current_user(),
        statut=request.args.get("statut"),
        limite=query_int("limite", 50) or 50,
    )
    return ok(
        data=[o.to_dict() for o in items],
        meta={"q": terme, "total": len(items)},
    )


@objets_bp.get("")
@login_required
@require_permission("objets.lire")
def lister():
    page, per_page = query_int("page", 1) or 1, query_int("per_page", 20) or 20
    items, total = objet_service.lister(
        current_user(),
        page=page,
        per_page=per_page,
        statut=request.args.get("statut"),
        id_type=query_int("id_type"),
        q=request.args.get("q"),
    )
    return paginated([o.to_dict() for o in items], page, per_page, total)


@objets_bp.get("/<int:objet_id>")
@login_required
@require_permission("objets.lire")
def detail(objet_id: int):
    objet = objet_service.recuperer(objet_id, current_user())
    data = objet.to_dict()
    preuves, _ = preuve_service.lister(
        current_user(), entite_type="objet", entite_id=objet.id, per_page=100
    )
    data["preuves"] = [p.to_dict(with_uploadeur=False) for p in preuves]
    return ok(data=data)


@objets_bp.patch("/<int:objet_id>")
@login_required
@require_permission("objets.maj")
def modifier(objet_id: int):
    objet = objet_service.recuperer(objet_id, current_user())
    return ok(
        data=objet_service.modifier(objet, payload(), current_user()).to_dict(),
        message="Objet mis à jour.",
    )


@objets_bp.post("/<int:objet_id>/statut")
@login_required
@require_permission("objets.maj")
def changer_statut(objet_id: int):
    objet = objet_service.recuperer(objet_id, current_user())
    return ok(
        data=objet_service.changer_statut(objet, payload(), current_user()).to_dict(),
        message="Statut mis à jour.",
    )


@objets_bp.post("/<int:objet_id>/partager")
@login_required
@require_permission("objets.maj")
def partager(objet_id: int):
    """Transmet l'objet (et ses images) à des amis ou à un collègue."""
    objet = objet_service.recuperer(objet_id, current_user())
    resultat = objet_service.partager(objet.id, payload(), current_user())
    return created(data=resultat, message="Objet transmis à ses destinataires.")

@objets_bp.delete("/<int:objet_id>")
@login_required
@require_permission("objets.supprimer")
def supprimer(objet_id: int):
    objet = objet_service.recuperer(objet_id, current_user())
    objet_service.supprimer(objet, current_user())
    return no_content("Objet supprimé (suppression douce).")
