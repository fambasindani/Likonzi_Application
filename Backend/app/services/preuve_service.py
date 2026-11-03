"""Téléversement des preuves avec empreinte SHA-256 et vérification d'intégrité."""
from __future__ import annotations

import hashlib
import mimetypes
import os
import uuid

from sqlalchemy import or_

from ..exceptions import ForbiddenError, NotFoundError, ValidationFailed
from ..extensions import db
from ..models import Alerte, Cas, Objet, Partage, Preuve, User
from . import alerte_service, audit_service, cas_service, social_service
from .validators import Payload

CHEMIN_RELATIF = "preuves"

# Extensions considérées comme des images (plafonnées à IMAGE_MAX_OCTETS).
EXTENSIONS_IMAGE = {"png", "jpg", "jpeg", "gif", "webp", "bmp", "heic", "tiff"}


def _est_image(extension: str) -> bool:
    return extension.lower() in EXTENSIONS_IMAGE


def _max_image() -> int:
    from flask import current_app, has_app_context

    if not has_app_context():
        return 200 * 1024
    return int(current_app.config.get("IMAGE_MAX_OCTETS", 200 * 1024))


# Liste blanche : aucun exécutable ni script ne doit pouvoir être stocké.
EXTENSIONS_AUTORISEES = {
    # images
    "png", "jpg", "jpeg", "gif", "webp", "bmp", "heic", "tiff",
    # vidéo / audio
    "mp4", "mov", "avi", "mkv", "webm", "3gp",
    "mp3", "wav", "m4a", "ogg", "flac", "aac",
    # documents
    "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "csv", "json", "odt", "ods",
    # archives
    "zip", "rar", "7z",
}
ROLES_POLICE = ("policier", "enqueteur", "admin", "super_admin")

EXTENSION_MIME = {
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "png": "image/png",
    "gif": "image/gif",
    "webp": "image/webp",
}


# ----------------------------------------------------------------------- autorisations


def _charger_entite(entite_type: str, entite_id: int, user: User):
    """Vérifie que l'entité existe et que `user` a le droit d'y rattacher une preuve."""
    if entite_type == "alerte":
        return alerte_service.recuperer(entite_id, user)
    if entite_type == "cas":
        return cas_service.recuperer(entite_id, user)
    if entite_type == "objet":
        objet = db.session.get(Objet, entite_id)
        if objet is None or objet.deleted_at is not None:
            raise NotFoundError("Objet introuvable.")
        # Propriétaire, forces de l'ordre, ou destinataire d'un partage.
        from . import objet_service

        if not objet_service._visible(objet, user):
            raise NotFoundError("Objet introuvable.")
        return objet
    if entite_type == "intervention":
        return cas_service.recuperer_intervention(entite_id, user)
    raise ValidationFailed(
        "Entité inconnue.",
        errors={"entite_type": ["Valeurs attendues : alerte, cas, objet, intervention."]},
    )


# ------------------------------------------------------------------------ enregistrement


def _extension(nom_fichier: str) -> str:
    ext = os.path.splitext(nom_fichier or "")[1].lstrip(".").lower()
    if not ext:
        raise ValidationFailed(
            "Fichier sans extension.", errors={"fichier": ["Extension manquante."]}
        )
    if ext not in EXTENSIONS_AUTORISEES:
        raise ValidationFailed(
            "Type de fichier refusé.",
            errors={
                "fichier": [
                    f"Extension « .{ext} » non autorisée. "
                    f"Acceptées : {', '.join(sorted(EXTENSIONS_AUTORISEES))}."
                ]
            },
        )
    return ext


def _mime(nom_stocke: str, fourni: str | None) -> str:
    if fourni and fourni.startswith(("image/", "video/", "audio/", "application/", "text/")):
        # On ne fait pas confiance au client : on recalcule quand on peut.
        devine = mimetypes.guess_type(nom_stocke)[0]
        return devine or fourni
    return mimetypes.guess_type(nom_stocke)[0] or "application/octet-stream"


