"""Socle d'authentification : inscription, connexion, jetons, vérifications."""
from __future__ import annotations

import hmac
from collections.abc import Iterable
from datetime import datetime
from typing import Any

from flask import current_app

from ..exceptions import ConflictError, NotFoundError, UnauthorizedError, ValidationFailed
from ..extensions import db
from ..models import Role, User, VerificationToken
from ..utils import security as sec
from . import audit_service, mailer
from .validators import Payload

# Rôles attribuables lors d'une inscription libre (le reste exige un privilégié).
ROLES_LIBRES = ("citoyen",)


# --------------------------------------------------------------------------- politiques


def _politique_mdp(mot_de_passe: str) -> list[str]:
    """Retourne les manquements à la politique de mot de passe."""
    probleme: list[str] = []
    min_len = int(current_app.config.get("PASSWORD_MIN_LENGTH", 8))
    if len(mot_de_passe) < min_len:
        probleme.append(f"au moins {min_len} caractères")
    if not any(c.isdigit() for c in mot_de_passe):
        probleme.append("au moins un chiffre")
    return probleme


def _hmac_otp(id_user: int, type_jeton: str, code: str) -> str:
    secret = current_app.config["JWT_SECRET_KEY"].encode("utf-8")
    message = f"{id_user}:{type_jeton}:{code}".encode()
    return hmac.new(secret, message, "sha256").hexdigest()


def _charger_roles(noms: Iterable[str]) -> list[Role]:
    noms = list(dict.fromkeys(noms))
    roles = (
        db.session.query(Role).filter(Role.nom.in_(noms)).all() if noms else []
    )
    trouves = {r.nom for r in roles}
    manquants = [n for n in noms if n not in trouves]
    if manquants:
        raise ValidationFailed(
            "Rôle inconnu.",
            errors={"roles": [f"Rôle inconnu : {m}" for m in manquants]},
        )
    return roles


# --------------------------------------------------------------------------- inscription


def register(data: dict[str, Any], roles_autorises: tuple[str, ...] = ROLES_LIBRES) -> dict:
    """Crée un compte, lui attribue ses rôles et retourne la session."""
    p = Payload(data)
    nom = p.chaine("nom", max_len=50)
    postnom = p.chaine("postnom", requis=False, max_len=50)
    prenom = p.chaine("prenom", requis=False, max_len=50)
    email = p.email("email")
    telephone = p.telephone("telephone")
    password = p.mot_de_passe("password", min_len=int(current_app.config["PASSWORD_MIN_LENGTH"]))
    genre = p.enum("genre", ["M", "F", "Autre"])
    adresse = p.chaine("adresse", requis=False, max_len=255)
    date_naissance = p.date("date_naissance")
    matricule = p.chaine("matricule_police", requis=False, max_len=50)
    grade = p.chaine("grade_police", requis=False, max_len=50)
    id_commissariat = p.entier("id_commissariat")
    roles_demandes = data.get("roles") or data.get("role") or ["citoyen"]
    if isinstance(roles_demandes, str):
        roles_demandes = [roles_demandes]
    if not isinstance(roles_demandes, list):
        p.errors.setdefault("roles", []).append("Liste de rôles attendue.")
        roles_demandes = []
    p.fail_if_errors()

    # Politique de mot de passe
    if password:
        manques = _politique_mdp(password)
        if manques:
            raise ValidationFailed(
                "Mot de passe trop faible.",
                errors={"password": ["Doit contenir " + ", ".join(manques) + "."]},
            )

    # Rôles : on n'accepte que ceux explicitement autorisés par l'appelant.
    interdits = [r for r in roles_demandes if r not in roles_autorises]
    if interdits:
        raise ValidationFailed(
            "Attribution de rôle non autorisée ici.",
            errors={"roles": [f"Rôle non attribuable : {r}" for r in interdits]},
        )

    # Unicité
    conflits: dict[str, list[str]] = {}
    if email and db.session.query(User.id).filter(User.email == email).first():
        conflits.setdefault("email", []).append("Cette adresse e-mail est déjà utilisée.")
    if telephone and db.session.query(User.id).filter(User.telephone == telephone).first():
        conflits.setdefault("telephone", []).append("Ce numéro est déjà utilisé.")
    if matricule and db.session.query(User.id).filter(User.matricule_police == matricule).first():
        conflits.setdefault("matricule_police", []).append("Ce matricule est déjà attribué.")
    if conflits:
        raise ConflictError("Compte déjà existant.", errors=conflits)

    user = User(
        nom=nom,
        postnom=postnom,
        prenom=prenom,
        email=email,
        telephone=telephone,
        password=sec.hash_password(password),
        genre=genre,
        adresse=adresse,
        date_naissance=date_naissance,
        id_commissariat=id_commissariat,
        matricule_police=matricule,
        grade_police=grade,
        statut="actif",
        email_verifie=0,
        telephone_verifie=0,
    )
    user.roles = _charger_roles(roles_demandes)
    db.session.add(user)
    db.session.flush()  # obtient l'identifiant

    audit_service.audit(
        action="inscription",
        entite="user",
        entite_id=user.id,
        description=f"Création du compte {user.email}",
        apres={"email": user.email, "roles": user.role_names},
        user_id=user.id,
    )
    db.session.commit()

    return {
        "user": user,
        "access": sec.issue_access_token(user),
        "refresh": sec.issue_refresh_token(user),
    }


