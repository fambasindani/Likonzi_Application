"""SOS « minute de grâce » : déclenchement, compte à rebours, diffusion aux amis.

Le minuteur vit CÔTÉ SERVEUR (table `sos` + tâche de veille) : l'application
peut être fermée, l'envoi a quand même lieu à l'échéance.

Cycle de vie :
  * `programme`    — T+0 : déclenchement, l'utilisateur peut encore annuler
  * `intermediaire`— T-(duree-5) : message d'alerte intermédiaire aux amis
  * `envoye`       — échéance : SOS complet (message + notif + alerte police)
  * `annule`       — « Annuler » avant l'échéance (fausse alerte)
  * `cloture`      — « Je vais bien » (après envoi)
"""
from __future__ import annotations

import logging
import threading
import time
from datetime import datetime, timedelta

from ..exceptions import ConflictError, NotFoundError
from ..extensions import db
from ..models import Note, Sos, User
from ..realtime import prevoir
from . import alerte_service, audit_service, social_service
from .notification_service import notifier_groupe
from .validators import Payload

logger = logging.getLogger(__name__)

DUREE_DEFAUT = 15
DUREE_MIN = 5
DUREE_MAX = 60
DELAI_INTERMEDIAIRE = 5  # minutes avant l'échéance
INTERVALLE_VEILLE = 15  # secondes entre deux passages de la veille

STATUTS_ACTIFS = ("programme", "intermediaire")

TEXTE_INTERMEDIAIRE = (
    "⚠️ SOS — {nom} signale une situation dangereuse : « je suis en danger ». "
    "SOS complet dans {minutes} min si silence."
)
TEXTE_SOS = "🚨 SOS URGENT — {nom} est en DANGER. {position}Message automatique LIKONZI."
TEXTE_CLOTURE = "✅ SOS levé — {nom} est en sécurité."


# --------------------------------------------------------------------- lecture


def etat(user_id: int) -> dict:
    """État du SOS actif de l'utilisateur (pour le compte à rebours côté client).

    Renvoie aussi un SOS `envoye` non levé : l'application doit pouvoir proposer
    « Je vais bien » après l'envoi.
    """
    sos = _actif(user_id)
    if sos is None:
        sos = (
            db.session.query(Sos)
            .filter(Sos.id_user == user_id, Sos.statut == "envoye")
            .order_by(Sos.id.desc())
            .first()
        )
    return {"actif": sos is not None, "sos": sos.to_dict() if sos else None}


def _actif(user_id: int) -> Sos | None:
    return (
        db.session.query(Sos)
        .filter(Sos.id_user == user_id, Sos.statut.in_(STATUTS_ACTIFS))
        .order_by(Sos.id.desc())
        .first()
    )


# ------------------------------------------------------------------ déclenchement


def programmer(acteur: User, data: dict | None = None) -> Sos:
    """Lance le décompte (un seul SOS actif par utilisateur)."""
    if _actif(acteur.id) is not None:
        raise ConflictError("Un SOS est déjà en cours. Annulez-le avant d'en lancer un autre.")

    p = Payload(data or {})
    duree = p.entier(
        "duree_minutes", requis=False, default=DUREE_DEFAUT, min_val=DUREE_MIN, max_val=DUREE_MAX
    )
    latitude = p.decimal("latitude", min_val=-90.0, max_val=90.0)
    longitude = p.decimal("longitude", min_val=-180.0, max_val=180.0)
    p.fail_if_errors()

    now = datetime.now()
    sos = Sos(
        id_user=acteur.id,
        statut="programme",
        duree_minutes=duree,
        echeance=now + timedelta(minutes=duree),
        latitude=latitude,
        longitude=longitude,
    )
    db.session.add(sos)
    db.session.flush()

    audit_service.audit(
        action="sos_programme",
        entite="sos",
        entite_id=sos.id,
        description=(
            f"SOS programmé par {acteur.email} — {duree} min, "
            f"échéance {sos.echeance:%H:%M:%S}"
        ),
        apres={"duree_minutes": duree, "echeance": sos.echeance.isoformat()},
        user_id=acteur.id,
    )
    prevoir(
        [f"user:{acteur.id}"],
        "sos",
        etat="programme",
        sos=sos.to_dict(),
    )
    db.session.commit()
    return sos


def annuler(acteur: User) -> Sos:
    """« Annuler » : fausse alerte, aucun ami prévenu."""
    sos = _actif(acteur.id)
    if sos is None:
        raise NotFoundError("Aucun SOS en cours.")
    sos.statut = "annule"
    sos.cloture_at = datetime.now()
    audit_service.audit(
        action="sos_annule",
        entite="sos",
        entite_id=sos.id,
        description=f"SOS {sos.id} annulé par {acteur.email}",
        user_id=acteur.id,
    )
    prevoir([f"user:{acteur.id}"], "sos", etat="annule", sos=sos.to_dict())
    db.session.commit()
    return sos


