"""Tests du temps réel (Socket.IO) et de la limitation de débit.

Lancement depuis le dossier `Backend/` :
    .venv\\Scripts\\python.exe tests\\test_temps_reel.py
"""
from __future__ import annotations

import os
import secrets
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir)))

from app import create_app
from app.extensions import socketio
from app.utils import ratelimit

app = create_app("development")
C = app.test_client()

RESULTATS: list[tuple[bool, str]] = []


def check(label: str, cond: bool, extra: str = "") -> None:
    RESULTATS.append((bool(cond), label + (f" — {extra}" if extra else "")))


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


def data_of(resp) -> dict:
    return json_of(resp).get("data") or {}


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def noms(recus: list[dict]) -> list[str]:
    return [e.get("name") for e in recus]


P = "/api/v1"
suffix = secrets.token_hex(4)

# ================================================================== mise en place

r = C.post(f"{P}/auth/login", json={"email": "admin@securite.cd", "password": "12345678"})
T_ADMIN = data_of(r).get("access_token")
check("admin connecté", bool(T_ADMIN))

r = C.get(f"{P}/commissariats", headers=auth(T_ADMIN))
kin1 = next((c for c in data_of(r) if c["code"] == "COM-KIN-001"), None)
KIN1 = kin1["id"] if kin1 else 1
LAT, LON = (kin1 or {}).get("latitude", -4.325), (kin1 or {}).get("longitude", 15.31)

r = C.post(
    f"{P}/users",
    headers=auth(T_ADMIN),
    json={
        "nom": "TEMPSREEL",
        "prenom": "Policier",
        "email": f"rt.{suffix}@test.cd",
        "telephone": f"+2437{secrets.randbelow(10**8):08d}",
        "password": "Motdepasse2026",
        "roles": ["policier"],
        "id_commissariat": KIN1,
    },
)
pol = data_of(r)
T_POL = pol.get("access_token")
ID_POL = (pol.get("user") or {}).get("id")
check("policier créé", bool(T_POL))

r = C.post(
    f"{P}/auth/register",
    json={
        "nom": "TEMPSREEL",
        "prenom": "Citoyen",
        "email": f"rt.citoyen.{suffix}@test.cd",
        "telephone": f"+2436{secrets.randbelow(10**8):08d}",
        "password": "Citoyen2026",
    },
)
citoyen = data_of(r)
T_CIT = citoyen.get("access_token")
ID_CIT = (citoyen.get("user") or {}).get("id")
check("citoyen créé", bool(T_CIT))

# ======================================================== TEMPS RÉEL : CONNEXION

c_sans = socketio.test_client(app)
check("connexion Socket.IO sans jeton refusée", not c_sans.is_connected())

c_faux = socketio.test_client(app, auth={"token": "n.importe.quoi"})
check("connexion Socket.IO avec jeton invalide refusée", not c_faux.is_connected())

c_pol = socketio.test_client(app, auth={"token": T_POL})
check("connexion Socket.IO du policier acceptée", c_pol.is_connected())

c_cit = socketio.test_client(app, auth={"token": T_CIT})
check("connexion Socket.IO du citoyen acceptée", c_cit.is_connected())

# Vider les files d'attente éventuelles des connexions
c_pol.get_received()
c_cit.get_received()

# ================================================ TEMPS RÉEL : NOTIFICATIONS MÉTIER

r = C.post(
    f"{P}/alertes",
    headers=auth(T_CIT),
    json={
        "id_type_alerte": 1,
        "contenu": "Test temps réel : moto suspecte devant chez moi.",
        "niveau_urgence": "critique",
        "latitude": LAT,
        "longitude": LON,
    },
)
alerte = data_of(r)
AL = alerte.get("id")
check("alerte créée", r.status_code == 201, str(r.status_code))

recus_pol = noms(c_pol.get_received())
recus_cit = noms(c_cit.get_received())
check("le policier reçoit alerte_nouvelle en direct", "alerte_nouvelle" in recus_pol,
      str(recus_pol))
check("le citoyen n'est pas dans la salle du commissariat",
      "alerte_nouvelle" not in recus_cit, str(recus_cit))

r = C.post(f"{P}/alertes/{AL}/prendre-en-charge", headers=auth(T_POL))
check("prise en charge -> 200", r.status_code == 200, str(r.status_code) + str(json_of(r)))

