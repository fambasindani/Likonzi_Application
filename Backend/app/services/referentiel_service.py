"""Référentiels géographiques : provinces → villes → communes → commissariats.

Écritures réservées à la permission `geo.gerer` (admin / super_admin).
Chaque création, modification et suppression est journalisée dans `audit_logs`.

Chaîne de cohérence imposée : la commune appartient à une ville, la ville à
une province. Lors de la création, les niveaux non fournis sont déduits du
niveau le plus fin saisi ; toute incohérence est rejetée en 422.
"""
from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from ..exceptions import ConflictError, NotFoundError, ValidationFailed
from ..extensions import db
from ..models import Commissariat, Commune, Province, User, Ville
from . import audit_service
from .validators import Payload

LAT_MIN, LAT_MAX = -90.0, 90.0
LON_MIN, LON_MAX = -180.0, 180.0


# --------------------------------------------------------------------- utilitaires


def _recuperer(modele, identifiant: int | None, libelle: str):
    if not identifiant:
        raise NotFoundError(f"{libelle} à préciser.")
    item = db.session.get(modele, identifiant)
    if item is None or getattr(item, "deleted_at", None) is not None:
        raise NotFoundError(f"{libelle} introuvable.")
    return item


def _coordonnees(p: Payload) -> tuple[Decimal | None, Decimal | None]:
    latitude = p.decimal("latitude", min_val=LAT_MIN, max_val=LAT_MAX)
    longitude = p.decimal("longitude", min_val=LON_MIN, max_val=LON_MAX)
    return latitude, longitude


def _imposer_paire(latitude, longitude) -> None:
    if (latitude is None) != (longitude is None):
        champ = "longitude" if latitude is not None else "latitude"
        raise ValidationFailed(
            "Données invalides.",
            errors={champ: ["Latitude et longitude doivent être fournies ensemble."]},
        )


def _enregistrer(entite: str, action: str, item, libelle: str, acteur: User) -> None:
    audit_service.audit(
        action=action,
        entite=entite,
        entite_id=item.id,
        description=libelle,
        user_id=acteur.id,
    )
    db.session.commit()


def _doublon(erreurs: dict, message: str) -> None:
    raise ConflictError(message, errors=erreurs)


# ----------------------------------------------------------------------- provinces


def creer_province(data: dict, acteur: User) -> Province:
    p = Payload(data)
    code = p.chaine("code", max_len=10)
    nom = p.chaine("nom", max_len=100)
    chef_lieu = p.chaine("chef_lieu", requis=False, max_len=100)
    p.fail_if_errors()

    code = code.upper()
    if Province.query.filter((Province.code == code) | (Province.nom == nom)).first():
        _doublon({"code": ["Ce code est déjà utilisé."]}, "Code ou nom de province déjà utilisé.")

    item = Province(code=code, nom=nom, chef_lieu=chef_lieu)
    db.session.add(item)
    db.session.flush()
    _enregistrer("province", "province_creee", item, f"Province {item.nom} créée", acteur)
    return item


def modifier_province(item: Province, data: dict, acteur: User) -> Province:
    p = Payload(data)
    code = p.chaine("code", requis=False, max_len=10, default=item.code)
    nom = p.chaine("nom", requis=False, max_len=100, default=item.nom)
    chef_lieu = item.chef_lieu
    if "chef_lieu" in data:
        chef_lieu = p.chaine("chef_lieu", requis=False, max_len=100) or None
    p.fail_if_errors()

    code = code.upper()
    doublon = Province.query.filter(
        ((Province.code == code) | (Province.nom == nom)) & (Province.id != item.id)
    ).first()
    if doublon:
        _doublon({"code": ["Ce code est déjà utilisé."]}, "Code ou nom de province déjà utilisé.")

    item.code, item.nom, item.chef_lieu = code, nom, chef_lieu
    _enregistrer("province", "province_modifiee", item, f"Province {item.nom} modifiée", acteur)
    return item


def supprimer_province(item: Province, acteur: User) -> None:
    if item.villes:
        _doublon(
            {"province": ["Des villes sont rattachées à cette province."]},
            "Province non vide : supprimez d'abord ses villes.",
        )
    nom = item.nom
    db.session.delete(item)
    _enregistrer("province", "province_supprimee", item, f"Province {nom} supprimée", acteur)


# ------------------------------------------------------------------------- villes


