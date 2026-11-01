"""Référentiels géographiques, commissariats et localisations GPS."""
from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Index, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..extensions import db
from .base import TimestampMixin
from .enums import SourceLocalisation
from .types import LatLon, TinyBool, UBigInt, UInt

if TYPE_CHECKING:
    from .user import User



class Province(db.Model, TimestampMixin):
    __tablename__ = "provinces"

    id: Mapped[int] = mapped_column(UInt, primary_key=True, autoincrement=True)
    code: Mapped[str] = mapped_column(String(10), nullable=False, unique=True)
    nom: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    chef_lieu: Mapped[str | None] = mapped_column(String(100))

    villes: Mapped[list["Ville"]] = relationship(
        back_populates="province", cascade="all, delete-orphan", lazy="selectin"
    )

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "code": self.code,
            "nom": self.nom,
            "chef_lieu": self.chef_lieu,
        }


class Ville(db.Model, TimestampMixin):
    __tablename__ = "villes"
    __table_args__ = (Index("uk_villes_province_nom", "id_province", "nom", unique=True),)

    id: Mapped[int] = mapped_column(UInt, primary_key=True, autoincrement=True)
    id_province: Mapped[int] = mapped_column(
        UInt, ForeignKey("provinces.id", ondelete="RESTRICT", onupdate="CASCADE"), nullable=False
    )
    nom: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    latitude: Mapped[Decimal | None] = mapped_column(LatLon)
    longitude: Mapped[Decimal | None] = mapped_column(LatLon)

    province: Mapped["Province"] = relationship(back_populates="villes", lazy="joined")
    # `select` (et non `selectin`) : chaque chargement de ville déclencherait
    # sinon une requête batch sur toutes les communes — inutile hors suppression.
    communes: Mapped[list["Commune"]] = relationship(
        back_populates="ville", lazy="select"
    )

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "id_province": self.id_province,
            "nom": self.nom,
            "latitude": float(self.latitude) if self.latitude is not None else None,
            "longitude": float(self.longitude) if self.longitude is not None else None,
            "province": self.province.to_dict() if self.province else None,
        }


class Commune(db.Model, TimestampMixin):
    """Commune : sous-divison d'une ville (ex. Limete, Masina a Kinshasa)."""

    __tablename__ = "communes"
    __table_args__ = (Index("uk_communes_ville_nom", "id_ville", "nom", unique=True),)

    id: Mapped[int] = mapped_column(UInt, primary_key=True, autoincrement=True)
    id_ville: Mapped[int] = mapped_column(
        UInt, ForeignKey("villes.id", ondelete="RESTRICT", onupdate="CASCADE"), nullable=False
    )
    code: Mapped[str | None] = mapped_column(String(20))
    nom: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    latitude: Mapped[Decimal | None] = mapped_column(LatLon)
    longitude: Mapped[Decimal | None] = mapped_column(LatLon)

    ville: Mapped["Ville"] = relationship(back_populates="communes", lazy="joined")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "id_ville": self.id_ville,
            "code": self.code,
            "nom": self.nom,
            "latitude": float(self.latitude) if self.latitude is not None else None,
            "longitude": float(self.longitude) if self.longitude is not None else None,
            "ville": self.ville.nom if self.ville else None,
            "province": self.ville.province.nom
            if self.ville and self.ville.province
            else None,
        }


