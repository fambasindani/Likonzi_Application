"""Preuves (photos, vidéos, documents) avec empreinte SHA-256 pour l'intégrité."""
from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, Index, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..extensions import db
from .base import SoftDeleteMixin, TimestampMixin
from .types import Hash64, TailleFichier, UBigInt, UInt

if TYPE_CHECKING:
    from .user import User


class Preuve(db.Model, TimestampMixin, SoftDeleteMixin):
    """Table polymorphe : `entite_type` + `entite_id` (pas de FK possible)."""

    __tablename__ = "preuves"
    __table_args__ = (
        Index("idx_preuves_entite", "entite_type", "entite_id"),
        UniqueConstraint("nom_stocke", name="uk_preuves_nom_stocke"),
    )

    id: Mapped[int] = mapped_column(UBigInt, primary_key=True, autoincrement=True)
    entite_type: Mapped[str] = mapped_column(String(15), nullable=False)
    entite_id: Mapped[int] = mapped_column(UBigInt, nullable=False)
    type_preuve: Mapped[str] = mapped_column(String(10), nullable=False)
    nom_original: Mapped[str] = mapped_column(String(255), nullable=False)
    nom_stocke: Mapped[str] = mapped_column(String(255), nullable=False)
    extension: Mapped[str] = mapped_column(String(10), nullable=False)
    type_mime: Mapped[str] = mapped_column(String(100), nullable=False)
    taille_octets: Mapped[int] = mapped_column(TailleFichier, nullable=False)
    chemin_stockage: Mapped[str] = mapped_column(String(500), nullable=False)
    hash_sha256: Mapped[str | None] = mapped_column(Hash64, index=True)
    description: Mapped[str | None] = mapped_column(Text)
    id_user_upload: Mapped[int | None] = mapped_column(
        UInt, ForeignKey("users.id", ondelete="SET NULL", onupdate="CASCADE"), index=True
    )

    uploadeur: Mapped["User | None"] = relationship(lazy="joined")

    @property
    def est_integre(self) -> bool:
        """Sans hash enregistré, l'intégrité n'est pas vérifiable."""
        return bool(self.hash_sha256)

    def to_dict(self, with_uploadeur: bool = True) -> dict:
        data = {
            "id": self.id,
            "entite_type": self.entite_type,
            "entite_id": self.entite_id,
            "type_preuve": self.type_preuve,
            "nom_original": self.nom_original,
            "nom_stocke": self.nom_stocke,
            "extension": self.extension,
            "type_mime": self.type_mime,
            "taille_octets": self.taille_octets,
            "chemin_stockage": self.chemin_stockage,
            "url": f"/static/uploads/{self.chemin_stockage}",
            "hash_sha256": self.hash_sha256,
            "description": self.description,
            "id_user_upload": self.id_user_upload,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
        if with_uploadeur and self.uploadeur:
            data["uploadeur"] = {
                "id": self.uploadeur.id,
                "nom": self.uploadeur.nom,
                "prenom": self.uploadeur.prenom,
            }
        return data
