"""Alertes : déclenchement citoyen et file de traitement policière — `/api/v1/alertes`."""
from __future__ import annotations

from flask import Blueprint, request

from ..models import TypeAlerte
from ..services import alerte_service, geo_service, preuve_service
from ..services.validators import Payload
from ..utils.decorators import current_user, login_required, require_permission
from ..utils.payload import payload, query_float, query_int
from ..utils.responses import created, no_content, ok, paginated

alertes_bp = Blueprint("alertes", __name__)


@alertes_bp.get("/types")
@login_required
def types_alertes():
    """Types d'alertes actifs (pour le sélecteur de l'application)."""
    return ok(
        data=[
            t.to_dict()
            for t in TypeAlerte.query.filter(TypeAlerte.statut == 1).order_by(TypeAlerte.id).all()
        ]
    )


@alertes_bp.post("")
@login_required
@require_permission("alertes.creer")
def creer():
    alerte = alerte_service.creer(payload(), current_user())
    return created(data=alerte.to_dict(), message="Alerte enregistrée et transmise.")


@alertes_bp.get("")
@login_required
@require_permission("alertes.lire")
def lister():
    page, per_page = query_int("page", 1) or 1, query_int("per_page", 20) or 20
    items, total = alerte_service.lister(
        current_user(),
        page=page,
        per_page=per_page,
        statut=request.args.get("statut"),
        urgence=request.args.get("niveau_urgence"),
        id_commissariat=query_int("id_commissariat"),
        id_user=query_int("id_user"),
        q=request.args.get("q"),
    )
    return paginated([a.to_dict() for a in items], page, per_page, total)


@alertes_bp.get("/<int:alerte_id>")
@login_required
@require_permission("alertes.lire")
def detail(alerte_id: int):
    alerte = alerte_service.recuperer(alerte_id, current_user())
    data = alerte.to_dict()
    preuves, _ = preuve_service.lister(
        current_user(), entite_type="alerte", entite_id=alerte.id, per_page=100
    )
    data["preuves"] = [p.to_dict(with_uploadeur=False) for p in preuves]
    return ok(data=data)


@alertes_bp.post("/<int:alerte_id>/prendre-en-charge")
@login_required
@require_permission("alertes.assigner")
def prendre_en_charge(alerte_id: int):
    alerte = alerte_service.recuperer(alerte_id, current_user())
    return ok(
        data=alerte_service.prendre_en_charge(alerte, current_user()).to_dict(),
        message="Alerte prise en charge.",
    )


@alertes_bp.post("/<int:alerte_id>/assigner")
@login_required
@require_permission("alertes.assigner")
def assigner(alerte_id: int):
    p = Payload(payload())
    policier_id = p.entier("id_policier_assignee", requis=True, min_val=1)
    p.fail_if_errors()
    alerte = alerte_service.recuperer(alerte_id, current_user())
    return ok(
        data=alerte_service.assigner(alerte, policier_id, current_user()).to_dict(),
        message="Alerte assignée.",
    )


@alertes_bp.patch("/<int:alerte_id>/statut")
@login_required
@require_permission("alertes.traiter")
def changer_statut(alerte_id: int):
    alerte = alerte_service.recuperer(alerte_id, current_user())
    return ok(
        data=alerte_service.changer_statut(alerte, payload(), current_user()).to_dict(),
        message="Statut mis à jour.",
    )


@alertes_bp.post("/<int:alerte_id>/ouvrir-cas")
@login_required
@require_permission("cas.creer")
def ouvrir_cas(alerte_id: int):
    alerte = alerte_service.recuperer(alerte_id, current_user())
    cas = alerte_service.ouvrir_cas(alerte, payload(), current_user())
    return created(data=cas.to_dict(), message="Dossier ouvert à partir de l'alerte.")


@alertes_bp.delete("/<int:alerte_id>")
@login_required
@require_permission("alertes.supprimer")
def supprimer(alerte_id: int):
    alerte = alerte_service.recuperer(alerte_id, current_user())
    alerte_service.supprimer(alerte, current_user())
    return no_content("Alerte supprimée (suppression douce).")


# ------------------------------------------------------------------------- proximité


@alertes_bp.get("/autour-de-moi")
@login_required
@require_permission("geo.proximite")
def alertes_proches():
    latitude = query_float("lat", requis=True, min_val=-90.0, max_val=90.0)
    longitude = query_float("lon", requis=True, min_val=-180.0, max_val=180.0)
    rayon = query_float("rayon_km", 10.0, min_val=0.1, max_val=500.0) or 10.0
    brut = request.args.get("statuts")
    statuts = [s.strip() for s in brut.split(",") if s.strip()] if brut else None

    resultats = geo_service.alertes_proches(
        latitude,
        longitude,
        rayon_km=rayon,
        limite=query_int("limite", 50) or 50,
        statuts=statuts,
    )
    return ok(
        data=resultats,
        meta={"lat": latitude, "lon": longitude, "rayon_km": rayon, "total": len(resultats)},
    )
