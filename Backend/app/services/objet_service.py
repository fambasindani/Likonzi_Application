"""Objets volés : déclaration, recherche (immatriculation / châssis / n° de série), statuts."""
from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import or_

from ..exceptions import ForbiddenError, NotFoundError, ValidationFailed
from ..extensions import db
from ..models import Cas, Objet, Partage, TypeObjet, User
from . import audit_service, social_service
from .notification_service import creer_notification, notifier_groupe
from .validators import Payload

STATUTS_OBJET = [
    "en_possession",
    "declare_vol",
    "recherche",
    "retrouve",
    "restitue",
    "en_fourriere",
    "classe",
]

# Bien pré-enregistré (pas encore volé) -> déclaré volé -> recherche -> retrouvé
TRANSITIONS_OBJET: dict[str, set[str]] = {
    "en_possession": {"declare_vol", "classe"},
    "declare_vol": {"recherche", "retrouve", "classe"},
    "recherche": {"retrouve", "en_fourriere", "classe"},
    "retrouve": {"restitue", "en_fourriere"},
    "en_fourriere": {"restitue", "retrouve"},
    "restitue": set(),
    "classe": set(),
}
ROLES_POLICE = ("policier", "enqueteur", "admin", "super_admin")


# --------------------------------------------------------------------------- utilitaires


def _objets_partages_vers(user: User):
    """Sous-requête : objets transmis à `user` (cf. table `partages`)."""
    return db.session.query(Partage.id_objet).filter(Partage.id_destinataire == user.id)


def _visible(objet: Objet, user: User) -> bool:
    if user.has_role(*ROLES_POLICE) or objet.id_user_proprietaire == user.id:
        return True
    # Les amis voient les objets déclarés par leurs contacts.
    if objet.id_user_proprietaire in social_service.ids_amis(user):
        return True
    # L'objet a été explicitement partagé avec cet utilisateur.
    return (
        db.session.query(Partage.id)
        .filter(Partage.id_objet == objet.id, Partage.id_destinataire == user.id)
        .first()
        is not None
    )


def scope_objets(query, user: User):
    """Périmètre : police = tout ; citoyen = ses objets **et ceux de ses amis**."""
    if user.has_role(*ROLES_POLICE):
        return query
    amis = social_service.ids_amis(user)
    if amis:
        return query.filter(Objet.id_user_proprietaire.in_([user.id, *amis]))
    return query.filter(Objet.id_user_proprietaire == user.id)


def recuperer(objet_id: int, user: User) -> Objet:
    objet = db.session.get(Objet, objet_id)
    if objet is None or objet.deleted_at is not None or not _visible(objet, user):
        raise NotFoundError("Objet introuvable.")
    return objet


# -------------------------------------------------------------------------- création