def creer(data: dict, fichier, acteur: User) -> Preuve:
    """Téléverse une preuve : hash calculé en flux, puis écriture atomique."""
    p = Payload(data)
    entite_type = p.enum("entite_type", ["alerte", "cas", "objet", "intervention"], requis=True)
    entite_id = p.entier("entite_id", requis=True, min_val=1)
    type_preuve = p.enum("type_preuve", ["photo", "video", "audio", "document", "autre"], requis=True)
    description = p.chaine("description", requis=False, max_len=5000)
    p.fail_if_errors()

    if fichier is None or not getattr(fichier, "filename", ""):
        raise ValidationFailed(
            "Aucun fichier reçu.",
            errors={"fichier": ["Envoyez le fichier dans le champ « fichier »."]},
        )

    entite = _charger_entite(entite_type, entite_id, acteur)

    # Les amis CONSULTENT les alertes de leurs contacts, mais le téléversement
    # reste réservé à l'auteur de l'alerte (et aux forces de l'ordre).
    if entite_type == "alerte" and not (
        acteur.has_role(*ROLES_POLICE) or entite.id_user == acteur.id
    ):
        raise ForbiddenError(
            "Seul l'auteur de l'alerte peut y ajouter des fichiers."
        )

    ext = _extension(fichier.filename)
    nom_stocke = f"{uuid.uuid4().hex}.{ext}"
    nom_original = os.path.basename(fichier.filename)[:255]

    # Empreinte SHA-256 calculée en lecture flux (le fichier n'est jamais entier en RAM).
    hachage = hashlib.sha256()
    taille = 0
    dossier = os.path.join(_racine_uploads(), "preuves")
    os.makedirs(dossier, exist_ok=True)
    chemin_final = os.path.join(dossier, nom_stocke)

    with open(chemin_final, "wb") as sortie:
        while True:
            bloc = fichier.stream.read(1024 * 1024)
            if not bloc:
                break
            taille += len(bloc)
            hachage.update(bloc)
            sortie.write(bloc)

    if taille == 0:
        fichier.close()
        try:
            os.remove(chemin_final)
        except OSError:
            pass
        raise ValidationFailed("Fichier vide.", errors={"fichier": ["Le fichier est vide."]})

    # Les images sont plafonnées (200 Ko par défaut) : on refuse avant d'écrire
    # la ligne en base, et on supprime le fichier déjà écrit sur le disque.
    if _est_image(ext) and taille > _max_image():
        try:
            os.remove(chemin_final)
        except OSError:
            pass
        raise ValidationFailed(
            "Image trop lourde.",
            errors={
                "fichier": [
                    f"{taille // 1024} Ko — maximum {_max_image() // 1024} Ko. "
                    "Réduisez la résolution ou recadrez la photo."
                ]
            },
        )

    preuve = Preuve(
        entite_type=entite_type,
        entite_id=entite_id,
        type_preuve=type_preuve,
        nom_original=nom_original,
        nom_stocke=nom_stocke,
        extension=ext,
        type_mime=_mime(nom_stocke, getattr(fichier, "mimetype", None)),
        taille_octets=taille,
        chemin_stockage=f"{CHEMIN_RELATIF}/{nom_stocke}",
        hash_sha256=hachage.hexdigest(),
        description=description,
        id_user_upload=acteur.id,
    )
    db.session.add(preuve)
    db.session.flush()

    audit_service.audit(
        action="preuve_televersee",
        entite="preuve",
        entite_id=preuve.id,
        description=(
            f"Preuve « {nom_original} » rattachée à {entite_type}#{entite_id} "
            f"par {acteur.email}"
        ),
        apres={
            "hash_sha256": preuve.hash_sha256,
            "taille_octets": taille,
            "type_mime": preuve.type_mime,
        },
        user_id=acteur.id,
    )
    db.session.commit()
    return preuve


def _racine_uploads() -> str:
    from flask import current_app

    return current_app.config["UPLOAD_FOLDER"]


# --------------------------------------------------------------------------- lecture


def scope_preuves(query, user: User):
    """Sélectionne les preuves que l'utilisateur est en droit de consulter.

    Un ami consulte les fichiers des alertes **et des objets** de ses
    contacts (lecture seule — voir `creer` pour le téléversement).
    """
    if user.has_role(*ROLES_POLICE):
        return query  # le détail d'entité est revérifié à l'affichage

    amis = social_service.ids_amis(user)
    alertes = db.session.query(Alerte.id).filter(
        or_(Alerte.id_user == user.id, Alerte.id_user.in_(amis))
    )
    cas = db.session.query(Cas.id).filter(Cas.id_victime == user.id)
    objets_possedes = db.session.query(Objet.id).filter(
        or_(
            Objet.id_user_proprietaire == user.id,
            Objet.id_user_proprietaire.in_(amis),
        )
    )
    # Les objets explicitement partagés avec l'utilisateur sont également visibles.
    objets_partages = db.session.query(Partage.id_objet).filter(
        Partage.id_destinataire == user.id
    )
    return query.filter(
        or_(
            (Preuve.entite_type == "alerte") & Preuve.entite_id.in_(alertes),
            (Preuve.entite_type == "cas") & Preuve.entite_id.in_(cas),
            (Preuve.entite_type == "objet")
            & (Preuve.entite_id.in_(objets_possedes) | Preuve.entite_id.in_(objets_partages)),
        )
    )


