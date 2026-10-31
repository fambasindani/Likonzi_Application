"""Enregistrement des blueprints de l'API v1."""
from __future__ import annotations

API_PREFIX = "/api/v1"


def register_blueprints(app) -> None:
    from .alertes import alertes_bp
    from .auth import auth_bp
    from .cas import cas_bp, interventions_bp
    from .geo import geo_bp
    from .meta import meta_bp
    from .objets import objets_bp
    from .partages import partages_bp
    from .preuves import preuves_bp
    from .social import social_bp
    from .users import users_bp

    app.register_blueprint(auth_bp, url_prefix=f"{API_PREFIX}/auth")
    app.register_blueprint(users_bp, url_prefix=f"{API_PREFIX}/users")

    # Domaine métier
    app.register_blueprint(alertes_bp, url_prefix=f"{API_PREFIX}/alertes")
    app.register_blueprint(cas_bp, url_prefix=f"{API_PREFIX}/cas")
    app.register_blueprint(interventions_bp, url_prefix=f"{API_PREFIX}/interventions")
    app.register_blueprint(objets_bp, url_prefix=f"{API_PREFIX}/objets")
    app.register_blueprint(partages_bp, url_prefix=f"{API_PREFIX}/partages")
    app.register_blueprint(preuves_bp, url_prefix=f"{API_PREFIX}/preuves")

    # Transversal
    app.register_blueprint(geo_bp, url_prefix=API_PREFIX)
    app.register_blueprint(social_bp, url_prefix=API_PREFIX)

    # Référentiels / santé / audit
    app.register_blueprint(meta_bp, url_prefix=API_PREFIX)