def creer(data: dict, acteur: User) -> Objet:
    p = Payload(data)
    id_type = p.entier("id_type", requis=True, min_val=1)
    marque = p.chaine("marque", requis=False, max_len=100)
    model = p.chaine("model", requis=False, max_len=100)
    chassis = p.chaine("numero_chassis", requis=False, max_len=100)
    immat = p.chaine("immatriculation", requis=False, max_len=50)
    serie = p.chaine("numero_serie", requis=False, max_len=100)
    couleur = p.chaine("couleur", requis=False, max_len=50)
    description = p.chaine("description", requis=False, max_len=5000)
    date_vol = p.datetime_("date_vol")
    lieu_vol = p.chaine("lieu_vol", requis=False, max_len=255)
    latitude = p.decimal("latitude_vol", min_val=-90.0, max_val=90.0)
    longitude = p.decimal("longitude_vol", min_val=-180.0, max_val=180.0)
    statut = p.enum("statut", STATUTS_OBJET, default="declare_vol")
    id_cas = p.entier("id_cas", min_val=1)
    id_proprietaire = p.entier("id_user_proprietaire", min_val=1)
    p.fail_if_errors()

    type_objet = db.session.get(TypeObjet, id_type)
    if type_objet is None or type_objet.statut != 1:
        raise ValidationFailed(
            "Type d'objet inconnu ou inactif.",
            errors={"id_type": ["Type inexistant ou désactivé."]},
        )
    if not any([marque, model, chassis, immat, serie, description]):
        raise ValidationFailed(
            "Aucun signe distinctif.",
            errors={
                "marque": [
                    "Renseignez au moins un élément d'identification "
                    "(marque, modèle, châssis, immatriculation, n° de série…)."
                ]
            },
        )

    proprietaire_id = id_proprietaire or acteur.id
    proprietaire = db.session.get(User, proprietaire_id)
    if proprietaire is None or proprietaire.deleted_at is not None:
        raise ValidationFailed(
            "Propriétaire introuvable.",
            errors={"id_user_proprietaire": ["Utilisateur introuvable."]},
        )
    if proprietaire_id != acteur.id and not acteur.has_role(*ROLES_POLICE):
        raise ForbiddenError("Vous ne pouvez déclarer qu'un objet vous appartenant.")

    if id_cas is not None:
        cas = db.session.get(Cas, id_cas)
        if cas is None or cas.deleted_at is not None:
            raise ValidationFailed("Dossier introuvable.", errors={"id_cas": ["Inexistant."]})
        if not acteur.has_role(*ROLES_POLICE) and cas.id_victime != acteur.id:
            raise ForbiddenError("Dossier hors de votre périmètre.")

    if date_vol and date_vol > datetime.now():
        raise ValidationFailed(
            "Date de vol dans le futur.",
            errors={"date_vol": ["La date du vol ne peut pas être postérieure à maintenant."]},
        )

    objet = Objet(
        id_type=id_type,
        id_user_proprietaire=proprietaire_id,
        marque=marque,
        model=model,
        numero_chassis=chassis,
        immatriculation=immat,
        numero_serie=serie,
        couleur=couleur,
        description=description,
        date_vol=date_vol,
        lieu_vol=lieu_vol,
        latitude_vol=Decimal(str(latitude)) if latitude is not None else None,
        longitude_vol=Decimal(str(longitude)) if longitude is not None else None,
        statut=statut or "declare_vol",
        id_cas=id_cas,
    )
    db.session.add(objet)
    db.session.flush()

    # Les amis sont prévenus de la déclaration (vol / perte).
    amis_ids = social_service.ids_amis(acteur)
    if amis_ids:
        libelle = " — ".join(
            str(v) for v in (type_objet.description, marque, model, immat) if v
        )
        notifier_groupe(
            amis_ids,
            f"Objet déclaré par {acteur.nom}",
            (libelle or "Voir le détail de l'objet.")[:150],
            type_notif="objet_declare",
            id_sender=acteur.id,
            entite_type="objet",
            entite_id=objet.id,
            lien=f"/objets/{objet.id}",
        )

    audit_service.audit(
        action="objet_declare",
        entite="objet",
        entite_id=objet.id,
        description=(
            f"Objet {type_objet.code} déclaré volé par {acteur.email}"
        ),
        apres={"statut": objet.statut, "id_type": objet.id_type, "immatriculation": immat},
        user_id=acteur.id,
    )
    db.session.commit()
    return objet


# -------------------------------------------------------------------------- lecture


def lister(
    user: User,
    page: int = 1,
    per_page: int = 20,
    statut: str | None = None,
    id_type: int | None = None,
    q: str | None = None,
) -> tuple[list[Objet], int]:
    query = scope_objets(db.session.query(Objet), user).filter(Objet.deleted_at.is_(None))

    if statut:
        valeurs = [s.strip() for s in statut.split(",") if s.strip()]
        inconnus = [v for v in valeurs if v not in STATUTS_OBJET]
        if inconnus:
            raise ValidationFailed(
                "Statut invalide.", errors={"statut": [f"Inconnu : {v}" for v in inconnus]}
            )
        query = query.filter(Objet.statut.in_(valeurs))
    if id_type:
        query = query.filter(Objet.id_type == id_type)
    if q:
        query = query.filter(_filtre_recherche(q))

    total = query.count()
    page, per_page = max(page, 1), min(max(per_page, 1), 100)
    items = (
        query.order_by(Objet.created_at.desc(), Objet.id.desc())
        .offset((page - 1) * per_page)
        .limit(per_page)
        .all()
    )
    return items, total


