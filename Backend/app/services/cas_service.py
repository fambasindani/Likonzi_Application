"""Dossiers (`cas`) et interventions policières."""
from __future__ import annotations

import secrets
from datetime import datetime
from decimal import Decimal

from sqlalchemy import or_, text
from sqlalchemy.orm import lazyload

from ..exceptions import ForbiddenError, NotFoundError, ValidationFailed
from ..extensions import db
from ..models import Cas, Intervention, User
from ..realtime import prevoir
from . import audit_service
from .notification_service import creer_notification
from .validators import Payload

TRANSITIONS_CAS: dict[str, set[str]] = {
    "ouvert": {"en_cours", "en_attente", "clos", "classe"},
    "en_cours": {"en_attente", "clos", "classe"},
    "en_attente": {"en_cours", "clos", "classe"},
    "clos": set(),
    "classe": set(),
}
STATUTS_CAS = sorted(set(TRANSITIONS_CAS) | {t for v in TRANSITIONS_CAS.values() for t in v})
PRIORITES = ["basse", "normale", "haute", "critique"]
TYPES_CAS = ["enlevement", "vol_vehicule", "vol_objet", "agression", "disparition", "autre"]
TYPES_INTERVENTION = [
    "patrouille",
    "perquisition",
    "audition",
    "arrestation",
    "perquisition_domicile",
    "convocation",
    "autre",
]
ROLES_POLICE = ("policier", "enqueteur", "admin", "super_admin")


# --------------------------------------------------------------------------- utilitaires


def nouveau_numero() -> str:
    """`DOS-AAAAMMJJ-XXXXXX` — unicité garantie par `uk_cas_numero`."""
    return f"DOS-{datetime.now():%Y%m%d}-{secrets.token_hex(3).upper()}"


def scope_cas(query, user: User):
    if user.has_role("admin", "super_admin"):
        return query
    if user.has_role(*ROLES_POLICE):
        conditions = []
        if user.id_commissariat:
            conditions.append(Cas.id_commissariat == user.id_commissariat)
        conditions.append(Cas.id_enqueteur_principal == user.id)
        conditions.append(Cas.id_victime == user.id)
        return query.filter(or_(*conditions))
    # Un citoyen ne suit que ses propres dossiers.
    return query.filter(Cas.id_victime == user.id)


def _visible(cas: Cas, user: User) -> bool:
    if user.has_role("admin", "super_admin"):
        return True
    if user.has_role(*ROLES_POLICE):
        return (
            (user.id_commissariat and cas.id_commissariat == user.id_commissariat)
            or cas.id_enqueteur_principal == user.id
            or cas.id_victime == user.id
        )
    return cas.id_victime == user.id


def recuperer(cas_id: int, user: User) -> Cas:
    cas = db.session.get(Cas, cas_id)
    if cas is None or cas.deleted_at is not None or not _visible(cas, user):
        raise NotFoundError("Dossier introuvable.")
    return cas


# -------------------------------------------------------------------------- création


def _resolve_commissariat(data_id: int | None, acteur: User, errors: dict) -> int | None:
    if data_id:
        from ..models import Commissariat

        c = db.session.get(Commissariat, data_id)
        if c is None or c.deleted_at is not None:
            errors["id_commissariat"] = ["Commissariat introuvable."]
            return None
        return c.id
    if acteur.id_commissariat:
        return acteur.id_commissariat
    errors["id_commissariat"] = ["Aucun commissariat de rattachement pour ce compte."]
    return None


