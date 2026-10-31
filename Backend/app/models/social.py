"""Vie sociale (demandes d'amis, messages) et notifications."""
from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Index, String, Text, event, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..extensions import db
from .base import TimestampMixin
from .types import TinyBool, UBigInt, UInt

if TYPE_CHECKING:
    from .user import User



class Demande(db.Model, TimestampMixin):
    """Demande d'ami.

    `cle_paire` (clé de couple non ordonnée) est calculée à la fois par le trigger
    MySQL `trg_demandes_bi/bu` et par l'écouteur SQLAlchemy ci-dessous, ce qui
    interdit d'avoir A->B et B->A simultanément pour un même statut.
    """

    __tablename__ = "demandes"
    __table_args__ = (
        Index("uk_demandes_paire_statut", "cle_paire", "statut", unique=True),
        Index("idx_demandes_recev_statut", "recev_id", "statut"),
        Index("idx_demandes_envoi_statut", "envoi_id", "statut"),
    )

    id: Mapped[int] = mapped_column(UBigInt, primary_key=True, autoincrement=True)
    recev_id: Mapped[int] = mapped_column(
        UInt, ForeignKey("users.id", ondelete="CASCADE", onupdate="CASCADE"), nullable=False
    )
    envoi_id: Mapped[int] = mapped_column(
        UInt, ForeignKey("users.id", ondelete="CASCADE", onupdate="CASCADE"), nullable=False
    )
    date_demande: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=datetime.now, server_default=func.now()
    )
    statut: Mapped[str] = mapped_column(
        String(12), nullable=False, default="en_attente", server_default="en_attente"
    )
    date_reponse: Mapped[datetime | None] = mapped_column(DateTime)
    cle_paire: Mapped[str] = mapped_column(String(23), nullable=False, default="", server_default="")

    destinataire: Mapped["User"] = relationship(
        foreign_keys=[recev_id], lazy="joined"
    )
    emetteur: Mapped["User"] = relationship(
        foreign_keys=[envoi_id], lazy="joined"
    )

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "recev_id": self.recev_id,
            "envoi_id": self.envoi_id,
            "date_demande": self.date_demande.isoformat() if self.date_demande else None,
            "statut": self.statut,
            "date_reponse": self.date_reponse.isoformat() if self.date_reponse else None,
            "destinataire": (
                {"id": self.destinataire.id, "nom": self.destinataire.nom,
                 "prenom": self.destinataire.prenom, "avatar": self.destinataire.avatar}
                if self.destinataire else None
            ),
            "emetteur": (
                {"id": self.emetteur.id, "nom": self.emetteur.nom,
                 "prenom": self.emetteur.prenom, "avatar": self.emetteur.avatar}
                if self.emetteur else None
            ),
        }


def _calculer_cle_paire(target) -> str | None:
    a, b = target.recev_id, target.envoi_id
    if a is None or b is None:
        return None
    if a == b:
        from ..exceptions import ValidationFailed

        raise ValidationFailed(
            "Une demande d'ami ne peut pas partir vers soi-même.",
            errors={"envoi_id": ["destinataire identique à l'émetteur"]},
        )
    return f"{min(a, b)}-{max(a, b)}"


@event.listens_for(Demande, "before_insert")
def _demande_before_insert(mapper, connection, target) -> None:
    """Calcule `cle_paire` et refuse l'auto-demande AVANT l'écriture.

    Les mises à jour des participants sont couvertes par le trigger MySQL
    `trg_demandes_bu` ; ce point d'entrée sert surtout à renvoyer une 422
    propre plutôt qu'une erreur SQL 1644.
    """
    cle = _calculer_cle_paire(target)
    if cle is not None:
        target.cle_paire = cle


class Note(db.Model, TimestampMixin):
    """Message privé entre deux utilisateurs."""

    __tablename__ = "notes"
    __table_args__ = (
        Index("idx_notes_rec_lu", "id_rec", "lu"),
        Index("idx_notes_conversation", "id_sender", "id_rec", "created_at"),
    )

    id: Mapped[int] = mapped_column(UBigInt, primary_key=True, autoincrement=True)
    id_rec: Mapped[int] = mapped_column(
        UInt, ForeignKey("users.id", ondelete="CASCADE", onupdate="CASCADE"), nullable=False
    )
    id_sender: Mapped[int] = mapped_column(
        UInt, ForeignKey("users.id", ondelete="CASCADE", onupdate="CASCADE"), nullable=False
    )
    messages: Mapped[str] = mapped_column(Text, nullable=False)
    lu: Mapped[int] = mapped_column(TinyBool, nullable=False, default=0, server_default="0")

    destinataire: Mapped["User"] = relationship(foreign_keys=[id_rec], lazy="joined")
    emetteur: Mapped["User"] = relationship(foreign_keys=[id_sender], lazy="joined")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "id_rec": self.id_rec,
            "id_sender": self.id_sender,
            "messages": self.messages,
            "lu": bool(self.lu),
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class Notification(db.Model, TimestampMixin):
    __tablename__ = "notifications"
    __table_args__ = (
        Index("idx_notif_user_lu", "id_user", "lu"),
        Index("idx_notif_user_date", "id_user", "date_envoi"),
        Index("idx_notif_entite", "entite_type", "entite_id"),
    )

    id: Mapped[int] = mapped_column(UBigInt, primary_key=True, autoincrement=True)
    id_user: Mapped[int] = mapped_column(
        UInt, ForeignKey("users.id", ondelete="CASCADE", onupdate="CASCADE"), nullable=False
    )
    id_sender: Mapped[int | None] = mapped_column(
        UInt, ForeignKey("users.id", ondelete="SET NULL", onupdate="CASCADE")
    )
    type: Mapped[str] = mapped_column(String(20), nullable=False, default="systeme", server_default="systeme")
    titre: Mapped[str] = mapped_column(String(150), nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    entite_type: Mapped[str | None] = mapped_column(String(15))
    entite_id: Mapped[int | None] = mapped_column(UBigInt)
    lien: Mapped[str | None] = mapped_column(String(255))
    lu: Mapped[int] = mapped_column(TinyBool, nullable=False, default=0, server_default="0")
    date_envoi: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=datetime.now, server_default=func.now()
    )
    date_lecture: Mapped[datetime | None] = mapped_column(DateTime)

    destinataire: Mapped["User"] = relationship(foreign_keys=[id_user], lazy="joined")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "id_user": self.id_user,
            "id_sender": self.id_sender,
            "type": self.type,
            "titre": self.titre,
            "message": self.message,
            "entite_type": self.entite_type,
            "entite_id": self.entite_id,
            "lien": self.lien,
            "lu": bool(self.lu),
            "date_envoi": self.date_envoi.isoformat() if self.date_envoi else None,
            "date_lecture": self.date_lecture.isoformat() if self.date_lecture else None,
        }
