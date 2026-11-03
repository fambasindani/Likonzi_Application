"""Tests bout en bout du domaine métier : alertes, dossiers, preuves, objets, géo, social.

Lancement depuis le dossier `Backend/` :
    .venv\\Scripts\\python.exe tests\\test_metier.py
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


def _bilan() -> None:
    reussis = sum(1 for c, _ in RESULTATS if c)
    for c, label in RESULTATS:
        print(("  OK   " if c else "  ECHEC") + " | " + label)
    print(f"\n{reussis}/{len(RESULTATS)} vérifications réussies")


def _hook(exc_type, exc, tb):
    """Affiche le bilan même en cas d'arrêt brutal pour localiser l'étape fautive."""
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


P = "/api/v1"
suffix = secrets.token_hex(4)


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


# ===================================================================== mise en place

r = C.post(f"{P}/auth/login", json={"email": "admin@securite.cd", "password": "12345678"})
admin = data_of(r)
T_ADMIN = admin.get("access_token")
check("admin connecté", bool(T_ADMIN))

# Échec volontaire pour vérifier que l'audit journalise aussi les refus.
C.post(f"{P}/auth/login", json={"email": "admin@securite.cd", "password": "mauvais"})

r = C.get(f"{P}/commissariats", headers=auth(T_ADMIN))
comms = data_of(r)
kin1 = next((c for c in comms if c["code"] == "COM-KIN-001"), None)
check("commissariat COM-KIN-001 trouvé", kin1 is not None, str(len(comms)))
KIN1 = kin1["id"] if kin1 else 1
LAT, LON = (kin1 or {}).get("latitude", -4.325), (kin1 or {}).get("longitude", 15.31)


def creer_compte(roles: list[str], tag: str, **extra) -> dict:
    body = {
        "nom": tag.upper(),
        "prenom": "Test",
        "email": f"{tag}.{suffix}@test.cd",
        "telephone": f"+2439{secrets.randbelow(10**8):08d}",
        "password": "Motdepasse2026",
        "roles": roles,
    }
    body.update(extra)
    resp = C.post(f"{P}/users", json=body, headers=auth(T_ADMIN))
    if resp.status_code not in (200, 201):
        raise SystemExit(f"Échec création {tag}: {resp.status_code} {resp.get_json()}")
    return data_of(resp)


pol = creer_compte(["policier"], "policier", id_commissariat=KIN1)
enq = creer_compte(["enqueteur"], "enqueteur", id_commissariat=KIN1)
T_POL = pol["access_token"]
T_ENQ = enq["access_token"]
ID_POL, ID_ENQ = pol["user"]["id"], enq["user"]["id"]
check("policier créé avec le bon commissariat", pol["user"]["id_commissariat"] == KIN1,
      str(pol["user"]["id_commissariat"]))
check("policier a le rôle attendu", "policier" in pol["user"]["roles"], str(pol["user"]["roles"]))
check("enquêteur créé", "enqueteur" in enq["user"]["roles"], str(enq["user"]["roles"]))


def inscrire(tag: str, **extra) -> dict:
    body = {
        "nom": tag.upper(),
        "prenom": "Test",
        "email": f"{tag}.{suffix}@test.cd",
        "telephone": f"+2438{secrets.randbelow(10**8):08d}",
        "password": "Citoyen2026",
    }
    body.update(extra)
    resp = C.post(f"{P}/auth/register", json=body)
    if resp.status_code != 201:
        raise SystemExit(f"Échec inscription {tag}: {resp.status_code} {resp.get_json()}")
    return data_of(resp)


A = inscrire("alice")   # victime
B = inscrire("bob")     # ami
X = inscrire("intrus")  # hors périmètre
T_A, T_B, T_X = A["access_token"], B["access_token"], X["access_token"]
ID_A, ID_B = A["user"]["id"], B["user"]["id"]

# ======================================================================= ALERTES

r = C.post(
    f"{P}/alertes",
    headers=auth(T_A),
    json={
        "id_type_alerte": 1,  # DANGER
        "contenu": "Deux motards me suivent sur l'avenue Kasa-Vubu.",
        "niveau_urgence": "critique",
        "latitude": LAT,
        "longitude": LON,
        "adresse_precise": "Av. Kasa-Vubu, Gombe",
    },
)
alerte = data_of(r)
AL = alerte.get("id")
check("citoyen crée une alerte -> 201", r.status_code == 201, str(r.status_code) + str(json_of(r)))
check("référence au format ALT-AAAAMMJJ-XXXXXX",
      str(alerte.get("reference", "")).startswith("ALT-"), str(alerte.get("reference")))
check("statut initial = nouvelle", alerte.get("statut") == "nouvelle", str(alerte.get("statut")))
check("commissariat affecté automatiquement par la proximité",
      alerte.get("id_commissariat") == KIN1, str(alerte.get("id_commissariat")))
check("urgence forcée au niveau demandé", alerte.get("niveau_urgence") == "critique")

r = C.get(f"{P}/alertes/{AL}", headers=auth(T_A))
check("le déclencheur voit son alerte", r.status_code == 200, str(r.status_code))
r = C.get(f"{P}/alertes/{AL}", headers=auth(T_X))
check("un tiers ne voit PAS l'alerte (404)", r.status_code == 404, str(r.status_code))

r = C.get(f"{P}/alertes", headers=auth(T_X))
autre_ids = [a["id"] for a in data_of(r)]
check("la liste est filtrée par périmètre", AL not in autre_ids, str(len(autre_ids)))
r = C.get(f"{P}/alertes", headers=auth(T_POL))
ids_pol = [a["id"] for a in data_of(r)]
check("le policier voit l'alerte de son commissariat", AL in ids_pol, str(len(ids_pol)))

r = C.post(f"{P}/alertes/{AL}/prendre-en-charge", headers=auth(T_A))
check("un citoyen ne peut pas prendre en charge -> 403", r.status_code == 403, str(r.status_code))

r = C.post(f"{P}/alertes/{AL}/prendre-en-charge", headers=auth(T_POL))
prise = data_of(r)
check("policier prend l'alerte en charge -> 200", r.status_code == 200, str(r.status_code) + str(json_of(r)))
check("statut = prise_en_compte", prise.get("statut") == "prise_en_compte", str(prise.get("statut")))
check("assignée au policier connecté", prise.get("id_policier_assignee") == ID_POL,
      str(prise.get("id_policier_assignee")))
check("date de prise en compte renseignée", bool(prise.get("date_prise_en_compte")))
check("policier visible dans le détail", (prise.get("policier") or {}).get("id") == ID_POL)

r = C.get(f"{P}/notifications", headers=auth(T_A))
types_notif = {n["type"] for n in data_of(r)}
check("le déclencheur est notifié de la prise en charge",
      "alerte_assignee" in types_notif, str(sorted(types_notif)))

r = C.get(f"{P}/alertes/autour-de-moi?lat={LAT}&lon={LON}&rayon_km=5", headers=auth(T_A))
alentours = data_of(r)
check("alerte trouvée par proximité", any(a["id"] == AL for a in alentours),
      str([(a.get("reference"), a.get("distance_km")) for a in alentours]))
check("distance calculée en km", all("distance_km" in a for a in alentours))

r = C.get(f"{P}/alertes/autour-de-moi?lat=-11.66&lon=27.48&rayon_km=5", headers=auth(T_A))
check("hors rayon -> liste vide", json_of(r).get("data") == [], str(json_of(r).get("data")))

# ======================================================================== DOSSIERS

r = C.post(f"{P}/cas", headers=auth(T_A),
           json={"type_cas": "agression", "description": "Test", "date_faits": "2026-10-30T08:00:00"})
check("un citoyen ne peut pas ouvrir de dossier -> 403", r.status_code == 403, str(r.status_code))

r = C.post(
    f"{P}/alertes/{AL}/ouvrir-cas",
    headers=auth(T_ENQ),
    json={"type_cas": "agression", "description": "Agression à main armée signalée par la victime.",
          "date_faits": "2026-10-30T07:30:00", "priorite": "haute"},
)
cas = data_of(r)
CAS = cas.get("id")
check("ouverture de dossier depuis l'alerte -> 201", r.status_code == 201,
      str(r.status_code) + str(json_of(r)))
check("numéro de dossier au format DOS-…", str(cas.get("numero_dossier", "")).startswith("DOS-"),
      str(cas.get("numero_dossier")))
check("dossier lié à l'alerte", cas.get("id_alerte") == AL, str(cas.get("id_alerte")))
check("victime héritée de l'alerte", cas.get("id_victime") == ID_A, str(cas.get("id_victime")))
check("enquêteur auto-affecté", cas.get("id_enqueteur_principal") == ID_ENQ,
      str(cas.get("id_enqueteur_principal")))
check("priorite haute enregistrée", cas.get("priorite") == "haute", str(cas.get("priorite")))

r = C.post(f"{P}/cas", headers=auth(T_ENQ),
           json={"type_cas": "vol", "description": "Test date future.",
                 "date_faits": "2099-01-01T00:00:00"})
check("date des faits dans le futur -> 422", r.status_code == 422, str(r.status_code))

r = C.get(f"{P}/cas", headers=auth(T_A))
ids_a = [c["id"] for c in data_of(r)]
check("la victime suit son dossier", CAS in ids_a, str(len(ids_a)))
r = C.get(f"{P}/cas", headers=auth(T_X))
ids_x = [c["id"] for c in data_of(r)]
check("un tiers ne voit PAS le dossier", CAS not in ids_x, str(len(ids_x)))
r = C.get(f"{P}/cas/{CAS}", headers=auth(T_X))
check("détail hors périmètre -> 404", r.status_code == 404, str(r.status_code))

r = C.post(
    f"{P}/cas/{CAS}/interventions",
    headers=auth(T_POL),
    json={"type_intervention": "patrouille",
          "description": "Ronde de contrôle sur l'avenue.",
          "duree_minutes": 45, "lieu": "Av. Kasa-Vubu"},
)
inter = data_of(r)
check("intervention enregistrée -> 201", r.status_code == 201, str(r.status_code) + str(json_of(r)))
check("intervention rattachée au dossier", inter.get("id_cas") == CAS, str(inter.get("id_cas")))
check("policier auto-affecté", inter.get("id_policier") == ID_POL, str(inter.get("id_policier")))

r = C.get(f"{P}/cas/{CAS}", headers=auth(T_ENQ))
check("une intervention fait passer le dossier en en_cours",
      data_of(r).get("statut") == "en_cours", str(data_of(r).get("statut")))
check("l'intervention figure dans le dossier",
      any(i["id"] == inter["id"] for i in data_of(r).get("interventions", [])))

r = C.get(f"{P}/interventions", headers=auth(T_POL))
check("liste des interventions du policier -> 200", r.status_code == 200, str(r.status_code))

r = C.post(f"{P}/cas/{CAS}/cloturer", headers=auth(T_ENQ),
           json={"statut": "clos", "resultat": "Suspects identifiés et placés en garde à vue."})
cloture = data_of(r)
check("clôture du dossier -> 200", r.status_code == 200, str(r.status_code) + str(json_of(r)))
check("statut = clos", cloture.get("statut") == "clos", str(cloture.get("statut")))
check("date de clôture renseignée", bool(cloture.get("date_cloture")))
check("résultat enregistré", "garde à vue" in (cloture.get("resultat") or ""))

r = C.patch(f"{P}/cas/{CAS}", headers=auth(T_ENQ), json={"statut": "en_cours"})
check("dossier clos -> réouverture refusée (422)", r.status_code == 422, str(r.status_code))

r = C.get(f"{P}/notifications", headers=auth(T_A))
cas_notifs = [n for n in data_of(r) if n["type"] == "cas_maj"]
check("la victime est notifiée de l'ouverture et de la clôture", len(cas_notifs) >= 2,
      str(len(cas_notifs)))

# La résolution vient APRÈS l'ouverture du dossier : une alerte finalisée
# ne peut plus donner lieu à un dossier.
r = C.patch(f"{P}/alertes/{AL}/statut", headers=auth(T_POL), json={"statut": "resolue",
                                                                    "observation": "Suspects interpellés."})
resolue = data_of(r)
check("passage à resolue -> 200", r.status_code == 200, str(r.status_code) + str(json_of(r)))
check("date_resolution renseignée", bool(resolue.get("date_resolution")))

r = C.patch(f"{P}/alertes/{AL}/statut", headers=auth(T_POL), json={"statut": "en_cours"})
check("transition retour resolue -> en_cours refusée (422)",
      r.status_code == 422, str(r.status_code))
check("422 détaille la transition", "statut" in (json_of(r).get("errors") or {}),
      str(json_of(r).get("errors")))

# ======================================================================== PREUVES

PNG = bytes.fromhex(
    "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489"
    "0000000a49444154789c63000100000500010d0a2db40000000049454e44ae426082"
)
r = C.post(
    f"{P}/preuves",
    headers=auth(T_A),
    data={
        "entite_type": "alerte",
        "entite_id": str(AL),
        "type_preuve": "photo",
        "description": "Capture de la conversation",
        "fichier": (io.BytesIO(PNG), "temoin.png"),
    },
    content_type="multipart/form-data",
)
preuve = data_of(r)
PRE = preuve.get("id")
check("téléversement d'une preuve -> 201", r.status_code == 201,
      str(r.status_code) + str(json_of(r)))
check("empreinte SHA-256 calculée (64 hex)", len(str(preuve.get("hash_sha256") or "")) == 64,
      str(preuve.get("hash_sha256"))[:16])
check("taille du fichier enregistrée", preuve.get("taille_octets") == len(PNG),
      str(preuve.get("taille_octets")))

r = C.get(f"{P}/preuves/{PRE}/verifier", headers=auth(T_A))
verif = data_of(r)
check("intégrité conforme juste après l'upload", verif.get("conforme") is True, str(verif))

r = C.get(f"{P}/preuves/{PRE}/telecharger", headers=auth(T_A))
check("téléchargement de la preuve -> 200", r.status_code == 200, str(r.status_code))
check("le téléchargement est en pièce jointe",
      "attachment" in r.headers.get("Content-Disposition", ""))

# Altération volontaire du fichier pour déclencher l'alerte d'intégrité
chemin = os.path.join(app.config["UPLOAD_FOLDER"],
                      preuve["chemin_stockage"].replace("/", os.sep))
check("fichier présent sur le disque", os.path.isfile(chemin), chemin)
with open(chemin, "r+b") as f:
    f.write(b"XX")
r = C.get(f"{P}/preuves/{PRE}/verifier", headers=auth(T_A))
verif2 = data_of(r)
check("altération détectée par le recalcul du hash", verif2.get("conforme") is False, str(verif2))
check("message d'altération explicite", "ALTÉRATION" in (verif2.get("message") or ""),
      str(verif2.get("message")))

r = C.post(
    f"{P}/preuves",
    headers=auth(T_A),
    data={"entite_type": "alerte", "entite_id": str(AL), "type_preuve": "document",
          "fichier": (io.BytesIO(b"MZ"), "payload.exe")},
    content_type="multipart/form-data",
)
check("fichier .exe refusé -> 422", r.status_code == 422, str(r.status_code))
check("la liste blanche est citée dans l'erreur",
      "non autorisée" in str(json_of(r).get("errors")), str(json_of(r).get("errors"))[:160])

r = C.get(f"{P}/preuves/{PRE}", headers=auth(T_X))
check("preuve d'autrui -> 404", r.status_code == 404, str(r.status_code))
r = C.get(f"{P}/preuves/{PRE}/telecharger", headers=auth(T_X))
check("téléchargement par un tiers -> 403 ou 404", r.status_code in (403, 404), str(r.status_code))

r = C.post(
    f"{P}/preuves",
    headers=auth(T_POL),
    data={"entite_type": "cas", "entite_id": str(CAS), "type_preuve": "document",
          "fichier": (io.BytesIO("procès-verbal".encode()), "pv.txt")},
    content_type="multipart/form-data",
)
pv = data_of(r)
check("policier joint une preuve au dossier -> 201", r.status_code == 201,
      str(r.status_code) + str(json_of(r)))
if pv.get("id"):
    r = C.get(f"{P}/preuves/{pv['id']}/verifier", headers=auth(T_ENQ))
    check("l'enquêteur vérifie l'intégrité du PV", data_of(r).get("conforme") is True)
else:
    check("l'enquêteur vérifie l'intégrité du PV", False, "preuve non créée")

# ========================================================================= OBJETS

r = C.post(
    f"{P}/objets",
    headers=auth(T_A),
    json={"id_type": 2, "marque": "Toyota", "model": "Hilux", "couleur": "Blanc",
          "immatriculation": "CD 4521 AB", "numero_chassis": "JT8H1234567",
          "date_vol": "2026-10-29T18:00:00", "lieu_vol": "Parking de la Gombe"},
)
objet = data_of(r)
OBJ = objet.get("id")
check("déclaration d'un objet volé -> 201", r.status_code == 201,
      str(r.status_code) + str(json_of(r)))
check("statut initial declare_vol", objet.get("statut") == "declare_vol", str(objet.get("statut")))

r = C.post(f"{P}/objets", headers=auth(T_A), json={"id_type": 2})
check("objet sans signe distinctif -> 422", r.status_code == 422,
      str(r.status_code) + str(json_of(r)))

r = C.get(f"{P}/objets/recherche?q=CD+4521", headers=auth(T_A))
trouves = data_of(r)
check("recherche par immatriculation", any(o["id"] == OBJ for o in trouves),
      str([o.get("immatriculation") for o in trouves]))
r = C.get(f"{P}/objets/recherche?q=JT8H1234567", headers=auth(T_X))
check("recherche par n° de châssis accessible", r.status_code == 200, str(r.status_code))

r = C.post(f"{P}/objets/{OBJ}/statut", headers=auth(T_A), json={"statut": "recherche"})
check("propriétaire : declare_vol -> recherche autorisé", r.status_code == 200,
      str(r.status_code) + str(json_of(r)))
r = C.post(f"{P}/objets/{OBJ}/statut", headers=auth(T_A), json={"statut": "restitue"})
check("propriétaire : declare_vol -> restitue refusé (422)", r.status_code == 422,
      str(r.status_code))

r = C.post(f"{P}/objets/{OBJ}/statut", headers=auth(T_POL), json={"statut": "retrouve",
                                                                  "motif": "Retrouvé au poste."})
check("policier : -> retrouve autorisé", r.status_code == 200,
      str(r.status_code) + str(json_of(r)))
r = C.get(f"{P}/notifications", headers=auth(T_A))
check("le propriétaire est notifié du retrouvé",
      any(n["type"] == "objet_retrouve" for n in data_of(r)))

r = C.post(f"{P}/objets/{OBJ}/statut", headers=auth(T_A), json={"statut": "restitue"})
check("propriétaire : retrouve -> restitue refusé (403)", r.status_code == 403, str(r.status_code))

# ==================================================================== GÉOLOCALISATION

r = C.post(f"{P}/positions", headers=auth(T_A),
           json={"latitude": LAT, "longitude": LON, "source": "gps", "precision_metres": 8.5})
pos = data_of(r)
check("enregistrement de position -> 201", r.status_code == 201,
      str(r.status_code) + str(json_of(r)))
r = C.get(f"{P}/positions/moi", headers=auth(T_A))
check("dernière position lue", data_of(r).get("latitude") is not None, str(data_of(r)))

r = C.get(f"{P}/positions", headers=auth(T_A))
check("citoyen sans geo.lire -> 403", r.status_code == 403, str(r.status_code))
r = C.get(f"{P}/positions?vue=derniere", headers=auth(T_POL))
check("cartographie policière -> 200", r.status_code == 200, str(r.status_code))

r = C.post(f"{P}/positions", headers=auth(T_A),
           json={"latitude": 999, "longitude": 0})
check("latitude hors bornes -> 422", r.status_code == 422, str(r.status_code))

r = C.get(f"{P}/proximite/commissariats?lat={LAT}&lon={LON}&rayon_km=5", headers=auth(T_A))
proches = data_of(r)
check("commissariat le plus proche trouvé", any(c["id"] == KIN1 for c in proches),
      str([(c.get("code"), c.get("distance_km")) for c in proches]))
check("distance renseignée sur chaque résultat",
      all("distance_km" in c for c in proches))

# ============================================================================ SOCIAL

r = C.post(f"{P}/demandes", headers=auth(T_A), json={"id_destinataire": ID_B})
d1 = data_of(r)
check("demande d'ami envoyée -> 201", r.status_code == 201, str(r.status_code) + str(json_of(r)))
check("statut en_attente", d1.get("statut") == "en_attente", str(d1.get("statut")))

r = C.post(f"{P}/demandes", headers=auth(T_A), json={"id_destinataire": ID_B})
check("demande en double -> 409", r.status_code == 409, str(r.status_code))
r = C.post(f"{P}/demandes", headers=auth(T_A), json={"id_destinataire": ID_A})
check("auto-demande -> 422", r.status_code == 422, str(r.status_code))

r = C.get(f"{P}/demandes?sens=recues", headers=auth(T_B))
recues = data_of(r)
check("B reçoit la demande", any(d["id"] == d1["id"] for d in recues), str(len(recues)))

r = C.get(f"{P}/notifications", headers=auth(T_B))
check("B est notifié de la demande",
      any(n["type"] == "demande_ami" for n in data_of(r)))

r = C.post(f"{P}/demandes/{d1['id']}/repondre", headers=auth(T_A), json={"statut": "acceptee"})
check("seul B peut répondre -> 403", r.status_code == 403, str(r.status_code))
r = C.post(f"{P}/demandes/{d1['id']}/repondre", headers=auth(T_B), json={"statut": "acceptee"})
acc = data_of(r)
check("B accepte -> 200", r.status_code == 200, str(r.status_code) + str(json_of(r)))
check("statut acceptee", acc.get("statut") == "acceptee", str(acc.get("statut")))
check("date_reponse renseignée", bool(acc.get("date_reponse")))

r = C.get(f"{P}/amis", headers=auth(T_A))
amis_a = [u["id"] for u in data_of(r)]
r = C.get(f"{P}/amis", headers=auth(T_B))
amis_b = [u["id"] for u in data_of(r)]
check("A voit B parmi ses amis", ID_B in amis_a, str(amis_a))
check("B voit A parmi ses amis (miroir de la vue)", ID_A in amis_b, str(amis_b))

# ------------------------------------------- les amis voient mes alertes
r = C.post(f"{P}/alertes", headers=auth(T_A),
           json={"id_type_alerte": 1, "contenu": "Alerte visible par mes amis.",
                 "niveau_urgence": "moyen", "latitude": LAT, "longitude": LON})
AL_AMI = data_of(r).get("id")
check("alerte creee apres l amitie -> 201", r.status_code == 201,
      str(r.status_code) + str(json_of(r))[:160])

r = C.get(f"{P}/alertes", headers=auth(T_B))
ids_b = [a["id"] for a in data_of(r)]
check("l ami voit l alerte de son contact dans sa liste", AL_AMI in ids_b, str(len(ids_b)))
r = C.get(f"{P}/alertes/{AL_AMI}", headers=auth(T_B))
check("l ami ouvre le detail (200)", r.status_code == 200, str(r.status_code))
r = C.get(f"{P}/alertes/{AL_AMI}", headers=auth(T_X))
check("l intrus ne voit pas (404)", r.status_code == 404, str(r.status_code))
r = C.get(f"{P}/notifications", headers=auth(T_B))
check("l ami est notifie a la creation",
      any(n.get("entite_type") == "alerte" and n.get("entite_id") == AL_AMI
          for n in data_of(r)),
      str([n.get("type") for n in data_of(r)])[:200])

# ------------------------------------- fichiers de l'alerte : lecture vs ecriture
r = C.post(
    f"{P}/preuves",
    headers=auth(T_A),
    data={
        "entite_type": "alerte",
        "entite_id": str(AL_AMI),
        "type_preuve": "photo",
        "description": "Photo jointee par l auteur",
        "fichier": (io.BytesIO(PNG), "auteur.png"),
    },
    content_type="multipart/form-data",
)
PRE_AMI = data_of(r).get("id")
check("l auteur televerse sur son alerte -> 201", r.status_code == 201,
      str(r.status_code) + str(json_of(r))[:160])

r = C.get(f"{P}/preuves?entite_type=alerte&entite_id={AL_AMI}", headers=auth(T_B))
preuves_b = data_of(r)
check("l ami voit les fichiers de l alerte",
      any(p.get("id") == PRE_AMI for p in preuves_b), str(len(preuves_b)))

r = C.get(f"{P}/preuves/{PRE_AMI}/telecharger", headers=auth(T_B))
check("l ami telecharge le fichier -> 200", r.status_code == 200, str(r.status_code))

r = C.post(
    f"{P}/preuves",
    headers=auth(T_B),
    data={
        "entite_type": "alerte",
        "entite_id": str(AL_AMI),
        "type_preuve": "photo",
        "description": "Tentative de l ami",
        "fichier": (io.BytesIO(PNG), "ami.png"),
    },
    content_type="multipart/form-data",
)
check("l ami ne peut PAS televerser sur l alerte d autrui -> 403", r.status_code == 403,
      str(r.status_code) + str(json_of(r))[:160])

r = C.get(f"{P}/preuves?entite_type=alerte&entite_id={AL_AMI}", headers=auth(T_X))
check("l intrus ne voit aucun fichier -> 404 (entite invisible)",
      r.status_code == 404, str(r.status_code))

r = C.post(f"{P}/messages", headers=auth(T_A),
           json={"id_destinataire": ID_B, "messages": "Merci pour l'alerte partagée."})
msg = data_of(r)
check("message envoyé -> 201", r.status_code == 201, str(r.status_code) + str(json_of(r)))
check("message non lu à l'envoi", msg.get("lu") is False, str(msg.get("lu")))

r = C.get(f"{P}/messages/{ID_A}", headers=auth(T_B))
conv = data_of(r)
check("conversation consultée par B", any(m["id"] == msg["id"] for m in conv), str(len(conv)))
r = C.post(f"{P}/messages/{msg['id']}/lu", headers=auth(T_B))
check("B marque le message lu", data_of(r).get("lu") is True, str(r.status_code))
r = C.post(f"{P}/messages/{msg['id']}/lu", headers=auth(T_A))
check("A ne peut pas marquer le message reçu par B -> 403", r.status_code == 403,
      str(r.status_code))

r = C.get(f"{P}/messages-non-lus", headers=auth(T_B))
check("compteur de messages non lus", data_of(r).get("non_lus") == 0, str(data_of(r)))

r = C.post(f"{P}/notifications/tout-lu", headers=auth(T_B))
check("tout marquer lu -> 200", r.status_code == 200, str(r.status_code))
r = C.get(f"{P}/notifications?non_lues=1", headers=auth(T_B))
check("plus aucune notification non lue", json_of(r).get("data") == [],
      str(json_of(r).get("data")))



# ============================================================ PLAFOND DES IMAGES (200 Ko)

gros_png = b"\x89PNG\r\n\x1a\n" + b"\x00" * (200 * 1024 + 8192)
r = C.post(
    f"{P}/preuves",
    headers=auth(T_A),
    data={"entite_type": "alerte", "entite_id": str(AL), "type_preuve": "photo",
          "fichier": (io.BytesIO(gros_png), "photo_trop_lourde.png")},
    content_type="multipart/form-data",
)
check("image > 200 Ko refusee -> 422", r.status_code == 422, str(r.status_code))
check("le message indique le plafond",
      "200" in str(json_of(r).get("errors")), str(json_of(r).get("errors"))[:160])

# la regle ne vaut que pour les images : un document depasse peut le depasser
r = C.post(
    f"{P}/preuves",
    headers=auth(T_A),
    data={"entite_type": "alerte", "entite_id": str(AL), "type_preuve": "document",
          "fichier": (io.BytesIO(b"x" * 300 * 1024), "pv_long.txt")},
    content_type="multipart/form-data",
)
check("document > 200 Ko accepte (regle limitee aux images)",
      r.status_code == 201, str(r.status_code) + str(json_of(r))[:160])

# avatar soumis au meme plafond
r = C.post(
    f"{P}/users/{ID_A}/avatar",
    headers=auth(T_A),
    data={"image": (io.BytesIO(gros_png), "avatar_lourd.png")},
    content_type="multipart/form-data",
)
check("avatar > 200 Ko refuse -> 422", r.status_code == 422, str(r.status_code))

# et l'avatar normal fonctionne
r = C.post(
    f"{P}/users/{ID_A}/avatar",
    headers=auth(T_A),
    data={"image": (io.BytesIO(PNG), "avatar_ok.png")},
    content_type="multipart/form-data",
)
check("avatar dans la limite -> 200", r.status_code == 200, str(r.status_code))

# le plafond est expose au client
r = C.get(f"{P}/config-public", headers=auth(T_A))
check("config-public expose image_max_octets = 204800",
      json_of(r).get("data", {}).get("image_max_octets") == 200 * 1024,
      str(json_of(r).get("data")))


# ================================================== MES BIENS ET PARTAGE D'IMAGES

r = C.post(f"{P}/objets", headers=auth(T_A),
           json={"id_type": 3, "marque": "Dell", "model": "Latitude",
                 "numero_serie": "DL-998877", "couleur": "Noir",
                 "statut": "en_possession"})
bien = data_of(r)
BIEN = bien.get("id")
check("bien pré-enregistré (en_possession) -> 201", r.status_code == 201,
      str(r.status_code) + str(json_of(r)))
check("statut = en_possession", bien.get("statut") == "en_possession",
      str(bien.get("statut")))

r = C.get(f"{P}/objets?statut=en_possession", headers=auth(T_A))
check("mes biens listés pour le propriétaire",
      any(o["id"] == BIEN for o in data_of(r)), str(len(data_of(r))))

# photo du bien
r = C.post(
    f"{P}/preuves",
    headers=auth(T_A),
    data={"entite_type": "objet", "entite_id": str(BIEN), "type_preuve": "photo",
          "fichier": (io.BytesIO(PNG), "ordinateur.png")},
    content_type="multipart/form-data",
)
photo = data_of(r)
check("photo du bien téléversée", r.status_code == 201, str(r.status_code) + str(json_of(r)))

# partage vers un ami
r = C.post(f"{P}/objets/{BIEN}/partager", headers=auth(T_A),
           json={"destinataires": [ID_B], "message": "Regarde, ceci m'a été volé."})
partage = data_of(r)
check("partage de l'objet -> 201", r.status_code == 201, str(r.status_code) + str(json_of(r)))
check("destinataire enregistré", ID_B in (partage.get("destinataires") or []),
      str(partage))

# le destinataire voit le partage
r = C.get(f"{P}/partages", headers=auth(T_B))
recus = data_of(r)
check("ami : partage reçu listé", any(p_["id_objet"] == BIEN for p_ in recus),
      str(len(recus)))
check("ami : payload avec l'objet complet",
      all("objet" in p_ for p_ in recus), str(len(recus)))

# ... et peut ouvrir l'objet ainsi que ses images
r = C.get(f"{P}/objets/{BIEN}", headers=auth(T_B))
check("ami : détail de l'objet partagé -> 200", r.status_code == 200, str(r.status_code))
r = C.get(f"{P}/preuves?entite_type=objet&entite_id={BIEN}", headers=auth(T_B))
check("ami : images du bien accessibles", r.status_code == 200 and len(data_of(r)) >= 1,
      str(r.status_code) + str(data_of(r)))

# ... mais pas de droit de changer le statut
r = C.post(f"{P}/objets/{BIEN}/statut", headers=auth(T_B), json={"statut": "declare_vol"})
check("ami : changement de statut refusé -> 403", r.status_code == 403, str(r.status_code))

# notification de partage
r = C.get(f"{P}/notifications", headers=auth(T_B))
check("ami notifié du partage",
      any(n["type"] == "partage" for n in data_of(r)),
      str(sorted({n["type"] for n in data_of(r)})))

# hors partage : invisible
r = C.get(f"{P}/objets/{BIEN}", headers=auth(T_X))
check("tiers : objet non partagé -> 404", r.status_code == 404, str(r.status_code))
r = C.get(f"{P}/partages", headers=auth(T_X))
check("tiers : aucun partage reçu", json_of(r).get("data") == [],
      str(json_of(r).get("data")))

# double partage : idempotent (pas d'erreur, pas de doublon)
r = C.post(f"{P}/objets/{BIEN}/partager", headers=auth(T_A),
           json={"destinataires": [ID_B]})
check("partage répété sans erreur", r.status_code == 201, str(r.status_code))
check("partage répété sans doublon", (data_of(r).get("total") == 0), str(data_of(r)))

# passage en vol : la police voit desormais l'objet
r = C.post(f"{P}/objets/{BIEN}/statut", headers=auth(T_A), json={"statut": "declare_vol"})
check("propriétaire : en_possession -> declare_vol", r.status_code == 200,
      str(r.status_code) + str(json_of(r)))
r = C.get(f"{P}/objets?statut=declare_vol", headers=auth(T_POL))
check("police : l'objet volé apparait dans sa file",
      any(o["id"] == BIEN for o in data_of(r)), str(len(data_of(r))))

# marquage lu
r = C.get(f"{P}/partages", headers=auth(T_B))
partage_id = next((p_["id"] for p_ in data_of(r) if p_["id_objet"] == BIEN), None)
if partage_id:
    r2 = C.post(f"{P}/partages/{partage_id}/lu", headers=auth(T_B))
    check("partage marqué comme lu -> 200", r2.status_code == 200, str(r2.status_code))
else:
    check("partage marqué comme lu -> 200", False, "partage introuvable")

# le bien ne doit plus figurer dans « mes biens »
r = C.get(f"{P}/objets?statut=en_possession", headers=auth(T_A))
check("bien retiré de la liste des biens après vol",
      not any(o["id"] == BIEN for o in data_of(r)), str(len(data_of(r))))



# ============================================ MODIFICATION ET SUPPRESSION DU BIEN

r = C.post(f"{P}/objets", headers=auth(T_A),
           json={"id_type": 4, "marque": "Apple", "model": "MacBook Pro",
                 "numero_serie": "AP-112233", "statut": "en_possession"})
bien2 = data_of(r)
BIEN2 = bien2.get("id")
check("second bien cree", r.status_code == 201, str(r.status_code))

# --- modification par le proprietaire (objets.maj)
r = C.patch(f"{P}/objets/{BIEN2}", headers=auth(T_A),
            json={"marque": "Lenovo", "model": "ThinkPad X1", "couleur": "Noir mat"})
maj = data_of(r)
check("proprietaire : modification -> 200", r.status_code == 200,
      str(r.status_code) + str(json_of(r))[:200])
check("modification enregistree (marque)",
      maj.get("marque") == "Lenovo", str(maj.get("marque")))
check("modification enregistree (modele)",
      maj.get("model") == "ThinkPad X1", str(maj.get("model")))

# --- un ami VOIT le bien (nouveau perimetre : les amis voient mes objets)
# --- mais il ne peut ni le modifier ni le supprimer
r = C.patch(f"{P}/objets/{BIEN2}", headers=auth(T_B), json={"marque": "Pirate"})
check("ami : modification refusee (403, visible sans etre proprietaire)",
      r.status_code == 403, str(r.status_code))

# --- un tiers hors amitie ne voit toujours pas la fiche
r = C.patch(f"{P}/objets/{BIEN2}", headers=auth(T_X), json={"marque": "Pirate"})
check("intrus : objet toujours invisible -> 404", r.status_code == 404, str(r.status_code))

# --- suppression par un ami
r = C.delete(f"{P}/objets/{BIEN2}", headers=auth(T_B))
check("ami : suppression refusee -> 403", r.status_code == 403, str(r.status_code))

# --- suppression par le proprietaire
r = C.delete(f"{P}/objets/{BIEN2}", headers=auth(T_A))
check("proprietaire : suppression -> 200", r.status_code == 200,
      str(r.status_code) + str(json_of(r)))
r = C.get(f"{P}/objets/{BIEN2}", headers=auth(T_A))
check("bien supprime (404 apres suppression douce)", r.status_code == 404, str(r.status_code))
r = C.get(f"{P}/objets?statut=en_possession", headers=auth(T_A))
check("le bien supprime disparait de l'inventaire",
      not any(o["id"] == BIEN2 for o in data_of(r)), str(len(data_of(r))))

# --- la police peut elle aussi supprimer ? (oui, si elle a objets.supprimer)
r = C.post(f"{P}/objets", headers=auth(T_A),
           json={"id_type": 1, "marque": "Yamaha", "model": "XTZ", "statut": "en_possession"})
bien3 = data_of(r)
BIEN3 = bien3.get("id")
r = C.delete(f"{P}/objets/{BIEN3}", headers=auth(T_POL))
check("policier simple : suppression refusee -> 403 (droit reserve)",
      r.status_code == 403, str(r.status_code))
r = C.delete(f"{P}/objets/{BIEN3}", headers=auth(T_ADMIN))
check("admin : suppression d'un bien -> 200", r.status_code == 200,
      str(r.status_code) + str(json_of(r)))



# --------------------------- le policier est aussi citoyen dans sa vie privee

r = C.post(f"{P}/objets", headers=auth(T_POL),
           json={"id_type": 1, "marque": "Suzuki", "model": "GN 125",
                 "numero_serie": "SZ-778899", "statut": "en_possession"})
bien_pol = data_of(r)
check("policier : creation de SON bien -> 201", r.status_code == 201,
      str(r.status_code) + str(json_of(r))[:200])
check("bien du policier au statut en_possession",
      bien_pol.get("statut") == "en_possession", str(bien_pol.get("statut")))

r = C.get(f"{P}/objets?statut=en_possession", headers=auth(T_POL))
check("policier : son bien figure dans son inventaire",
      any(o["id"] == bien_pol.get("id") for o in data_of(r)), str(len(data_of(r))))

# ... il peut le supprimer lui-meme
r = C.delete(f"{P}/objets/{bien_pol.get('id')}", headers=auth(T_POL))
check("policier : suppression de SON bien -> 200", r.status_code == 200,
      str(r.status_code) + str(json_of(r)))

# ... mais pas celui d'un autre (meme avec objets.supprimer)
r = C.post(f"{P}/objets", headers=auth(T_A),
           json={"id_type": 3, "marque": "Autre", "model": "Test",
                 "numero_serie": "OT-001122", "statut": "en_possession"})
bien_autrui = data_of(r)
r = C.delete(f"{P}/objets/{bien_autrui.get('id')}", headers=auth(T_POL))
check("policier : suppression du bien d AUTRUI -> 403", r.status_code == 403,
      str(r.status_code))
C.delete(f"{P}/objets/{bien_autrui.get('id')}", headers=auth(T_A))

# le policier peut aussi declarer une alerte
r = C.post(f"{P}/alertes", headers=auth(T_POL),
           json={"id_type_alerte": 1, "contenu": "Alerte déclarée par un agent en service.",
                 "latitude": -4.325, "longitude": 15.31})
check("policier : creation d une alerte -> 201", r.status_code == 201,
      str(r.status_code) + str(json_of(r))[:160])


# ============================================================================= RBAC

r = C.post(f"{P}/alertes", headers=auth(T_X),
           json={"id_type_alerte": 1, "contenu": "Test"})
check("alerte sans GPS ni commissariat -> 422", r.status_code == 422, str(r.status_code))
check("la 422 indique comment résoudre", "latitude" in (json_of(r).get("errors") or {}),
      str(json_of(r).get("errors"))[:160])

r = C.get(f"{P}/alertes", headers=auth(T_A))
check("citoyen : alertes visibles = les siennes",
      all(a["id_user"] == ID_A for a in data_of(r)), str(len(data_of(r))))

r = C.get(f"{P}/alertes?statut=bidon", headers=auth(T_POL))
check("filtre statut invalide -> 422", r.status_code == 422, str(r.status_code))
r = C.get(f"{P}/alertes?niveau_urgence=bidon", headers=auth(T_POL))
check("filtre urgence invalide -> 422", r.status_code == 422, str(r.status_code))

r = C.get(f"{P}/audit?per_page=100", headers=auth(T_ADMIN))
actions = {e["action"] for e in data_of(r)}
attendues = {"alerte_creee", "alerte_prise_en_charge", "alerte_statut", "cas_cree",
             "intervention_creee", "preuve_televersee", "objet_declare",
             "demande_envoyee", "demande_reponse", "cas_maj"}
check("l'audit trace le cycle complet", attendues <= actions,
      str(sorted(actions)))
check("l'audit trace aussi les échecs de connexion",
      "connexion_echec" in actions, str(sorted(a for a in actions if "connexion" in a)))


# ========================================== UTILISATEUR ASSOCIE A UN ROLE (ET SES PERMISSIONS)

# 1) creation d'un compte rattache a un role
suffixe_role = secrets.token_hex(4)
r = C.post(
    f"{P}/users",
    headers=auth(T_ADMIN),
    json={
        "nom": "ENQ", "prenom": "Test",
        "email": f"enq.{suffixe_role}@test.cd",
        "telephone": f"+2437{secrets.randbelow(10**8):08d}",
        "password": "Motdepasse2026",
        "roles": ["enqueteur"],
        "matricule_police": f"ENQ-{suffixe_role[:6].upper()}",
    },
)
compte = data_of(r)
utilisateur = compte.get("user") or {}
check("creation avec role -> 201", r.status_code == 201, str(r.status_code) + str(json_of(r))[:200])
check("role enqueteur rattache a l'utilisateur",
      "enqueteur" in (utilisateur.get("roles") or []), str(utilisateur.get("roles")))
check("les permissions du role sont rendues avec le compte",
      "cas.creer" in (utilisateur.get("permissions") or []),
      str((utilisateur.get("permissions") or [])[:6]))
ID_ENQ2 = utilisateur.get("id")
T_ENQ2 = compte.get("access_token")

# 2) le compte voit effectivement ses permissions via /auth/me
r = C.get(f"{P}/auth/me", headers=auth(T_ENQ2))
moi = data_of(r)
check("/auth/me expose les permissions du role",
      "cas.creer" in (moi.get("permissions") or []), str((moi.get("permissions") or [])[:6]))

# 3) changement de role par le super administrateur
r = C.put(f"{P}/users/{ID_ENQ2}/roles", headers=auth(T_ADMIN),
          json={"roles": ["citoyen", "policier"]})
maj = data_of(r)
check("attribution de roles -> 200", r.status_code == 200,
      str(r.status_code) + str(json_of(r))[:200])
check("les nouveaux roles sont enregistres",
      sorted(maj.get("roles") or []) == ["citoyen", "policier"], str(maj.get("roles")))
check("les permissions suivent le role (alertes.assigner)",
      "alertes.assigner" in (maj.get("permissions") or []),
      str((maj.get("permissions") or [])[:8]))
check("l'ancien role a disparu", "enqueteur" not in (maj.get("roles") or []),
      str(maj.get("roles")))

# 4) apres reconnexion, le compte a bien les permissions du nouveau role
r = C.post(f"{P}/auth/login", json={"email": f"enq.{suffixe_role}@test.cd",
                                    "password": "Motdepasse2026"})
check("reconnexion apres changement de role", r.status_code == 200, str(r.status_code))
r = C.get(f"{P}/auth/me", headers=auth(data_of(r).get("access_token")))
check("/auth/me reflete le nouveau role (alertes.assigner)",
      "alertes.assigner" in (data_of(r).get("permissions") or []),
      str(data_of(r).get("roles")))

# 5) seul le super administrateur peut modifier les roles
r = C.put(f"{P}/users/{ID_ENQ2}/roles", headers=auth(T_POL), json={"roles": ["admin"]})
check("policier : attribution de roles refusee -> 403", r.status_code == 403,
      str(r.status_code))

# 6) role inconnu refuse
r = C.put(f"{P}/users/{ID_ENQ2}/roles", headers=auth(T_ADMIN), json={"roles": ["magicien"]})
check("role inconnu -> 422", r.status_code == 422, str(r.status_code))
check("le role inconnu est signale", "roles" in (json_of(r).get("errors") or {}),
      str(json_of(r).get("errors")))

# 7) remise en etat
r = C.put(f"{P}/users/{ID_ENQ2}/roles", headers=auth(T_ADMIN), json={"roles": ["citoyen"]})
check("remise a citoyen -> 200", r.status_code == 200, str(r.status_code))


# ============================================================================= BILAN

reussis = sum(1 for c, _ in RESULTATS if c)
_bilan()
sys.exit(0 if reussis == len(RESULTATS) else 1)
