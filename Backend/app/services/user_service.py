"""Consultation et gestion des comptes utilisateurs."""
from __future__ import annotations

import os
import uuid
from datetime import datetime
from typing import Any

from flask import current_app
from sqlalchemy import func, or_

from ..exceptions import ForbiddenError, NotFoundError, ValidationFailed
from ..extensions import db
from ..models import Role, User
from . import audit_service
from .validators import Payload

CHAMPS_LIBRES = {
    "nom",
    "postnom",
    "prenom",
    "adresse",
    "genre",
    "date_naissance",
    "avatar",
}
CHAMPS_ADMIN = CHAMPS_LIBRES | {
    "email",
    "telephone",
    "statut",
    "id_commissariat",
    "matricule_police",
    "grade_police",
}


# --------------------------------------------------------------------------- lecture


def lister(
    page: int = 1,
    per_page: int = 20,
    q: str | None = None,
    role: str | None = None,
    statut: str | None = None,
    id_commissariat: int | None = None,
    exclure_id: int | None = None,
) -> tuple[list[User], int]:
    query = db.session.query(User).filter(User.deleted_at.is_(None))

    if q:
        like = f"%{q.strip()}%"
        query = query.filter(
            or_(
                User.nom.ilike(like),
                User.postnom.ilike(like),
                User.prenom.ilike(like),
                User.email.ilike(like),
                User.telephone.ilike(like),
                User.matricule_police.ilike(like),
            )
        )
    if statut:
        query = query.filter(User.statut == statut)
    if id_commissariat:
        query = query.filter(User.id_commissariat == id_commissariat)
    if role:
        query = query.join(User.roles).filter(Role.nom == role)
    if exclure_id:
        query = query.filter(User.id != exclure_id)

    total = query.with_entities(func.count(func.distinct(User.id))).scalar() or 0
    page = max(page, 1)
    per_page = min(max(per_page, 1), 100)
    items = (
        query.order_by(User.nom, User.id)
        .offset((page - 1) * per_page)
        .limit(per_page)
        .all()
    )
    return items, total


def recuperer(user_id: int) -> User:
    user = db.session.get(User, user_id)
    if user is None or user.deleted_at is not None:
        raise NotFoundError("Utilisateur introuvable.")
    return user


# --------------------------------------------------------------------------- écriture