def creer(data: dict, acteur: User, alerte_source=None) -> Cas:
    if not acteur.has_role(*ROLES_POLICE):
        raise ForbiddenError("Seul un membre des forces peut ouvrir un dossier.")

    p = Payload(data)
    type_cas = p.enum("type_cas", TYPES_CAS, requis=True)
    description = p.chaine("description", requis=True, min_len=5, max_len=10000)
    date_faits = p.datetime_("date_faits", requis=True)
    lieu = p.chaine("lieu", requis=False, max_len=255)
    latitude = p.decimal("latitude", min_val=-90.0, max_val=90.0)
    longitude = p.decimal("longitude", min_val=-180.0, max_val=180.0)
    priorite = p.enum("priorite", PRIORITES, default="normale")
    id_victime = p.entier("id_victime", min_val=1)
    id_enqueteur = p.entier("id_enqueteur_principal", min_val=1)
    id_commissariat = p.entier("id_commissariat", min_val=1)
    resultat = p.chaine("resultat", requis=False, max_len=10000)
    p.fail_if_errors()

    if date_faits and date_faits > datetime.now():
        raise ValidationFailed(
            "Date des faits dans le futur.",
            errors={"date_faits": ["La date des faits ne peut pas être postérieure à maintenant."]},
        )

    erreurs: dict[str, list[str]] = {}
    commissariat_id = _resolve_commissariat(id_commissariat, acteur, erreurs)

    victime_id = id_victime
    if victime_id is None and alerte_source is not None:
        victime_id = alerte_source.id_user
    if victime_id is not None:
        victime = db.session.get(User, victime_id)
        if victime is None or victime.deleted_at is not None:
            erreurs["id_victime"] = ["Victime introuvable."]
    if id_enqueteur is not None:
        enqueteur = db.session.get(User, id_enqueteur)
        if enqueteur is None or enqueteur.deleted_at is not None:
            erreurs["id_enqueteur_principal"] = ["Enquêteur introuvable."]
        elif not enqueteur.has_role("enqueteur", "admin", "super_admin"):
            erreurs["id_enqueteur_principal"] = ["Ce compte n'a pas le rôle enquêteur."]
    if erreurs:
        raise ValidationFailed("Dossier invalide.", errors=erreurs)

    if id_enqueteur is None and acteur.has_role("enqueteur", "admin", "super_admin"):
        id_enqueteur = acteur.id

    cas = Cas(
        numero_dossier=nouveau_numero(),
        id_alerte=alerte_source.id if alerte_source is not None else data.get("id_alerte"),
        type_cas=type_cas,
        id_victime=victime_id,
        description=description,
        lieu=lieu,
        latitude=Decimal(str(latitude)) if latitude is not None else None,
        longitude=Decimal(str(longitude)) if longitude is not None else None,
        date_faits=date_faits,
        date_ouverture=datetime.now(),
        statut="ouvert",
        priorite=priorite or "normale",
        id_commissariat=commissariat_id,
        id_enqueteur_principal=id_enqueteur,
        resultat=resultat,
    )
    db.session.add(cas)
    db.session.flush()

    if victime_id and victime_id != acteur.id:
        creer_notification(
            victime_id,
            "Dossier ouvert",
            f"Le dossier {cas.numero_dossier} ({cas.type_cas.replace('_', ' ')}) a été ouvert.",
            type_notif="cas_maj",
            id_sender=acteur.id,
            entite_type="cas",
            entite_id=cas.id,
            lien=f"/cas/{cas.id}",
        )
    if id_enqueteur and id_enqueteur != acteur.id:
        creer_notification(
            id_enqueteur,
            "Dossier attribué",
            f"Le dossier {cas.numero_dossier} vous est attribué.",
            type_notif="cas_maj",
            id_sender=acteur.id,
            entite_type="cas",
            entite_id=cas.id,
            lien=f"/cas/{cas.id}",
        )

    salles_dossier = [f"user:{a}" for a in (victime_id, id_enqueteur) if a]
    if cas.id_commissariat:
        salles_dossier.append(f"commissariat:{cas.id_commissariat}")
    prevoir(
        salles_dossier,
        "dossier_ouvert",
        id=cas.id,
        numero_dossier=cas.numero_dossier,
        type_cas=cas.type_cas,
        priorite=cas.priorite,
        statut=cas.statut,
        id_alerte=cas.id_alerte,
        id_victime=cas.id_victime,
        id_enqueteur=cas.id_enqueteur_principal,
        ouvert_par=acteur.id,
    )

    audit_service.audit(
        action="cas_cree",
        entite="cas",
        entite_id=cas.id,
        description=f"Dossier {cas.numero_dossier} ouvert par {acteur.email}",
        apres={
            "numero_dossier": cas.numero_dossier,
            "type_cas": cas.type_cas,
            "priorite": cas.priorite,
        },
        user_id=acteur.id,
    )
    db.session.commit()
    return cas


# -------------------------------------------------------------------------- lecture


