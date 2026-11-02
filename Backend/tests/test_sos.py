"""Tests SOS « minute de grâce » : déclenchement, minuteur serveur, diffusion aux amis.

Lancement depuis le dossier `Backend/` :
    .venv\\Scripts\\python.exe tests\\test_sos.py
"""
from __future__ import annotations

import os
import secrets
import sys
from datetime import datetime, timedelta

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir)))

from app import create_app

app = create_app("development")
C = app.test_client()

RESULTATS: list[tuple[bool, str]] = []


def check(label: str, cond: bool, extra: str = "") -> None:
    texte = label + (f" — {extra}" if extra else "")
    # Console Windows en cp1252 : on remplace les caractères non imprimables (emoji…).
    RESULTATS.append((bool(cond), texte.encode("cp1252", "replace").decode("cp1252")))


def _bilan() -> None:
    reussis = sum(1 for c, _ in RESULTATS if c)
    for c, label in RESULTATS:
        print(("  OK   " if c else "  ECHEC") + " | " + label)
    print(f"\n{reussis}/{len(RESULTATS)} vérifications réussies")


def _hook(exc_type, exc, tb):
    import traceback

    _bilan()
    print("--- arrêt brutal ---")
    traceback.print_exception(exc_type, exc, tb)


sys.excepthook = _hook


def json_of(resp):
    try:
        return resp.get_json() or {}
    except Exception:
        return {}


def data_of(resp) -> dict | list:
    return json_of(resp).get("data") or {}


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


P = "/api/v1"
suffix = secrets.token_hex(4)


def inscrire(tag: str) -> dict:
    body = {
        "nom": tag.upper(),
        "prenom": "Test",
        "email": f"{tag}.{suffix}@test.cd",
        "telephone": f"+2438{secrets.randbelow(10**8):08d}",
        "password": "Citoyen2026",
    }
    resp = C.post(f"{P}/auth/register", json=body)
    if resp.status_code != 201:
        raise SystemExit(f"Echec inscription {tag}: {resp.status_code} {resp.get_json()}")
    return data_of(resp)


def maj_echeance(sos_id: int, quand: datetime) -> None:
    """Repositionne l'échéance en base (simule l'écoulement du temps)."""
    from sqlalchemy import text

    from app.extensions import db

    with app.app_context():
        db.session.execute(
            text("UPDATE sos SET echeance = :q WHERE id = :i"),
            {"q": quand, "i": sos_id},
        )
        db.session.commit()


def traiter() -> int:
    """Exécute un passage de la veille SOS."""
    from app.services import sos_service

    with app.app_context():
        return sos_service.traiter()


def messages_de(token: str, autre_id: int) -> str:
    return str(json_of(C.get(f"{P}/messages/{autre_id}", headers=auth(token))))


# ===================================================================== mise en place

r = C.post(f"{P}/auth/login", json={"email": "admin@securite.cd", "password": "12345678"})
T_ADMIN = data_of(r).get("access_token")
check("admin connecté", bool(T_ADMIN))

r = C.get(f"{P}/commissariats", headers=auth(T_ADMIN))
comms = data_of(r) or []
kin = next((c for c in comms if c.get("latitude") is not None), None)
check("commissariat de référence trouvé", kin is not None, str(len(comms)))
LAT = (kin or {}).get("latitude", -4.325)
LON = (kin or {}).get("longitude", 15.31)

A = inscrire("alice")  # victime
B = inscrire("bob")  # ami prévenu
T_A, T_B = A["access_token"], B["access_token"]
ID_A, ID_B = A["user"]["id"], B["user"]["id"]

r = C.post(f"{P}/demandes", headers=auth(T_A), json={"id_destinataire": ID_B})
d1 = data_of(r)
r = C.post(
    f"{P}/demandes/{d1['id']}/repondre", headers=auth(T_B), json={"statut": "acceptee"}
)
amis = data_of(C.get(f"{P}/amis", headers=auth(T_A))) or []
check("A et B sont amis", len(amis) == 1, str(len(amis)))

# ===================================================================== état initial

r = C.get(f"{P}/sos")
check("GET /sos sans jeton -> 401", r.status_code == 401, str(r.status_code))

r = C.get(f"{P}/sos", headers=auth(T_A))
check("aucun SOS actif au démarrage", data_of(r).get("actif") is False, str(json_of(r)))

# ===================================================================== validation

r = C.post(f"{P}/sos", headers=auth(T_A), json={"duree_minutes": 3})
check("durée < 5 min -> 422", r.status_code == 422, str(r.status_code))
r = C.post(f"{P}/sos", headers=auth(T_A), json={"latitude": 999})
check("latitude hors bornes -> 422", r.status_code == 422, str(r.status_code))

# ===================================================================== déclenchement

r = C.post(
    f"{P}/sos",
    headers=auth(T_A),
    json={"duree_minutes": 5, "latitude": LAT, "longitude": LON},
)
prog = data_of(r)
SOS1 = prog["sos"]["id"]
check("SOS programmé -> 201", r.status_code == 201, str(r.status_code) + str(json_of(r))[:200])
check("statut initial = programme", prog["sos"]["statut"] == "programme", str(prog["sos"]["statut"]))
echeance = datetime.fromisoformat(prog["sos"]["echeance"])
check("echeance ~ maintenant + 5 min", abs((echeance - datetime.now()).total_seconds() - 300) < 60,
      str(echeance))

r = C.post(f"{P}/sos", headers=auth(T_A), json={})
check("second SOS alors qu'un est en cours -> 409", r.status_code == 409, str(r.status_code))