def _appliquer_champs(user: User, data: dict[str, Any], champs_autorises: set[str]) -> dict:
    """Met à jour les champs autorisés ; renvoie les valeurs avant/après pour l'audit."""
    p = Payload(data)

    champs_modifies: dict[str, Any] = {}
    avant: dict[str, Any] = {}
    apres: dict[str, Any] = {}

    if "nom" in champs_autorises and "nom" in data:
        champs_modifies["nom"] = p.chaine("nom", requis=False, max_len=50)
    if "postnom" in champs_autorises and "postnom" in data:
        champs_modifies["postnom"] = p.chaine("postnom", requis=False, max_len=50)
    if "prenom" in champs_autorises and "prenom" in data:
        champs_modifies["prenom"] = p.chaine("prenom", requis=False, max_len=50)
    if "adresse" in champs_autorises and "adresse" in data:
        champs_modifies["adresse"] = p.chaine("adresse", requis=False, max_len=255)
    if "genre" in champs_autorises and "genre" in data:
        champs_modifies["genre"] = p.enum("genre", ["M", "F", "Autre"], requis=False)
    if "date_naissance" in champs_autorises and "date_naissance" in data:
        champs_modifies["date_naissance"] = p.date("date_naissance", requis=False)

    # ------------------------------------------------------- champs réservés admin
    if "email" in champs_autorises and "email" in data:
        email = p.email("email")
        if email and email != user.email:
            if db.session.query(User.id).filter(User.email == email, User.id != user.id).first():
                p.errors.setdefault("email", []).append("Cette adresse e-mail est déjà utilisée.")
            else:
                champs_modifies["email"] = email
                user.email_verifie = 0
    if "telephone" in champs_autorises and "telephone" in data:
        tel = p.telephone("telephone")
        if tel and tel != user.telephone:
            if db.session.query(User.id).filter(User.telephone == tel, User.id != user.id).first():
                p.errors.setdefault("telephone", []).append("Ce numéro est déjà utilisé.")
            else:
                champs_modifies["telephone"] = tel
                user.telephone_verifie = 0
    if "statut" in champs_autorises and "statut" in data:
        val = p.enum("statut", ["actif", "inactif", "suspendu", "bloque"], requis=True)
        champs_modifies["statut"] = val
    if "id_commissariat" in champs_autorises and "id_commissariat" in data:
        val = p.entier("id_commissariat", requis=False, min_val=1)
        champs_modifies["id_commissariat"] = val
    if "matricule_police" in champs_autorises and "matricule_police" in data:
        val = p.chaine("matricule_police", requis=False, max_len=50)
        if val and val != user.matricule_police:
            if (
                db.session.query(User.id)
                .filter(User.matricule_police == val, User.id != user.id)
                .first()
            ):
                p.errors.setdefault("matricule_police", []).append("Ce matricule est déjà attribué.")
            else:
                champs_modifies["matricule_police"] = val
    if "grade_police" in champs_autorises and "grade_police" in data:
        val = p.chaine("grade_police", requis=False, max_len=50)
        champs_modifies["grade_police"] = val

    if p.errors:
        raise ValidationFailed("Données invalides.", errors=p.errors)

    for field, value in champs_modifies.items():
        ancien = getattr(user, field)
        if ancien != value:
            avant[field] = ancien.isoformat() if isinstance(ancien, datetime) else ancien
            apres[field] = value.isoformat() if isinstance(value, datetime) else value
            setattr(user, field, value)
    return {"avant": avant or None, "apres": apres or None}


def modifier(user_cible: User, data: dict[str, Any], acteur: User) -> User:
    """`acteur` ne peut modifier que les champs autorisés par son périmètre."""
    est_soimeme = acteur.id == user_cible.id
    est_admin = acteur.has_permission("users.suspendre") or acteur.has_role(
        "admin", "super_admin"
    )

    if est_soimeme:
        champs = CHAMPS_LIBRES
    elif est_admin:
        champs = CHAMPS_ADMIN
    else:
        raise ForbiddenError("Vous ne pouvez modifier que votre propre profil.")

    diff = _appliquer_champs(user_cible, data, champs)
    if diff["apres"]:
        audit_service.audit(
            action="maj_utilisateur",
            entite="user",
            entite_id=user_cible.id,
            description=f"Profil de {user_cible.email} mis à jour",
            avant=diff["avant"],
            apres=diff["apres"],
            user_id=acteur.id,
        )
        db.session.commit()
    else:
        db.session.rollback()
    return user_cible


def changer_statut(user_cible: User, statut: str, acteur: User) -> User:
    if user_cible.id == acteur.id:
        raise ForbiddenError("Vous ne pouvez pas changer votre propre statut.")
    if user_cible.has_role("super_admin") and not acteur.has_role("super_admin"):
        raise ForbiddenError("Seul un super administrateur peut agir sur un super administrateur.")
    if statut not in ("actif", "inactif", "suspendu", "bloque"):
        raise ValidationFailed(
            "Statut invalide.",
            errors={"statut": ["Valeurs attendues : actif, inactif, suspendu, bloque."]},
        )
    ancien = user_cible.statut
    if ancien == statut:
        return user_cible
    user_cible.statut = statut
    audit_service.audit(
        action="changement_statut",
        entite="user",
        entite_id=user_cible.id,
        description=f"Statut {ancien} -> {statut}",
        avant={"statut": ancien},
        apres={"statut": statut},
        user_id=acteur.id,
    )
    db.session.commit()
    return user_cible


