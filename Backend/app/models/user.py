"""Utilisateurs et RBAC (rôles / permissions) — source unique des droits."""
from __future__ import annotations

from datetime import date, datetime
from typing import TYPE_CHECKING

from sqlalchemy import Date, DateTime, ForeignKey, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..extensions import db
from .base import SoftDeleteMixin, TimestampMixin
from .enums import StatutUtilisateur
from .types import TinyBool, UInt

if TYPE_CHECKING:
    from .geo import Commissariat



class Role(db.Model, TimestampMixin):
    __tablename__ = "roles"

    id: Mapped[int] = mapped_column(UInt, primary_key=True, autoincrement=True)
    nom: Mapped[str] = mapped_column(String(100), nullable=False, unique=True)
    description: Mapped[str | None] = mapped_column(Text)

    users: Mapped[list["User"]] = relationship(
        secondary="user_role", back_populates="roles", lazy="selectin"
    )
    permissions: Mapped[list["Permission"]] = relationship(
        secondary="role_permission", back_populates="roles", lazy="selectin"
    )

    def to_dict(self, with_permissions: bool = False) -> dict:
        data = {"id": self.id, "nom": self.nom, "description": self.description}
        if with_permissions:
            data["permissions"] = sorted(p.code for p in self.permissions)
        return data


class Permission(db.Model, TimestampMixin):
    __tablename__ = "permissions"

    id: Mapped[int] = mapped_column(UInt, primary_key=True, autoincrement=True)
    code: Mapped[str] = mapped_column(String(100), nullable=False, unique=True)
    description: Mapped[str | None] = mapped_column(Text)
    module: Mapped[str | None] = mapped_column(String(50), index=True)

    roles: Mapped[list[Role]] = relationship(
        secondary="role_permission", back_populates="permissions", lazy="selectin"
    )

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "code": self.code,
            "description": self.description,
            "module": self.module,
        }


class UserRole(db.Model, TimestampMixin):
    __tablename__ = "user_role"
    __table_args__ = (UniqueConstraint("user_id", "role_id", name="uk_user_role"),)

    id: Mapped[int] = mapped_column(UInt, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        UInt, ForeignKey("users.id", ondelete="CASCADE", onupdate="CASCADE"), nullable=False
    )
    role_id: Mapped[int] = mapped_column(
        UInt, ForeignKey("roles.id", ondelete="CASCADE", onupdate="CASCADE"), nullable=False
    )


class RolePermission(db.Model, TimestampMixin):
    __tablename__ = "role_permission"
    __table_args__ = (UniqueConstraint("role_id", "permission_id", name="uk_role_permission"),)

    id: Mapped[int] = mapped_column(UInt, primary_key=True, autoincrement=True)
    role_id: Mapped[int] = mapped_column(
        UInt, ForeignKey("roles.id", ondelete="CASCADE", onupdate="CASCADE"), nullable=False
    )
    permission_id: Mapped[int] = mapped_column(
        UInt, ForeignKey("permissions.id", ondelete="CASCADE", onupdate="CASCADE"), nullable=False
    )


class User(db.Model, TimestampMixin, SoftDeleteMixin):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(UInt, primary_key=True, autoincrement=True)
    nom: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    postnom: Mapped[str | None] = mapped_column(String(50), index=True)
    prenom: Mapped[str | None] = mapped_column(String(50), index=True)
    email: Mapped[str] = mapped_column(String(100), nullable=False, unique=True, index=True)
    telephone: Mapped[str] = mapped_column(String(20), nullable=False, unique=True, index=True)
    password: Mapped[str] = mapped_column(String(255), nullable=False)
    avatar: Mapped[str | None] = mapped_column(String(255))
    statut: Mapped[str] = mapped_column(
        String(16), nullable=False, default=StatutUtilisateur.ACTIF.value, server_default="actif"
    )
    adresse: Mapped[str | None] = mapped_column(String(255))
    date_naissance: Mapped[date | None] = mapped_column(Date)
    genre: Mapped[str | None] = mapped_column(String(6))
    id_commissariat: Mapped[int | None] = mapped_column(
        UInt,
        ForeignKey("commissariats.id", ondelete="SET NULL", onupdate="CASCADE"),
        index=True,
    )
    matricule_police: Mapped[str | None] = mapped_column(String(50), unique=True)
    grade_police: Mapped[str | None] = mapped_column(String(50))
    email_verifie: Mapped[int] = mapped_column(
        TinyBool, nullable=False, default=0, server_default="0"
    )
    telephone_verifie: Mapped[int] = mapped_column(
        TinyBool, nullable=False, default=0, server_default="0"
    )
    derniere_connexion: Mapped[datetime | None] = mapped_column(DateTime)
    last_password_change: Mapped[datetime | None] = mapped_column(DateTime)

    # -------------------------------------------------------------- Relations
    commissariat: Mapped["Commissariat | None"] = relationship(
        foreign_keys=[id_commissariat], back_populates="agents", lazy="joined"
    )
    roles: Mapped[list[Role]] = relationship(
        secondary="user_role", back_populates="users", lazy="selectin"
    )

    # ------------------------------------------------------- RBAC (aide-mémoire)
    @property
    def role_names(self) -> list[str]:
        return sorted(r.nom for r in self.roles)

    @property
    def permission_codes(self) -> set[str]:
        codes: set[str] = set()
        for role in self.roles:
            codes.update(p.code for p in role.permissions)
        return codes

    def has_role(self, *noms: str) -> bool:
        return bool(set(noms) & set(self.role_names))

    def has_permission(self, code: str) -> bool:
        return code in self.permission_codes

    def est_policier(self) -> bool:
        return self.has_role("policier", "enqueteur", "admin", "super_admin")

    @property
    def est_actif(self) -> bool:
        return self.statut == StatutUtilisateur.ACTIF.value

    # ----------------------------------------------------------- Sérialisation
    def to_dict(
        self,
        with_roles: bool = True,
        with_permissions: bool = False,
        with_sensitive: bool = False,
    ) -> dict:
        data: dict = {
            "id": self.id,
            "nom": self.nom,
            "postnom": self.postnom,
            "prenom": self.prenom,
            "nom_complet": " ".join(
                p for p in (self.nom, self.postnom, self.prenom) if p
            ),
            "email": self.email,
            "telephone": self.telephone,
            "avatar": self.avatar,
            "statut": self.statut,
            "adresse": self.adresse,
            "date_naissance": self.date_naissance.isoformat() if self.date_naissance else None,
            "genre": self.genre,
            "id_commissariat": self.id_commissariat,
            "commissariat": self.commissariat.to_dict(with_geo=False) if self.commissariat else None,
            "matricule_police": self.matricule_police,
            "grade_police": self.grade_police,
            "email_verifie": bool(self.email_verifie),
            "telephone_verifie": bool(self.telephone_verifie),
            "derniere_connexion": self.derniere_connexion.isoformat() if self.derniere_connexion else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
        if with_roles:
            data["roles"] = self.role_names
        if with_permissions:
            data["permissions"] = sorted(self.permission_codes)
        if with_sensitive:
            data["last_password_change"] = (
                self.last_password_change.isoformat() if self.last_password_change else None
            )
            data["deleted_at"] = self.deleted_at.isoformat() if self.deleted_at else None
        return data