# --------------------------------------------------------------------------- connexion


def login(data: dict[str, Any]) -> dict:
    p = Payload(data)
    email = p.email("email")
    password = p.mot_de_passe("password", min_len=1, max_len=128)
    p.fail_if_errors()

    user = db.session.query(User).filter(User.email == email).first()
    # Message unique : on ne révèle jamais si l'adresse existe.
    message_refus = "Adresse e-mail ou mot de passe incorrect."

    if user is None or user.deleted_at is not None or not sec.check_password(user.password, password):
        audit_service.audit(
            action="connexion_echec",
            entite="user",
            entite_id=user.id if user else None,
            description=f"Échec de connexion pour {email}",
        )
        db.session.commit()
        raise UnauthorizedError(message_refus)

    if not user.est_actif:
        audit_service.audit(
            action="connexion_bloquee",
            entite="user",
            entite_id=user.id,
            description=f"Compte en statut {user.statut}",
            user_id=user.id,
        )
        db.session.commit()
        from ..exceptions import ForbiddenError

        raise ForbiddenError(
            f"Compte « {user.statut} » : contactez l'administration.",
            errors={"statut": user.statut},
        )

    user.derniere_connexion = datetime.now()
    audit_service.audit(
        action="connexion",
        entite="user",
        entite_id=user.id,
        description=f"Connexion de {user.email}",
        user_id=user.id,
    )
    db.session.commit()

    return {
        "user": user,
        "access": sec.issue_access_token(user),
        "refresh": sec.issue_refresh_token(user),
    }


def refresh(data: dict[str, Any]) -> dict:
    token = (data or {}).get("refresh_token") or (data or {}).get("token")
    if not token:
        raise ValidationFailed(
            "Jeton de rafraîchissement manquant.",
            errors={"refresh_token": ["Ce champ est obligatoire."]},
        )

    claims = sec.decode_token(token, expected_type="refresh")
    if sec.is_revoked(claims["jti"]):
        raise UnauthorizedError("Jeton de rafraîchissement révoqué.")

    user = db.session.get(User, int(claims["sub"]))
    if user is None or user.deleted_at is not None or not user.est_actif:
        raise UnauthorizedError("Compte indisponible.")

    return {
        "user": user,
        "access": sec.issue_access_token(user),
        "refresh": sec.issue_refresh_token(user),
    }


def logout(claims: dict[str, Any]) -> None:
    sec.revoke_token(claims["jti"], int(claims["sub"]), claims["exp"])
    audit_service.audit(
        action="deconnexion",
        entite="user",
        entite_id=int(claims["sub"]),
        description="Révocation du jeton d'accès",
        user_id=int(claims["sub"]),
    )
    db.session.commit()


# ---------------------------------------------------------------------- vérifications