class Commissariat(db.Model, TimestampMixin):
    __tablename__ = "commissariats"

    id: Mapped[int] = mapped_column(UInt, primary_key=True, autoincrement=True)
    code: Mapped[str] = mapped_column(String(20), nullable=False, unique=True)
    nom: Mapped[str] = mapped_column(String(150), nullable=False)
    id_province: Mapped[int | None] = mapped_column(
        UInt, ForeignKey("provinces.id", ondelete="SET NULL", onupdate="CASCADE")
    )
    id_ville: Mapped[int | None] = mapped_column(
        UInt, ForeignKey("villes.id", ondelete="SET NULL", onupdate="CASCADE")
    )
    id_commune: Mapped[int | None] = mapped_column(
        UInt, ForeignKey("communes.id", ondelete="SET NULL", onupdate="CASCADE")
    )
    adresse: Mapped[str | None] = mapped_column(String(255))
    telephone: Mapped[str | None] = mapped_column(String(20))
    email: Mapped[str | None] = mapped_column(String(100))
    latitude: Mapped[Decimal | None] = mapped_column(LatLon)
    longitude: Mapped[Decimal | None] = mapped_column(LatLon)
    responsable_id: Mapped[int | None] = mapped_column(
        UInt, ForeignKey("users.id", ondelete="SET NULL", onupdate="CASCADE"), index=True
    )
    statut: Mapped[int] = mapped_column(TinyBool, nullable=False, default=1, server_default="1")
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    province: Mapped["Province | None"] = relationship(lazy="joined")
    ville: Mapped["Ville | None"] = relationship(lazy="joined")
    # `selectin` ET NON `joined` : la jointure cumulée province/ville/commune
    # faisait dépasser MySQL la limite de 61 tables jointes (erreur 1116) sur
    # les requêtes déjà larges (ex. `GET /partages`, ~55 tables).
    commune: Mapped["Commune | None"] = relationship(lazy="selectin")
    # Clés FK multiples : les deux sens doivent être explicites.
    responsable: Mapped["User | None"] = relationship(
        foreign_keys=[responsable_id], lazy="selectin"
    )
    agents: Mapped[list["User"]] = relationship(
        foreign_keys="User.id_commissariat", back_populates="commissariat", lazy="selectin"
    )

    def to_dict(self, with_geo: bool = True) -> dict:
        data = {
            "id": self.id,
            "code": self.code,
            "nom": self.nom,
            "adresse": self.adresse,
            "telephone": self.telephone,
            "email": self.email,
            "statut": bool(self.statut),
            "id_province": self.id_province,
            "id_ville": self.id_ville,
            "id_commune": self.id_commune,
            "province": self.province.nom if self.province else None,
            "ville": self.ville.nom if self.ville else None,
            "commune": self.commune.nom if self.commune else None,
            "responsable_id": self.responsable_id,
        }
        if with_geo:
            data["latitude"] = float(self.latitude) if self.latitude is not None else None
            data["longitude"] = float(self.longitude) if self.longitude is not None else None
        return data


class Localisation(db.Model):
    __tablename__ = "localisations"
    __table_args__ = (
        Index("idx_loc_user_date", "id_user", "date_localisation"),
        Index("idx_loc_geo", "latitude", "longitude"),
    )

    id: Mapped[int] = mapped_column(UBigInt, primary_key=True, autoincrement=True)
    id_user: Mapped[int] = mapped_column(
        UInt, ForeignKey("users.id", ondelete="CASCADE", onupdate="CASCADE"), nullable=False
    )
    latitude: Mapped[Decimal] = mapped_column(LatLon, nullable=False)
    longitude: Mapped[Decimal] = mapped_column(LatLon, nullable=False)
    latitude_delta: Mapped[Decimal | None] = mapped_column(LatLon)
    longitude_delta: Mapped[Decimal | None] = mapped_column(LatLon)
    precision_metres: Mapped[Decimal | None] = mapped_column(
        Numeric(precision=8, scale=2)
    )
    source: Mapped[str] = mapped_column(
        String(10), nullable=False, default=SourceLocalisation.GPS.value, server_default="gps"
    )
    date_localisation: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=datetime.now, server_default=func.now()
    )
    created_at: Mapped[datetime | None] = mapped_column(
        DateTime, nullable=True, default=datetime.now, server_default=func.now()
    )

    user: Mapped["User"] = relationship(lazy="selectin")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "id_user": self.id_user,
            "latitude": float(self.latitude),
            "longitude": float(self.longitude),
            "latitude_delta": float(self.latitude_delta) if self.latitude_delta else None,
            "longitude_delta": float(self.longitude_delta) if self.longitude_delta else None,
            "precision_metres": float(self.precision_metres) if self.precision_metres else None,
            "source": self.source,
            "date_localisation": self.date_localisation.isoformat() if self.date_localisation else None,
        }