def lister(
    user: User,
    page: int = 1,
    per_page: int = 20,
    statut: str | None = None,
    priorite: str | None = None,
    type_cas: str | None = None,
    id_commissariat: int | None = None,
    q: str | None = None,
) -> tuple[list[Cas], int]:
    # La liste n'utilise que les colonnes de `cas` (to_dict sans détail) :
    # on désactive les chargements de relations, qui coûtaient 44 requêtes
    # (chaque ligne tirait victime/enqueteur/commissariat + leurs propres
    # relations + les interventions). Le détail, lui, charge à la demande.
    query = (
        scope_cas(db.session.query(Cas), user)
        .options(
            lazyload(Cas.alerte),
            lazyload(Cas.victime),
            lazyload(Cas.enqueteur),
            lazyload(Cas.commissariat),
            lazyload(Cas.interventions),
        )
        .filter(Cas.deleted_at.is_(None))
    )

    if statut:
        valeurs = [s.strip() for s in statut.split(",") if s.strip()]
        inconnus = [v for v in valeurs if v not in STATUTS_CAS]
        if inconnus:
            raise ValidationFailed(
                "Statut invalide.", errors={"statut": [f"Inconnu : {v}" for v in inconnus]}
            )
        query = query.filter(Cas.statut.in_(valeurs))
    if priorite:
        if priorite not in PRIORITES:
            raise ValidationFailed(
                "Priorité invalide.", errors={"priorite": [f"Inconnue : {priorite}"]}
            )
        query = query.filter(Cas.priorite == priorite)
    if type_cas:
        if type_cas not in TYPES_CAS:
            raise ValidationFailed(
                "Type de dossier invalide.", errors={"type_cas": [f"Inconnu : {type_cas}"]}
            )
        query = query.filter(Cas.type_cas == type_cas)
    if id_commissariat and user.has_role(*ROLES_POLICE):
        query = query.filter(Cas.id_commissariat == id_commissariat)
    if q:
        like = f"%{q.strip()}%"
        query = query.filter(
            or_(Cas.numero_dossier.ilike(like), Cas.description.ilike(like), Cas.lieu.ilike(like))
        )

    total = query.count()
    page, per_page = max(page, 1), min(max(per_page, 1), 100)
    items = (
        query.order_by(text("FIELD(priorite,'critique','haute','normale','basse')"), Cas.date_ouverture.desc())
        .offset((page - 1) * per_page)
        .limit(per_page)
        .all()
    )
    return items, total


# -------------------------------------------------------------------------- mise à jour


def modifier(cas: Cas, data: dict, acteur: User) -> Cas:
    if not acteur.has_role(*ROLES_POLICE):
        raise ForbiddenError("Accès réservé aux forces de l'ordre.")

    p = Payload(data)
    erreurs: dict[str, list[str]] = {}
    changements: dict[str, object] = {}

    if "description" in data:
        val = p.chaine("description", requis=True, min_len=5, max_len=10000)
        if val:
            changements["description"] = val
    if "lieu" in data:
        changements["lieu"] = p.chaine("lieu", requis=False, max_len=255)
    if "latitude" in data:
        val = p.decimal("latitude", min_val=-90.0, max_val=90.0)
        changements["latitude"] = Decimal(str(val)) if val is not None else None
    if "longitude" in data:
        val = p.decimal("longitude", min_val=-180.0, max_val=180.0)
        changements["longitude"] = Decimal(str(val)) if val is not None else None
    if "date_faits" in data:
        val = p.datetime_("date_faits", requis=True)
        if val and val > datetime.now():
            erreurs["date_faits"] = ["Date des faits dans le futur."]
        elif val:
            changements["date_faits"] = val
    if "priorite" in data:
        val = p.enum("priorite", PRIORITES, requis=True)
        if val:
            changements["priorite"] = val
    if "resultat" in data:
        changements["resultat"] = p.chaine("resultat", requis=False, max_len=10000)
    if "id_enqueteur_principal" in data:
        val = p.entier("id_enqueteur_principal", requis=False, min_val=1)
        if val:
            enq = db.session.get(User, val)
            if enq is None or enq.deleted_at is not None:
                erreurs["id_enqueteur_principal"] = ["Enquêteur introuvable."]
            elif not enq.has_role("enqueteur", "admin", "super_admin"):
                erreurs["id_enqueteur_principal"] = ["Ce compte n'a pas le rôle enquêteur."]
            else:
                changements["id_enqueteur_principal"] = val
        else:
            changements["id_enqueteur_principal"] = None
    if "statut" in data:
        val = p.enum("statut", STATUTS_CAS, requis=True)
        if val:
            autorises = TRANSITIONS_CAS.get(cas.statut, set())
            if val not in autorises:
                erreurs["statut"] = [
                    f"« {cas.statut} » ne peut pas devenir « {val} ». "
                    f"Possibles : {', '.join(sorted(autorises)) or 'aucune'}."
                ]
            else:
                changements["statut"] = val
    p.fail_if_errors()
    if erreurs:
        raise ValidationFailed("Dossier invalide.", errors=erreurs)

    avant = {
        k: (v.isoformat() if isinstance(v, datetime) else v)
        for k, v in {
            attr: getattr(cas, attr) for attr in changements
        }.items()
    }
    for champ, valeur in changements.items():
        setattr(cas, champ, valeur)

    if cas.statut in {"clos", "classe"} and cas.date_cloture is None:
        cas.date_cloture = datetime.now()
    if cas.statut in {"en_cours", "en_attente"} and cas.date_cloture is not None:
        cas.date_cloture = None

    if not changements:
        db.session.rollback()
        return cas

    apres = {
        k: (v.isoformat() if isinstance(v, datetime) else v) for k, v in changements.items()
    }
    audit_service.audit(
        action="cas_maj",
        entite="cas",
        entite_id=cas.id,
        description=f"Dossier {cas.numero_dossier} modifié par {acteur.email}",
        avant=avant,
        apres=apres,
        user_id=acteur.id,
    )
    db.session.commit()
    return cas


