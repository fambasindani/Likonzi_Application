"""Extensions Flask partagées : initialisées ici, branchées dans le factory `create_app`."""
from __future__ import annotations

from flask_bcrypt import Bcrypt
from flask_cors import CORS
from flask_socketio import SocketIO
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()
bcrypt = Bcrypt()
cors = CORS()

# `threading` + `simple-websocket` : aucun broker requis pour une instance unique.
socketio = SocketIO(async_mode="threading", logger=False, engineio_logger=False)


def init_app(app) -> None:
    """Attache toutes les extensions à l'application."""
    db.init_app(app)
    bcrypt.init_app(app)
    cors.init_app(
        app,
        resources={r"/api/*": {"origins": app.config.get("CORS_ORIGINS", "*")}},
        supports_credentials=False,
    )
    socketio.init_app(
        app,
        cors_allowed_origins=app.config.get("SOCKETIO_CORS_ORIGINS", "*"),
        async_mode="threading",
    )