def _filtre_recherche(q: str):
    """Recherche libre sur tous les identifiants d'un objet volé."""
    terme = q.strip()
    if not terme:
        return Objet.id.isnot(None)
    like = f"%{terme}%"
    return or_(
        Objet.marque.ilike(like),
        Objet.model.ilike(like),
        Objet.numero_chassis.ilike(like),
        Objet.immatriculation.ilike(like),
        Objet.numero_serie.ilike(like),
        Objet.couleur.ilike(like),
        Objet.lieu_vol.ilike(like),
        Objet.description.ilike(like),
    )


def rechercher(q: str, user: User, statut: str | None = None, limite: int = 50) -> list[Objet]:
    """Recherche ciblée — utilisée par « mon véhicule/objet a été retrouvé ? »."""
    if not q or not q.strip():
        raise ValidationFailed("Terme requis.", errors={"q": ["Ce champ est obligatoire."]})
    query = db.session.query(Objet).filter(Objet.deleted_at.is_(None), _filtre_recherche(q))
    if statut:
        if statut not in STATUTS_OBJET:
            raise ValidationFailed(
                "Statut invalide.", errors={"statut": [f"Inconnu : {statut}"]}
            )
        query = query.filter(Objet.statut == statut)
    # Hors forces de l'ordre, on ne renvoie que les objets en recherche publique
    # ou les siens : évite de deviner le propriétaire d'un objet déposé.
    if not user.has_role(*ROLES_POLICE):
        query = query.filter(
            or_(Objet.id_user_proprietaire == user.id, Objet.statut.in_(["recherche", "retrouve"]))
        )
    return query.order_by(Objet.date_vol.desc()).limit(min(max(limite, 1), 200)).all()


# ---------------------------------------------------------------------- mise à jour


def changer_statut(objet: Objet, data: dict, acteur: User) -> Objet:
    p = Payload(data)
    statut = p.enum("statut", STATUTS_OBJET, requis=True)
    motif = p.chaine("motif", requis=False, max_len=1000)
    p.fail_if_errors()

    if not _visible(objet, acteur):
        raise NotFoundError("Objet introuvable.")
    # Un propriétaire peut signaler « retrouvé » ; le reste est réservé à la police.
    if statut != objet.statut:
        autorises = TRANSITIONS_OBJET.get(objet.statut, set())
        if statut not in autorises:
            raise ValidationFailed(
                "Transition interdite.",
                errors={
                    "statut": [
                        f"« {objet.statut} » ne peut pas devenir « {statut} ». "
                        f"Possibles : {', '.join(sorted(autorises)) or 'aucune'}."
                    ]
                },
            )
        if not acteur.has_role(*ROLES_POLICE):
            # Un simple destinataire d'un partage ne peut rien changer :
            # seules les forces ou le propriétaire lui-même.
            if objet.id_user_proprietaire != acteur.id:
                raise ForbiddenError(
                    "Seul le propriétaire peut modifier le statut de cet objet.",
                    errors={"statut": ["Destinataire d'un partage, lecture seule."]},
                )
            # Le propriétaire n'a que les transitions qui lui sont ouvertes :
            # déclarer un vol, ou signaler la recherche / le retrouvé.
            ouvertes = {
                "en_possession": {"declare_vol", "classe"},
                "declare_vol": {"recherche", "retrouve"},
            }.get(objet.statut, set())
            if statut not in ouvertes:
                raise ForbiddenError(
                    "Action réservée aux forces de l'ordre.",
                    errors={
                        "statut": [
                            f"Depuis « {objet.statut} », un propriétaire ne peut choisir que : "
                            + (", ".join(sorted(ouvertes)) or "aucune transition")
                            + "."
                        ]
                    },
                )
        avant = objet.statut
        objet.statut = statut

        if statut == "retrouve" and objet.id_user_proprietaire != acteur.id:
            creer_notification(
                objet.id_user_proprietaire,
                "Objet potentiellement retrouvé",
                f"Un objet correspondant à votre déclaration ({avant} -> {statut})"
                + (f" : {motif}" if motif else "."),
                type_notif="objet_retrouve",
                id_sender=acteur.id,
                entite_type="objet",
                entite_id=objet.id,
                lien=f"/objets/{objet.id}",
            )
        audit_service.audit(
            action="objet_statut",
            entite="objet",
            entite_id=objet.id,
            description=f"Objet #{objet.id} : {avant} -> {statut}",
            avant={"statut": avant},
            apres={"statut": statut, "motif": motif},
            user_id=acteur.id,
        )
        db.session.commit()
    return objet


