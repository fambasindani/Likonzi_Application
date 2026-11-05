"""Demandes d'amis, messages privés et notifications."""
from __future__ import annotations

from datetime import datetime

from sqlalchemy import or_

from ..exceptions import ConflictError, ForbiddenError, NotFoundError, ValidationFailed
from ..extensions import db
from ..models import Demande, Note, Notification, User
from . import audit_service
from .notification_service import creer_notification
from .validators import Payload

STATUTS_DEMANDE = ["en_attente", "acceptee", "refusee", "annulee"]
ROLES_POLICE = ("policier", "enqueteur", "admin", "super_admin")


# --------------------------------------------------------------------------- amis


def demander(destinataire_id: int, acteur: User) -> Demande:
    if destinataire_id == acteur.id:
        raise ValidationFailed(
            "Destinataire invalide.",
            errors={"id_destinataire": ["Vous ne pouvez pas vous envoyer une demande."]},
        )
    destinataire = db.session.get(User, destinataire_id)
    if destinataire is None or destinataire.deleted_at is not None:
        raise NotFoundError("Destinataire introuvable.")
    if not destinataire.est_actif:
        raise ValidationFailed(
            "Destinataire indisponible.",
            errors={"id_destinataire": [f"Compte en statut « {destinataire.statut} »."]},
        )

    # Existe-t-il déjà un lien entre ces deux comptes ?
    existante = (
        db.session.query(Demande)
        .filter(
            or_(
                (Demande.recev_id == acteur.id) & (Demande.envoi_id == destinataire_id),
                (Demande.recev_id == destinataire_id) & (Demande.envoi_id == acteur.id),
            )
        )
        .first()
    )
    if existante is not None:
        if existante.statut == "acceptee":
            raise ConflictError("Vous êtes déjà amis.")
        if existante.statut == "en_attente":
            if existante.envoi_id == acteur.id:
                raise ConflictError("Une demande est déjà en attente vers cet utilisateur.")
            # Inversion : l'autre nous avait déjà écrit → on accepte implicitement.
            existante.statut = "acceptee"
            existante.date_reponse = datetime.now()
            creer_notification(
                existante.recev_id,
                "Demande acceptée",
                f"{acteur.nom} {acteur.prenom or ''} a accepté votre demande d'ami.".strip(),
                type_notif="demande_ami",
                id_sender=acteur.id,
                entite_type="demande",
                entite_id=existante.id,
                lien=f"/demandes/{existante.id}",
            )
            audit_service.audit(
                action="ami_accepte",
                entite="demande",
                entite_id=existante.id,
                description=f"Demande inversée acceptée par {acteur.email}",
                user_id=acteur.id,
            )
            db.session.commit()
            return existante
        # Sinon (refusée/annulée) on repart d'une demande neuve : on nettoie l'ancienne.
        db.session.delete(existante)
        db.session.flush()

    demande = Demande(
        recev_id=destinataire_id,
        envoi_id=acteur.id,
        date_demande=datetime.now(),
        statut="en_attente",
    )
    db.session.add(demande)
    db.session.flush()

    creer_notification(
        destinataire_id,
        "Nouvelle demande d'ami",
        f"{acteur.nom} {acteur.prenom or ''} souhaite vous ajouter à ses contacts.".strip(),
        type_notif="demande_ami",
        id_sender=acteur.id,
        entite_type="demande",
        entite_id=demande.id,
        lien=f"/demandes/{demande.id}",
    )
    audit_service.audit(
        action="demande_envoyee",
        entite="demande",
        entite_id=demande.id,
        description=f"Demande {acteur.id} -> {destinataire_id}",
        user_id=acteur.id,
    )
    db.session.commit()
    return demande


def repondre(demande_id: int, decision: str, acteur: User) -> Demande:
    demande = _recuperer(demande_id, acteur)
    if demande.recev_id != acteur.id:
        raise ForbiddenError("Seul le destinataire peut répondre à cette demande.")
    if demande.statut != "en_attente":
        raise ValidationFailed(
            "Demande déjà traitée.",
            errors={"statut": [f"Statut actuel : {demande.statut}."]},
        )
    if decision not in ("acceptee", "refusee"):
        raise ValidationFailed(
            "Décision invalide.",
            errors={"statut": ["Valeurs attendues : acceptee, refusee."]},
        )

    demande.statut = decision
    demande.date_reponse = datetime.now()
    creer_notification(
        demande.envoi_id,
        "Demande acceptée" if decision == "acceptee" else "Demande refusée",
        f"{acteur.nom} {acteur.prenom or ''} a "
        + ("accepté" if decision == "acceptee" else "refusé")
        + " votre demande d'ami.",
        type_notif="demande_ami",
        id_sender=acteur.id,
        entite_type="demande",
        entite_id=demande.id,
        lien=f"/demandes/{demande.id}",
    )
    audit_service.audit(
        action="demande_reponse",
        entite="demande",
        entite_id=demande.id,
        description=f"Demande {demande.id} -> {decision} par {acteur.email}",
        user_id=acteur.id,
    )
    db.session.commit()
    return demande


