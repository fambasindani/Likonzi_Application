"""SOS « minute de grâce » : compte à rebours géré côté serveur.

Le décompte vit en base (`sos`) et non dans l'application : l'app peut être
fermée, l'envoi a lieu à l'échéance par la tâche de veille.
"""
from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Index, SmallInteger, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..extensions import db
from .base import TimestampMixin
from .types import LatLon, UBigInt, UInt

if TYPE_CHECKING:
    from .user import User

# Statuts du cycle de vie d'un SOS.
STATUT_PROGRAMME = "programme"
STATUT_INTERMEDIAIRE = "intermediaire"
STATUT_ENVOYE = "envoye"
STATUT_ANNULE = "annule"
STATUT_CLOTURE = "cloture"


class Sos(db.Model, TimestampMixin):
    """Un déclenchement SOS : `programme` -> `envoye` -> `cloture`."""

    __tablename__ = "sos"
    __table_args__ = (
        Index("idx_sos_user_statut", "id_user", "statut"),
        Index("idx_sos_echeance", "statut", "echeance"),
    )

    id: Mapped[int] = mapped_column(UBigInt, primary_key=True, autoincrement=True)
    id_user: Mapped[int] = mapped_column(
        UInt,
        ForeignKey("users.id", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
    )
    statut: Mapped[str] = mapped_column(
        String(20), nullable=False, default=STATUT_PROGRAMME, server_default=STATUT_PROGRAMME
    )
    duree_minutes: Mapped[int] = mapped_column(
        SmallInteger, nullable=False, default=15, server_default="15"
    )
    echeance: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    latitude: Mapped[Decimal | None] = mapped_column(LatLon)
    longitude: Mapped[Decimal | None] = mapped_column(LatLon)
    intermediaire_at: Mapped[datetime | None] = mapped_column(DateTime)
    envoye_at: Mapped[datetime | None] = mapped_column(DateTime)
    cloture_at: Mapped[datetime | None] = mapped_column(DateTime)
    id_alerte: Mapped[int | None] = mapped_column(
        UBigInt, ForeignKey("alertes.id", ondelete="SET NULL", onupdate="CASCADE")
    )

    user: Mapped["User"] = relationship(lazy="joined")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "id_user": self.id_user,
            "statut": self.statut,
            "duree_minutes": self.duree_minutes,
            "echeance": self.echeance.isoformat() if self.echeance else None,
            # Temps restant calculé CÔTÉ SERVEUR : le client décrémente localement
            # à partir de cette valeur (immunité au décalage horaire appareil).
            "restant_secondes": self.restant_secondes,
            "latitude": float(self.latitude) if self.latitude is not None else None,
            "longitude": float(self.longitude) if self.longitude is not None else None,
            "intermediaire_at": self.intermediaire_at.isoformat()
            if self.intermediaire_at
            else None,
            "envoye_at": self.envoye_at.isoformat() if self.envoye_at else None,
            "cloture_at": self.cloture_at.isoformat() if self.cloture_at else None,
            "id_alerte": self.id_alerte,
        }

    @property
    def restant_secondes(self) -> int:
        delta = self.echeance - datetime.now()
        return max(0, int(delta.total_seconds()))
