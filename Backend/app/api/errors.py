"""Gestionnaires d'erreurs : tout est renvoyé en JSON avec la même enveloppe."""
from __future__ import annotations

import logging

from flask import jsonify
from sqlalchemy.exc import DataError, IntegrityError, OperationalError
from werkzeug.exceptions import BadRequest, HTTPException, RequestEntityTooLarge

from ..exceptions import ApiError

logger = logging.getLogger("securite.api")


def _json_erreur(status: int, code: str, message: str, errors=None):
    body = {"success": False, "message": message, "code": code}
    if errors is not None:
        body["errors"] = errors
    return jsonify(body), status


def _message_integrite(exc: IntegrityError) -> tuple[int, str, str, dict | None]:
    orig = getattr(exc, "orig", None)
    texte = str(orig or exc)
    lower = texte.lower()
    if "duplicate entry" in lower:
        return 409, "conflict", "Contrainte d'unicité violée.", {"detail": texte}
    if "foreign key" in lower:
        return 409, "foreign_key", "Référence inexistante ou encore utilisée.", {"detail": texte}
    return 422, "integrity_error", "Violation d'intégrité des données.", {"detail": texte}


def register_error_handlers(app) -> None:
    @app.errorhandler(ApiError)
    def _api_error(exc: ApiError):
        body, status = _json_erreur(exc.status, exc.code, exc.message, exc.errors)
        for nom, valeur in (exc.headers or {}).items():
            body.headers[nom] = valeur
        return body, status

    @app.errorhandler(IntegrityError)
    def _integrity(exc: IntegrityError):
        from ..extensions import db

        db.session.rollback()
        status, code, message, errors = _message_integrite(exc)
        logger.warning("Intégrité : %s", exc)
        return _json_erreur(status, code, message, errors)

    @app.errorhandler(DataError)
    def _data_error(exc: DataError):
        from ..extensions import db

        db.session.rollback()
        orig = str(getattr(exc, "orig", exc))
        logger.warning("DataError : %s", orig)
        return _json_erreur(
            422,
            "invalid_data",
            "Valeur refusée par la base de données (format ou longueur).",
            {"detail": orig},
        )

    @app.errorhandler(OperationalError)
    def _db_down(exc: OperationalError):
        from ..extensions import db

        db.session.rollback()
        logger.exception("Erreur de connexion à la base")
        return _json_erreur(
            503,
            "database_unavailable",
            "Base de données momentanément indisponible.",
        )

    @app.errorhandler(RequestEntityTooLarge)
    def _too_large(exc: RequestEntityTooLarge):
        return _json_erreur(413, "too_large", "Fichier trop volumineux.")

    @app.errorhandler(BadRequest)
    def _bad_request(exc: BadRequest):
        return _json_erreur(400, "bad_request", str(getattr(exc, "description", exc)))

    @app.errorhandler(HTTPException)
    def _http(exc: HTTPException):
        codes = {
            401: "unauthorized",
            403: "forbidden",
            404: "not_found",
            405: "method_not_allowed",
            415: "unsupported_media_type",
        }
        return _json_erreur(
            exc.code or 500,
            codes.get(exc.code, "http_error"),
            getattr(exc, "description", str(exc)),
        )

    @app.errorhandler(Exception)
    def _unhandled(exc: Exception):
        from ..extensions import db

        db.session.rollback()
        logger.exception("Erreur non gérée")
        if app.config.get("DEBUG"):
            raise exc
        return _json_erreur(500, "internal_error", "Erreur interne du serveur.")
