"""Cycle de vie des alertes : création citoyenne, file du commissariat, traitement."""
from __future__ import annotations

import secrets
from datetime import datetime
from decimal import Decimal

from sqlalchemy import or_

from ..exceptions import ForbiddenError, NotFoundError, ValidationFailed
from ..extensions import db
from ..models import Alerte, TypeAlerte, User
from ..realtime import prevoir
from . import audit_service, geo_service, social_service
from .notification_service import creer_notification, notifier_groupe
from .validators import Payload

# Transitions autorisées du statut d'une alerte.
TRANSITIONS: dict[str, set[str]] = {
    "nouvelle": {"prise_en_compte", "en_cours", "resolue", "classee", "fausse_alerte"},
    "prise_en_compte": {"en_cours", "resolue", "classee", "fausse_alerte"},
    "en_cours": {"resolue", "classee", "fausse_alerte"},
    "resolue": set(),
    "classee": set(),
    "fausse_alerte": set(),
}
STATUTS_TERMINAUX = {"resolue", "classee", "fausse_alerte"}
STATUTS = sorted(set(TRANSITIONS) | {t for valeurs in TRANSITIONS.values() for t in valeurs})
URGENCES = ["faible", "moyen", "eleve", "critique"]
ROLES_POLICE = ("policier", "enqueteur", "admin", "super_admin")


# --------------------------------------------------------------------------- utilitaires


def nouvelle_reference() -> str:
    """`ALT-AAAAMMJJ-XXXXXX` — l'unicité est garantie par `uk_alertes_reference`."""
    return f"ALT-{datetime.now():%Y%m%d}-{secrets.token_hex(3).upper()}"


def scope_alertes(query, user: User):
    """Périmètre de visibilité selon le rôle de l'utilisateur.

    Un citoyen voit ses alertes **et celles de ses amis** (demandes acceptées) :
    « mes amis voient mes alertes ».
    """
    if user.has_role("admin", "super_admin"):
        return query
    if user.has_role(*ROLES_POLICE):
        conditions = []
        if user.id_commissariat:
            conditions.append(Alerte.id_commissariat == user.id_commissariat)
        conditions.append(Alerte.id_policier_assignee == user.id)
        return query.filter(or_(*conditions))
    amis = social_service.ids_amis(user)
    if amis:
        return query.filter(or_(Alerte.id_user == user.id, Alerte.id_user.in_(amis)))
    return query.filter(Alerte.id_user == user.id)


def _alerte_visible(alerte: Alerte, user: User) -> bool:
    if user.has_role("admin", "super_admin"):
        return True
    if user.has_role(*ROLES_POLICE):
        return (
            (user.id_commissariat and alerte.id_commissariat == user.id_commissariat)
            or alerte.id_policier_assignee == user.id
        )
    if alerte.id_user == user.id:
        return True
    # Les amis consultent les alertes de leurs contacts.
    return alerte.id_user in social_service.ids_amis(user)


def recuperer(alerte_id: int, user: User) -> Alerte:
    alerte = db.session.get(Alerte, alerte_id)
    if alerte is None or alerte.deleted_at is not None:
        raise NotFoundError("Alerte introuvable.")
    if not _alerte_visible(alerte, user):
        # On ne révèle pas l'existence d'une alerte hors périmètre.
        raise NotFoundError("Alerte introuvable.")
    return alerte


# -------------------------------------------------------------------------- création


