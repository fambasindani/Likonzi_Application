"""Tous les modèles — importez ce module pour que les mappers soient configurés."""
from __future__ import annotations

from .alerte import Alerte, TypeAlerte
from .audit import AuditLog
from .base import SoftDeleteMixin, TimestampMixin
from .cas import Cas, Intervention
from .enums import (
    EntiteNotification,
    EntitePreuve,
    Genre,
    NiveauUrgence,
    PrioriteCas,
    SourceLocalisation,
    StatutAlerte,
    StatutCas,
    StatutDemande,
    StatutObjet,
    StatutUtilisateur,
    TypeCas,
    TypeIntervention,
    TypeJeton,
    TypeNotification,
    TypePreuve,
)
from .geo import Commissariat, Localisation, Province, Ville
from .objet import Objet, Partage, TypeObjet
from .preuve import Preuve
from .security import TokenDenylist, VerificationToken
from .social import Demande, Note, Notification
from .user import Permission, Role, RolePermission, User, UserRole

__all__ = [
    # geo
    "Province",
    "Ville",
    "Commissariat",
    "Localisation",
    # users / rbac
    "User",
    "Role",
    "Permission",
    "UserRole",
    "RolePermission",
    # sécurité
    "VerificationToken",
    "TokenDenylist",
    # alertes
    "TypeAlerte",
    "Alerte",
    # cas
    "Cas",
    "Intervention",
    # objets
    "TypeObjet",
    "Objet",
    "Partage",
    # preuves
    "Preuve",
    # social
    "Demande",
    "Note",
    "Notification",
    # audit
    "AuditLog",
    # mixins
    "TimestampMixin",
    "SoftDeleteMixin",
    # enums
    "Genre",
    "StatutUtilisateur",
    "NiveauUrgence",
    "StatutAlerte",
    "TypeCas",
    "StatutCas",
    "PrioriteCas",
    "TypeIntervention",
    "StatutObjet",
    "TypePreuve",
    "EntitePreuve",
    "SourceLocalisation",
    "StatutDemande",
    "TypeNotification",
    "EntiteNotification",
    "TypeJeton",
]
