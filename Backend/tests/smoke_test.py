"""Tests de bout en bout de l'API v2 (client de test Flask, sans serveur).

Lancement depuis le dossier `Backend/` :
    .venv\\Scripts\\python.exe tests\\smoke_test.py
"""
from __future__ import annotations

import io
import os
import secrets
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir)))

from app import create_app

app = create_app("development")
C = app.test_client()

RESULTATS: list[tuple[bool, str]] = []


def check(label: str, cond: bool, extra: str = "") -> None:
    RESULTATS.append((bool(cond), label + (f" — {extra}" if extra else "")))


def json_of(resp):
    try:
        return resp.get_json() or {}
    except Exception:
        return {}


PREFIX = "/api/v1"
suffix = secrets.token_hex(4)

# ------------------------------------------------------------------ 1. santé
r = C.get(f"{PREFIX}/health")
j = json_of(r)
check("GET /health -> 200", r.status_code == 200, str(r.status_code))
check("GET /health base up", j.get("data", {}).get("base_de_donnees") == "up",
      str(j.get("data")))

# ------------------------------------------------------------------ 2. connexion admin
r = C.post(f"{PREFIX}/auth/login", json={"email": "admin@securite.cd", "password": "12345678"})
j = json_of(r)
check("POST /auth/login admin -> 200", r.status_code == 200, str(r.status_code))
ADMIN_TOKEN = j.get("data", {}).get("access_token")
ADMIN_REFRESH = j.get("data", {}).get("refresh_token")
check("login renvoie access_token", bool(ADMIN_TOKEN))
check("login renvoie user avec roles", "super_admin" in (j.get("data", {}).get("user", {}) or {}).get("roles", []),
      str((j.get("data", {}).get("user") or {}).get("roles")))

# ------------------------------------------------------------------ 3. mauvais mot de passe
r = C.post(f"{PREFIX}/auth/login", json={"email": "admin@securite.cd", "password": "mauvais"})
j = json_of(r)
check("login mauvais mdp -> 401", r.status_code == 401, str(r.status_code))
check("login mauvais mdp = JSON success false", j.get("success") is False and j.get("code") == "unauthorized",
      str(j))

# ------------------------------------------------------------------ 4. /auth/me
r = C.get(f"{PREFIX}/auth/me", headers={"Authorization": f"Bearer {ADMIN_TOKEN}"})
j = json_of(r)
check("GET /auth/me -> 200", r.status_code == 200, str(r.status_code))
check("/auth/me expose les permissions", len(j.get("data", {}).get("permissions", [])) >= 30,
      str(len(j.get("data", {}).get("permissions", []))))

# ------------------------------------------------------------------ 5. /auth/me sans jeton
r = C.get(f"{PREFIX}/auth/me")
j = json_of(r)
check("GET /auth/me sans jeton -> 401", r.status_code == 401, str(r.status_code))

# ------------------------------------------------------------------ 6. inscription citoyen
email_cit = f"citoyen.{suffix}@test.cd"
tel_cit = f"+2438{secrets.randbelow(10**8):08d}"
r = C.post(
    f"{PREFIX}/auth/register",
    json={
        "nom": "KABILA",
        "postnom": "MWAMBA",
        "prenom": "Jean",
        "email": email_cit,
        "telephone": tel_cit,
        "password": "Citoyen2026",
        "genre": "M",
        "adresse": "Av. de la Paix, Kinshasa",
        "date_naissance": "1995-04-12",
    },
)
j = json_of(r)
check("POST /auth/register citoyen -> 201", r.status_code == 201, str(r.status_code) + " " + str(j))
CITOYEN_TOKEN = j.get("data", {}).get("access_token")
CITOYEN_ID = (j.get("data", {}).get("user") or {}).get("id")
check("inscription renvoie un jeton", bool(CITOYEN_TOKEN))
check("citoyen a bien le rôle citoyen",
      (j.get("data", {}).get("user") or {}).get("roles") == ["citoyen"],
      str((j.get("data", {}).get("user") or {}).get("roles")))