r = C.get(f"{P}/sos", headers=auth(T_A))
check("état actif renvoyé au client", data_of(r).get("actif") is True, str(json_of(r))[:200])

# ===================================================================== annulation

r = C.post(f"{P}/sos/annuler", headers=auth(T_A))
check("annulation -> 200", r.status_code == 200, str(r.status_code))
check("statut = annule", data_of(r)["sos"]["statut"] == "annule", str(data_of(r)["sos"]["statut"]))

r = C.get(f"{P}/sos", headers=auth(T_A))
check("plus aucun SOS actif après annulation", data_of(r).get("actif") is False, str(json_of(r))[:120])
msgs_ann = json_of(C.get(f"{P}/messages/{ID_A}", headers=auth(T_B))).get("data") or []
check("annulation : aucun message envoyé à B", msgs_ann == [], str(msgs_ann)[:200])

# ===================================================================== minuteur serveur

r = C.post(
    f"{P}/sos",
    headers=auth(T_A),
    json={"duree_minutes": 10, "latitude": LAT, "longitude": LON},
)
SOS2 = data_of(r)["sos"]["id"]
check("second SOS (10 min) -> 201", r.status_code == 201, str(r.status_code))

# 1) Il reste moins de 5 min : message intermédiaire.
maj_echeance(SOS2, datetime.now() + timedelta(minutes=4))
n = traiter()
check("veille : passage intermédiaire effectué", n >= 1, str(n))
r = C.get(f"{P}/sos", headers=auth(T_A))
check("statut = intermediaire", data_of(r)["sos"]["statut"] == "intermediaire",
      str(data_of(r)["sos"]["statut"]))
brut_b = messages_de(T_B, ID_A)
check("B reçoit l'alerte intermédiaire", "SOS" in brut_b and "danger" in brut_b.lower(),
      brut_b[:220])

# 2) Échéance dépassée : SOS complet + alerte police.
maj_echeance(SOS2, datetime.now() - timedelta(seconds=5))
n = traiter()
check("veille : échéance traitée", n >= 1, str(n))
r = C.get(f"{P}/sos", headers=auth(T_A))
sos = data_of(r)["sos"]
check("statut = envoye", sos["statut"] == "envoye", str(sos["statut"]))
check("alerte police créée (id_alerte)", bool(sos.get("id_alerte")), str(sos.get("id_alerte")))
brut_b = messages_de(T_B, ID_A)
check("B reçoit le SOS complet", "URGENT" in brut_b, brut_b[:220])
r = C.get(f"{P}/notifications", headers=auth(T_B))
check("B reçoit une notification SOS", "SOS" in str(json_of(r)), str(json_of(r))[:220])
msgs_b = data_of(C.get(f"{P}/messages/{ID_A}", headers=auth(T_B))) or []
check("B a exactement 2 messages SOS (intermédiaire + complet)", len(msgs_b) == 2, str(len(msgs_b)))

# ===================================================================== clôture

r = C.post(f"{P}/sos/cloturer", headers=auth(T_A))
check("clôture -> 200", r.status_code == 200, str(r.status_code) + str(json_of(r))[:160])
check("statut = cloture", data_of(r)["sos"]["statut"] == "cloture", str(data_of(r)["sos"]["statut"]))
brut_b = messages_de(T_B, ID_A)
check("B reçoit le rétablissement", "levé" in brut_b, brut_b[-220:])
r = C.get(f"{P}/sos", headers=auth(T_A))
check("aucun SOS actif après clôture", data_of(r).get("actif") is False, str(json_of(r))[:120])

r = C.post(f"{P}/sos/annuler", headers=auth(T_A))
check("annuler sans SOS actif -> 404", r.status_code == 404, str(r.status_code))
r = C.post(f"{P}/sos/cloturer", headers=auth(T_A))
check("clôturer sans SOS actif -> 404", r.status_code == 404, str(r.status_code))

# ===================================================================== envoi immédiat

r = C.post(f"{P}/sos", headers=auth(T_A), json={"duree_minutes": 15})
SOS3 = data_of(r)["sos"]["id"]
check("troisième SOS -> 201", r.status_code == 201, str(r.status_code))
r = C.post(f"{P}/sos/envoyer", headers=auth(T_A))
check("envoi immédiat -> 200", r.status_code == 200, str(r.status_code) + str(json_of(r))[:160])
check("statut = envoye sans attendre l'échéance", data_of(r)["sos"]["statut"] == "envoye",
      str(data_of(r)["sos"]["statut"]))
check("envoye_at renseigné", bool(data_of(r)["sos"].get("envoye_at")),
      str(data_of(r)["sos"].get("envoye_at")))
brut_b = messages_de(T_B, ID_A)
check("B reçoit le SOS immédiat", "URGENT" in brut_b, brut_b[:160])

# Le SOS envoyé ne bloque pas un nouveau déclenchement.
r = C.post(f"{P}/sos", headers=auth(T_A), json={"duree_minutes": 5})
check("nouveau SOS possible après envoi -> 201", r.status_code == 201, str(r.status_code))
r = C.post(f"{P}/sos/annuler", headers=auth(T_A))
check("nettoyage : dernier SOS annulé", r.status_code == 200, str(r.status_code))

# ===================================================================== permissions

r = C.post(f"{P}/sos", headers=auth(T_A), json={})
r2 = C.post(f"{P}/sos/annuler", headers={"Authorization": "Bearer faux"})
check("action protégée sans jeton -> 401", r2.status_code == 401, str(r2.status_code))

# ============================================================================= BILAN

reussis = sum(1 for c, _ in RESULTATS if c)
_bilan()
sys.exit(0 if reussis == len(RESULTATS) else 1)
