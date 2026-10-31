"""Routes d'authentification : `/api/v1/auth/*`."""
from __future__ import annotations

from flask import Blueprint, current_app, g, jsonify

from ..services import auth_service
from ..utils import ratelimit
from ..utils.decorators import current_user, login_required
from ..utils.payload import payload
from ..utils.responses import created, no_content, ok

auth_bp = Blueprint("auth", __name__)


def _limiter(nom: str, identifiant: str | None = None) -> None:
    """Fenêtre glissante configurée par `<NOM>_MAX` / `<NOM>_WINDOW_SEC`."""
    cfg = current_app.config
    ratelimit.tenter(
        nom,
        identifiant=identifiant,
        max_tentatives=cfg[f"{nom.upper()}_MAX"],
        fenetre=cfg[f"{nom.upper()}_WINDOW_SEC"],
    )


def _session_reponse(result: dict, status_builder, identifiant: str | None = None):
    user = result["user"]
    access, refresh = result["access"], result["refresh"]
    # Une authentification réussie remet le compteur d'échecs à zéro.
    if identifiant:
        ratelimit.reinitialiser("login", identifiant)
    return status_builder(
        data={
            "access_token": access["token"],
            "token_type": "Bearer",
            "expires_in": access["expires_in"],
            "refresh_token": refresh["token"],
            "refresh_expires_in": refresh["expires_in"],
            "user": user.to_dict(with_permissions=True),
        },
        message="Authentification réussie.",
    )


# --------------------------------------------------------------------------- inscription


@auth_bp.post("/register")
def register():
    """Inscription libre : rôle `citoyen` uniquement.

    Un administrateur crée les comptes policiers via `POST /api/v1/users`.
    """
    _limiter("inscription")
    result = auth_service.register(payload(), roles_autorises=auth_service.ROLES_LIBRES)
    return _session_reponse(result, created)


# --------------------------------------------------------------------------- connexion


@auth_bp.post("/login")
def login():
    data = payload()
    identifiant = str(data.get("email") or "").strip().lower()
    _limiter("login", identifiant=identifiant)
    return _session_reponse(auth_service.login(data), ok, identifiant=identifiant)


@auth_bp.post("/refresh")
def refresh():
    result = auth_service.refresh(payload())
    user = result["user"]
    access, refresh_token = result["access"], result["refresh"]
    return ok(
        data={
            "access_token": access["token"],
            "token_type": "Bearer",
            "expires_in": access["expires_in"],
            "refresh_token": refresh_token["token"],
            "refresh_expires_in": refresh_token["expires_in"],
            "user": user.to_dict(with_permissions=True),
        },
        message="Jeton renouvelé.",
    )


@auth_bp.post("/logout")
@login_required
def logout():
    auth_service.logout(g.token_claims)
    return no_content("Session close.")


# ------------------------------------------------------------------------ profil courant


@auth_bp.get("/me")
@login_required
def me():
    user = current_user()
    return ok(data=user.to_dict(with_permissions=True))


@auth_bp.patch("/me")
@login_required
def update_me():
    from ..services import user_service

    user = user_service.modifier(current_user(), payload(), current_user())
    return ok(data=user.to_dict(with_permissions=True), message="Profil mis à jour.")


@auth_bp.post("/change-password")
@login_required
def change_password():
    return ok(data=auth_service.changer_mdp(current_user(), payload()))


# ------------------------------------------------------------------------ vérifications


@auth_bp.post("/send-verification")
@login_required
def send_verification():
    _limiter("verification")
    return ok(
        data=auth_service.demander_verification(current_user(), payload().get("type", "email"))
    )


@auth_bp.post("/verify")
@login_required
def verify():
    _limiter("verification")
    return ok(data=auth_service.confirmer_verification(current_user(), payload()))


# ------------------------------------------------------------------- réinitialisation


@auth_bp.post("/forgot-password")
def forgot_password():
    data = payload()
    _limiter("reset", identifiant=str(data.get("email") or "").strip().lower())
    return ok(data=auth_service.mot_de_passe_oublie(data))


@auth_bp.post("/reset-password")
def reset_password():
    data = payload()
    _limiter("reset", identifiant=str(data.get("email") or "").strip().lower())
    return ok(data=auth_service.reinitialiser_mdp(data))


@auth_bp.get("/_schema")
def _schema():
    """Auto-documentation minimale des routes d'authentification."""
    return jsonify(
        {
            "success": True,
            "data": [
                {"methode": "POST", "chemin": "/api/v1/auth/register"},
                {"methode": "POST", "chemin": "/api/v1/auth/login"},
                {"methode": "POST", "chemin": "/api/v1/auth/refresh"},
                {"methode": "POST", "chemin": "/api/v1/auth/logout"},
                {"methode": "GET", "chemin": "/api/v1/auth/me"},
                {"methode": "PATCH", "chemin": "/api/v1/auth/me"},
                {"methode": "POST", "chemin": "/api/v1/auth/change-password"},
                {"methode": "POST", "chemin": "/api/v1/auth/send-verification"},
                {"methode": "POST", "chemin": "/api/v1/auth/verify"},
                {"methode": "POST", "chemin": "/api/v1/auth/forgot-password"},
                {"methode": "POST", "chemin": "/api/v1/auth/reset-password"},
            ],
        }
    )