def supprimer(user_cible: User, acteur: User) -> User:
    """Suppression douce : les preuves/alertes judiciaires restent intactes."""
    if user_cible.id == acteur.id:
        raise ForbiddenError("Vous ne pouvez pas supprimer votre propre compte.")
    if user_cible.has_role("super_admin") and not acteur.has_role("super_admin"):
        raise ForbiddenError("Seul un super administrateur peut supprimer un super administrateur.")
    if user_cible.deleted_at is not None:
        return user_cible

    user_cible.deleted_at = datetime.now()
    user_cible.statut = "inactif"
    audit_service.audit(
        action="suppression_compte",
        entite="user",
        entite_id=user_cible.id,
        description=f"Suppression douce de {user_cible.email}",
        user_id=acteur.id,
    )
    db.session.commit()
    return user_cible


def attribuer_roles(user_cible: User, noms_roles: list[str], acteur: User) -> User:
    if not acteur.has_role("super_admin"):
        raise ForbiddenError("Seul un super administrateur peut modifier les rôles.")
    if not isinstance(noms_roles, list) or not noms_roles:
        raise ValidationFailed(
            "Liste de rôles requise.",
            errors={"roles": ["Fournissez au moins un rôle."]},
        )
    if user_cible.id == acteur.id and "super_admin" not in noms_roles:
        raise ForbiddenError("Vous ne pouvez pas retirer votre rôle de super administrateur.")

    roles = db.session.query(Role).filter(Role.nom.in_(noms_roles)).all()
    trouves = {r.nom for r in roles}
    manquants = [n for n in noms_roles if n not in trouves]
    if manquants:
        raise ValidationFailed(
            "Rôle inconnu.",
            errors={"roles": [f"Rôle inconnu : {m}" for m in manquants]},
        )

    avant = user_cible.role_names
    user_cible.roles = sorted(roles, key=lambda r: r.nom)
    audit_service.audit(
        action="attribution_roles",
        entite="user",
        entite_id=user_cible.id,
        description=f"Rôles {avant} -> {user_cible.role_names}",
        avant={"roles": avant},
        apres={"roles": user_cible.role_names},
        user_id=acteur.id,
    )
    db.session.commit()
    return user_cible


# --------------------------------------------------------------------------- avatar


def _extension_valide(nom_fichier: str, autorisees: set[str]) -> str:
    ext = os.path.splitext(nom_fichier or "")[1].lstrip(".").lower()
    if ext not in autorisees:
        raise ValidationFailed(
            "Format de fichier non autorisé.",
            errors={
                "image": [f"Extensions acceptées : {', '.join(sorted(autorisees))}."]
            },
        )
    return ext


def changer_avatar(user: User, fichier, acteur: User, dossier: str, autorisees: set[str]) -> str:
    """Enregistre l'avatar et renvoie le nom de fichier stocké."""
    if user.id != acteur.id and not acteur.has_permission("users.suspendre"):
        raise ForbiddenError("Vous ne pouvez changer que votre propre avatar.")

    ext = _extension_valide(getattr(fichier, "filename", "") or "", autorisees)
    nom_stocke = f"{uuid.uuid4().hex}.{ext}"

    dest_dir = os.path.join(dossier, "avatars")
    os.makedirs(dest_dir, exist_ok=True)
    chemin = os.path.join(dest_dir, nom_stocke)
    fichier.save(chemin)

    taille = os.path.getsize(chemin)
    plafond = int(current_app.config.get("IMAGE_MAX_OCTETS", 200 * 1024))
    if taille > plafond:
        try:
            os.remove(chemin)
        except OSError:
            pass
        raise ValidationFailed(
            "Image trop lourde.",
            errors={
                "image": [
                    f"{taille // 1024} Ko — maximum {plafond // 1024} Ko."
                ]
            },
        )

    ancien = user.avatar
    # Chemin web par rapport à /static/ (UPLOAD_FOLDER = static/uploads)
    user.avatar = f"uploads/avatars/{nom_stocke}"
    audit_service.audit(
        action="maj_avatar",
        entite="user",
        entite_id=user.id,
        description="Avatar mis à jour",
        avant={"avatar": ancien},
        apres={"avatar": user.avatar},
        user_id=acteur.id,
    )
    db.session.commit()
    return user.avatar