def creer_ville(data: dict, acteur: User) -> Ville:
    p = Payload(data)
    id_province = p.entier("id_province", requis=True, min_val=1)
    nom = p.chaine("nom", max_len=100)
    latitude, longitude = _coordonnees(p)
    p.fail_if_errors()

    _imposer_paire(latitude, longitude)
    _recuperer(Province, id_province, "Province")
    if Ville.query.filter_by(id_province=id_province, nom=nom).first():
        _doublon({"nom": ["Cette ville existe déjà dans la province."]},
                 "Cette ville existe déjà dans la province.")

    item = Ville(
        id_province=id_province, nom=nom, latitude=latitude, longitude=longitude
    )
    db.session.add(item)
    db.session.flush()
    _enregistrer("ville", "ville_creee", item, f"Ville {item.nom} créée", acteur)
    return item


def modifier_ville(item: Ville, data: dict, acteur: User) -> Ville:
    p = Payload(data)
    id_province = p.entier("id_province", requis=False, default=item.id_province, min_val=1)
    nom = p.chaine("nom", requis=False, max_len=100, default=item.nom)
    latitude = item.latitude
    longitude = item.longitude
    if "latitude" in data or "longitude" in data:
        latitude, longitude = _coordonnees(p)
    p.fail_if_errors()

    _imposer_paire(latitude, longitude)
    _recuperer(Province, id_province, "Province")
    doublon = Ville.query.filter(
        Ville.id_province == id_province, Ville.nom == nom, Ville.id != item.id
    ).first()
    if doublon:
        _doublon({"nom": ["Cette ville existe déjà dans la province."]},
                 "Cette ville existe déjà dans la province.")

    item.id_province, item.nom = id_province, nom
    item.latitude, item.longitude = latitude, longitude
    _enregistrer("ville", "ville_modifiee", item, f"Ville {item.nom} modifiée", acteur)
    return item


def supprimer_ville(item: Ville, acteur: User) -> None:
    if Commune.query.filter(Commune.id_ville == item.id).count():
        _doublon(
            {"ville": ["Des communes sont rattachées à cette ville."]},
            "Ville non vide : supprimez d'abord ses communes.",
        )
    nom = item.nom
    db.session.delete(item)
    _enregistrer("ville", "ville_supprimee", item, f"Ville {nom} supprimée", acteur)


# ----------------------------------------------------------------------- communes


def creer_commune(data: dict, acteur: User) -> Commune:
    p = Payload(data)
    id_ville = p.entier("id_ville", requis=True, min_val=1)
    nom = p.chaine("nom", max_len=100)
    code = p.chaine("code", requis=False, max_len=20)
    latitude, longitude = _coordonnees(p)
    p.fail_if_errors()

    _imposer_paire(latitude, longitude)
    _recuperer(Ville, id_ville, "Ville")
    if Commune.query.filter_by(id_ville=id_ville, nom=nom).first():
        _doublon({"nom": ["Cette commune existe déjà dans la ville."]},
                 "Cette commune existe déjà dans la ville.")

    item = Commune(
        id_ville=id_ville, nom=nom, code=code, latitude=latitude, longitude=longitude
    )
    db.session.add(item)
    db.session.flush()
    _enregistrer("commune", "commune_creee", item, f"Commune {item.nom} créée", acteur)
    return item


def modifier_commune(item: Commune, data: dict, acteur: User) -> Commune:
    p = Payload(data)
    id_ville = p.entier("id_ville", requis=False, default=item.id_ville, min_val=1)
    nom = p.chaine("nom", requis=False, max_len=100, default=item.nom)
    code = item.code
    if "code" in data:
        code = p.chaine("code", requis=False, max_len=20) or None
    latitude = item.latitude
    longitude = item.longitude
    if "latitude" in data or "longitude" in data:
        latitude, longitude = _coordonnees(p)
    p.fail_if_errors()

    _imposer_paire(latitude, longitude)
    _recuperer(Ville, id_ville, "Ville")
    doublon = Commune.query.filter(
        Commune.id_ville == id_ville, Commune.nom == nom, Commune.id != item.id
    ).first()
    if doublon:
        _doublon({"nom": ["Cette commune existe déjà dans la ville."]},
                 "Cette commune existe déjà dans la ville.")

    item.id_ville, item.nom, item.code = id_ville, nom, code
    item.latitude, item.longitude = latitude, longitude
    _enregistrer("commune", "commune_modifiee", item, f"Commune {item.nom} modifiée", acteur)
    return item


def supprimer_commune(item: Commune, acteur: User) -> None:
    nom = item.nom
    # Les commissariats rattachés sont détachés automatiquement (FK SET NULL).
    db.session.delete(item)
    _enregistrer("commune", "commune_supprimee", item, f"Commune {nom} supprimée", acteur)


# ------------------------------------------------------------------- commissariats


def _statut(data: dict, actuel: bool = True) -> int:
    brut = data.get("statut", actuel)
    if isinstance(brut, str):
        return 1 if brut.strip().lower() in {"1", "true", "yes", "on", "actif"} else 0
    return 1 if brut else 0