def lister(
    user: User,
    page: int = 1,
    per_page: int = 20,
    entite_type: str | None = None,
    entite_id: int | None = None,
) -> tuple[list[Preuve], int]:
    query = scope_preuves(db.session.query(Preuve), user).filter(Preuve.deleted_at.is_(None))
    if entite_type:
        if entite_type not in ("alerte", "cas", "objet", "intervention"):
            raise ValidationFailed(
                "Entité inconnue.",
                errors={"entite_type": ["Valeurs : alerte, cas, objet, intervention."]},
            )
        query = query.filter(Preuve.entite_type == entite_type)
        if entite_id:
            # On revalide le droit d'accès à l'entité elle-même.
            _charger_entite(entite_type, entite_id, user)
            query = query.filter(Preuve.entite_id == entite_id)

    total = query.count()
    page, per_page = max(page, 1), min(max(per_page, 1), 100)
    items = (
        query.order_by(Preuve.id.desc()).offset((page - 1) * per_page).limit(per_page).all()
    )
    return items, total


def recuperer(preuve_id: int, user: User) -> Preuve:
    preuve = db.session.get(Preuve, preuve_id)
    if preuve is None or preuve.deleted_at is not None:
        raise NotFoundError("Preuve introuvable.")
    # L'auteur de la preuve et les forces de l'ordre y accèdent directement ;
    # sinon on applique le même périmètre que pour l'énumération.
    if user.has_role(*ROLES_POLICE) or preuve.id_user_upload == user.id:
        return preuve
    autorisee = (
        scope_preuves(db.session.query(Preuve.id).filter(Preuve.id == preuve.id), user)
        .first()
        is not None
    )
    if not autorisee:
        raise NotFoundError("Preuve introuvable.")
    return preuve


def chemin_absolu(preuve: Preuve) -> str:
    return os.path.join(_racine_uploads(), preuve.chemin_stockage.replace("/", os.sep))


# ------------------------------------------------------------------------ intégrité


def verifier_integrite(preuve: Preuve) -> dict:
    """Recalcule le SHA-256 du fichier stocké et le compare à l'empreinte en base."""
    chemin = chemin_absolu(preuve)
    resultat: dict = {
        "id": preuve.id,
        "nom_stocke": preuve.nom_stocke,
        "hash_enregistre": preuve.hash_sha256,
        "fichier_present": os.path.isfile(chemin),
        "conforme": False,
    }
    if not resultat["fichier_present"]:
        resultat["message"] = "Fichier absent du stockage."
        return resultat

    hachage = hashlib.sha256()
    taille = 0
    with open(chemin, "rb") as flux:
        for bloc in iter(lambda: flux.read(1024 * 1024), b""):
            hachage.update(bloc)
            taille += len(bloc)

    calcule = hachage.hexdigest()
    resultat["hash_calcule"] = calcule
    resultat["taille_calculee"] = taille
    resultat["taille_attendue"] = preuve.taille_octets
    resultat["conforme"] = (
        preuve.hash_sha256 == calcule and preuve.taille_octets == taille
    )
    resultat["message"] = (
        "Intégrité vérifiée." if resultat["conforme"] else "ALTÉRATION DÉTECTÉE."
    )
    return resultat


# --------------------------------------------------------------------- suppression


def supprimer(preuve: Preuve, acteur: User) -> Preuve:
    if acteur.id != preuve.id_user_upload and not acteur.has_role(*ROLES_POLICE):
        raise ForbiddenError("Suppression réservée à l'auteur ou aux forces de l'ordre.")
    if preuve.deleted_at is not None:
        return preuve
    preuve.soft_delete()
    audit_service.audit(
        action="preuve_supprimee",
        entite="preuve",
        entite_id=preuve.id,
        description=f"Preuve {preuve.nom_stocke} marquée supprimée par {acteur.email}",
        user_id=acteur.id,
    )
    db.session.commit()
    return preuve


def export_fichier(preuve: Preuve) -> tuple[str, str, str]:
    """Renvoie (chemin absolu, nom à afficher, type MIME)."""
    chemin = chemin_absolu(preuve)
    if not os.path.isfile(chemin):
        raise NotFoundError("Fichier absent du stockage.")
    return chemin, preuve.nom_original, preuve.type_mime
