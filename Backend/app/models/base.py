"""Mixins réutilisés par tous les modèles."""
from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, func
from sqlalchemy.orm import Mapped, mapped_column


class TimestampMixin:
    """`created_at` / `updated_at` alignés sur les colonnes `DATETIME DEFAULT CURRENT_TIMESTAMP`."""

    created_at: Mapped[datetime | None] = mapped_column(
        DateTime, nullable=True, default=datetime.now, server_default=func.now()
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime,
        nullable=True,
        default=datetime.now,
        onupdate=datetime.now,
        server_default=func.now(),
    )


class SoftDeleteMixin:
    """Suppression douce : `deleted_at IS NULL` = en ligne de vie."""

    deleted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    @property
    def est_supprime(self) -> bool:
        return self.deleted_at is not None

    def soft_delete(self) -> None:
        self.deleted_at = datetime.now()
