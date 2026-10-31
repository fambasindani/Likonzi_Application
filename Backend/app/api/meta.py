"""Métadonnées de référence et santé du service : `/api/v1/*`."""
from __future__ import annotations

import platform
import time

from flask import Blueprint, current_app, request

from ..extensions import db
from ..models import (
    Commissariat,
    Permission,
    Province,
    Role,
    TypeAlerte,
    TypeObjet,
    User,
    Ville,
)
from ..utils.decorators import login_required, require_permission
from ..utils.payload import query_int
from ..utils.responses import ok

meta_bp = Blueprint("meta", __name__)

_DEMARRAGE = time.time()


# --------------------------------------------------------------------------- santé


@meta_bp.get("/health")
def health():
    base_ok = True
    try:
        db.session.execute(db.text("SELECT 1"))
    except Exception:
        base_ok = False
    payload = {
        "statut": "ok" if base_ok else "degrade",
        "base_de_donnees": "up" if base_ok else "down",
        "python": platform.python_version(),
        "uptime_secondes": int(time.time() - _DEMARRAGE),
        "utilisateurs": None,
    }
    if base_ok:
        payload["utilisateurs"] = (
            db.session.query(User).filter(User.deleted_at.is_(None)).count()
        )
    return ok(data=payload, message="Service opérationnel." if base_ok else "Service dégradé.")


# --------------------------------------------------------------------------- RBAC


@meta_bp.get("/roles")
@login_required
def roles():
    return ok(
        data=[r.to_dict(with_permissions=True) for r in Role.query.order_by(Role.nom).all()]
    )


@meta_bp.get("/permissions")
@login_required
@require_permission("rbac.gerer")
def permissions():
    return ok(data=[p.to_dict() for p in Permission.query.order_by(Permission.module, Permission.code).all()])


# ------------------------------------------------------------------- référentiels


@meta_bp.get("/provinces")
@login_required
def provinces():
    return ok(
        data=[
            {"id": p.id, "code": p.code, "nom": p.nom, "chef_lieu": p.chef_lieu}
            for p in Province.query.order_by(Province.nom).all()
        ]
    )


@meta_bp.get("/villes")
@login_required
def villes():
    id_province = query_int("id_province")
    query = Ville.query
    if id_province:
        query = query.filter(Ville.id_province == id_province)
    return ok(data=[v.to_dict() for v in query.order_by(Ville.nom).all()])


@meta_bp.get("/commissariats")
@login_required
@require_permission("commissariats.lire")
def commissariats():
    query = Commissariat.query.filter(Commissariat.deleted_at.is_(None))
    id_province = query_int("id_province")
    if id_province:
        query = query.filter(Commissariat.id_province == id_province)
    return ok(data=[c.to_dict() for c in query.order_by(Commissariat.nom).all()])


@meta_bp.get("/type-alertes")
@login_required
def type_alertes():
    return ok(
        data=[
            t.to_dict()
            for t in TypeAlerte.query.filter(TypeAlerte.statut == 1)
            .order_by(TypeAlerte.id)
            .all()
        ]
    )


@meta_bp.get("/type-objets")
@login_required
def type_objets():
    return ok(
        data=[
            t.to_dict()
            for t in TypeObjet.query.filter(TypeObjet.statut == 1).order_by(TypeObjet.id).all()
        ]
    )


# -------------------------------------------------------------------------- audit


@meta_bp.get("/audit")
@login_required
@require_permission("audit.lire")
def audit():
    from ..models import AuditLog

    page = query_int("page", 1) or 1
    per_page = min(query_int("per_page", 50) or 50, 200)
    query = AuditLog.query
    action = request.args.get("action")
    if action:
        query = query.filter(AuditLog.action == action)
    total = query.count()
    entries = (
        query.order_by(AuditLog.id.desc()).offset((page - 1) * per_page).limit(per_page).all()
    )
    from ..utils.responses import paginated

    return paginated([e.to_dict() for e in entries], page, per_page, total)


@meta_bp.get("/config-public")
def config_public():
    """Paramètres non sensibles utiles au client mobile au démarrage."""
    return ok(
        data={
            "password_min_length": current_app.config["PASSWORD_MIN_LENGTH"],
            "max_content_length": current_app.config["MAX_CONTENT_LENGTH"],
            "image_max_octets": current_app.config.get("IMAGE_MAX_OCTETS", 200 * 1024),
            "avatar_extensions": sorted(current_app.config["ALLOWED_AVATAR_EXT"]),
            "otp_ttl_minutes": current_app.config["OTP_TTL_MINUTES"],
        }
    )