# ------------------------------------------------------------------ 7. e-mail déjà pris
r = C.post(
    f"{PREFIX}/auth/register",
    json={
        "nom": "TEST",
        "email": email_cit,
        "telephone": f"+2438{secrets.randbelow(10**8):08d}",
        "password": "Citoyen2026",
    },
)
j = json_of(r)
check("inscription e-mail en double -> 409", r.status_code == 409, str(r.status_code))
check("409 détaille le champ", "email" in (j.get("errors") or {}), str(j.get("errors")))

# ------------------------------------------------------------------ 8. rôle interdit à l'inscription
r = C.post(
    f"{PREFIX}/auth/register",
    json={
        "nom": "MALIN",
        "email": f"malin.{suffix}@test.cd",
        "telephone": f"+2438{secrets.randbelow(10**8):08d}",
        "password": "Citoyen2026",
        "roles": ["super_admin"],
    },
)
j = json_of(r)
check("inscription avec rôle super_admin -> 422", r.status_code == 422, str(r.status_code))
check("422 nomme le rôle interdit", "roles" in (j.get("errors") or {}), str(j.get("errors")))

# ------------------------------------------------------------------ 9. validation multiple
r = C.post(
    f"{PREFIX}/auth/register",
    json={"nom": "", "email": "pas-un-mail", "telephone": "zz", "password": "court"},
)
j = json_of(r)
check("validation multiple -> 422", r.status_code == 422, str(r.status_code))
errs = j.get("errors") or {}
check("422 cumule les erreurs de champs",
      {"nom", "email", "telephone", "password"} <= set(errs), str(sorted(errs)))

# ------------------------------------------------------- 10. RBAC : citoyen vs /users
r = C.get(f"{PREFIX}/users", headers={"Authorization": f"Bearer {CITOYEN_TOKEN}"})
j = json_of(r)
check("citoyen -> GET /users = 403", r.status_code == 403, str(r.status_code))

r = C.get(f"{PREFIX}/users", headers={"Authorization": f"Bearer {ADMIN_TOKEN}"})
j = json_of(r)
check("admin -> GET /users = 200", r.status_code == 200, str(r.status_code))
check("GET /users paginé", j.get("meta", {}).get("total", 0) >= 2, str(j.get("meta")))
check("GET /users ne expose pas le hash", "password" not in str(j.get("data"))[:200])

r = C.get(f"{PREFIX}/users?role=policier", headers={"Authorization": f"Bearer {ADMIN_TOKEN}"})
check("filtre role= policier -> 200", r.status_code == 200, str(r.status_code))

# ------------------------------------------------------------------ 11. référentiels
for chemin in ("/provinces", "/type-alertes", "/type-objets", "/roles", "/config-public"):
    r = C.get(f"{PREFIX}{chemin}", headers={"Authorization": f"Bearer {CITOYEN_TOKEN}"})
    check(f"GET {chemin} (citoyen) -> 200", r.status_code == 200, str(r.status_code))

r = C.get(f"{PREFIX}/provinces", headers={"Authorization": f"Bearer {ADMIN_TOKEN}"})
j = json_of(r)
check("26 provinces en base", len(j.get("data", [])) == 26, str(len(j.get("data", []))))
check("accents provinciaux intacts", any(p["nom"] == "Équateur" for p in j.get("data", [])))

r = C.get(f"{PREFIX}/permissions", headers={"Authorization": f"Bearer {CITOYEN_TOKEN}"})
check("citoyen -> GET /permissions = 403 (rbac.gerer)", r.status_code == 403, str(r.status_code))

r = C.get(f"{PREFIX}/commissariats", headers={"Authorization": f"Bearer {ADMIN_TOKEN}"})
j = json_of(r)
check("au moins 10 commissariats (jeu de depart)",
      len(j.get("data", [])) >= 10, str(len(j.get("data", []))))

# ------------------------------------------------------------------ 12. mise à jour profil
r = C.patch(
    f"{PREFIX}/auth/me",
    headers={"Authorization": f"Bearer {CITOYEN_TOKEN}"},
    json={"adresse": "Av. Kasa-Vubu, Kinshasa", "genre": "M"},
)
j = json_of(r)
check("PATCH /auth/me -> 200", r.status_code == 200, str(r.status_code))
check("adresse mise à jour", j.get("data", {}).get("adresse") == "Av. Kasa-Vubu, Kinshasa",
      str(j.get("data", {}).get("adresse")))

