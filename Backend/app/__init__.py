"""Factory d'application Flask — `create_app()`."""
from __future__ import annotations

import logging
import os
import sys

from dotenv import load_dotenv

# Les variables d'environnement doivent être lues AVANT l'import de `config`
# (celui-ci fige les valeurs dans la classe `Config`).
_BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))
load_dotenv(os.path.join(_BASE_DIR, ".env"))

import click  # noqa: E402
from flask import Flask, jsonify, send_from_directory  # noqa: E402

from .config import get_config  # noqa: E402
from .extensions import db  # noqa: E402
from .extensions import init_app as init_extensions  # noqa: E402


def _configure_logging(app) -> None:
    niveau = logging.DEBUG if app.debug else logging.INFO
    logging.basicConfig(
        stream=sys.stdout,
        level=niveau,
        format="%(asctime)s %(levelname)-7s %(name)s — %(message)s",
        datefmt="%H:%M:%S",
    )
    logging.getLogger("sqlalchemy.engine").setLevel(
        logging.INFO if app.config.get("SQL_ECHO") else logging.WARNING
    )


def create_app(config_name: str | None = None) -> Flask:
    app = Flask(
        __name__,
        static_folder=os.path.join(_BASE_DIR, "static"),
        static_url_path="/static",
    )
    app.config.from_object(get_config(config_name))

    _configure_logging(app)
    init_extensions(app)

    from .api import register_blueprints
    from .api.errors import register_error_handlers

    register_blueprints(app)
    register_error_handlers(app)
    _register_cli(app)

    # Temps réel : authentification JWT à la connexion, salles utilisateur/commissariat.
    from .realtime import enregistrer_handlers

    enregistrer_handlers(app)

    # Veille SOS : le compte à rebours vit côté serveur (démarrage ignoré en tests).
    from .services.sos_service import demarrer_veille

    demarrer_veille(app)

    # Images historiques servies à l'emplacement attendu par l'application mobile.
    @app.get("/api/static/<path:filename>")
    def _static_legacy(filename: str):
        return send_from_directory(app.static_folder, filename)

    @app.get("/")
    def _racine():
        return jsonify(
            {
                "success": True,
                "message": "API sécurité sociale v2",
                "version": "2.1.0",
                "base": "/api/v1",
                "health": "/api/v1/health",
            }
        )

    return app


# --------------------------------------------------------------------------- CLI


def _register_cli(app) -> None:
    @app.cli.command("init-db")
    def init_db() -> None:
        """Crée les tables manquantes à partir des modèles (filet de sécurité).

        Le schéma canonique reste `securite_sociale_v2.sql`.
        """
        from . import models  # noqa: F401 - configure les mappers

        db.create_all()
        print("Tables créées/vérifiées via db.create_all().")

    @app.cli.command("check-db")
    def check_db() -> None:
        """Vérifie la connexion et la présence des tables du schéma v2."""
        resultat = db.session.execute(
            db.text(
                "SELECT COUNT(*) FROM information_schema.tables "
                "WHERE table_schema = DATABASE()"
            )
        ).scalar()
        print(f"Base « {db.engine.url.database} » : {resultat} table(s).")
        if not resultat:
            print("-> Schéma absent : lancez `mysql -u root < securite_sociale_v2.sql`.")
        db.session.commit()

    @app.cli.command("create-admin")
    @click.option("--email", required=True, help="Adresse e-mail du compte.")
    @click.option("--password", required=True, help="Mot de passe.")
    @click.option("--nom", default="ADMIN", show_default=True, help="Nom affiché.")
    def create_admin(email: str, password: str, nom: str) -> None:
        """Crée (ou réinitialise) un compte super administrateur."""
        from .models import Role, User
        from .services.auth_service import _charger_roles, _politique_mdp  # type: ignore
        from .utils import security as sec

        manques = _politique_mdp(password)
        if manques:
            print(f"Mot de passe refusé, il doit contenir : {', '.join(manques)}.")
            return

        user = db.session.query(User).filter(User.email == email).first()
        if user is None:
            user = User(
                nom=nom,
                email=email,
                telephone=f"+2438{abs(hash(email)) % 10**8:08d}",
                password=sec.hash_password(password),
                statut="actif",
                email_verifie=1,
                telephone_verifie=1,
            )
            user.roles = _charger_roles(["super_admin"])
            db.session.add(user)
            action = "créé"
        else:
            user.password = sec.hash_password(password)
            action = "mis à jour"
            if not user.has_role("super_admin"):
                super_admin = db.session.query(Role).filter(Role.nom == "super_admin").first()
                if super_admin and super_admin not in user.roles:
                    user.roles.append(super_admin)
        db.session.commit()
        print(f"Compte super_admin {email} {action} (id={user.id}).")
