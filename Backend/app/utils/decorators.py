"""Décorateurs d'authentification et d'autorisation (RBAC).

`current_user` est stocké sur `g` : une seule requête utilisateur par requête HTTP.
"""
from __future__ import annotations

from functools import wraps

from flask import g, request

from ..exceptions import ForbiddenError, UnauthorizedError
from .security import decode_token, is_revoked


def _charger_utilisateur():
    """Résout l'en-tête `Authorization: Bearer <jwt>` vers un `User` actif."""
    header = request.headers.get("Authorization", "")
    if not header:
        raise UnauthorizedError("En-tête Authorization manquant.")

    parts = header.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise UnauthorizedError("Format attendu : Authorization: Bearer <token>.")

    claims = decode_token(parts[1], expected_type="access")
    if is_revoked(claims["jti"]):
        raise UnauthorizedError("Jeton révoqué. Reconnectez-vous.")

    from ..extensions import db
    from ..models import User

    user = db.session.get(User, int(claims["sub"]))
    if user is None:
        raise UnauthorizedError("Compte introuvable.")
    if user.deleted_at is not None:
        raise UnauthorizedError("Compte supprimé.")
    if not user.est_actif:
        raise ForbiddenError(
            f"Compte en statut « {user.statut} » : accès refusé.",
            errors={"statut": user.statut},
        )

    g.current_user = user
    g.token_claims = claims
    return user


def login_required(view=None):
    """Exige un JWT valide et un compte actif."""

    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            if getattr(g, "current_user", None) is None:
                _charger_utilisateur()
            return func(*args, **kwargs)

        return wrapper

    return decorator(view) if view else decorator


def current_user():
    """Retourne l'utilisateur de la requête (le charge si nécessaire)."""
    user = getattr(g, "current_user", None)
    return user if user is not None else _charger_utilisateur()


def require_permission(*codes: str):
    """Autorise si l'utilisateur possède AU MOINS l'une des permissions demandées."""

    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            user = getattr(g, "current_user", None) or _charger_utilisateur()
            possedees = user.permission_codes
            if not set(codes) & possedees:
                raise ForbiddenError(
                    "Permission insuffisante.",
                    errors={
                        "requis": list(codes),
                        "possedees": sorted(possedees),
                    },
                )
            return func(*args, **kwargs)

        return wrapper

    return decorator


def require_all_permissions(*codes: str):
    """Autorise uniquement si l'utilisateur possède TOUTES les permissions."""

    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            user = getattr(g, "current_user", None) or _charger_utilisateur()
            possedees = user.permission_codes
            manquantes = [c for c in codes if c not in possedees]
            if manquantes:
                raise ForbiddenError(
                    "Permission insuffisante.",
                    errors={"manquantes": manquantes, "possedees": sorted(possedees)},
                )
            return func(*args, **kwargs)

        return wrapper

    return decorator


def require_role(*noms: str):
    """Autorise si l'utilisateur possède AU MOINS l'un des rôles."""

    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            user = getattr(g, "current_user", None) or _charger_utilisateur()
            if not user.has_role(*noms):
                raise ForbiddenError(
                    "Rôle insuffisant.",
                    errors={"requis": list(noms), "actuels": user.role_names},
                )
            return func(*args, **kwargs)

        return wrapper

    return decorator