# ------------------------------------------------------------------ 13. admin modifie un autre compte
r = C.patch(
    f"{PREFIX}/users/{CITOYEN_ID}",
    headers={"Authorization": f"Bearer {ADMIN_TOKEN}"},
    json={"grade_police": None, "adresse": "Modifié par admin"},
)
j = json_of(r)
check("admin PATCH /users/<id> -> 200", r.status_code == 200, str(r.status_code) + str(j))
check("admin a bien modifié l'adresse",
      j.get("data", {}).get("adresse") == "Modifié par admin", str(j.get("data", {}).get("adresse")))

# ------------------------------------------------------------------ 14. citoyen ne peut pas toucher aux autres
r = C.patch(
    f"{PREFIX}/users/1",
    headers={"Authorization": f"Bearer {CITOYEN_TOKEN}"},
    json={"nom": "PIRATAGE"},
)
j = json_of(r)
check("citoyen PATCH /users/1 -> 403", r.status_code == 403, str(r.status_code))

# ------------------------------------------------------------------ 15. vérification e-mail
r = C.post(f"{PREFIX}/auth/send-verification",
           headers={"Authorization": f"Bearer {CITOYEN_TOKEN}"}, json={"type": "email"})
j = json_of(r)
check("send-verification -> 200", r.status_code == 200, str(r.status_code) + str(j))
code = j.get("data", {}).get("code_demo")
check("code_demo exposé (MAIL_ENABLED=false)", bool(code), str(code))

r = C.post(f"{PREFIX}/auth/verify",
           headers={"Authorization": f"Bearer {CITOYEN_TOKEN}"},
           json={"type": "email", "code": code})
check("verify avec le bon code -> 200", r.status_code == 200, str(r.status_code))

r = C.get(f"{PREFIX}/auth/me", headers={"Authorization": f"Bearer {CITOYEN_TOKEN}"})
check("email_verifie passe à true", json_of(r).get("data", {}).get("email_verifie") is True)

# ------------------------------------------------------------------ 16. changement de mot de passe
r = C.post(f"{PREFIX}/auth/change-password",
           headers={"Authorization": f"Bearer {CITOYEN_TOKEN}"},
           json={"current_password": "Citoyen2026", "password": "Nouveau2026"})
check("change-password -> 200", r.status_code == 200, str(r.status_code))

r = C.post(f"{PREFIX}/auth/login", json={"email": email_cit, "password": "Citoyen2026"})
check("ancien mdp refusé après changement", r.status_code == 401, str(r.status_code))
r = C.post(f"{PREFIX}/auth/login", json={"email": email_cit, "password": "Nouveau2026"})
j = json_of(r)
check("nouveau mdp accepté", r.status_code == 200, str(r.status_code))
CITOYEN_TOKEN = j.get("data", {}).get("access_token") or CITOYEN_TOKEN
CITOYEN_REFRESH = j.get("data", {}).get("refresh_token")

# ------------------------------------------------------------------ 17. refresh
r = C.post(f"{PREFIX}/auth/refresh", json={"refresh_token": CITOYEN_REFRESH})
j = json_of(r)
check("POST /auth/refresh -> 200", r.status_code == 200, str(r.status_code))
NOUVEAU_ACCESS = j.get("data", {}).get("access_token")
check("refresh renvoie un nouvel access_token", bool(NOUVEAU_ACCESS))

r = C.post(f"{PREFIX}/auth/refresh", json={"refresh_token": NOUVEAU_ACCESS})
check("un access_token n'est pas un refresh_token", r.status_code == 401, str(r.status_code))

# ------------------------------------------------------------------ 18. logout = révocation réelle
r = C.post(f"{PREFIX}/auth/logout", headers={"Authorization": f"Bearer {NOUVEAU_ACCESS}"})
check("POST /auth/logout -> 200", r.status_code == 200, str(r.status_code))
r = C.get(f"{PREFIX}/auth/me", headers={"Authorization": f"Bearer {NOUVEAU_ACCESS}"})
check("jeton révoqué après logout -> 401", r.status_code == 401, str(r.status_code))

# ------------------------------------------------------------------ 19. mdp oublié
r = C.post(f"{PREFIX}/auth/forgot-password", json={"email": email_cit})
j = json_of(r)
check("forgot-password -> 200", r.status_code == 200, str(r.status_code))
reset_code = j.get("data", {}).get("code_demo")
check("code de reset exposé en dev", bool(reset_code), str(reset_code))