def creer(data: dict, acteur: User) -> Alerte:
    p = Payload(data)
    id_type = p.entier("id_type_alerte", requis=True, min_val=1)
    contenu = p.chaine("contenu", requis=True, min_len=3, max_len=5000)
    urgence = p.enum("niveau_urgence", URGENCES)
    latitude = p.decimal("latitude", min_val=-90.0, max_val=90.0)
    longitude = p.decimal("longitude", min_val=-180.0, max_val=180.0)
    adresse = p.chaine("adresse_precise", requis=False, max_len=255)
    id_commissariat = p.entier("id_commissariat", min_val=1)
    p.fail_if_errors()

    type_alerte = db.session.get(TypeAlerte, id_type)
    if type_alerte is None or type_alerte.statut != 1:
        raise ValidationFailed(
            "Type d'alerte inconnu ou inactif.",
            errors={"id_type_alerte": ["Type inexistant ou désactivé."]},
        )

    geo_complet = latitude is not None and longitude is not None

    # Affectation automatique au commissariat le plus proche si non précisé.
    if not id_commissariat and geo_complet:
        proche = geo_service.commissariat_le_plus_proche(float(latitude), float(longitude))
        if proche is not None:
            id_commissariat = proche.id
    if not id_commissariat and acteur.id_commissariat:
        id_commissariat = acteur.id_commissariat
    if not id_commissariat:
        raise ValidationFailed(
            "Aucun commissariat de rattachement.",
            errors={
                "latitude": ["Fournissez la position GPS ou un commissariat."],
                "id_commissariat": ["Ou précisez un commissariat."],
            },
        )

    alerte = Alerte(
        reference=nouvelle_reference(),
        id_user=acteur.id,
        id_type_alerte=id_type,
        contenu=contenu,
        niveau_urgence=urgence or type_alerte.niveau_urgence_defaut,
        statut="nouvelle",
        id_commissariat=id_commissariat,
        latitude=Decimal(str(latitude)) if latitude is not None else None,
        longitude=Decimal(str(longitude)) if longitude is not None else None,
        adresse_precise=adresse,
        date_alerte=datetime.now(),
    )
    db.session.add(alerte)
    db.session.flush()

    commissariat = alerte.commissariat
    if commissariat and commissariat.responsable_id:
        creer_notification(
            commissariat.responsable_id,
            "Nouvelle alerte",
            f"[{alerte.reference}] {alerte.niveau_urgence} — {contenu[:120]}",
            type_notif="alerte_creee",
            entite_type="alerte",
            entite_id=alerte.id,
            lien=f"/alertes/{alerte.id}",
        )

    if alerte.id_commissariat:
        prevoir(
            [f"commissariat:{alerte.id_commissariat}"],
            "alerte_nouvelle",
            id=alerte.id,
            reference=alerte.reference,
            niveau_urgence=alerte.niveau_urgence,
            statut=alerte.statut,
            latitude=float(alerte.latitude) if alerte.latitude is not None else None,
            longitude=float(alerte.longitude) if alerte.longitude is not None else None,
            adresse_precise=alerte.adresse_precise,
            emetteur_id=acteur.id,
        )

    # Les amis de l'émetteur reçoivent aussi l'alerte (notification + liste).
    amis_ids = social_service.ids_amis(acteur)
    if amis_ids:
        notifier_groupe(
            amis_ids,
            f"Alerte de {acteur.nom}",
            f"[{alerte.reference}] {contenu[:120]}",
            type_notif="alerte_creee",
            id_sender=acteur.id,
            entite_type="alerte",
            entite_id=alerte.id,
            lien=f"/alertes/{alerte.id}",
        )

    audit_service.audit(
        action="alerte_creee",
        entite="alerte",
        entite_id=alerte.id,
        description=f"Alerte {alerte.reference} déclarée par {acteur.email}",
        apres={
            "reference": alerte.reference,
            "niveau_urgence": alerte.niveau_urgence,
            "id_commissariat": alerte.id_commissariat,
        },
        user_id=acteur.id,
    )
    db.session.commit()
    return alerte


# -------------------------------------------------------------------------- lecture


def lister(
    user: User,
    page: int = 1,
    per_page: int = 20,
    statut: str | None = None,
    urgence: str | None = None,
    id_commissariat: int | None = None,
    id_user: int | None = None,
    q: str | None = None,
) -> tuple[list[Alerte], int]:
    query = scope_alertes(db.session.query(Alerte), user).filter(Alerte.deleted_at.is_(None))

    if statut:
        valeurs = [s.strip() for s in statut.split(",") if s.strip()]
        inconnus = [v for v in valeurs if v not in STATUTS]
        if inconnus:
            raise ValidationFailed(
                "Statut invalide.",
                errors={"statut": [f"Inconnu : {v}" for v in inconnus]},
            )
        query = query.filter(Alerte.statut.in_(valeurs))
    if urgence:
        if urgence not in URGENCES:
            raise ValidationFailed(
                "Niveau d'urgence invalide.",
                errors={"niveau_urgence": [f"Inconnu : {urgence}"]},
            )
        query = query.filter(Alerte.niveau_urgence == urgence)
    if id_commissariat and user.has_role(*ROLES_POLICE):
        query = query.filter(Alerte.id_commissariat == id_commissariat)
    if id_user and user.has_role(*ROLES_POLICE):
        query = query.filter(Alerte.id_user == id_user)
    if q:
        like = f"%{q.strip()}%"
        query = query.filter(or_(Alerte.reference.ilike(like), Alerte.contenu.ilike(like),
                                 Alerte.adresse_precise.ilike(like)))

    total = query.count()
    page, per_page = max(page, 1), min(max(per_page, 1), 100)
    # Dernier publié d'abord : les alertes les plus récentes en haut.
    items = (
        query.order_by(Alerte.date_alerte.desc(), Alerte.id.desc())
        .offset((page - 1) * per_page)
        .limit(per_page)
        .all()
    )
    return items, total