def _creer_otp(user: User, type_jeton: str) -> tuple[str, VerificationToken]:
    code = sec.generate_otp()
    # Une seule demande active par type : on invalide les précédentes.
    db.session.query(VerificationToken).filter(
        VerificationToken.id_user == user.id,
        VerificationToken.type == type_jeton,
        VerificationToken.utilise_le.is_(None),
    ).update({"utilise_le": datetime.now()}, synchronize_session=False)

    jeton = VerificationToken(
        id_user=user.id,
        type=type_jeton,
        code=code,
        jeton_hash=_hmac_otp(user.id, type_jeton, code),
        expire_at=sec.otp_expiry(),
    )
    db.session.add(jeton)
    return code, jeton


def demander_verification(user: User, type_jeton: str) -> dict:
    """Génère et « envoie » un code (e-mail ou SMS)."""
    if type_jeton not in ("email", "telephone"):
        raise ValidationFailed(
            "Type de vérification inconnu.",
            errors={"type": ["Valeurs attendues : email, telephone."]},
        )
    destination = user.email if type_jeton == "email" else user.telephone
    code, jeton = _creer_otp(user, type_jeton)
    mailer.envoyer(
        destination,
        f"Code de vérification {type_jeton}",
        f"Votre code de vérification est : {code}\n"
        f"Valable {current_app.config['OTP_TTL_MINUTES']} minutes.",
    )
    audit_service.audit(
        action="otp_envoye",
        entite="user",
        entite_id=user.id,
        description=f"Code de vérification {type_jeton} émis",
        user_id=user.id,
    )
    db.session.commit()

    reponse = {"destinataire": destination, "expire_at": jeton.expire_at.isoformat()}
    # En développement sans SMTP, on expose le code pour pouvoir tester.
    if not current_app.config.get("MAIL_ENABLED"):
        reponse["code_demo"] = code
    return reponse


def confirmer_verification(user: User, data: dict[str, Any]) -> dict:
    p = Payload(data)
    type_jeton = p.enum("type", ["email", "telephone"], requis=True)
    code = p.chaine("code", requis=True, min_len=4, max_len=10)
    p.fail_if_errors()

    jeton = (
        db.session.query(VerificationToken)
        .filter(
            VerificationToken.id_user == user.id,
            VerificationToken.type == type_jeton,
            VerificationToken.utilise_le.is_(None),
        )
        .order_by(VerificationToken.id.desc())
        .first()
    )
    if jeton is None:
        raise ValidationFailed("Aucun code en attente.", errors={"code": ["Demandez un nouveau code."]})
    if not jeton.est_valide():
        raise ValidationFailed("Code expiré.", errors={"code": ["Code expiré, demandez-en un nouveau."]})
    if jeton.tentatives >= int(current_app.config.get("OTP_MAX_ATTEMPTS", 5)):
        raise ValidationFailed("Trop de tentatives.", errors={"code": ["Trop de tentatives, demandez un nouveau code."]})

    if not hmac.compare_digest(jeton.jeton_hash, _hmac_otp(user.id, type_jeton, code)):
        jeton.tentatives = (jeton.tentatives or 0) + 1
        db.session.commit()
        raise ValidationFailed("Code incorrect.", errors={"code": ["Code incorrect."]})

    jeton.utilise_le = datetime.now()
    if type_jeton == "email":
        user.email_verifie = 1
    else:
        user.telephone_verifie = 1
    audit_service.audit(
        action="verification_effectuee",
        entite="user",
        entite_id=user.id,
        description=f"Vérification {type_jeton} confirmée",
        apres={"type": type_jeton},
        user_id=user.id,
    )
    db.session.commit()
    return {"type": type_jeton, "verifie": True}


# ------------------------------------------------------------------ réinitialisation


