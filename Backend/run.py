"""Point d'entrée de développement : `python run.py`."""
from __future__ import annotations

import os
import sys

from app import create_app
from app.extensions import socketio

app = create_app(os.getenv("FLASK_ENV", "development"))


def _adresse() -> tuple[str, int]:
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "1200"))
    return host, port


if __name__ == "__main__":
    host, port = _adresse()
    print(f"-> API sécurité sociale v2 sur http://{host}:{port}/api/v1")
    print(f"-> Santé      : http://127.0.0.1:{port}/api/v1/health")
    print(f"-> Connexion  : POST http://127.0.0.1:{port}/api/v1/auth/login")
    print(f"-> Temps réel : ws://{host}:{port}/socket.io/ (auth: JWT)")
    # `socketio.run` est indispensable : c'est lui qui monte le middleware Engine.IO
    # qui sert /socket.io/ (app.run() renverrait un 404 sur ce chemin).
    sys.exit(
        socketio.run(
            app,
            host=host,
            port=port,
            debug=app.config.get("DEBUG", True),
            use_reloader=True,
            allow_unsafe_werkzeug=True,
        )
    )