recus_cit = c_cit.get_received()
noms_cit = noms(recus_cit)
check("le citoyen reçoit alerte_assignee en direct", "alerte_assignee" in noms_cit,
      str(noms_cit))
check("le citoyen reçoit aussi la notification persistée", "notification" in noms_cit,
      str(noms_cit))
notif = next((e for e in recus_cit if e.get("name") == "notification"), None)
check("le contenu de la notification est exploitable",
      bool(notif) and (notif.get("args") or [{}])[0].get("type") == "alerte_assignee",
      str(notif))

recus_pol = noms(c_pol.get_received())
check("le policier voit aussi l'événement d'assignation", "alerte_assignee" in recus_pol,
      str(recus_pol))

r = C.patch(f"{P}/alertes/{AL}/statut", headers=auth(T_POL),
            json={"statut": "en_cours", "observation": "Patrouille lancée."})
check("changement de statut -> 200", r.status_code == 200, str(r.status_code))
recus_cit = noms(c_cit.get_received())
check("le citoyen reçoit alerte_mise_a_jour", "alerte_mise_a_jour" in recus_cit,
      str(recus_cit))

# Émission ciblée : un client hors salle ne reçoit rien
c_autre = socketio.test_client(app, auth={"token": T_ADMIN})
c_autre.get_received()
with app.test_request_context("/"):
    from app.realtime import notifier_commissariat

    notifier_commissariat(KIN1, "test_cible", message="uniquement la police")
check("l'admin (sans commissariat) ne reçoit pas l'événement du commissariat",
      "test_cible" not in noms(c_autre.get_received()))
check("le policier reçoit l'événement ciblé",
      "test_cible" in noms(c_pol.get_received()))

c_autre.disconnect()
c_pol.disconnect()
c_cit.disconnect()

# ================================================================= RATE LIMITING

ratelimit.purger()
app.config["RATE_LIMIT_ENABLED"] = False

codes_sans_limite = []
for _ in range(12):
    rr = C.post(f"{P}/auth/login",
                json={"email": f"sanslimite.{suffix}@test.cd", "password": "Mauvais123"})
    codes_sans_limite.append(rr.status_code)
check("limite désactivée : aucune 422/429 sur 12 échecs",
      codes_sans_limite == [401] * 12, str(codes_sans_limite))

app.config["RATE_LIMIT_ENABLED"] = True
ratelimit.purger()

email_cible = f"bruteforce.{suffix}@test.cd"
codes = []
dernier = None
for _ in range(1, 12):
    dernier = C.post(f"{P}/auth/login", json={"email": email_cible, "password": "Mauvais123"})
    codes.append(dernier.status_code)

check("les 10 premières tentatives restent des 401", codes[:10] == [401] * 10,
      str(codes[:10]))
check("la 11e tentative est bloquée en 429", codes[10] == 429, str(codes[10]))
check("la 429 porte le code rate_limited",
      json_of(dernier).get("code") == "rate_limited", str(json_of(dernier)))
retry_after = dernier.headers.get("Retry-After")
check("en-tête Retry-After présent et numérique",
      bool(retry_after) and str(retry_after).isdigit(), str(retry_after))

r = C.post(f"{P}/auth/login", json={"email": "admin@securite.cd", "password": "12345678"})
check("la limite est par compte : l'admin se connecte toujours",
      r.status_code == 200, str(r.status_code))

ratelimit.purger()
r = C.post(f"{P}/auth/login", json={"email": email_cible, "password": "Mauvais123"})
check("après purge du compteur, on reçoit de nouveau un 401",
      r.status_code == 401, str(r.status_code))

# Limite d'inscription (par IP)
app.config["INSCRIPTION_MAX"] = 3
ratelimit.reinitialiser("inscription")  # repart d'un compteur vierge
codes_inscription = []
for i in range(4):
    rr = C.post(
        f"{P}/auth/register",
        json={
            "nom": "LIMITE",
            "email": f"limite{i}.{suffix}@test.cd",
            "telephone": f"+2435{secrets.randbelow(10**8):08d}",
            "password": "Citoyen2026",
        },
    )
    codes_inscription.append(rr.status_code)
check("inscription : 3 créations acceptées puis 429",
      codes_inscription == [201, 201, 201, 429], str(codes_inscription))
app.config["INSCRIPTION_MAX"] = 10

# ======================================================================= BILAN

_bilan()
sys.exit(0 if sum(1 for c, _ in RESULTATS if c) == len(RESULTATS) else 1)