def cloturer(cas: Cas, data: dict, acteur: User) -> Cas:
    """Raccourci de clôture : `clos` (résolu) ou `classe` (sans suite)."""
    p = Payload(data)
    statut = p.enum("statut", ["clos", "classe"], default="clos")
    resultat = p.chaine("resultat", requis=False, max_len=10000)
    observation = p.chaine("observation", requis=False, max_len=5000)
    p.fail_if_errors()

    payload = {"statut": statut}
    if resultat:
        payload["resultat"] = resultat
    elif observation:
        payload["resultat"] = observation
    cas = modifier(cas, payload, acteur)

    salles = [f"user:{a}" for a in (cas.id_victime, cas.id_enqueteur_principal) if a]
    if cas.id_commissariat:
        salles.append(f"commissariat:{cas.id_commissariat}")
    prevoir(
        salles,
        "dossier_mis_a_jour",
        id=cas.id,
        numero_dossier=cas.numero_dossier,
        statut=cas.statut,
        date_cloture=cas.date_cloture.isoformat() if cas.date_cloture else None,
        par=acteur.id,
    )

    if cas.id_victime and cas.id_victime != acteur.id:
        creer_notification(
            cas.id_victime,
            "Dossier clôturé",
            f"Votre dossier {cas.numero_dossier} est désormais « {cas.statut} ».",
            type_notif="cas_maj",
            id_sender=acteur.id,
            entite_type="cas",
            entite_id=cas.id,
            lien=f"/cas/{cas.id}",
        )
        db.session.commit()
    return cas


def supprimer(cas: Cas, acteur: User) -> Cas:
    if cas.deleted_at is not None:
        return cas
    cas.soft_delete()
    audit_service.audit(
        action="cas_supprime",
        entite="cas",
        entite_id=cas.id,
        description=f"Purge douce du dossier {cas.numero_dossier} par {acteur.email}",
        user_id=acteur.id,
    )
    db.session.commit()
    return cas


# ---------------------------------------------------------------------- interventions


