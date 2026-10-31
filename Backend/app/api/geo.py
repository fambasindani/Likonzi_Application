"""Géolocalisation : positions, proximité — `/api/v1/positions`, `/api/v1/proximite`."""
from __future__ import annotations

from flask import Blueprint, request

from ..services import geo_service
from ..utils.decorators import current_user, login_required, require_permission
from ..utils.payload import query_float, query_int
from ..utils.responses import created, ok, paginated

geo_bp = Blueprint("geo", __name__)


# ------------------------------------------------------------------------ positions


@geo_bp.post("/positions")
@login_required
def enregistrer_position():
    """Tout utilisateur authentifié publie sa position (historique conservé)."""
    position = geo_service.enregistrer_position(request.get_json(silent=True) or request.form, current_user())
    return created(data=position.to_dict(), message="Position enregistrée.")


@geo_bp.get("/positions/moi")
@login_required
def ma_position():
    position = geo_service.derniere_position(current_user().id)
    if position is None:
        return ok(data=None, message="Aucune position enregistrée.")
    return ok(data=position.to_dict())


@geo_bp.get("/positions")
@login_required
@require_permission("geo.lire")
def lister_positions():
    """Dernière position de chaque utilisateur (cartographie policière)."""
    page, per_page = query_int("page", 1) or 1, query_int("per_page", 50) or 50
    if request.args.get("vue") == "derniere":
        data = geo_service.cartographie_positions(
            plusieurs_jours=query_int("jours", 7) or 7
        )
        return ok(data=data, meta={"total": len(data), "vue": "derniere"})

    id_user = query_int("id_user")
    items, total = geo_service.lister_positions(page=page, per_page=per_page, id_user=id_user)
    return paginated([p.to_dict() for p in items], page, per_page, total)


# ------------------------------------------------------------------------ proximité


@geo_bp.get("/proximite/commissariats")
@login_required
@require_permission("geo.proximite")
def commissariats_proches():
    latitude = query_float("lat", requis=True, min_val=-90.0, max_val=90.0)
    longitude = query_float("lon", requis=True, min_val=-180.0, max_val=180.0)
    rayon = query_float("rayon_km", 25.0, min_val=0.1, max_val=500.0) or 25.0
    resultats = geo_service.commissariats_proches(
        latitude, longitude, rayon_km=rayon, limite=query_int("limite", 20) or 20
    )
    return ok(
        data=resultats,
        meta={"lat": latitude, "lon": longitude, "rayon_km": rayon, "total": len(resultats)},
    )
