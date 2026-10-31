"""Erreurs métier levées par les services et transformées en JSON par `api/errors.py`."""
from __future__ import annotations

from typing import Any


class ApiError(Exception):
    """Erreur contrôlée destinée au client."""

    def __init__(
        self,
        message: str,
        status: int = 400,
        code: str = "bad_request",
        errors: dict[str, Any] | list[str] | None = None,
        payload: dict[str, Any] | None = None,
        headers: dict[str, str] | None = None,
    ) -> None:
        super().__init__(message)
        self.message = message
        self.status = status
        self.code = code
        self.errors = errors
        self.payload = payload or {}
        self.headers = headers or {}


class NotFoundError(ApiError):
    def __init__(self, message: str = "Ressource introuvable.") -> None:
        super().__init__(message, status=404, code="not_found")


class UnauthorizedError(ApiError):
    def __init__(self, message: str = "Authentification requise.") -> None:
        super().__init__(message, status=401, code="unauthorized")


class ForbiddenError(ApiError):
    def __init__(
        self,
        message: str = "Accès refusé.",
        errors: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(message, status=403, code="forbidden", errors=errors)


class ConflictError(ApiError):
    def __init__(self, message: str = "Conflit.", errors=None) -> None:
        super().__init__(message, status=409, code="conflict", errors=errors)


class ValidationFailed(ApiError):
    def __init__(
        self,
        message: str = "Données invalides.",
        errors: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(message, status=422, code="validation_failed", errors=errors)
