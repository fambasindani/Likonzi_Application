"""Journal d'audit : qui a fait quoi, quand, depuis où."""
from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import JSON, DateTime, ForeignKey, Index, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..extensions import db
from .types import UBigInt, UInt

if TYPE_CHECKING:
    from .user import User



class AuditLog(db.Model):
    __tablename__ = "audit_logs"
    __table_args__ = (
        Index("idx_audit_entite", "entite", "entite_id"),
        Index("idx_audit_action", "action"),
        Index("idx_audit_date", "created_at"),
    )

    id: Mapped[int] = mapped_column(UBigInt, primary_key=True, autoincrement=True)
    user_id: Mapped[int | None] = mapped_column(
        UInt, ForeignKey("users.id", ondelete="SET NULL", onupdate="CASCADE"), index=True
    )
    action: Mapped[str] = mapped_column(String(50), nullable=False)
    entite: Mapped[str] = mapped_column(String(100), nullable=False)
    entite_id: Mapped[int | None] = mapped_column(UBigInt)
    description: Mapped[str | None] = mapped_column(Text)
    valeurs_avant: Mapped[dict | None] = mapped_column(JSON)
    valeurs_apres: Mapped[dict | None] = mapped_column(JSON)
    ip_address: Mapped[str | None] = mapped_column(String(45))
    user_agent: Mapped[str | None] = mapped_column(String(500))
    created_at: Mapped[datetime | None] = mapped_column(
        DateTime, nullable=True, default=datetime.now, server_default=func.now()
    )

    user: Mapped["User | None"] = relationship(lazy="joined")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "action": self.action,
            "entite": self.entite,
            "entite_id": self.entite_id,
            "description": self.description,
            "valeurs_avant": self.valeurs_avant,
            "valeurs_apres": self.valeurs_apres,
            "ip_address": self.ip_address,
            "user_agent": self.user_agent,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
