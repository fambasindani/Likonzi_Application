"""Jetons de vérification (OTP e-mail / téléphone / réinitialisation) et révocation JWT."""
from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..extensions import db
from .base import TimestampMixin
from .types import UBigInt, UInt, UTinyInt

if TYPE_CHECKING:
    from .user import User



class VerificationToken(db.Model, TimestampMixin):
    __tablename__ = "verification_tokens"

    id: Mapped[int] = mapped_column(UInt, primary_key=True, autoincrement=True)
    id_user: Mapped[int] = mapped_column(
        UInt, ForeignKey("users.id", ondelete="CASCADE", onupdate="CASCADE"), nullable=False
    )
    type: Mapped[str] = mapped_column(String(15), nullable=False)
    code: Mapped[str | None] = mapped_column(String(10))
    jeton_hash: Mapped[str] = mapped_column(String(64), nullable=False, unique=True)
    tentatives: Mapped[int] = mapped_column(
        UTinyInt, nullable=False, default=0, server_default="0"
    )
    expire_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, index=True)
    utilise_le: Mapped[datetime | None] = mapped_column(DateTime)

    user: Mapped["User"] = relationship(lazy="joined")

    def est_valide(self, maintenant: datetime | None = None) -> bool:
        maintenant = maintenant or datetime.now()
        return self.utilise_le is None and self.expire_at > maintenant

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "id_user": self.id_user,
            "type": self.type,
            "expire_at": self.expire_at.isoformat(),
            "utilise": self.utilise_le is not None,
        }


class TokenDenylist(db.Model):
    """Liste noire des JWT révoqués (logout réel, révocation après compromission)."""

    __tablename__ = "token_denylist"

    id: Mapped[int] = mapped_column(UBigInt, primary_key=True, autoincrement=True)
    jti: Mapped[str] = mapped_column(String(36), nullable=False, unique=True, index=True)
    id_user: Mapped[int | None] = mapped_column(UInt, index=True)
    expire_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, index=True)
    created_at: Mapped[datetime | None] = mapped_column(
        DateTime, nullable=True, default=datetime.now, server_default=func.now()
    )

    @classmethod
    def est_revoque(cls, jti: str, db_session) -> bool:
        return db_session.query(cls).filter(cls.jti == jti).first() is not None
