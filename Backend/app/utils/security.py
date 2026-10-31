"""Émission / vérification des JWT (PyJWT) et jetons de vérification.

Choix assumés pour une application policière :
  * access token court (30 min) + refresh token long (14 j) ;
  * `jti` unique par jeton, révocable via la table `token_denylist` (logout réel) ;
  * empreinte SHA-256 stockée pour les OTP (le code en clair n'est jamais persisté).
"""
from __future__ import annotations

import hashlib
import secrets
import time
import uuid
from datetime import datetime, timedelta
from typing import Any

import jwt
from flask import current_app, has_app_context

from ..exceptions import UnauthorizedError

# --------------------------------------------------------------------------- mots de passe


def hash_password(raw: str) -> str:
    from ..extensions import bcrypt

    return bcrypt.generate_password_hash(raw).decode("utf-8")


def check_password(hashed: str, raw: str) -> bool:
    from ..extensions import bcrypt

    try:
        return bcrypt.check_password_hash(hashed, raw)
    except Exception:  # hash malformé / incompatible
        return False


# --------------------------------------------------------------------------- JWT


def _cfg(key: str, default=None):
    return current_app.config.get(key, default) if has_app_context() else default


def _now() -> int:
    return int(time.time())


def _base_claims(user_id: int, typ: str, roles: list[str]) -> dict[str, Any]:
    ttl = (
        _cfg("JWT_ACCESS_TTL")
        if typ == "access"
        else _cfg("JWT_REFRESH_TTL")
    )
    now = _now()
    return {
        "sub": str(user_id),
        "typ": typ,
        "jti": str(uuid.uuid4()),
        "iat": now,
        "nbf": now,
        "exp": now + int(ttl.total_seconds()),
        "iss": _cfg("JWT_ISSUER", "securite-sociale-v2"),
        "roles": roles,
    }


def _sign(claims: dict[str, Any]) -> str:
    return jwt.encode(
        claims,
        _cfg("JWT_SECRET_KEY"),
        algorithm=_cfg("JWT_ALGORITHM", "HS256"),
    )


def issue_access_token(user) -> dict[str, Any]:
    claims = _base_claims(user.id, "access", user.role_names)
    return {
        "token": _sign(claims),
        "jti": claims["jti"],
        "expires_in": int(_cfg("JWT_ACCESS_TTL").total_seconds()),
        "exp": claims["exp"],
    }


def issue_refresh_token(user) -> dict[str, Any]:
    claims = _base_claims(user.id, "refresh", user.role_names)
    return {
        "token": _sign(claims),
        "jti": claims["jti"],
        "expires_in": int(_cfg("JWT_REFRESH_TTL").total_seconds()),
        "exp": claims["exp"],
    }


def decode_token(token: str, expected_type: str = "access") -> dict[str, Any]:
    """Décode et valide un JWT. Lève `UnauthorizedError` en cas de problème."""
    try:
        claims = jwt.decode(
            token,
            _cfg("JWT_SECRET_KEY"),
            algorithms=[_cfg("JWT_ALGORITHM", "HS256")],
            issuer=_cfg("JWT_ISSUER", "securite-sociale-v2"),
            options={"require": ["exp", "iat", "sub", "jti", "typ"]},
        )
    except jwt.ExpiredSignatureError as exc:
        raise UnauthorizedError(
            "Jeton expiré. Prolongez la session via /auth/refresh."
        ) from exc
    except jwt.InvalidTokenError as exc:
        raise UnauthorizedError(f"Jeton invalide : {exc}") from exc

    if claims.get("typ") != expected_type:
        raise UnauthorizedError("Type de jeton incorrect pour cette opération.")
    return claims


def is_revoked(jti: str) -> bool:
    from ..extensions import db
    from ..models import TokenDenylist

    return (
        db.session.query(TokenDenylist.id)
        .filter(TokenDenylist.jti == jti)
        .first()
        is not None
    )


def revoke_token(jti: str, user_id: int | None, exp: int) -> None:
    from ..extensions import db
    from ..models import TokenDenylist

    expire_at = datetime.fromtimestamp(exp)
    # Pas de doublon : un même `jti` ne peut être révoqué qu'une fois.
    exists = db.session.query(TokenDenylist.id).filter(TokenDenylist.jti == jti).first()
    if exists:
        return
    db.session.add(
        TokenDenylist(jti=jti, id_user=user_id, expire_at=expire_at)
    )


# --------------------------------------------------------------------------- OTP / hash


def generate_otp(length: int = 6) -> str:
    return "".join(secrets.choice("0123456789") for _ in range(length))


def hash_jeton(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def otp_expiry(minutes: int | None = None) -> datetime:
    minutes = minutes if minutes is not None else int(
        _cfg("OTP_TTL_MINUTES", 15)
    )
    return datetime.now() + timedelta(minutes=minutes)