# ------------------------------------------------------------------------- traitement


def _appliquer_statut(alerte: Alerte, nouveau: str, observation: str | None, acteur: User) -> None:
    autorises = TRANSITIONS.get(alerte.statut, set())
    if nouveau not in autorises:
        raise ValidationFailed(
            "Transition de statut interdite.",
            errors={
                "statut": [
                    f"« {alerte.statut} » ne peut pas devenir « {nouveau} ». "
                    f"Valeurs possibles : {', '.join(sorted(autorises)) or 'aucune (dossier finalisé)'}."
                ]
            },
        )
    alerte.statut = nouveau
    if observation:
        alerte.observation = observation
    if nouveau in {"prise_en_compte", "en_cours"} and alerte.date_prise_en_compte is None:
        alerte.date_prise_en_compte = datetime.now()
    if nouveau in STATUTS_TERMINAUX:
        alerte.date_resolution = datetime.now()
        if alerte.date_prise_en_compte is None:
            alerte.date_prise_en_compte = alerte.date_resolution


def _policier_disponible(policier_id: int, acteur: User) -> User:
    policier = db.session.get(User, policier_id)
    if policier is None or policier.deleted_at is not None:
        raise ValidationFailed(
            "Policier introuvable.",
            errors={"id_policier_assignee": ["Utilisateur introuvable."]},
        )
    if not policier.has_role(*ROLES_POLICE):
        raise ValidationFailed(
            "Rôle insuffisant.",
            errors={"id_policier_assignee": ["Ce compte n'est pas un membre des forces."]},
        )
    if (
        acteur.id_commissariat
        and policier.id_commissariat
        and policier.id_commissariat != acteur.id_commissariat
    ):
        raise ForbiddenError(
            "Ce policier relève d'un autre commissariat.",
            errors={"id_policier_assignee": ["Commissariat différent."]},
        )
    return policier


def prendre_en_charge(alerte: Alerte, acteur: User) -> Alerte:
    """Le policier s'attribue l'alerte et passe en `prise_en_compte`."""
    if not acteur.has_role(*ROLES_POLICE):
        raise ForbiddenError("Seul un membre des forces peut prendre une alerte en charge.")
    if alerte.statut == "nouvelle":
        _appliquer_statut(alerte, "prise_en_compte", None, acteur)
    elif alerte.statut not in {"prise_en_compte", "en_cours"}:
        raise ValidationFailed(
            "Alerte déjà finalisée.",
            errors={"statut": [f"Statut actuel : {alerte.statut}."]},
        )
    alerte.id_policier_assignee = acteur.id

    creer_notification(
        alerte.id_user,
        "Alerte prise en charge",
        f"Votre alerte {alerte.reference} est prise en charge par "
        f"{acteur.nom} {acteur.prenom or ''}".strip(),
        type_notif="alerte_assignee",
        id_sender=acteur.id,
        entite_type="alerte",
        entite_id=alerte.id,
        lien=f"/alertes/{alerte.id}",
    )
    salles = [f"user:{alerte.id_user}"]
    if alerte.id_commissariat:
        salles.append(f"commissariat:{alerte.id_commissariat}")
    prevoir(
        salles,
        "alerte_assignee",
        id=alerte.id,
        reference=alerte.reference,
        statut=alerte.statut,
        id_policier=acteur.id,
        policier=f"{acteur.nom} {acteur.prenom or ''}".strip(),
        niveau_urgence=alerte.niveau_urgence,
    )

    audit_service.audit(
        action="alerte_prise_en_charge",
        entite="alerte",
        entite_id=alerte.id,
        description=f"{alerte.reference} prise en charge par {acteur.email}",
        apres={"statut": alerte.statut, "id_policier_assignee": acteur.id},
        user_id=acteur.id,
    )
    db.session.commit()
    return alerte