def envoyer_maintenant(acteur: User) -> Sos:
    """« Envoyer maintenant » : saute le compte à rebours."""
    sos = _actif(acteur.id)
    if sos is None:
        raise NotFoundError("Aucun SOS en cours.")
    _finaliser(sos)
    db.session.commit()
    return sos


def cloturer(acteur: User) -> Sos:
    """« Je vais bien » : lève le SOS et prévient les amis du rétablissement."""
    sos = (
        db.session.query(Sos)
        .filter(Sos.id_user == acteur.id, Sos.statut.in_((*STATUTS_ACTIFS, "envoye")))
        .order_by(Sos.id.desc())
        .first()
    )
    if sos is None:
        raise NotFoundError("Aucun SOS en cours.")

    sos.statut = "cloture"
    sos.cloture_at = datetime.now()
    _diffuser(sos, _texte_c(acteur), evenement="sos_cloture", type_notif="sos")
    audit_service.audit(
        action="sos_cloture",
        entite="sos",
        entite_id=sos.id,
        description=f"SOS {sos.id} levé par {acteur.email}",
        user_id=acteur.id,
    )
    prevoir([f"user:{acteur.id}"], "sos", etat="cloture", sos=sos.to_dict())
    db.session.commit()
    return sos


# -------------------------------------------------------------------- diffusion


def _nom(user: User) -> str:
    return f"{user.nom} {user.prenom or ''}".strip()


def _texte_sos(sos: Sos, acteur: User) -> str:
    position = (
        f"Position : {float(sos.latitude):.5f}, {float(sos.longitude):.5f}. "
        if sos.latitude is not None and sos.longitude is not None
        else ""
    )
    return TEXTE_SOS.format(nom=_nom(acteur), position=position)


def _texte_intermediaire(sos: Sos, acteur: User, minutes: int) -> str:
    return TEXTE_INTERMEDIAIRE.format(nom=_nom(acteur), minutes=minutes)


def _texte_c(acteur: User) -> str:
    return TEXTE_CLOTURE.format(nom=_nom(acteur))


def _diffuser(sos: Sos, texte: str, *, evenement: str, type_notif: str) -> int:
    """Message (Note) + notification + socket à chaque ami. Renvoie le nombre de destinataires."""
    acteur = db.session.get(User, sos.id_user)
    if acteur is None:
        return 0
    amis = social_service.mes_amis(acteur)
    if not amis:
        logger.info("SOS %s : aucun ami à prévenir.", sos.id)
        return 0

    for ami in amis:
        db.session.add(
            Note(id_rec=ami.id, id_sender=acteur.id, messages=texte, lu=0)
        )
    db.session.flush()

    notifier_groupe(
        [ami.id for ami in amis],
        "SOS" if type_notif == "sos" else "Alerte SOS",
        texte,
        type_notif=type_notif,
        id_sender=acteur.id,
        entite_type="alerte",
        lien="/sos",
    )
    salles = [f"user:{ami.id}" for ami in amis]
    salles.append(f"user:{acteur.id}")
    prevoir(
        salles,
        evenement,
        sos=sos.to_dict(),
        message=texte,
        emetteur_id=acteur.id,
    )
    return len(amis)


def _creer_alerte(sos: Sos, acteur: User) -> None:
    """Alerte police (commissariat le plus proche) — best effort, jamais bloquant."""
    if sos.latitude is None or sos.longitude is None:
        return
    try:
        type_danger = None
        from ..models import TypeAlerte

        type_danger = (
            db.session.query(TypeAlerte).filter(TypeAlerte.code == "DANGER").first()
        )
        if type_danger is None:
            return
        alerte = alerte_service.creer(
            {
                "id_type_alerte": type_danger.id,
                "contenu": f"SOS déclenché par {_nom(acteur)} — je suis en danger.",
                "niveau_urgence": "critique",
                "latitude": float(sos.latitude),
                "longitude": float(sos.longitude),
            },
            acteur,
        )
        sos.id_alerte = alerte.id
    except Exception:
        logger.exception("SOS %s : création de l'alerte impossible", sos.id)


