"""Vie sociale : demandes d'amis, messages, notifications — `/api/v1/*`."""
from __future__ import annotations

from flask import Blueprint, request

from ..exceptions import ValidationFailed
from ..services import social_service, user_service
from ..utils.decorators import current_user, login_required, require_permission
from ..utils.payload import payload, query_int
from ..utils.responses import created, no_content, ok, paginated

social_bp = Blueprint("social", __name__)


# --------------------------------------------------------------------------- amis


@social_bp.get("/demandes")
@login_required
@require_permission("social.amis")
def demandes():
    items = social_service.lister_demandes(
        current_user(),
        statut=request.args.get("statut"),
        sens=request.args.get("sens"),
    )
    return ok(data=[d.to_dict() for d in items], meta={"total": len(items)})


@social_bp.post("/demandes")
@login_required
@require_permission("social.amis")
def demander():
    p_id = payload().get("id_destinataire")
    if p_id is None:
        from ..exceptions import ValidationFailed

        raise ValidationFailed(
            "Destinataire requis.",
            errors={"id_destinataire": ["Ce champ est obligatoire."]},
        )
    try:
        destinataire_id = int(p_id)
    except (TypeError, ValueError):
        from ..exceptions import ValidationFailed

        raise ValidationFailed(
            "Identifiant invalide.", errors={"id_destinataire": ["Entier attendu."]}
        ) from None
    demande = social_service.demander(destinataire_id, current_user())
    return created(data=demande.to_dict(), message="Demande envoyée.")


@social_bp.post("/demandes/<int:demande_id>/repondre")
@login_required
@require_permission("social.amis")
def repondre(demande_id: int):
    decision = payload().get("statut") or payload().get("decision")
    demande = social_service.repondre(demande_id, decision, current_user())
    return ok(data=demande.to_dict(), message="Demande mise à jour.")


@social_bp.delete("/demandes/<int:demande_id>")
@login_required
@require_permission("social.amis")
def annuler(demande_id: int):
    demande = social_service.annuler(demande_id, current_user())
    return no_content(f"Demande {demande.statut}.")


@social_bp.get("/amis")
@login_required
@require_permission("social.amis")
def amis():
    items = social_service.mes_amis(current_user(), q=request.args.get("q"))
    return ok(
        data=[u.to_dict(with_roles=False) for u in items],
        meta={"total": len(items)},
    )


@social_bp.get("/annuaire")
@login_required
@require_permission("social.amis")
def annuaire():
    """Recherche de personnes pour initier une demande d'ami.

    Champs volontairement réduits : l'e-mail et le téléphone des tiers ne sont
    pas exposés (le critère de recherche reste appliqué côté serveur).
    """
    terme = (request.args.get("q") or "").strip()
    if len(terme) < 2:
        raise ValidationFailed(
            "Terme de recherche trop court.",
            errors={"q": ["Saisissez au moins 2 caractères."]},
        )

    items, _total = user_service.lister(
        page=1,
        per_page=query_int("limite", 30) or 30,
        q=terme,
        exclure_id=current_user().id,
    )
    deja_amis = {u.id for u in social_service.mes_amis(current_user())}
    resultats = [
        {
            "id": u.id,
            "nom": u.nom,
            "postnom": u.postnom,
            "prenom": u.prenom,
            "avatar": u.avatar,
            "id_commissariat": u.id_commissariat,
            "commissariat": {"id": u.id_commissariat, "nom": u.commissariat_nom}
                if u.id_commissariat
                else None,
            "deja_ami": u.id in deja_amis,
            "roles": u.role_names,
        }
        for u in items
        if u.id not in deja_amis
    ]
    return ok(data=resultats, meta={"total": len(resultats), "q": terme})


# ------------------------------------------------------------------------- messages


@social_bp.get("/messages/<int:autre_id>")
@login_required
@require_permission("social.messages")
def conversation(autre_id: int):
    page, per_page = query_int("page", 1) or 1, query_int("per_page", 50) or 50
    items, total = social_service.conversation(autre_id, current_user(), page, per_page)
    return paginated([n.to_dict() for n in items], page, per_page, total)


@social_bp.post("/messages")
@login_required
@require_permission("social.messages")
def envoyer():
    data = payload()
    destinataire = data.get("id_destinataire")
    texte = data.get("messages") or data.get("contenu")
    from ..exceptions import ValidationFailed

    try:
        destinataire = int(destinataire)
    except (TypeError, ValueError):
        raise ValidationFailed(
            "Destinataire invalide.",
            errors={"id_destinataire": ["Entier attendu."]},
        ) from None
    note = social_service.envoyer_message(destinataire, texte, current_user())
    return created(data=note.to_dict(), message="Message envoyé.")


@social_bp.post("/messages/<int:note_id>/lu")
@login_required
@require_permission("social.messages")
def marquer_lu(note_id: int):
    note = social_service.marquer_lu(note_id, current_user())
    return ok(data=note.to_dict(), message="Message marqué comme lu.")


@social_bp.get("/messages-non-lus")
@login_required
@require_permission("social.messages")
def non_lus():
    return ok(data={"non_lus": social_service.messages_non_lus(current_user())})


# --------------------------------------------------------------------- notifications


@social_bp.get("/notifications")
@login_required
@require_permission("notifications.lire")
def notifications():
    page, per_page = query_int("page", 1) or 1, query_int("per_page", 20) or 20
    items, total = social_service.lister_notifications(
        current_user(),
        page=page,
        per_page=per_page,
        non_lues=str(request.args.get("non_lues", "")).lower() in {"1", "true", "yes"},
    )
    return paginated([n.to_dict() for n in items], page, per_page, total)


@social_bp.post("/notifications/<int:notification_id>/lu")
@login_required
@require_permission("notifications.lire")
def marquer_notification(notification_id: int):
    lu = str(payload().get("lu", "1")).lower() not in {"0", "false", "no"}
    notif = social_service.marquer_notification(notification_id, current_user(), lu=lu)
    return ok(data=notif.to_dict())


@social_bp.post("/notifications/tout-lu")
@login_required
@require_permission("notifications.lire")
def tout_marquer_lu():
    nombre = social_service.tout_marquer_lu(current_user())
    return ok(data={"mises_a_jour": nombre}, message="Notifications marquées comme lues.")