def modifier(objet: Objet, data: dict, acteur: User) -> Objet:
    p = Payload(data)
    changements: dict[str, object] = {}

    if not _visible(objet, acteur):
        raise NotFoundError("Objet introuvable.")
    if not acteur.has_role(*ROLES_POLICE) and objet.id_user_proprietaire != acteur.id:
        raise ForbiddenError("Modification réservée au propriétaire ou à la police.")

    champs_texte = {
        "marque": 100,
        "model": 100,
        "numero_chassis": 100,
        "immatriculation": 50,
        "numero_serie": 100,
        "couleur": 50,
        "lieu_vol": 255,
        "description": 5000,
    }
    for champ, longueur in champs_texte.items():
        if champ in data:
            changements[champ] = p.chaine(champ, requis=False, max_len=longueur)
    if "date_vol" in data:
        val = p.datetime_("date_vol", requis=False)
        if val and val > datetime.now():
            p.errors.setdefault("date_vol", []).append("Date du vol dans le futur.")
        changements["date_vol"] = val
    if "id_cas" in data:
        val = p.entier("id_cas", requis=False, min_val=1)
        if val:
            cas = db.session.get(Cas, val)
            if cas is None or cas.deleted_at is not None:
                p.errors.setdefault("id_cas", []).append("Dossier introuvable.")
            else:
                changements["id_cas"] = val
        else:
            changements["id_cas"] = None
    if "id_type" in data:
        val = p.entier("id_type", requis=True, min_val=1)
        if val:
            type_objet = db.session.get(TypeObjet, val)
            if type_objet is None or type_objet.statut != 1:
                p.errors.setdefault("id_type", []).append("Type d'objet inconnu ou inactif.")
            else:
                changements["id_type"] = val
    p.fail_if_errors()

    if not changements:
        db.session.rollback()
        return objet

    avant = {k: (v.isoformat() if isinstance(v, datetime) else v)
             for k, v in ((k, getattr(objet, k)) for k in changements)}
    for champ, valeur in changements.items():
        setattr(objet, champ, valeur)
    apres = {k: (v.isoformat() if isinstance(v, datetime) else v) for k, v in changements.items()}

    audit_service.audit(
        action="objet_maj",
        entite="objet",
        entite_id=objet.id,
        description=f"Objet #{objet.id} modifié par {acteur.email}",
        avant=avant,
        apres=apres,
        user_id=acteur.id,
    )
    db.session.commit()
    return objet


def supprimer(objet: Objet, acteur: User) -> Objet:
    if objet.deleted_at is not None:
        return objet
    # Le propriétaire supprime le sien ; la purge des objets d'autrui est
    # réservée à l'enquêteur et aux administrateurs — pas au simple policier,
    # même s'il détient `objets.supprimer` pour ses propres biens.
    if objet.id_user_proprietaire != acteur.id and not acteur.has_role(
        "enqueteur", "admin", "super_admin"
    ):
        raise ForbiddenError(
            "Suppression réservée au propriétaire ou aux enquêteurs."
        )
    objet.soft_delete()
    audit_service.audit(
        action="objet_supprime",
        entite="objet",
        entite_id=objet.id,
        description=f"Purge douce de l'objet #{objet.id} par {acteur.email}",
        user_id=acteur.id,
    )
    db.session.commit()
    return objet


