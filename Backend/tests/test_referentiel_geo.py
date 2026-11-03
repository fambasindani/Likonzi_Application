"""Référentiel géographique : provinces → villes → communes → commissariats.

Lancement depuis le dossier `Backend/` :
    .venv\\Scripts\\python.exe tests\\test_referentiel_geo.py
"""
from __future__ import annotations

import os
import secrets
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir)))

from app import create_app

app = create_app("development")
C = app.test_client()

RESULTATS: list[tuple[bool, str]] = []


def check(label: str, cond: bool, extra: str = "") -> None:
    RESULTATS.append((bool(cond), label + (f" ? {extra}" if extra else "")))


def _bilan() -> None:
    reussis = sum(1 for c, _ in RESULTATS if c)
    for c, label in RESULTATS:
        print(("  OK   " if c else "  ECHEC") + " | " + label)
    print(f"\n{reussis}/{len(RESULTATS)} verifications reussies")


def _hook(exc_type, exc, tb):
    import traceback

    _bilan()
    print("--- arret brutal ---")
    traceback.print_exception(exc_type, exc, tb)


sys.excepthook = _hook

P = "/api/v1"
suffix = secrets.token_hex(4)


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def json_of(resp):
    try:
        return resp.get_json() or {}
    except Exception:
        return {}


def data_of(resp):
    return json_of(resp).get("data") or {}


def erreurs_of(resp) -> dict:
    corps = json_of(resp)
    return corps.get("errors") or corps.get("meta", {}).get("erreurs") or {}


# ==================================================================== mise en place

r = C.post(f"{P}/auth/login", json={"email": "admin@securite.cd", "password": "12345678"})
T_ADMIN = data_of(r).get("access_token")
check("admin connecte", bool(T_ADMIN))
H = auth(T_ADMIN)

# ----------------------------------------------------------------- lecture initiale
r = C.get(f"{P}/communes", headers=H)
communes = data_of(r)
check("GET /communes -> 200", r.status_code == 200, str(r.status_code))
check("au moins 24 communes en base (24 pour Kinshasa)",
      len(communes) >= 24, str(len(communes)))
check("une commune porte ses ville et province",
      bool(communes and communes[0].get("ville") and communes[0].get("province")))

r = C.get(f"{P}/provinces", headers=H)
provinces = data_of(r)
kin = next((p for p in provinces if p["code"] == "KIN"), None)
check("province KIN trouvee", kin is not None, str(len(provinces)))

r = C.get(f"{P}/villes", headers=H, query_string={"id_province": kin["id"]})
villes_kin = data_of(r)
ville_kin = next((v for v in villes_kin if v["nom"] == "Kinshasa"), None)
check("ville Kinshasa trouvee", ville_kin is not None, str(len(villes_kin)))
check("province KIN : une seule ville (Kinshasa)",
      len(villes_kin) == 1, str([v["nom"] for v in villes_kin]))
check("Limete/Masina/Ngaliema/Kintambo ne sont plus des villes",
      not any(v["nom"] in ("Limete", "Masina", "Ngaliema", "Kintambo")
              for v in villes_kin), str([v["nom"] for v in villes_kin]))

r = C.get(f"{P}/communes", headers=H, query_string={"id_ville": ville_kin["id"]})
check("filtre ?id_ville -> 24 communes", len(data_of(r)) == 24, str(len(data_of(r))))

r = C.get(f"{P}/commissariats", headers=H,
          query_string={"id_commune": next(c["id"] for c in communes if c["nom"] == "Gombe")})
gombe = data_of(r)
check("commissariat rattache a la commune de Gombe",
      len(gombe) == 1 and gombe[0].get("code") == "COM-KIN-001", str(len(gombe)))

# ================================================================ creation province
r = C.post(f"{P}/provinces", headers=H,
           json={"code": f"TT{suffix[:4]}", "nom": f"Province Test {suffix}"})
prov_test = data_of(r)
check("POST /provinces -> 201", r.status_code == 201, str(r.status_code) + str(json_of(r))[:150])
check("province renvoyee avec son id", bool(prov_test.get("id")))

r = C.post(f"{P}/provinces", headers=H,
           json={"code": f"TT{suffix[:4]}", "nom": "Doublon"})