r = C.post(f"{PREFIX}/auth/reset-password",
           json={"email": email_cit, "code": reset_code, "password": "Reprise2026"})
check("reset-password -> 200", r.status_code == 200, str(r.status_code) + str(json_of(r)))
r = C.post(f"{PREFIX}/auth/login", json={"email": email_cit, "password": "Reprise2026"})
check("connexion avec le mdp réinitialisé", r.status_code == 200, str(r.status_code))

# ------------------------------------------------------------------ 20. anti-énumération
r = C.post(f"{PREFIX}/auth/forgot-password", json={"email": "inconnu@quelquepart.cd"})
check("forgot-password inconnu -> 200 (mêmes messages)",
      r.status_code == 200 and "code_demo" not in json_of(r).get("data", {}), str(r.status_code))

# ------------------------------------------------------------------ 21. audit
r = C.get(f"{PREFIX}/audit?per_page=100", headers={"Authorization": f"Bearer {ADMIN_TOKEN}"})
j = json_of(r)
check("GET /audit -> 200", r.status_code == 200, str(r.status_code))
actions = {e.get("action") for e in j.get("data", [])}
check("audit contient connexion et inscription",
      {"connexion", "inscription"} <= actions, str(sorted(a for a in actions if a)))
check("audit journalise l'IP", all(e.get("ip_address") for e in j.get("data", [])[:5]))

# ------------------------------------------------------------------ 22. mdp faible
r = C.post(f"{PREFIX}/auth/register",
           json={"nom": "FAIBLE", "email": f"faible.{suffix}@test.cd",
                 "telephone": f"+2438{secrets.randbelow(10**8):08d}", "password": "123"})
j = json_of(r)
check("mot de passe trop court -> 422", r.status_code == 422, str(r.status_code))
check("message de politique de mdp", "password" in (j.get("errors") or {}), str(j.get("errors")))

# ------------------------------------------------------------------ 23. avatar
# PNG 1x1 minimal (valide)
_PNG = bytes.fromhex(
    "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489"
    "0000000a49444154789c6300010000050001"
    "0d0a2db40000000049454e44ae426082"
)
r = C.post(
    f"{PREFIX}/users/{CITOYEN_ID}/avatar",
    headers={"Authorization": f"Bearer {CITOYEN_TOKEN}"},
    data={"image": (io.BytesIO(_PNG), "profil.png")},
    content_type="multipart/form-data",
)
j = json_of(r)
check("POST avatar -> 200", r.status_code == 200, str(r.status_code) + str(j))
check("avatar enregistré", str(j.get("data", {}).get("avatar", "")).startswith("uploads/avatars/"),
      str(j.get("data")))
# L'URL annoncée doit réellement résoudre (cohérence chemin web / disque).
r = C.get("/static/" + str(j.get("data", {}).get("avatar", "")))
check("le fichier d'avatar est réellement servi (URL cohérente)",
      r.status_code == 200, str(r.status_code))

# format refusé
r = C.post(
    f"{PREFIX}/users/{CITOYEN_ID}/avatar",
    headers={"Authorization": f"Bearer {CITOYEN_TOKEN}"},
    data={"image": (io.BytesIO(b"pas du vrai"), "dangereux.exe")},
    content_type="multipart/form-data",
)
j = json_of(r)
check("avatar .exe -> 422", r.status_code == 422, str(r.status_code))

# l'avatar servi est accessible (le dossier static historique est conservé)
r = C.get("/static/Image/user.png")
check("GET /static/Image/user.png (héritage mobile) -> 200", r.status_code == 200, str(r.status_code))
r = C.get("/static/uploads/avatars/inexistant.png")
check("404 fichier inexistant en JSON", r.status_code == 404, str(r.status_code))

# ------------------------------------------------------------------ bilan
ok = sum(1 for c, _ in RESULTATS if c)
for c, label in RESULTATS:
    print(("  OK   " if c else "  ECHEC") + " | " + label)
print(f"\n{ok}/{len(RESULTATS)} vérifications réussies")
sys.exit(0 if ok == len(RESULTATS) else 1)