def assigner(alerte: Alerte, policier_id: int, acteur: User) -> Alerte:
    policier = _policier_disponible(policier_id, acteur)
    if alerte.statut == "nouvelle":
        _appliquer_statut(alerte, "prise_en_compte", None, acteur)
    alerte.id_policier_assignee = policier.id

    creer_notification(
        policier.id,
        "Alerte assignée",
        f"[{alerte.reference}] {alerte.niveau_urgence} — {alerte.contenu[:120]}",
        type_notif="alerte_assignee",
        id_sender=acteur.id,
        entite_type="alerte",
        entite_id=alerte.id,
        lien=f"/alertes/{alerte.id}",
    )
    salles = [f"user:{alerte.id_user}", f"user:{policier.id}"]
    if alerte.id_commissariat:
        salles.append(f"commissariat:{alerte.id_commissariat}")
    prevoir(
        salles,
        "alerte_assignee",
        id=alerte.id,
        reference=alerte.reference,
        statut=alerte.statut,
        id_policier=policier.id,
        policier=f"{policier.nom} {policier.prenom or ''}".strip(),
        assigne_par=acteur.id,
    )

    audit_service.audit(
        action="alerte_assignee",
        entite="alerte",
        entite_id=alerte.id,
        description=f"{alerte.reference} assignée à {policier.email} par {acteur.email}",
        avant={"id_policier_assignee": None},
        apres={"id_policier_assignee": policier.id},
        user_id=acteur.id,
    )
    db.session.commit()
    return alerte


def changer_statut(alerte: Alerte, data: dict, acteur: User) -> Alerte:
    p = Payload(data)
    nouveau = p.enum("statut", STATUTS, requis=True)
    observation = p.chaine("observation", requis=False, max_len=5000)
    p.fail_if_errors()

    avant = alerte.statut
    _appliquer_statut(alerte, nouveau, observation, acteur)

    if nouveau in STATUTS_TERMINAUX:
        creer_notification(
            alerte.id_user,
            "Alerte mise à jour",
            f"Votre alerte {alerte.reference} : {nouveau.replace('_', ' ')}.",
            type_notif="alerte_resolue",
            id_sender=acteur.id,
            entite_type="alerte",
            entite_id=alerte.id,
            lien=f"/alertes/{alerte.id}",
        )

    salles = [f"user:{alerte.id_user}"]
    if alerte.id_policier_assignee:
        salles.append(f"user:{alerte.id_policier_assignee}")
    if alerte.id_commissariat:
        salles.append(f"commissariat:{alerte.id_commissariat}")
    prevoir(
        salles,
        "alerte_mise_a_jour",
        id=alerte.id,
        reference=alerte.reference,
        ancien_statut=avant,
        statut=nouveau,
        observation=observation,
        par=acteur.id,
    )

    audit_service.audit(
        action="alerte_statut",
        entite="alerte",
        entite_id=alerte.id,
        description=f"{alerte.reference} : {avant} -> {nouveau}",
        avant={"statut": avant},
        apres={"statut": nouveau, "observation": observation},
        user_id=acteur.id,
    )
    db.session.commit()
    return alerte


def supprimer(alerte: Alerte, acteur: User) -> Alerte:
    if alerte.deleted_at is not None:
        return alerte
    alerte.soft_delete()
    audit_service.audit(
        action="alerte_supprimee",
        entite="alerte",
        entite_id=alerte.id,
        description=f"Purge douce de {alerte.reference} par {acteur.email}",
        user_id=acteur.id,
    )
    db.session.commit()
    return alerte


# ------------------------------------------------------------------------ dossier


def ouvrir_cas(alerte: Alerte, data: dict, acteur: User):
    """Crée un dossier (`cas`) rattaché à cette alerte."""
    from . import cas_service

    if alerte.statut in STATUTS_TERMINAUX:
        raise ValidationFailed(
            "Alerte déjà finalisée.",
            errors={"statut": ["Impossible d'ouvrir un dossier sur une alerte finalisée."]},
        )
    payload = dict(data)
    payload.setdefault("id_alerte", alerte.id)
    payload.setdefault("id_victime", alerte.id_user)
    payload.setdefault(
        "latitude", float(alerte.latitude) if alerte.latitude is not None else None
    )
    payload.setdefault(
        "longitude", float(alerte.longitude) if alerte.longitude is not None else None
    )
    payload.setdefault("lieu", alerte.adresse_precise)
    payload.setdefault("id_commissariat", alerte.id_commissariat)
    return cas_service.creer(payload, acteur, alerte_source=alerte)
