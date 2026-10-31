"""Gestion des comptes utilisateurs : `/api/v1/users/*`."""
from __future__ import annotations

from flask import Blueprint, current_app, request

from ..exceptions import ValidationFailed
from ..models import Role
from ..services import auth_service, user_service
from ..utils.decorators import current_user, login_required, require_permission, require_role
from ..utils.payload import payload, query_int
from ..utils.responses import created, no_content, ok, paginated

users_bp = Blueprint("users", __name__)


# --------------------------------------------------------------------------- listing


@users_bp.get("")
@login_required
@require_permission("users.lire")
def lister():
    items, total = user_service.lister(
        page=query_int("page", 1) or 1,
        per_page=query_int("per_page", 20) or 20,
        q=request.args.get("q"),
        role=request.args.get("role"),
        statut=request.args.get("statut"),
        id_commissariat=query_int("id_commissariat"),
    )
    return paginated([u.to_dict(with_roles=True) for u in items], query_int("page", 1) or 1, query_int("per_page", 20) or 20, total)


@users_bp.get("/<int:user_id>")
@login_required
@require_permission("users.lire")
def detail(user_id: int):
    return ok(data=user_service.recuperer(user_id).to_dict(with_permissions=True))


# ----------------------------------------------------------------------- création


@users_bp.post("")
@login_required
@require_permission("users.creer")
def creer():
    """Crée un compte avec les rôles de son choix (usage policier / administration)."""
    data = payload()
    roles = data.get("roles") or ([data["role"]] if data.get("role") else [])
    if not roles:
        raise ValidationFailed(
            "Rôle requis.",
            errors={"roles": ["Fournissez au moins un rôle (ex. policier)."]},
        )
    result = auth_service.register(data, roles_autorises=tuple(r.nom for r in Role.query.all()))
    return created(
        data={
            "user": result["user"].to_dict(with_permissions=True),
            "access_token": result["access"]["token"],
            "expires_in": result["access"]["expires_in"],
            "refresh_token": result["refresh"]["token"],
        },
        message="Compte créé.",
    )


# --------------------------------------------------------------------------- mise à jour


@users_bp.patch("/<int:user_id>")
@login_required
@require_permission("users.maj")
def modifier(user_id: int):
    cible = user_service.recuperer(user_id)
    return ok(
        data=user_service.modifier(cible, payload(), current_user()).to_dict(with_permissions=True),
        message="Utilisateur mis à jour.",
    )


@users_bp.post("/<int:user_id>/avatar")
@login_required
def avatar(user_id: int):
    cible = user_service.recuperer(user_id)
    fichier = request.files.get("image") or request.files.get("avatar")
    if fichier is None or not fichier.filename:
        raise ValidationFailed(
            "Aucun fichier reçu.",
            errors={"image": ["Envoyez le fichier sous le nom de champ « image »."]},
        )
    nom = user_service.changer_avatar(
        cible,
        fichier,
        current_user(),
        dossier=current_app.config["UPLOAD_FOLDER"],
        autorisees=current_app.config["ALLOWED_AVATAR_EXT"],
    )
    return ok(data={"avatar": nom, "url": f"/static/{nom}"}, message="Avatar mis à jour.")


@users_bp.put("/<int:user_id>/roles")
@login_required
@require_role("super_admin")
def attribuer_roles(user_id: int):
    cible = user_service.recuperer(user_id)
    data = payload()
    roles = data.get("roles")
    if roles is None and data.get("role"):
        roles = [data["role"]]
    return ok(
        data=user_service.attribuer_roles(cible, roles or [], current_user()).to_dict(
            with_permissions=True
        ),
        message="Rôles mis à jour.",
    )


@users_bp.post("/<int:user_id>/statut")
@login_required
@require_permission("users.suspendre")
def changer_statut(user_id: int):
    cible = user_service.recuperer(user_id)
    statut = payload().get("statut")
    if not statut:
        raise ValidationFailed("Statut requis.", errors={"statut": ["Ce champ est obligatoire."]})
    return ok(
        data=user_service.changer_statut(cible, statut, current_user()).to_dict(),
        message="Statut modifié.",
    )


@users_bp.delete("/<int:user_id>")
@login_required
@require_permission("users.supprimer")
def supprimer(user_id: int):
    cible = user_service.recuperer(user_id)
    user_service.supprimer(cible, current_user())
    return no_content("Compte supprimé (suppression douce).")


# --------------------------------------------------------------------------- rôles


@users_bp.get("/moi/roles")
@login_required
def mes_roles():
    user = current_user()
    return ok(
        data={
            "roles": user.role_names,
            "permissions": sorted(user.permission_codes),
        }
    )