def mot_de_passe_oublie(data: dict[str, Any]) -> dict:
    p = Payload(data)
    email = p.email("email")
    p.fail_if_errors()

    user = db.session.query(User).filter(User.email == email).first()
    # Réponse identique que le compte existe ou non (anti-énumération).
    reponse: dict[str, Any] = {
        "message": "Si ce compte existe, un code de réinitialisation a été envoyé."
    }
    if user is None or user.deleted_at is not None:
        return reponse

    code, _ = _creer_otp(user, "password_reset")
    mailer.envoyer(
        user.email,
        "Réinitialisation de votre mot de passe",
        f"Code de réinitialisation : {code}\n"
        f"Valable {current_app.config['OTP_TTL_MINUTES']} minutes. "
        "Si ce n'est pas vous, ignorez ce message.",
    )
    audit_service.audit(
        action="reset_demande",
        entite="user",
        entite_id=user.id,
        description="Demande de réinitialisation de mot de passe",
        user_id=user.id,
    )
    db.session.commit()
    if not current_app.config.get("MAIL_ENABLED"):
        reponse["code_demo"] = code
    return reponse


def reinitialiser_mdp(data: dict[str, Any]) -> dict:
    p = Payload(data)
    email = p.email("email")
    code = p.chaine("code", requis=True, min_len=4, max_len=10)
    password = p.mot_de_passe("password", min_len=int(current_app.config["PASSWORD_MIN_LENGTH"]))
    p.fail_if_errors()

    manques = _politique_mdp(password or "")
    if manques:
        raise ValidationFailed(
            "Mot de passe trop faible.",
            errors={"password": ["Doit contenir " + ", ".join(manques) + "."]},
        )

    user = db.session.query(User).filter(User.email == email).first()
    if user is None or user.deleted_at is not None:
        raise NotFoundError("Compte introuvable.")

    jeton = (
        db.session.query(VerificationToken)
        .filter(
            VerificationToken.id_user == user.id,
            VerificationToken.type == "password_reset",
            VerificationToken.utilise_le.is_(None),
        )
        .order_by(VerificationToken.id.desc())
        .first()
    )
    if jeton is None or not jeton.est_valide():
        raise ValidationFailed("Code invalide ou expiré.", errors={"code": ["Code invalide ou expiré."]})
    if jeton.tentatives >= int(current_app.config.get("OTP_MAX_ATTEMPTS", 5)):
        raise ValidationFailed("Trop de tentatives.", errors={"code": ["Trop de tentatives."]})
    if not hmac.compare_digest(jeton.jeton_hash, _hmac_otp(user.id, "password_reset", code)):
        jeton.tentatives = (jeton.tentatives or 0) + 1
        db.session.commit()
        raise ValidationFailed("Code incorrect.", errors={"code": ["Code incorrect."]})

    jeton.utilise_le = datetime.now()
    user.password = sec.hash_password(password)
    user.last_password_change = datetime.now()
    audit_service.audit(
        action="reset_mdp",
        entite="user",
        entite_id=user.id,
        description="Mot de passe réinitialisé",
        user_id=user.id,
    )
    db.session.commit()
    return {"message": "Mot de passe réinitialisé avec succès."}


def changer_mdp(user: User, data: dict[str, Any]) -> dict:
    p = Payload(data)
    actuel = p.mot_de_passe("current_password", min_len=1, max_len=128)
    nouveau = p.mot_de_passe("password", min_len=int(current_app.config["PASSWORD_MIN_LENGTH"]))
    p.fail_if_errors()

    if not sec.check_password(user.password, actuel):
        raise ValidationFailed(
            "Mot de passe actuel incorrect.",
            errors={"current_password": ["Mot de passe actuel incorrect."]},
        )
    manques = _politique_mdp(nouveau or "")
    if manques:
        raise ValidationFailed(
            "Mot de passe trop faible.",
            errors={"password": ["Doit contenir " + ", ".join(manques) + "."]},
        )
    if sec.check_password(user.password, nouveau):
        raise ValidationFailed(
            "Identique à l'actuel.",
            errors={"password": ["Le nouveau mot de passe doit être différent de l'actuel."]},
        )

    user.password = sec.hash_password(nouveau)
    user.last_password_change = datetime.now()
    audit_service.audit(
        action="changement_mdp",
        entite="user",
        entite_id=user.id,
        description="Mot de passe modifié",
        user_id=user.id,
    )
    db.session.commit()
    return {"message": "Mot de passe modifié."}