check("code de province duplique -> 409", r.status_code == 409, str(r.status_code))

r = C.post(f"{P}/provinces", headers=H, json={"code": "", "nom": ""})
check("province sans champs -> 422", r.status_code == 422, str(r.status_code))

# ==================================================================== creation ville
r = C.post(f"{P}/villes", headers=H,
           json={"id_province": prov_test["id"], "nom": f"Ville Test {suffix}",
                 "latitude": -4.32, "longitude": 15.31})
ville_test = data_of(r)
check("POST /villes -> 201", r.status_code == 201, str(r.status_code) + str(json_of(r))[:150])
check("ville rattachee a la province",
      ville_test.get("province", {}).get("id") == prov_test["id"]
      if isinstance(ville_test.get("province"), dict) else False,
      str(ville_test.get("province"))[:60])

r = C.post(f"{P}/villes", headers=H,
           json={"id_province": prov_test["id"], "nom": "Uniq", "latitude": -4.0})
check("latitude sans longitude -> 422", r.status_code == 422, str(r.status_code))

# ================================================================== creation commune
r = C.post(f"{P}/communes", headers=H,
           json={"id_ville": ville_test["id"], "nom": f"Commune Test {suffix}",
                 "code": f"CMT{suffix[:4]}", "latitude": -4.33, "longitude": 15.34})
commune_test = data_of(r)
check("POST /communes -> 201", r.status_code == 201, str(r.status_code) + str(json_of(r))[:150])
check("commune renvoie ville ET province",
      commune_test.get("ville") == ville_test["nom"]
      and commune_test.get("province") == f"Province Test {suffix}",
      f"{commune_test.get('ville')} / {commune_test.get('province')}")

r = C.post(f"{P}/communes", headers=H,
           json={"id_ville": ville_test["id"], "nom": f"Commune Test {suffix}"})
check("commune en double -> 409", r.status_code == 409, str(r.status_code))

# =========================================================== creation commissariat
r = C.post(f"{P}/commissariats", headers=H,
           json={"code": f"COM-T{suffix[:5]}", "nom": f"Commissariat Test {suffix}",
                 "id_commune": commune_test["id"], "adresse": "Av. du Test, Q. Central",
                 "telephone": "+243810000009", "latitude": -4.33, "longitude": 15.34})
com_test = data_of(r)
check("POST /commissariats -> 201", r.status_code == 201,
      str(r.status_code) + str(json_of(r))[:150])
check("province et ville deduites de la commune",
      com_test.get("id_commune") == commune_test["id"]
      and com_test.get("id_ville") == ville_test["id"]
      and com_test.get("id_province") == prov_test["id"],
      f"{com_test.get('id_province')}/{com_test.get('id_ville')}/{com_test.get('id_commune')}")
check("nom de commune expose", com_test.get("commune") == f"Commune Test {suffix}",
      str(com_test.get("commune")))

r = C.post(f"{P}/commissariats", headers=H,
           json={"code": f"COM-T{suffix[:5]}", "nom": "Doublon commissariat"})
check("code de commissariat duplique -> 409", r.status_code == 409, str(r.status_code))

# ============================================================= incoherence de chaine
r = C.post(f"{P}/commissariats", headers=H,
           json={"code": f"COM-X{suffix[:5]}", "nom": "Incoherent",
                 "id_commune": commune_test["id"], "id_ville": ville_kin["id"]})
check("commune d une autre ville -> 422", r.status_code == 422, str(r.status_code))

# ================================================================== modification
r = C.patch(f"{P}/communes/{commune_test['id']}", headers=H,
            json={"nom": f"Commune Renom {suffix}", "latitude": -4.4, "longitude": 15.5})
maj = data_of(r)
check("PATCH /communes -> 200", r.status_code == 200, str(r.status_code))
check("nom mis a jour", maj.get("nom") == f"Commune Renom {suffix}", str(maj.get("nom")))

r = C.get(f"{P}/audit", headers=H, query_string={"action": "commune_modifiee", "per_page": 5})
lignes_audit = data_of(r)
lignes_audit = lignes_audit.get("items", lignes_audit) if isinstance(lignes_audit, dict) else lignes_audit
check("modification tracee dans l audit",
      r.status_code == 200 and len(lignes_audit) >= 1, str(r.status_code))

