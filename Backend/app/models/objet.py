"""Types d'objets et objets volés / recherchés."""
from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Index, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..extensions import db
from .base import SoftDeleteMixin, TimestampMixin
from .types import LatLon, TinyBool, UBigInt, UInt

if TYPE_CHECKING:
    from .cas import Cas
    from .user import User



class TypeObjet(db.Model, TimestampMixin):
    __tablename__ = "type_objets"

    id: Mapped[int] = mapped_column(UInt, primary_key=True, autoincrement=True)
    code: Mapped[str] = mapped_column(String(30), nullable=False, unique=True)
    description: Mapped[str] = mapped_column(String(150), nullable=False)
    icone: Mapped[str | None] = mapped_column(String(100))
    statut: Mapped[int] = mapped_column(TinyBool, nullable=False, default=1, server_default="1")

    objets: Mapped[list["Objet"]] = relationship(back_populates="type_objet", lazy="raise")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "code": self.code,
            "description": self.description,
            "icone": self.icone,
            "statut": bool(self.statut),
        }


class Objet(db.Model, TimestampMixin, SoftDeleteMixin):
    __tablename__ = "objets"

    id: Mapped[int] = mapped_column(UInt, primary_key=True, autoincrement=True)
    id_type: Mapped[int] = mapped_column(
        UInt, ForeignKey("type_objets.id", ondelete="RESTRICT", onupdate="CASCADE"), nullable=False
    )
    id_user_proprietaire: Mapped[int] = mapped_column(
        UInt, ForeignKey("users.id", ondelete="RESTRICT", onupdate="CASCADE"), nullable=False
    )
    marque: Mapped[str | None] = mapped_column(String(100))
    model: Mapped[str | None] = mapped_column(String(100))
    numero_chassis: Mapped[str | None] = mapped_column(String(100), index=True)
    immatriculation: Mapped[str | None] = mapped_column(String(50), index=True)
    numero_serie: Mapped[str | None] = mapped_column(String(100), index=True)
    couleur: Mapped[str | None] = mapped_column(String(50))
    description: Mapped[str | None] = mapped_column(Text)
    date_vol: Mapped[datetime | None] = mapped_column(DateTime)
    lieu_vol: Mapped[str | None] = mapped_column(String(255))
    latitude_vol: Mapped[Decimal | None] = mapped_column(LatLon)
    longitude_vol: Mapped[Decimal | None] = mapped_column(LatLon)
    statut: Mapped[str] = mapped_column(
        String(15), nullable=False, default="declare_vol", server_default="declare_vol"
    )
    id_cas: Mapped[int | None] = mapped_column(
        UBigInt, ForeignKey("cas.id", ondelete="SET NULL", onupdate="CASCADE"), index=True
    )

    type_objet: Mapped["TypeObjet"] = relationship(back_populates="objets", lazy="joined")
    proprietaire: Mapped["User"] = relationship(lazy="joined")
    cas: Mapped["Cas | None"] = relationship(lazy="joined")

    def to_dict(self, with_details: bool = True) -> dict:
        data = {
            "id": self.id,
            "id_type": self.id_type,
            "id_user_proprietaire": self.id_user_proprietaire,
            "marque": self.marque,
            "model": self.model,
            "numero_chassis": self.numero_chassis,
            "immatriculation": self.immatriculation,
            "numero_serie": self.numero_serie,
            "couleur": self.couleur,
            "description": self.description,
            "date_vol": self.date_vol.isoformat() if self.date_vol else None,
            "lieu_vol": self.lieu_vol,
            "latitude_vol": float(self.latitude_vol) if self.latitude_vol is not None else None,
            "longitude_vol": float(self.longitude_vol) if self.longitude_vol is not None else None,
            "statut": self.statut,
            "id_cas": self.id_cas,
        }
        if with_details:
            data["type"] = self.type_objet.to_dict() if self.type_objet else None
            data["proprietaire"] = (
                {"id": self.proprietaire.id, "nom": self.proprietaire.nom,
                 "postnom": self.proprietaire.postnom, "prenom": self.proprietaire.prenom,
                 "telephone": self.proprietaire.telephone, "avatar": self.proprietaire.avatar,
                 "matricule_police": self.proprietaire.matricule_police}
                if self.proprietaire else None
            )
        return data


class Partage(db.Model, TimestampMixin):
    """Transmission d'un objet (et de ses images) à un ami ou aux forces.

    Une ligne par (objet, destinataire) : `uk_partage_objet_destinataire`.
    """

    __tablename__ = "partages"
    __table_args__ = (
        Index("idx_partages_destinataire", "id_destinataire", "lu"),
        Index("idx_partages_objet", "id_objet"),
        UniqueConstraint("id_objet", "id_destinataire", name="uk_partage_objet_destinataire"),
    )

    id: Mapped[int] = mapped_column(UBigInt, primary_key=True, autoincrement=True)
    id_objet: Mapped[int] = mapped_column(
        UInt, ForeignKey("objets.id", ondelete="CASCADE", onupdate="CASCADE"), nullable=False
    )
    id_proprietaire: Mapped[int] = mapped_column(
        UInt, ForeignKey("users.id", ondelete="CASCADE", onupdate="CASCADE"), nullable=False
    )
    id_destinataire: Mapped[int] = mapped_column(
        UInt, ForeignKey("users.id", ondelete="CASCADE", onupdate="CASCADE"), nullable=False
    )
    message: Mapped[str | None] = mapped_column(String(500))
    lu: Mapped[int] = mapped_column(TinyBool, nullable=False, default=0, server_default="0")
    date_partage: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=datetime.now, server_default=func.now()
    )

    objet: Mapped["Objet"] = relationship(lazy="joined")
    proprietaire: Mapped["User"] = relationship(foreign_keys=[id_proprietaire], lazy="joined")
    destinataire: Mapped["User"] = relationship(foreign_keys=[id_destinataire], lazy="joined")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "id_objet": self.id_objet,
            "id_proprietaire": self.id_proprietaire,
            "id_destinataire": self.id_destinataire,
            "message": self.message,
            "lu": bool(self.lu),
            "date_partage": self.date_partage.isoformat() if self.date_partage else None,
            "objet": self.objet.to_dict() if self.objet else None,
            "proprietaire": (
                {
                    "id": self.proprietaire.id,
                    "nom": self.proprietaire.nom,
                    "prenom": self.proprietaire.prenom,
                    "avatar": self.proprietaire.avatar,
                    "telephone": self.proprietaire.telephone,
                }
                if self.proprietaire
                else None
            ),
        }