# --------------------------------------------------------------------------- partage


def partager(objet_id: int, data: dict, acteur: User) -> dict:
    """Transmet un objet (et donc ses images) à des destinataires."""
    p = Payload(data)
    message = p.chaine("message", requis=False, max_len=500)
    p.fail_if_errors()

    destinataires = (data or {}).get("destinataires")
    if not isinstance(destinataires, list) or not destinataires:
        raise ValidationFailed(
            "Destinataires requis.",
            errors={"destinataires": ["Fournissez au moins un destinataire."]},
        )
    try:
        ids = [int(d) for d in destinataires]
    except (TypeError, ValueError):
        raise ValidationFailed(
            "Destinataires invalides.",
            errors={"destinataires": ["Identifiants entiers attendus."]},
        ) from None

    objet = recuperer(objet_id, acteur)
    if objet.id_user_proprietaire != acteur.id and not acteur.has_role(*ROLES_POLICE):
        raise ForbiddenError("Seul le propriétaire peut partager cet objet.")

    envois: list[int] = []
    pour_charger: list[int] = []
    for dest_id in dict.fromkeys(ids):
        if dest_id == acteur.id:
            continue
        destinataire = db.session.get(User, dest_id)
        if destinataire is None or destinataire.deleted_at is not None:
            raise ValidationFailed(
                "Destinataire introuvable.",
                errors={"destinataires": [f"Utilisateur #{dest_id} introuvable."]},
            )
        existante = (
            db.session.query(Partage.id)
            .filter(Partage.id_objet == objet.id, Partage.id_destinataire == dest_id)
            .first()
        )
        if existante is not None:
            continue
        db.session.add(
            Partage(
                id_objet=objet.id,
                id_proprietaire=objet.id_user_proprietaire,
                id_destinataire=dest_id,
                message=message,
            )
        )
        envois.append(dest_id)
        pour_charger.append(dest_id)
    db.session.flush()

    for dest_id in pour_charger:
        creer_notification(
            dest_id,
            "Objet partagé",
            (
                f"{acteur.nom} {acteur.prenom or ''} partage un objet avec vous"
                f"{' : ' + message if message else '.'}"
            ).strip(),
            type_notif="partage",
            id_sender=acteur.id,
            entite_type="objet",
            entite_id=objet.id,
            lien=f"/objets/{objet.id}",
        )

    audit_service.audit(
        action="objet_partage",
        entite="objet",
        entite_id=objet.id,
        description=(
            f"Objet #{objet.id} partagé par {acteur.email} vers {len(envois)} destinataire(s)"
        ),
        apres={"destinataires": envois},
        user_id=acteur.id,
    )
    db.session.commit()
    return {"objets_partages": 1, "destinataires": envois, "total": len(envois)}


def partages_recus(user: User, page: int = 1, per_page: int = 20, non_lus: bool = False):
    query = db.session.query(Partage).filter(Partage.id_destinataire == user.id)
    if non_lus:
        query = query.filter(Partage.lu == 0)
    total = query.count()
    page, per_page = max(page, 1), min(max(per_page, 1), 100)
    items = (
        query.order_by(Partage.date_partage.desc())
        .offset((page - 1) * per_page)
        .limit(per_page)
        .all()
    )
    return items, total


def marquer_partage_lu(partage_id: int, user: User) -> Partage:
    partage = db.session.get(Partage, partage_id)
    if partage is None or partage.id_destinataire != user.id:
        raise NotFoundError("Partage introuvable.")
    if not partage.lu:
        partage.lu = 1
        db.session.commit()
    return partage