# ================================================================== suppression
r = C.delete(f"{P}/communes/{commune_test['id']}", headers=H)
check("DELETE /communes -> 200", r.status_code == 200, str(r.status_code))
r = C.get(f"{P}/commissariats", headers=H, query_string={"id_commune": commune_test["id"]})
check("commissariat detache (SET NULL) apres suppression",
      len(data_of(r)) == 0, str(len(data_of(r))))

r = C.delete(f"{P}/villes/{ville_test['id']}", headers=H)
check("DELETE /villes -> 200", r.status_code == 200, str(r.status_code))
r = C.delete(f"{P}/provinces/{prov_test['id']}", headers=H)
check("DELETE /provinces -> 200", r.status_code == 200, str(r.status_code))

# ville encore peuplee -> refusee
r = C.delete(f"{P}/villes/{ville_kin['id']}", headers=H)
check("suppression d une ville peuplee -> 409", r.status_code == 409, str(r.status_code))

# purge douce du commissariat de test
r = C.get(f"{P}/commissariats", headers=H)
# Le service force les codes en majuscules : comparer en majuscules aussi.
com_test_ligne = next(
    (c for c in data_of(r) if c["code"] == f"COM-T{suffix[:5]}".upper()), None
)
if com_test_ligne:
    r = C.delete(f"{P}/commissariats/{com_test_ligne['id']}", headers=H)
    check("DELETE /commissariats (purge douce) -> 200", r.status_code == 200, str(r.status_code))

# ============================================================ géocodage inverse
r = C.get(f"{P}/lieu", headers=H, query_string={"lat": -4.32, "lon": 15.31})
lieu = data_of(r) if r.status_code == 200 else {}
check("GET /lieu -> 200", r.status_code == 200, str(r.status_code) + str(json_of(r))[:200])
check("lieu : ville identifiee depuis les coordonnees", bool(lieu.get("ville")),
      str(lieu.get("ville")))
check("lieu : commune renvoyee", bool(lieu.get("commune")), str(lieu.get("commune")))
check("lieu : distance en km calculee", lieu.get("distance_km") is not None,
      str(lieu.get("distance_km")))
r = C.get(f"{P}/lieu", headers=H)
check("GET /lieu sans coordonnees -> 422", r.status_code == 422, str(r.status_code))
r = C.get(f"{P}/lieu", query_string={"lat": -4.32, "lon": 15.31})
check("GET /lieu sans jeton -> 401", r.status_code == 401, str(r.status_code))

# ================================================================ cloisonnement RBAC
r = C.post(f"{P}/users", headers=H,
           json={"email": f"geo{suffix}@test.cd", "password": "12345678",
                 "nom": "GEO", "prenom": "Test", "role": "citoyen",
                 "telephone": f"+24381{int(suffix, 16) % 10_000_000:07d}",
                 "genre": "M", "date_naissance": "1995-01-01"})
check("creation d un compte citoyen (controle)", r.status_code in (200, 201), str(r.status_code))
r = C.post(f"{P}/auth/login", json={"email": f"geo{suffix}@test.cd", "password": "12345678"})
token_citoyen = data_of(r).get("access_token")
check("citoyen connecte", bool(token_citoyen))

r = C.post(f"{P}/provinces", headers=auth(token_citoyen),
           json={"code": "ZAX", "nom": "Interdit"})
check("citoyen : POST /provinces -> 403", r.status_code == 403, str(r.status_code))
r = C.delete(f"{P}/communes/1", headers=auth(token_citoyen))
check("citoyen : DELETE /communes -> 403", r.status_code == 403, str(r.status_code))

# nettoyage du compte de controle
r = C.get(f"{P}/users", headers=H, query_string={"q": f"geo{suffix}"})
u = data_of(r)
u = u.get("items") if isinstance(u, dict) else u
if isinstance(u, list) and u:
    C.delete(f"{P}/users/{u[0]['id']}", headers=H)

_bilan()
sys.exit(0 if all(c for c, _ in RESULTATS) else 1)
