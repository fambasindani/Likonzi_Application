"""Format de réponse JSON unique de l'API."""
from __future__ import annotations

from typing import Any

from flask import jsonify


def _enveloppe(
    success: bool,
    message: str | None,
    data: Any = None,
    meta: dict | None = None,
    errors: Any = None,
) -> tuple[dict, int]:
    body: dict[str, Any] = {"success": success}
    if message:
        body["message"] = message
    if data is not None:
        body["data"] = data
    if meta:
        body["meta"] = meta
    if errors is not None:
        body["errors"] = errors
    return body, 200


def ok(data: Any = None, message: str | None = None, meta: dict | None = None):
    body, status = _enveloppe(True, message, data, meta)
    return jsonify(body), status


def created(data: Any = None, message: str | None = None, meta: dict | None = None):
    body, _status = _enveloppe(True, message, data, meta)
    return jsonify(body), 201


def no_content(message: str | None = None):
    body, _ = _enveloppe(True, message, None)
    return jsonify(body), 200


def paginated(
    items: list,
    page: int,
    per_page: int,
    total: int,
    message: str | None = None,
    extra: dict | None = None,
):
    pages = -(-total // per_page) if per_page else 0
    meta = {
        "page": page,
        "per_page": per_page,
        "total": total,
        "pages": pages,
        "has_next": page < pages,
        "has_prev": page > 1,
    }
    if extra:
        meta.update(extra)
    return ok(data=items, message=message, meta=meta)