def annuler(demande_id: int, acteur: User) -> Demande:
    demande = _recuperer(demande_id, acteur)
    if demande.envoi_id != acteur.id:
        raise ForbiddenError("Seul l'émetteur peut annuler cette demande.")
    if demande.statut != "en_attente":
        raise ValidationFailed(
            "Demande déjà traitée.",
            errors={"statut": [f"Statut actuel : {demande.statut}."]},
        )
    demande.statut = "annulee"
    demande.date_reponse = datetime.now()
    audit_service.audit(
        action="demande_annulee",
        entite="demande",
        entite_id=demande.id,
        description=f"Demande {demande.id} annulée par {acteur.email}",
        user_id=acteur.id,
    )
    db.session.commit()
    return demande


def _recuperer(demande_id: int, acteur: User) -> Demande:
    demande = db.session.get(Demande, demande_id)
    if demande is None:
        raise NotFoundError("Demande introuvable.")
    if demande.recev_id != acteur.id and demande.envoi_id != acteur.id:
        raise NotFoundError("Demande introuvable.")
    return demande


def lister_demandes(
    acteur: User, statut: str | None = None, sens: str | None = None
) -> list[Demande]:
    query = db.session.query(Demande).filter(
        or_(Demande.recev_id == acteur.id, Demande.envoi_id == acteur.id)
    )
    if statut:
        if statut not in STATUTS_DEMANDE:
            raise ValidationFailed(
                "Statut invalide.", errors={"statut": [f"Inconnu : {statut}"]}
            )
        query = query.filter(Demande.statut == statut)
    if sens == "recues":
        query = query.filter(Demande.recev_id == acteur.id)
    elif sens == "envoyees":
        query = query.filter(Demande.envoi_id == acteur.id)
    elif sens is not None:
        raise ValidationFailed(
            "Sens invalide.", errors={"sens": ["Valeurs : recues, envoyees."]}
        )
    return query.order_by(Demande.date_demande.desc()).all()


def ids_amis(acteur: User) -> list[int]:
    """Identifiants des amis acceptés — version légère de `mes_amis` (sans `User`).

    Sert de périmètre partagé : alertes et objets visibles par les contacts.
    """
    ids: set[int] = set()
    for d in (
        db.session.query(Demande)
        .filter(
            Demande.statut == "acceptee",
            or_(Demande.recev_id == acteur.id, Demande.envoi_id == acteur.id),
        )
        .all()
    ):
        ids.add(d.envoi_id if d.recev_id == acteur.id else d.recev_id)
    ids.discard(acteur.id)
    return sorted(ids)


def mes_amis(acteur: User, q: str | None = None) -> list[User]:
    """Amis dans les DEUX sens (miroir de la vue `v_amis_acceptes`)."""
    ids = ids_amis(acteur)
    if not ids:
        return []
    query = db.session.query(User).filter(User.id.in_(ids), User.deleted_at.is_(None))
    if q:
        like = f"%{q.strip()}%"
        query = query.filter(
            or_(User.nom.ilike(like), User.postnom.ilike(like), User.prenom.ilike(like))
        )
    return query.order_by(User.nom, User.prenom).all()


def suggestions(acteur: User, limite: int = 20) -> list[tuple[User, int]]:
    """« Personnes que vous pourriez connaître » — style Facebook.

    Écarte l'utilisateur lui-même, ses amis et les demandes en attente (les
    deux sens), puis classe par **nombre d'amis en commun** ; à défaut de lien,
    propose les comptes actifs les plus récents. Renvoie `(utilisateur, amis_communs)`.
    """
    exclus: set[int] = {acteur.id, *ids_amis(acteur)}

    # Demandes en attente (envoyées ou reçues) : pas encore ami, pas à proposer.
    for d in (
        db.session.query(Demande)
        .filter(
            Demande.statut == "en_attente",
            or_(Demande.recev_id == acteur.id, Demande.envoi_id == acteur.id),
        )
        .all()
    ):
        exclus.add(d.envoi_id if d.recev_id == acteur.id else d.recev_id)

    # Amis en commun : demandes acceptées impliquant un de mes amis.
    mes_amis_ids = ids_amis(acteur)
    scores: dict[int, int] = {}
    if mes_amis_ids:
        for d in (
            db.session.query(Demande)
            .filter(
                Demande.statut == "acceptee",
                or_(
                    Demande.recev_id.in_(mes_amis_ids),
                    Demande.envoi_id.in_(mes_amis_ids),
                ),
            )
            .all()
        ):
            autre = d.recev_id if d.envoi_id in mes_amis_ids else d.envoi_id
            if autre in exclus:
                continue
            scores[autre] = scores.get(autre, 0) + 1

    if scores:
        candidats = sorted(scores, key=lambda i: (-scores[i], i))[: limite * 2]
    else:
        # Sans lien : on propose les comptes actifs les plus récents.
        candidats = [
            r[0]
            for r in (
                db.session.query(User.id)
                .filter(
                    User.deleted_at.is_(None),
                    User.statut == "actif",
                    User.id.notin_(exclus),
                )
                .order_by(User.id.desc())
                .limit(limite * 2)
                .all()
            )
        ]
    if not candidats:
        return []

    personnes = (
        db.session.query(User)
        .filter(User.id.in_(candidats), User.deleted_at.is_(None), User.statut == "actif")
        .all()
    )
    personnes.sort(key=lambda u: (-scores.get(u.id, 0), u.nom, u.prenom or ""))
    return [(u, scores.get(u.id, 0)) for u in personnes[:limite]]


