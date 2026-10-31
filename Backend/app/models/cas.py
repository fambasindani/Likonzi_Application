"""Dossiers (cas) et interventions policières."""
from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Index, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..extensions import db
from .base import SoftDeleteMixin, TimestampMixin
from .types import LatLon, UBigInt, UInt

if TYPE_CHECKING:
    from .alerte import Alerte
    from .geo import Commissariat
    from .user import User



class Cas(db.Model, TimestampMixin, SoftDeleteMixin):
    __tablename__ = "cas"
    __table_args__ = (Index("idx_cas_file", "id_commissariat", "statut", "priorite"),)

    id: Mapped[int] = mapped_column(UBigInt, primary_key=True, autoincrement=True)
    numero_dossier: Mapped[str] = mapped_column(String(50), nullable=False, unique=True)
    id_alerte: Mapped[int | None] = mapped_column(
        UBigInt, ForeignKey("alertes.id", ondelete="SET NULL", onupdate="CASCADE"), index=True
    )
    type_cas: Mapped[str] = mapped_column(String(20), nullable=False)
    id_victime: Mapped[int | None] = mapped_column(
        UInt, ForeignKey("users.id", ondelete="RESTRICT", onupdate="CASCADE"), index=True
    )
    description: Mapped[str] = mapped_column(Text, nullable=False)
    lieu: Mapped[str | None] = mapped_column(String(255))
    latitude: Mapped[Decimal | None] = mapped_column(LatLon)
    longitude: Mapped[Decimal | None] = mapped_column(LatLon)
    date_faits: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    date_ouverture: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=datetime.now, server_default=func.now()
    )
    date_cloture: Mapped[datetime | None] = mapped_column(DateTime)
    statut: Mapped[str] = mapped_column(
        String(12), nullable=False, default="ouvert", server_default="ouvert"
    )
    priorite: Mapped[str] = mapped_column(
        String(12), nullable=False, default="normale", server_default="normale"
    )
    id_commissariat: Mapped[int] = mapped_column(
        UInt,
        ForeignKey("commissariats.id", ondelete="RESTRICT", onupdate="CASCADE"),
        nullable=False,
    )
    id_enqueteur_principal: Mapped[int | None] = mapped_column(
        UInt, ForeignKey("users.id", ondelete="SET NULL", onupdate="CASCADE"), index=True
    )
    resultat: Mapped[str | None] = mapped_column(Text)

    # ------------------------------------------------------------- Relations
    alerte: Mapped["Alerte | None"] = relationship(lazy="joined")
    victime: Mapped["User | None"] = relationship(
        foreign_keys=[id_victime], lazy="joined"
    )
    commissariat: Mapped["Commissariat"] = relationship(lazy="joined")
    enqueteur: Mapped["User | None"] = relationship(
        foreign_keys=[id_enqueteur_principal], lazy="joined"
    )
    interventions: Mapped[list["Intervention"]] = relationship(
        back_populates="cas", cascade="all, delete-orphan", lazy="selectin"
    )

    def to_dict(self, with_details: bool = True) -> dict:
        data = {
            "id": self.id,
            "numero_dossier": self.numero_dossier,
            "id_alerte": self.id_alerte,
            "type_cas": self.type_cas,
            "id_victime": self.id_victime,
            "description": self.description,
            "lieu": self.lieu,
            "latitude": float(self.latitude) if self.latitude is not None else None,
            "longitude": float(self.longitude) if self.longitude is not None else None,
            "date_faits": self.date_faits.isoformat(),
            "date_ouverture": self.date_ouverture.isoformat() if self.date_ouverture else None,
            "date_cloture": self.date_cloture.isoformat() if self.date_cloture else None,
            "statut": self.statut,
            "priorite": self.priorite,
            "id_commissariat": self.id_commissariat,
            "id_enqueteur_principal": self.id_enqueteur_principal,
            "resultat": self.resultat,
        }
        if with_details:
            data["commissariat_nom"] = self.commissariat.nom if self.commissariat else None
            data["victime"] = (
                {"id": self.victime.id, "nom": self.victime.nom, "prenom": self.victime.prenom,
                 "telephone": self.victime.telephone}
                if self.victime else None
            )
            data["enqueteur"] = (
                {"id": self.enqueteur.id, "nom": self.enqueteur.nom,
                 "prenom": self.enqueteur.prenom}
                if self.enqueteur else None
            )
            data["nb_interventions"] = len(self.interventions)
        return data


class Intervention(db.Model, TimestampMixin):
    __tablename__ = "interventions"
    __table_args__ = (Index("idx_interventions_cas_date", "id_cas", "date_intervention"),)

    id: Mapped[int] = mapped_column(UBigInt, primary_key=True, autoincrement=True)
    id_cas: Mapped[int] = mapped_column(
        UBigInt,
        ForeignKey("cas.id", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )
    id_policier: Mapped[int] = mapped_column(
        UInt, ForeignKey("users.id", ondelete="RESTRICT", onupdate="CASCADE"), nullable=False
    )
    type_intervention: Mapped[str] = mapped_column(String(30), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    date_intervention: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    duree_minutes: Mapped[int | None] = mapped_column()
    lieu: Mapped[str | None] = mapped_column(String(255))
    resultat: Mapped[str | None] = mapped_column(Text)

    cas: Mapped["Cas"] = relationship(back_populates="interventions", lazy="joined")
    policier: Mapped["User"] = relationship(lazy="joined")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "id_cas": self.id_cas,
            "id_policier": self.id_policier,
            "policier": (
                {"id": self.policier.id, "nom": self.policier.nom,
                 "prenom": self.policier.prenom, "matricule": self.policier.matricule_police}
                if self.policier else None
            ),
            "type_intervention": self.type_intervention,
            "description": self.description,
            "date_intervention": self.date_intervention.isoformat(),
            "duree_minutes": self.duree_minutes,
            "lieu": self.lieu,
            "resultat": self.resultat,
        }
