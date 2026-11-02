"""Types d'alertes et alertes déclenchées par les citoyens."""
from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Index, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..extensions import db
from .base import SoftDeleteMixin, TimestampMixin
from .types import LatLon, TinyBool, UBigInt, UInt

if TYPE_CHECKING:
    from .geo import Commissariat
    from .user import User



class TypeAlerte(db.Model, TimestampMixin):
    __tablename__ = "typealertes"

    id: Mapped[int] = mapped_column(UInt, primary_key=True, autoincrement=True)
    code: Mapped[str] = mapped_column(String(30), nullable=False, unique=True)
    contenu: Mapped[str] = mapped_column(String(150), nullable=False)
    niveau_urgence_defaut: Mapped[str] = mapped_column(
        String(10), nullable=False, default="moyen", server_default="moyen"
    )
    necessite_police: Mapped[int] = mapped_column(
        TinyBool, nullable=False, default=1, server_default="1"
    )
    icone: Mapped[str | None] = mapped_column(String(100))
    statut: Mapped[int] = mapped_column(TinyBool, nullable=False, default=1, server_default="1")

    alertes: Mapped[list["Alerte"]] = relationship(back_populates="type_alerte", lazy="raise")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "code": self.code,
            "contenu": self.contenu,
            "niveau_urgence_defaut": self.niveau_urgence_defaut,
            "necessite_police": bool(self.necessite_police),
            "icone": self.icone,
            "statut": bool(self.statut),
        }


class Alerte(db.Model, TimestampMixin, SoftDeleteMixin):
    __tablename__ = "alertes"
    __table_args__ = (
        Index("idx_alertes_file", "id_commissariat", "statut", "date_alerte"),
        Index("idx_alertes_priorite", "statut", "niveau_urgence", "date_alerte"),
        Index("idx_alertes_geo", "latitude", "longitude"),
    )

    id: Mapped[int] = mapped_column(UBigInt, primary_key=True, autoincrement=True)
    reference: Mapped[str] = mapped_column(String(50), nullable=False, unique=True)
    id_user: Mapped[int] = mapped_column(
        UInt,
        ForeignKey("users.id", ondelete="RESTRICT", onupdate="CASCADE"),
        nullable=False,
    )
    id_type_alerte: Mapped[int] = mapped_column(
        UInt,
        ForeignKey("typealertes.id", ondelete="RESTRICT", onupdate="CASCADE"),
        nullable=False,
    )
    contenu: Mapped[str] = mapped_column(Text, nullable=False)
    niveau_urgence: Mapped[str] = mapped_column(
        String(10), nullable=False, default="moyen", server_default="moyen"
    )
    statut: Mapped[str] = mapped_column(
        String(20), nullable=False, default="nouvelle", server_default="nouvelle"
    )
    id_commissariat: Mapped[int | None] = mapped_column(
        UInt,
        ForeignKey("commissariats.id", ondelete="SET NULL", onupdate="CASCADE"),
        index=True,
    )
    id_policier_assignee: Mapped[int | None] = mapped_column(
        UInt, ForeignKey("users.id", ondelete="SET NULL", onupdate="CASCADE"), index=True
    )
    latitude: Mapped[Decimal | None] = mapped_column(LatLon)
    longitude: Mapped[Decimal | None] = mapped_column(LatLon)
    adresse_precise: Mapped[str | None] = mapped_column(String(255))
    date_alerte: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=datetime.now, server_default=func.now()
    )
    date_prise_en_compte: Mapped[datetime | None] = mapped_column(DateTime)
    date_resolution: Mapped[datetime | None] = mapped_column(DateTime)
    observation: Mapped[str | None] = mapped_column(Text)

    # ------------------------------------------------------------- Relations
    user: Mapped["User"] = relationship(foreign_keys=[id_user], lazy="joined")
    type_alerte: Mapped["TypeAlerte"] = relationship(back_populates="alertes", lazy="joined")
    commissariat: Mapped["Commissariat | None"] = relationship(lazy="joined")
    policier_assigne: Mapped["User | None"] = relationship(
        foreign_keys=[id_policier_assignee], lazy="joined"
    )

    def to_dict(self, with_details: bool = True) -> dict:
        data = {
            "id": self.id,
            "reference": self.reference,
            "id_user": self.id_user,
            "id_type_alerte": self.id_type_alerte,
            "contenu": self.contenu,
            "niveau_urgence": self.niveau_urgence,
            "statut": self.statut,
            "id_commissariat": self.id_commissariat,
            "id_policier_assignee": self.id_policier_assignee,
            "latitude": float(self.latitude) if self.latitude is not None else None,
            "longitude": float(self.longitude) if self.longitude is not None else None,
            "adresse_precise": self.adresse_precise,
            "date_alerte": self.date_alerte.isoformat() if self.date_alerte else None,
            "date_prise_en_compte": (
                self.date_prise_en_compte.isoformat() if self.date_prise_en_compte else None
            ),
            "date_resolution": self.date_resolution.isoformat() if self.date_resolution else None,
            "observation": self.observation,
        }
        if with_details:
            data["type"] = self.type_alerte.to_dict() if self.type_alerte else None
            data["emetteur"] = (
                {"id": self.user.id, "nom": self.user.nom, "prenom": self.user.prenom,
                 "telephone": self.user.telephone, "avatar": self.user.avatar}
                if self.user else None
            )
            data["commissariat_nom"] = self.commissariat.nom if self.commissariat else None
            data["policier"] = (
                {"id": self.policier_assigne.id, "nom": self.policier_assigne.nom,
                 "prenom": self.policier_assigne.prenom}
                if self.policier_assigne else None
            )
        return data
