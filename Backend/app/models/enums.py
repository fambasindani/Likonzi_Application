"""Types énumérés miroir des ENUM MySQL.

`values_callable` force SQLAlchemy à persister `.value` (et non `.name`),
ce qui garantit l'adéquation avec les ENUM définis dans `securite_sociale_v2.sql`.
"""
from __future__ import annotations

import enum


def _values(enum_cls: type[enum.Enum]) -> list[str]:
    return [member.value for member in enum_cls]


class StrEnum(str, enum.Enum):
    """Base : comparable aux `str` natifs, sérialisable en JSON sans surcouche."""

    def __str__(self) -> str:  # pragma: no cover - trivial
        return self.value

    @classmethod
    def values(cls) -> list[str]:
        return _values(cls)


class Genre(StrEnum):
    M = "M"
    F = "F"
    AUTRE = "Autre"


class StatutUtilisateur(StrEnum):
    ACTIF = "actif"
    INACTIF = "inactif"
    SUSPENDU = "suspendu"
    BLOQUE = "bloque"


class NiveauUrgence(StrEnum):
    FAIBLE = "faible"
    MOYEN = "moyen"
    ELEVE = "eleve"
    CRITIQUE = "critique"


class StatutAlerte(StrEnum):
    NOUVELLE = "nouvelle"
    PRISE_EN_COMPTE = "prise_en_compte"
    EN_COURS = "en_cours"
    RESOLUE = "resolue"
    CLASSEE = "classee"
    FAUSSE_ALERTE = "fausse_alerte"


class TypeCas(StrEnum):
    ENLEVEMENT = "enlevement"
    VOL_VEHICULE = "vol_vehicule"
    VOL_OBJET = "vol_objet"
    AGRESSION = "agression"
    DISPARITION = "disparition"
    AUTRE = "autre"


class StatutCas(StrEnum):
    OUVERT = "ouvert"
    EN_COURS = "en_cours"
    EN_ATTENTE = "en_attente"
    CLOS = "clos"
    CLASSE = "classe"


class PrioriteCas(StrEnum):
    BASSE = "basse"
    NORMALE = "normale"
    HAUTE = "haute"
    CRITIQUE = "critique"


class TypeIntervention(StrEnum):
    PATROUILLE = "patrouille"
    PERQUISITION = "perquisition"
    AUDITION = "audition"
    ARRESTATION = "arrestation"
    PERQUISITION_DOMICILE = "perquisition_domicile"
    CONVOCATION = "convocation"
    AUTRE = "autre"


class StatutObjet(StrEnum):
    DECLARE_VOL = "declare_vol"
    RECHERCHE = "recherche"
    RETROUVE = "retrouve"
    RESTITUE = "restitue"
    EN_FOURRIERE = "en_fourriere"
    CLASSE = "classe"


class TypePreuve(StrEnum):
    PHOTO = "photo"
    VIDEO = "video"
    AUDIO = "audio"
    DOCUMENT = "document"
    AUTRE = "autre"


class EntitePreuve(StrEnum):
    CAS = "cas"
    ALERTE = "alerte"
    OBJET = "objet"
    INTERVENTION = "intervention"


class SourceLocalisation(StrEnum):
    GPS = "gps"
    RESEAU = "reseau"
    MANUEL = "manuel"


class StatutDemande(StrEnum):
    EN_ATTENTE = "en_attente"
    ACCEPTEE = "acceptee"
    REFUSEE = "refusee"
    ANNULEE = "annulee"


class TypeNotification(StrEnum):
    SYSTEME = "systeme"
    DEMANDE_AMI = "demande_ami"
    MESSAGE = "message"
    ALERTE_CREEE = "alerte_creee"
    ALERTE_ASSIGNEE = "alerte_assignee"
    ALERTE_RESOLUE = "alerte_resolue"
    CAS_MAJ = "cas_maj"
    PREUVE_AJOUTEE = "preuve_ajoutee"
    OBJET_RETROUVE = "objet_retrouve"
    SOS = "sos"


class EntiteNotification(StrEnum):
    ALERTE = "alerte"
    CAS = "cas"
    OBJET = "objet"
    INTERVENTION = "intervention"
    DEMANDE = "demande"
    PREUVE = "preuve"
    USER = "user"


class TypeJeton(StrEnum):
    EMAIL = "email"
    TELEPHONE = "telephone"
    PASSWORD_RESET = "password_reset"