def _coherencer(
    id_province: int | None,
    id_ville: int | None,
    id_commune: int | None,
) -> tuple[int | None, int | None, int | None]:
    """Déduit les niveaux manquants à partir du niveau le plus fin saisi."""
    commune = _recuperer(Commune, id_commune, "Commune") if id_commune else None
    ville = _recuperer(Ville, id_ville, "Ville") if id_ville else (commune.ville if commune else None)
    if commune and ville and commune.id_ville != ville.id:
        raise ValidationFailed(
            "Données invalides.",
            errors={"id_commune": ["Cette commune n'appartient pas à cette ville."]},
        )
    province = _recuperer(Province, id_province, "Province") if id_province else (
        ville.province if ville else None
    )
    if ville and province and ville.id_province != province.id:
        raise ValidationFailed(
            "Données invalides.",
            errors={"id_ville": ["Cette ville n'appartient pas à cette province."]},
        )
    id_commune = commune.id if commune else None
    id_ville = ville.id if ville else None
    id_province = province.id if province else None
    return id_province, id_ville, id_commune


def creer_commissariat(data: dict, acteur: User) -> Commissariat:
    p = Payload(data)
    code = p.chaine("code", max_len=20)
    nom = p.chaine("nom", max_len=150)
    adresse = p.chaine("adresse", requis=False, max_len=255)
    telephone = p.telephone(requis=False)
    email = p.email(requis=False)
    id_province = p.entier("id_province", min_val=1)
    id_ville = p.entier("id_ville", min_val=1)
    id_commune = p.entier("id_commune", min_val=1)
    latitude, longitude = _coordonnees(p)
    p.fail_if_errors()

    _imposer_paire(latitude, longitude)
    code = code.upper()
    if Commissariat.query.filter(
        Commissariat.code == code, Commissariat.deleted_at.is_(None)
    ).first():
        _doublon({"code": ["Ce code est déjà utilisé."]}, "Code de commissariat déjà utilisé.")

    id_province, id_ville, id_commune = _coherencer(id_province, id_ville, id_commune)
    item = Commissariat(
        code=code,
        nom=nom,
        id_province=id_province,
        id_ville=id_ville,
        id_commune=id_commune,
        adresse=adresse,
        telephone=telephone,
        email=email,
        latitude=latitude,
        longitude=longitude,
        statut=_statut(data),
    )
    db.session.add(item)
    db.session.flush()
    _enregistrer("commissariat", "commissariat_cree",
                 item, f"Commissariat {item.nom} créé", acteur)
    return item


def modifier_commissariat(item: Commissariat, data: dict, acteur: User) -> Commissariat:
    p = Payload(data)
    code = p.chaine("code", requis=False, max_len=20, default=item.code)
    nom = p.chaine("nom", requis=False, max_len=150, default=item.nom)
    adresse = item.adresse
    if "adresse" in data:
        adresse = p.chaine("adresse", requis=False, max_len=255) or None
    telephone = p.telephone(requis=False) if "telephone" in data else item.telephone
    email = p.email(requis=False) if "email" in data else item.email
    id_province = p.entier("id_province", min_val=1) if "id_province" in data else item.id_province
    id_ville = p.entier("id_ville", min_val=1) if "id_ville" in data else item.id_ville
    id_commune = p.entier("id_commune", min_val=1) if "id_commune" in data else item.id_commune
    latitude = item.latitude
    longitude = item.longitude
    if "latitude" in data or "longitude" in data:
        latitude, longitude = _coordonnees(p)
    p.fail_if_errors()

    _imposer_paire(latitude, longitude)
    code = code.upper()
    doublon = Commissariat.query.filter(
        Commissariat.code == code,
        Commissariat.deleted_at.is_(None),
        Commissariat.id != item.id,
    ).first()
    if doublon:
        _doublon({"code": ["Ce code est déjà utilisé."]}, "Code de commissariat déjà utilisé.")

    id_province, id_ville, id_commune = _coherencer(id_province, id_ville, id_commune)
    item.code, item.nom = code, nom
    item.adresse, item.telephone, item.email = adresse, telephone, email
    item.id_province, item.id_ville, item.id_commune = id_province, id_ville, id_commune
    item.latitude, item.longitude = latitude, longitude
    if "statut" in data:
        item.statut = _statut(data, bool(item.statut))
    _enregistrer("commissariat", "commissariat_modifie",
                 item, f"Commissariat {item.nom} modifié", acteur)
    return item


def supprimer_commissariat(item: Commissariat, acteur: User) -> None:
    """Purge douce : le commissariat disparaît des listings, l'audit conserve la trace."""
    item.deleted_at = datetime.now()
    _enregistrer(
        "commissariat", "commissariat_supprime", item,
        f"Commissariat {item.nom} archivé", acteur,
    )
