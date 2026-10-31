"""Validation des entrées : collecte TOUTES les erreurs avant de lever la 422."""
from __future__ import annotations

import re
import unicodedata
from datetime import date, datetime
from typing import Any

from ..exceptions import ValidationFailed

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$")
# RDC : +243 8X/9X XXX XXX — on tolère aussi les formats internationaux.
TELEPHONE_RE = re.compile(r"^\+?[0-9][0-9\s\-]{6,19}$")


class Payload:
    """Collecteur d'erreurs de validation."""

    def __init__(self, data: dict[str, Any] | None = None) -> None:
        self.data = data or {}
        self.errors: dict[str, list[str]] = {}

    # ------------------------------------------------------------------ helpers
    def _add(self, field: str, message: str) -> None:
        self.errors.setdefault(field, []).append(message)

    def fail_if_errors(self) -> None:
        if self.errors:
            raise ValidationFailed("Données invalides.", errors=self.errors)

    def _raw(self, field: str) -> Any:
        return self.data.get(field)

    # ------------------------------------------------------------------ champs
    def chaine(
        self,
        field: str,
        *,
        requis: bool = True,
        min_len: int = 1,
        max_len: int = 255,
        strip: bool = True,
        default: str | None = None,
    ) -> str | None:
        value = self._raw(field)
        if value is None or (isinstance(value, str) and value.strip() == ""):
            if requis:
                self._add(field, "Ce champ est obligatoire.")
            return default
        if not isinstance(value, str):
            self._add(field, "Valeur texte attendue.")
            return default
        value = value.strip() if strip else value
        if len(value) < min_len:
            self._add(field, f"Minimum {min_len} caractère(s).")
            return default
        if len(value) > max_len:
            self._add(field, f"Maximum {max_len} caractères.")
            return default
        return value

    def email(self, field: str = "email", *, requis: bool = True) -> str | None:
        value = self.chaine(field, requis=requis, max_len=100)
        if value and not EMAIL_RE.match(value):
            self._add(field, "Adresse e-mail invalide.")
            return None
        return value.lower() if value else None

    def telephone(self, field: str = "telephone", *, requis: bool = True) -> str | None:
        value = self.chaine(field, requis=requis, max_len=20)
        if value and not TELEPHONE_RE.match(value):
            self._add(field, "Numéro de téléphone invalide (ex. +243810000000).")
            return None
        return value

    def mot_de_passe(
        self,
        field: str = "password",
        *,
        requis: bool = True,
        min_len: int = 8,
        max_len: int = 128,
    ) -> str | None:
        value = self._raw(field)
        if value is None or value == "":
            if requis:
                self._add(field, "Ce champ est obligatoire.")
            return None
        if not isinstance(value, str):
            self._add(field, "Valeur texte attendue.")
            return None
        if len(value) < min_len:
            self._add(field, f"Le mot de passe doit faire au moins {min_len} caractères.")
            return None
        if len(value) > max_len:
            self._add(field, f"Le mot de passe dépasse {max_len} caractères.")
            return None
        return value

    def enum(
        self,
        field: str,
        valeurs: list[str],
        *,
        requis: bool = False,
        default: str | None = None,
    ) -> str | None:
        value = self._raw(field)
        if value is None or value == "":
            if requis:
                self._add(field, "Ce champ est obligatoire.")
            return default
        if value not in valeurs:
            self._add(field, f"Valeur attendue parmi : {', '.join(valeurs)}.")
            return default
        return value

    def entier(
        self,
        field: str,
        *,
        requis: bool = False,
        default: int | None = None,
        min_val: int | None = None,
        max_val: int | None = None,
    ) -> int | None:
        value = self._raw(field)
        if value is None or value == "":
            if requis:
                self._add(field, "Ce champ est obligatoire.")
            return default
        try:
            value = int(value)
        except (TypeError, ValueError):
            self._add(field, "Valeur entière attendue.")
            return default
        if min_val is not None and value < min_val:
            self._add(field, f"Valeur minimale : {min_val}.")
            return default
        if max_val is not None and value > max_val:
            self._add(field, f"Valeur maximale : {max_val}.")
            return default
        return value

    def decimal(
        self,
        field: str,
        *,
        requis: bool = False,
        default=None,
        min_val: float | None = None,
        max_val: float | None = None,
    ):
        value = self._raw(field)
        if value is None or value == "":
            if requis:
                self._add(field, "Ce champ est obligatoire.")
            return default
        try:
            value = float(value)
        except (TypeError, ValueError):
            self._add(field, "Valeur numérique attendue.")
            return default
        if min_val is not None and value < min_val:
            self._add(field, f"Valeur minimale : {min_val}.")
            return default
        if max_val is not None and value > max_val:
            self._add(field, f"Valeur maximale : {max_val}.")
            return default
        return value

    def date(self, field: str, *, requis: bool = False, default=None) -> date | None:
        value = self._raw(field)
        if value is None or value == "":
            if requis:
                self._add(field, "Ce champ est obligatoire.")
            return default
        if isinstance(value, date) and not isinstance(value, datetime):
            return value
        try:
            return datetime.strptime(str(value)[:10], "%Y-%m-%d").date()
        except ValueError:
            self._add(field, "Format attendu : AAAA-MM-JJ.")
            return default

    def datetime_(self, field: str, *, requis: bool = False, default=None) -> datetime | None:
        value = self._raw(field)
        if value is None or value == "":
            if requis:
                self._add(field, "Ce champ est obligatoire.")
            return default
        if isinstance(value, datetime):
            return value
        try:
            return datetime.fromisoformat(str(value).replace("Z", ""))
        except ValueError:
            self._add(field, "Format attendu : ISO 8601 (AAAA-MM-JJTHH:MM:SS).")
            return default


def normaliser_recherche(term: str) -> str:
    """Retire les accents pour une recherche insensible à la casse/diacritiques."""
    term = unicodedata.normalize("NFKD", term)
    return "".join(c for c in term if not unicodedata.combining(c)).lower()