def _finaliser(sos: Sos) -> None:
    """Échéance atteinte : SOS complet aux amis (+ alerte police si position)."""
    acteur = db.session.get(User, sos.id_user)
    if acteur is None or sos.statut not in STATUTS_ACTIFS:
        return
    sos.statut = "envoye"
    sos.envoye_at = datetime.now()
    _diffuser(sos, _texte_sos(sos, acteur), evenement="sos_envoye", type_notif="sos")
    _creer_alerte(sos, acteur)
    audit_service.audit(
        action="sos_envoye",
        entite="sos",
        entite_id=sos.id,
        description=f"SOS {sos.id} envoyé par {acteur.email}",
        apres={"id_alerte": sos.id_alerte},
        user_id=acteur.id,
    )


# ----------------------------------------------------------------------- veille

# État observable de la tâche de fond (exposé par `GET /sos/veille`).
_veille_derniere_execution: datetime | None = None
_veille_derniere_erreur: str | None = None
_veille_traitees: int = 0
_thread: threading.Thread | None = None


def traiter() -> int:
    """Passe les SOS dus : message intermédiaire puis échéance.

    Chaque SOS est traité **dans sa propre transaction** : une erreur sur l'un
    n'empêche jamais les autres, ni le passage suivant.
    """
    global _veille_traitees
    maintenant = datetime.now()
    traitees = 0

    # 1. Message intermédiaire (5 min avant l'échéance, une seule fois).
    seuil = maintenant + timedelta(minutes=DELAI_INTERMEDIAIRE)
    intermediaires = (
        db.session.query(Sos)
        .filter(
            Sos.statut == "programme",
            Sos.intermediaire_at.is_(None),
            Sos.duree_minutes > DELAI_INTERMEDIAIRE,
            Sos.echeance <= seuil,
        )
        .all()
    )
    for sos in intermediaires:
        try:
            acteur = db.session.get(User, sos.id_user)
            if acteur is None:
                sos.statut = "annule"
                db.session.commit()
                continue
            sos.statut = "intermediaire"
            sos.intermediaire_at = maintenant
            minutes = max(1, int((sos.echeance - maintenant).total_seconds() // 60))
            nb = _diffuser(
                sos,
                _texte_intermediaire(sos, acteur, minutes),
                evenement="sos_intermediaire",
                type_notif="sos",
            )
            db.session.commit()
            logger.info("SOS %s : alerte intermédiaire envoyée à %d ami(s).", sos.id, nb)
            traitees += 1
        except Exception:
            logger.exception("SOS %s : alerte intermédiaire impossible", sos.id)
            db.session.rollback()

    # 2. Échéances : SOS complet.
    dues = (
        db.session.query(Sos)
        .filter(Sos.statut.in_(STATUTS_ACTIFS), Sos.echeance <= maintenant)
        .all()
    )
    for sos in dues:
        try:
            _finaliser(sos)
            db.session.commit()
            logger.info("SOS %s : échéance atteinte, message envoyé.", sos.id)
            traitees += 1
        except Exception:
            logger.exception("SOS %s : envoi à l'échéance impossible", sos.id)
            db.session.rollback()

    _veille_traitees += traitees
    return traitees


def etat_veille() -> dict:
    """Diagnostic de la tâche de fond : thread vivant ? dernière exécution ? erreur ?"""
    return {
        "actif": _thread is not None and _thread.is_alive(),
        "intervalle_secondes": INTERVALLE_VEILLE,
        "derniere_execution": (
            _veille_derniere_execution.isoformat(timespec="seconds")
            if _veille_derniere_execution
            else None
        ),
        "derniere_erreur": _veille_derniere_erreur,
        "traitees_total": _veille_traitees,
        "heure_serveur": datetime.now().isoformat(timespec="seconds"),
    }


def demarrer_veille(app, intervalle: int = INTERVALLE_VEILLE) -> threading.Thread | None:
    """Démarre la tâche de fond (une seule fois, thread daemon)."""
    global _thread
    if app.testing or (_thread is not None and _thread.is_alive()):
        return _thread

    def _boucle() -> None:
        global _veille_derniere_execution, _veille_derniere_erreur
        logger.info("Veille SOS démarrée (intervalle %ss).", intervalle)
        while True:
            time.sleep(intervalle)
            try:
                with app.app_context():
                    _veille_derniere_execution = datetime.now()
                    _veille_derniere_erreur = None
                    traitees = traiter()
                    if traitees:
                        logger.info("Veille SOS : %d SOS traité(s).", traitees)
            except Exception as exc:
                _veille_derniere_erreur = f"{type(exc).__name__}: {exc}"
                logger.exception("Veille SOS : erreur inattendue")

    _thread = threading.Thread(target=_boucle, name="veille-sos", daemon=True)
    _thread.start()
    return _thread
