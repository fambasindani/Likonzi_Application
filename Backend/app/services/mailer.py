"""Envoi d'e-mails : SMTP si configuré, sinon journalisation (mode développement)."""
from __future__ import annotations

import logging
import smtplib
from email.mime.text import MIMEText

from flask import current_app, has_app_context

logger = logging.getLogger("securite.mail")


def envoyer(to: str, sujet: str, corps: str) -> bool:
    """Renvoie `True` si le message a réellement été remis au transporteur."""
    if not (has_app_context() and current_app.config.get("MAIL_ENABLED")):
        logger.info(
            "[MAIL désactivé] À %s — %s\n%s", to, sujet, corps
        )
        return False

    cfg = current_app.config
    msg = MIMEText(corps, "plain", "utf-8")
    msg["Subject"] = sujet
    msg["From"] = cfg.get("MAIL_FROM")
    msg["To"] = to

    try:
        with smtplib.SMTP(cfg["MAIL_SERVER"], cfg["MAIL_PORT"], timeout=15) as server:
            if cfg.get("MAIL_USE_TLS"):
                server.starttls()
            username = cfg.get("MAIL_USERNAME")
            if username:
                server.login(username, cfg.get("MAIL_PASSWORD", ""))
            server.sendmail(cfg["MAIL_FROM"], [to], msg.as_string())
        return True
    except Exception as exc:
        logger.error("Échec d'envoi mail vers %s : %s", to, exc)
        return False
