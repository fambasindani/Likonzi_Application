"""Lecture du corps de requête : JSON en premier, `application/x-www-form-urlencoded` ensuite."""
from __future__ import annotations

from typing import Any

from flask import request


def payload() -> dict[str, Any]:
    """Renvoie le corps de la requête sous forme de dict plat.

    L'application mobile historique envoie du `form-data` : on accepte les deux
    pour ne pas casser les clients existants.
    """
    data = request.get_json(silent=True)
    if isinstance(data, dict):
        return data
    if request.form:
        return request.form.to_dict()
    if request.args:
        return request.args.to_dict()
    return {}


def query_int(name: str, default: int | None = None) -> int | None:
    raw = request.args.get(name)
    if raw in (None, ""):
        return default
    try:
        return int(raw)
    except (TypeError, ValueError):
        return default


def query_bool(name: str, default: bool = False) -> bool:
    raw = request.args.get(name)
    if raw is None:
        return default
    return str(raw).strip().lower() in {"1", "true", "yes", "on"}
def query_float(
    name: str,
    default: float | None = None,
    *,
    requis: bool = False,
    min_val: float | None = None,
    max_val: float | None = None,
) -> float | None:
    """Lit un paramètre flottant dans la query-string, avec validation optionnelle."""
    from ..exceptions import ValidationFailed

    raw = request.args.get(name)
    if raw in (None, ""):
        if requis:
            raise ValidationFailed(
                "Paramètre manquant.", errors={name: ["Ce paramètre est obligatoire."]}
            )
        return default
    try:
        value = float(raw)
    except (TypeError, ValueError):
        raise ValidationFailed(
            "Paramètre invalide.", errors={name: ["Valeur numérique attendue."]}
        ) from None
    if min_val is not None and value < min_val:
        raise ValidationFailed(
            "Paramètre hors bornes.", errors={name: [f"Valeur minimale : {min_val}."]}
        )
    if max_val is not None and value > max_val:
        raise ValidationFailed(
            "Paramètre hors bornes.", errors={name: [f"Valeur maximale : {max_val}."]}
        )
    return value