def creer_intervention(cas: Cas, data: dict, acteur: User) -> Intervention:
    if not acteur.has_role(*ROLES_POLICE):
        raise ForbiddenError("Accès réservé aux forces de l'ordre.")

    p = Payload(data)
    type_intervention = p.enum("type_intervention", TYPES_INTERVENTION, requis=True)
    description = p.chaine("description", requis=True, min_len=3, max_len=10000)
    date_intervention = p.datetime_("date_intervention")
    duree = p.entier("duree_minutes", min_val=0, max_val=60 * 24 * 30)
    lieu = p.chaine("lieu", requis=False, max_len=255)
    resultat = p.chaine("resultat", requis=False, max_len=10000)
    id_policier = p.entier("id_policier", min_val=1)
    p.fail_if_errors()

    if date_intervention is None:
        date_intervention = datetime.now()

    if id_policier is None:
        id_policier = acteur.id
    policier = db.session.get(User, id_policier)
    if policier is None or policier.deleted_at is not None:
        raise ValidationFailed(
            "Policier introuvable.", errors={"id_policier": ["Utilisateur introuvable."]}
        )
    if not policier.has_role(*ROLES_POLICE):
        raise ValidationFailed(
            "Rôle insuffisant.", errors={"id_policier": ["Ce compte n'est pas un policier."]}
        )

    intervention = Intervention(
        id_cas=cas.id,
        id_policier=policier.id,
        type_intervention=type_intervention,
        description=description,
        date_intervention=date_intervention,
        duree_minutes=duree,
        lieu=lieu,
        resultat=resultat,
    )
    db.session.add(intervention)
    db.session.flush()

    # Une intervention fait avancer un dossier encore « ouvert ».
    if cas.statut == "ouvert":
        cas.statut = "en_cours"

    if cas.id_enqueteur_principal and cas.id_enqueteur_principal != acteur.id:
        creer_notification(
            cas.id_enqueteur_principal,
            "Intervention enregistrée",
            f"{policier.nom} a enregistré une intervention « {type_intervention} » "
            f"sur le dossier {cas.numero_dossier}.",
            type_notif="cas_maj",
            id_sender=acteur.id,
            entite_type="intervention",
            entite_id=intervention.id,
            lien=f"/cas/{cas.id}",
        )

    salles = [f"user:{a}" for a in (cas.id_victime, cas.id_enqueteur_principal) if a]
    if cas.id_commissariat:
        salles.append(f"commissariat:{cas.id_commissariat}")
    prevoir(
        salles,
        "intervention_enregistree",
        id=cas.id,
        numero_dossier=cas.numero_dossier,
        type_intervention=type_intervention,
        id_policier=policier.id,
        statut=cas.statut,
        par=acteur.id,
    )

    audit_service.audit(
        action="intervention_creee",
        entite="intervention",
        entite_id=intervention.id,
        description=f"Intervention {type_intervention} sur {cas.numero_dossier}",
        apres={"type_intervention": type_intervention, "id_policier": policier.id},
        user_id=acteur.id,
    )
    db.session.commit()
    return intervention


def lister_interventions(cas: Cas) -> list[Intervention]:
    return (
        db.session.query(Intervention)
        .filter(Intervention.id_cas == cas.id)
        .order_by(Intervention.date_intervention.desc())
        .all()
    )


def recuperer_intervention(intervention_id: int, user: User) -> Intervention:
    intervention = db.session.get(Intervention, intervention_id)
    if intervention is None:
        raise NotFoundError("Intervention introuvable.")
    if not _visible(intervention.cas, user):
        raise NotFoundError("Intervention introuvable.")
    return intervention


def modifier_intervention(intervention: Intervention, data: dict, acteur: User) -> Intervention:
    if not acteur.has_role(*ROLES_POLICE):
        raise ForbiddenError("Accès réservé aux forces de l'ordre.")

    p = Payload(data)
    changements: dict[str, object] = {}
    if "description" in data:
        val = p.chaine("description", requis=True, min_len=3, max_len=10000)
        if val:
            changements["description"] = val
    if "type_intervention" in data:
        val = p.enum("type_intervention", TYPES_INTERVENTION, requis=True)
        if val:
            changements["type_intervention"] = val
    if "date_intervention" in data:
        val = p.datetime_("date_intervention", requis=True)
        if val:
            changements["date_intervention"] = val
    if "duree_minutes" in data:
        changements["duree_minutes"] = p.entier("duree_minutes", min_val=0, max_val=60 * 24 * 30)
    if "lieu" in data:
        changements["lieu"] = p.chaine("lieu", requis=False, max_len=255)
    if "resultat" in data:
        changements["resultat"] = p.chaine("resultat", requis=False, max_len=10000)
    p.fail_if_errors()

    if not changements:
        db.session.rollback()
        return intervention

    avant = {k: (v.isoformat() if isinstance(v, datetime) else v)
             for k, v in ((k, getattr(intervention, k)) for k in changements)}
    for champ, valeur in changements.items():
        setattr(intervention, champ, valeur)
    apres = {k: (v.isoformat() if isinstance(v, datetime) else v) for k, v in changements.items()}

    audit_service.audit(
        action="intervention_maj",
        entite="intervention",
        entite_id=intervention.id,
        description=f"Intervention #{intervention.id} modifiée par {acteur.email}",
        avant=avant,
        apres=apres,
        user_id=acteur.id,
    )
    db.session.commit()
    return intervention
