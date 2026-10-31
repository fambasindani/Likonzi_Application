"""Configuration de l'application, pilotée par les variables d'environnement (.env)."""
from __future__ import annotations

import os
from datetime import timedelta
from typing import ClassVar

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
PROJECT_DIR = os.path.abspath(os.path.join(BASE_DIR, os.pardir))


def _bool(value: str | None, default: bool = False) -> bool:
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


class Config:
    """Configuration commune."""

    # ------------------------------------------------------------------ Flask
    SECRET_KEY = os.getenv("SECRET_KEY", "changez-moi-en-production")
    DEBUG = False
    TESTING = False

    # ------------------------------------------------------------------ JSON
    JSON_AS_ASCII = False
    JSON_SORT_KEYS = False

    # --------------------------------------------------------------- Base de données
    DB_DRIVER = os.getenv("DB_DRIVER", "pymysql")
    DB_HOST = os.getenv("DB_HOST", "localhost")
    DB_PORT = int(os.getenv("DB_PORT", "3306"))
    DB_USER = os.getenv("DB_USER", "root")
    DB_PASSWORD = os.getenv("DB_PASSWORD", "")
    DB_NAME = os.getenv("DB_NAME", "securite_sociale_v2")
    DB_CHARSET = os.getenv("DB_CHARSET", "utf8mb4")

    SQLALCHEMY_DATABASE_URI = (
        f"mysql+{DB_DRIVER}://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
        f"?charset={DB_CHARSET}"
    )
    SQLALCHEMY_ENGINE_OPTIONS: ClassVar[dict] = {
        "pool_pre_ping": True,
        "pool_recycle": 3600,
        "pool_size": 10,
        "max_overflow": 20,
        "future": True,
    }
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ECHO = _bool(os.getenv("SQL_ECHO"), False)

    # ------------------------------------------------------------------ JWT
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", SECRET_KEY)
    JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
    JWT_ACCESS_TTL = timedelta(minutes=int(os.getenv("JWT_ACCESS_MINUTES", "30")))
    JWT_REFRESH_TTL = timedelta(days=int(os.getenv("JWT_REFRESH_DAYS", "14")))
    JWT_ISSUER = os.getenv("JWT_ISSUER", "securite-sociale-v2")

    # --------------------------------------------------------------- CORS / Sécurité
    CORS_ORIGINS: ClassVar[list[str]] = [
        o.strip()
        for o in os.getenv("CORS_ORIGINS", "*").split(",")
        if o.strip()
    ]
    BCRYPT_LOG_ROUNDS = int(os.getenv("BCRYPT_LOG_ROUNDS", "12"))

    # --------------------------------------------------------------- Fichiers
    # Racine des fichiers téléversés, servie publiquement via /static/uploads/<chemin>
    UPLOAD_FOLDER = os.path.join(PROJECT_DIR, "static", "uploads")
    AVATARS_SUBFOLDER = "avatars"
    PREUVES_SUBFOLDER = "preuves"
    # Limite des images (200 Ko par défaut) — voir .env
    IMAGE_MAX_OCTETS = int(os.getenv("IMAGE_MAX_OCTETS", str(200 * 1024)))
    MAX_CONTENT_LENGTH = int(os.getenv("MAX_CONTENT_LENGTH", str(15 * 1024 * 1024)))
    ALLOWED_AVATAR_EXT: ClassVar[set[str]] = {"png", "jpg", "jpeg", "gif", "webp"}

    # --------------------------------------------------------------- Validation
    PASSWORD_MIN_LENGTH = int(os.getenv("PASSWORD_MIN_LENGTH", "8"))
    OTP_TTL_MINUTES = int(os.getenv("OTP_TTL_MINUTES", "15"))
    OTP_MAX_ATTEMPTS = int(os.getenv("OTP_MAX_ATTEMPTS", "5"))

    # --------------------------------------------------------------- Limitation de débit
    RATE_LIMIT_ENABLED = _bool(os.getenv("RATE_LIMIT_ENABLED"), True)
    RATE_LIMIT_MAX = int(os.getenv("RATE_LIMIT_MAX", "20"))
    RATE_LIMIT_WINDOW_SEC = int(os.getenv("RATE_LIMIT_WINDOW_SEC", "300"))
    # Clés : <NOM>_MAX / <NOM>_WINDOW_SEC — consommées par `ratelimit.tenter(nom)`
    LOGIN_MAX = int(os.getenv("LOGIN_MAX", "10"))
    LOGIN_WINDOW_SEC = int(os.getenv("LOGIN_WINDOW_SEC", "300"))
    INSCRIPTION_MAX = int(os.getenv("INSCRIPTION_MAX", "10"))
    INSCRIPTION_WINDOW_SEC = int(os.getenv("INSCRIPTION_WINDOW_SEC", "3600"))
    RESET_MAX = int(os.getenv("RESET_MAX", "5"))
    RESET_WINDOW_SEC = int(os.getenv("RESET_WINDOW_SEC", "300"))
    VERIFICATION_MAX = int(os.getenv("VERIFICATION_MAX", "10"))
    VERIFICATION_WINDOW_SEC = int(os.getenv("VERIFICATION_WINDOW_SEC", "300"))

    # --------------------------------------------------------------- Temps réel
    SOCKETIO_CORS_ORIGINS = os.getenv("SOCKETIO_CORS_ORIGINS", "*")

    # --------------------------------------------------------------- Mail
    MAIL_ENABLED = _bool(os.getenv("MAIL_ENABLED"), False)
    MAIL_SERVER = os.getenv("MAIL_SERVER", "smtp.gmail.com")
    MAIL_PORT = int(os.getenv("MAIL_PORT", "587"))
    MAIL_USE_TLS = _bool(os.getenv("MAIL_USE_TLS"), True)
    MAIL_USERNAME = os.getenv("MAIL_USERNAME", "")
    MAIL_PASSWORD = os.getenv("MAIL_PASSWORD", "")
    MAIL_FROM = os.getenv("MAIL_FROM", "no-reply@securite.cd")

    # --------------------------------------------------------------- Compte bootstrap
    ADMIN_EMAIL = os.getenv("ADMIN_EMAIL", "admin@securite.cd")


class DevelopmentConfig(Config):
    DEBUG = True


class TestingConfig(Config):
    TESTING = True
    SQLALCHEMY_DATABASE_URI = os.getenv(
        "TEST_DATABASE_URI",
        "sqlite:///" + os.path.join(PROJECT_DIR, "test.db"),
    )
    WTF_CSRF_ENABLED = False
    BCRYPT_LOG_ROUNDS = 4


class ProductionConfig(Config):
    DEBUG = False


CONFIGS = {
    "development": DevelopmentConfig,
    "testing": TestingConfig,
    "production": ProductionConfig,
}


def get_config(name: str | None = None) -> type[Config]:
    name = (name or os.getenv("FLASK_ENV", "development")).lower()
    return CONFIGS.get(name, DevelopmentConfig)