# ------------------------------------------------------------------------- messages


def envoyer_message(destinataire_id: int, texte: str, acteur: User) -> Note:
    if destinataire_id == acteur.id:
        raise ValidationFailed(
            "Destinataire invalide.",
            errors={"id_destinataire": ["Vous ne pouvez pas vous écrire à vous-même."]},
        )
    destinataire = db.session.get(User, destinataire_id)
    if destinataire is None or destinataire.deleted_at is not None:
        raise NotFoundError("Destinataire introuvable.")

    p = Payload({"messages": texte})
    contenu = p.chaine("messages", requis=True, min_len=1, max_len=10000)
    p.fail_if_errors()

    note = Note(id_rec=destinataire_id, id_sender=acteur.id, messages=contenu, lu=0)
    db.session.add(note)
    db.session.flush()

    creer_notification(
        destinataire_id,
        "Nouveau message",
        f"{acteur.nom} {acteur.prenom or ''} : {contenu[:100]}",
        type_notif="message",
        id_sender=acteur.id,
        entite_type="demande",
        entite_id=None,
        lien=f"/messages/{acteur.id}",
    )
    db.session.commit()
    return note


def conversation(autre_id: int, acteur: User, page: int = 1, per_page: int = 50):
    """Historique trié chronologiquement entre l'utilisateur et `autre_id`."""
    query = db.session.query(Note).filter(
        or_(
            (Note.id_rec == acteur.id) & (Note.id_sender == autre_id),
            (Note.id_rec == autre_id) & (Note.id_sender == acteur.id),
        )
    )
    total = query.count()
    page, per_page = max(page, 1), min(max(per_page, 1), 200)
    items = (
        query.order_by(Note.id.asc()).offset((page - 1) * per_page).limit(per_page).all()
    )
    return items, total


def marquer_lu(note_id: int, acteur: User) -> Note:
    note = db.session.get(Note, note_id)
    if note is None:
        raise NotFoundError("Message introuvable.")
    if note.id_rec != acteur.id:
        raise ForbiddenError("Seul le destinataire peut marquer le message comme lu.")
    if not note.lu:
        note.lu = 1
        db.session.commit()
    return note


def messages_non_lus(acteur: User) -> int:
    return (
        db.session.query(Note.id).filter(Note.id_rec == acteur.id, Note.lu == 0).count()
    )


# --------------------------------------------------------------------- notifications


def lister_notifications(
    acteur: User, page: int = 1, per_page: int = 20, non_lues: bool = False
) -> tuple[list[Notification], int]:
    query = db.session.query(Notification).filter(Notification.id_user == acteur.id)
    if non_lues:
        query = query.filter(Notification.lu == 0)
    total = query.count()
    page, per_page = max(page, 1), min(max(per_page, 1), 100)
    items = (
        query.order_by(Notification.date_envoi.desc())
        .offset((page - 1) * per_page)
        .limit(per_page)
        .all()
    )
    return items, total


def marquer_notification(notification_id: int, acteur: User, lu: bool = True) -> Notification:
    notif = db.session.get(Notification, notification_id)
    if notif is None or notif.id_user != acteur.id:
        raise NotFoundError("Notification introuvable.")
    if notif.lu != int(lu):
        notif.lu = int(lu)
        if lu:
            notif.date_lecture = datetime.now()
        else:
            notif.date_lecture = None
        db.session.commit()
    return notif


def tout_marquer_lu(acteur: User) -> int:
    modifiees = (
        db.session.query(Notification)
        .filter(Notification.id_user == acteur.id, Notification.lu == 0)
        .update({"lu": 1, "date_lecture": datetime.now()}, synchronize_session=False)
    )
    db.session.commit()
    return modifiees
