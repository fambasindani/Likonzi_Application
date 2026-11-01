# API Sécurité Sociale v2 — Backend

Application de sécurité pour la **RDC (Police / Citoyens)** : alertes citoyennes,
dossiers policiers, interventions, preuves, objets volés, géolocalisation.

- **SGBD** : MySQL 8 (`securite_sociale_v2`)
- **Framework** : Flask 3 + **SQLAlchemy 2.0** (ORM, plus de `mysql.connector`)
- **Auth** : JWT PyJWT (access 30 min / refresh 14 j, révocable via `token_denylist`)
- **RBAC** : tables `roles` / `permissions` = **source unique** des droits
- **Audit** : `audit_logs` rempli dans la même transaction que l'action

---

## 1. Démarrage

```bash
# 1. Base de données (une seule fois) — depuis la racine du projet
C:\laragon\bin\mysql\mysql-8.0.30-winx64\bin\mysql.exe -u root --default-character-set=utf8mb4 < securite_sociale_v2.sql

# 2. Environnement Python (déjà créé : Backend\.venv)
cd Backend
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt

# 3. Configuration
copy .env.example .env        # puis adapter DB_*, SECRET_KEY, JWT_SECRET_KEY

# 4. Lancer
.venv\Scripts\python.exe app.py
```

Sur Linux/macOS : `python3 -m venv .venv && .venv/bin/pip install -r requirements.txt && .venv/bin/python app.py`

**Compte de démarrage** (créé par le script SQL) :

| Champ | Valeur |
|---|---|
| e-mail | `admin@securite.cd` |
| mot de passe | `Admin@2026` |
| rôle | `super_admin` |

> ⚠️ À changer dès la première connexion en production.

### Commandes CLI

```bash
.venv\Scripts\flask --app app.py check-db      # vérifie la connexion + les tables
.venv\Scripts\flask --app app.py init-db       # db.create_all() (filet de sécurité)
.venv\Scripts\flask --app app.py create-admin --email a@b.cd --password Mot2Passe
```

### Tests

```bash
.venv\Scripts\python.exe tests\smoke_test.py     # 66 vérifications — socle auth / utilisateurs
.venv\Scripts\python.exe tests\test_metier.py    # 110 vérifications — alertes, dossiers, preuves…
.venv\Scripts\python.exe tests\test_temps_reel.py # 27 vérifications — Socket.IO + rate limiting
.venv\Scripts\python.exe -m pytest               # 4 tests : lance les 3 suites + lint
.venv\Scripts\ruff.exe check app app.py tests    # lint (0 erreur attendu)
```

> `requirements-dev.txt` : pytest est figé `<9` car pytest 9 utilise
> `dataclasses(slots=True)`, inutilisable sous **Python 3.10.0**.

---

## 2. Structure

```
Backend/
├── app.py                    # point d'entrée
├── .env / .env.example       # configuration
├── requirements.txt
├── requirements-dev.txt      # ruff + pytest
├── pyproject.toml            # configuration ruff + pytest
├── app/
│   ├── __init__.py           # create_app() + CLI
│   ├── config.py             # Config / Development / Testing / Production
│   ├── extensions.py         # db, bcrypt, cors, socketio
│   ├── realtime.py           # Socket.IO : salles, auth à la connexion, émissions
│   ├── exceptions.py         # ApiError, NotFoundError, ForbiddenError…
│   ├── models/               # miroir exact du schéma SQL
│   │   ├── geo.py            # provinces, villes, commissariats, localisations
│   │   ├── user.py           # users + RBAC (roles, permissions)
│   │   ├── security.py       # verification_tokens, token_denylist
│   │   ├── alerte.py         # typealertes, alertes
│   │   ├── cas.py            # cas, interventions
│   │   ├── objet.py          # type_objets, objets
│   │   ├── preuve.py         # preuves (SHA-256)
│   │   ├── social.py         # demandes, notes, notifications
│   │   └── audit.py          # audit_logs
│   ├── services/             # logique métier (les routes ne font que du transport)
│   │   ├── auth_service.py   # register, login, refresh, OTP, reset
│   │   ├── user_service.py   # CRUD, avatar, statuts, rôles
│   │   ├── alerte_service.py # création citoyenne, file, transitions de statut
│   │   ├── cas_service.py    # dossiers + interventions
│   │   ├── preuve_service.py # upload, SHA-256, vérification d'intégrité
│   │   ├── objet_service.py  # déclaration, recherche, transitions
│   │   ├── geo_service.py    # Haversine, boîtes englobantes, proximité
│   │   ├── social_service.py # demandes, messages, notifications
│   │   ├── notification_service.py
│   │   ├── audit_service.py  # journalisation
│   │   ├── validators.py     # Payload : collecte toutes les erreurs (422 groupée)
│   │   └── mailer.py         # SMTP ou journalisation si MAIL_ENABLED=false
│   ├── api/
│   │   ├── auth.py           # /api/v1/auth/*
│   │   ├── users.py          # /api/v1/users/*
│   │   ├── alertes.py        # /api/v1/alertes/*
│   │   ├── cas.py            # /api/v1/cas/*, /api/v1/interventions/*
│   │   ├── objets.py         # /api/v1/objets/*
│   │   ├── preuves.py        # /api/v1/preuves/*
│   │   ├── geo.py            # /api/v1/positions, /api/v1/proximite/*
│   │   ├── social.py         # /api/v1/demandes, /amis, /messages, /notifications
│   │   ├── meta.py           # /api/v1/health, /roles, /provinces, /audit…
│   │   └── errors.py         # erreurs JSON homogènes
│   └── utils/
│       ├── security.py       # émission/vérification JWT, OTP
│       ├── decorators.py     # login_required, require_permission, require_role
│       ├── ratelimit.py      # fenêtre glissante (429 + Retry-After)
│       ├── responses.py      # ok / created / paginated
│       └── payload.py        # JSON + form-data
├── tests/
│   ├── smoke_test.py         # socle auth / utilisateurs (66)
│   ├── test_metier.py        # alertes, dossiers, preuves, objets, geo, social (110)
│   ├── test_temps_reel.py    # Socket.IO + rate limiting (27)
│   └── test_suite.py         # runner pytest
├── static/                   # avatars + images historiques de l'app mobile
└── legacy/                   # ancien main.py + controllers (mysql.connector)
```

---

## 3. Points d'entrée de l'API

Toutes les réponses partagent la même enveloppe :

```json
{ "success": true,  "message": "...", "data": {...}, "meta": { "page": 1, "total": 42 } }
{ "success": false, "message": "...", "code": "validation_failed", "errors": { "email": ["..."] } }
```

### Authentification — `/api/v1/auth`

| Méthode | Chemin | Accès | Description |
|---|---|---|---|
| POST | `/register` | public | Inscription (rôle `citoyen` uniquement) |
| POST | `/login` | public | Connexion → access + refresh token |
| POST | `/refresh` | public | Prolonge la session |
| POST | `/logout` | connecté | Révoque réellement le jeton (denylist) |
| GET | `/me` | connecté | Profil + rôles + permissions |
| PATCH | `/me` | connecté | Modifier son propre profil |
| POST | `/change-password` | connecté | Changement de mot de passe |
| POST | `/send-verification` | connecté | Émet un code e-mail/téléphone |
| POST | `/verify` | connecté | Valide le code |
| POST | `/forgot-password` | public | Demande de réinitialisation |
| POST | `/reset-password` | public | Réinitialise avec le code |

### Comptes — `/api/v1/users`

| Méthode | Chemin | Permission requise |
|---|---|---|
| GET | `/` | `users.lire` |
| POST | `/` | `users.creer` (création de comptes policiers) |
| GET | `/<id>` | `users.lire` |
| PATCH | `/<id>` | `users.maj` |
| POST | `/<id>/avatar` | propriétaire ou `users.suspendre` |
| PUT | `/<id>/roles` | rôle `super_admin` |
| POST | `/<id>/statut` | `users.suspendre` |
| DELETE | `/<id>` | `users.supprimer` (suppression **douce**) |

### Référentiels — `/api/v1`

`/health`, `/roles`, `/permissions` (`rbac.gerer`), `/provinces`, `/villes`,
`/commissariats` (`commissariats.lire`), `/type-alertes`, `/type-objets`,
`/audit` (`audit.lire`), `/config-public`.

### Alertes — `/api/v1/alertes`

| Méthode | Chemin | Permission | Description |
|---|---|---|---|
| GET | `/types` | connecté | Types d'alertes actifs |
| POST | `/` | `alertes.creer` | Déclenchement citoyen (affectation auto du commissariat le plus proche) |
| GET | `/` | `alertes.lire` | Liste selon le périmètre (citoyen = les siennes, policier = son commissariat) |
| GET | `/<id>` | `alertes.lire` | Détail + preuves rattachées |
| POST | `/<id>/prendre-en-charge` | `alertes.assigner` | Le policier s'attribue l'alerte |
| POST | `/<id>/assigner` | `alertes.assigner` | Attribution à un autre policier |
| PATCH | `/<id>/statut` | `alertes.traiter` | Transitions contrôlées + `date_resolution` |
| POST | `/<id>/ouvrir-cas` | `cas.creer` | Ouvre un dossier à partir de l'alerte |
| GET | `/autour-de-moi` | `geo.proximite` | `?lat=&lon=&rayon_km=` (Haversine) |
| DELETE | `/<id>` | `alertes.supprimer` | Suppression douce |

### Dossiers — `/api/v1/cas` et `/api/v1/interventions`

| Méthode | Chemin | Permission |
|---|---|---|
| POST `/cas` · GET `/cas` · GET `/cas/<id>` | `cas.creer` / `cas.lire` / `cas.lire` |
| PATCH `/cas/<id>` · POST `/cas/<id>/cloturer` · DELETE `/cas/<id>` | `cas.maj` / `cas.cloturer` / `cas.supprimer` |
| POST `/cas/<id>/interventions` · GET `/cas/<id>/interventions` | `interventions.creer` / `interventions.lire` |
| GET `/interventions` · GET `/interventions/<id>` · PATCH `/interventions/<id>` | `interventions.lire` / `interventions.maj` |

Filtres : `?statut=` `?priorite=` `?type_cas=` `?q=` `?id_commissariat=` `?page=` `?per_page=`

### Objets volés — `/api/v1/objets`

`GET /types` · `POST /` (`objets.creer`) · `GET /` (`objets.lire`) · `GET /recherche?q=` (immatriculation, châssis, n° de série, marque…) ·
`GET /<id>` · `PATCH /<id>` · `POST /<id>/statut` (`objets.maj`) · `DELETE /<id>` (`objets.supprimer`)

Transitions limitées (`declare_vol → recherche → retrouve → restitue`) et, pour un
propriétaire, **seulement** `recherche` / `retrouve`.

### Preuves — `/api/v1/preuves`

| Méthode | Chemin | Description |
|---|---|---|
| GET | `/types-autorises` | Liste blanche des extensions + taille max |
| POST | `/` | Téléversement, **SHA-256 calculé en flux** (`entite_type`, `entite_id`, `type_preuve`, `fichier`) |
| GET | `/` | `?entite_type=&entite_id=` |
| GET | `/<id>/verifier` | Recalcule le hash et compare → `conforme` / `ALTÉRATION DÉTECTÉE` |
| GET | `/<id>/telecharger` | Pièce jointe |
| DELETE | `/<id>` | Suppression douce (fichier conservé pour l'audit) |

### Géolocalisation — `/api/v1`

`POST /positions` · `GET /positions/moi` · `GET /positions?vue=derniere` (`geo.lire`) ·
`GET /proximite/commissariats?lat=&lon=&rayon_km=` (`geo.proximite`)

### Social — `/api/v1`

`GET|POST /demandes` · `POST /demandes/<id>/repondre` · `DELETE /demandes/<id>` · `GET /amis` ·
`GET /messages/<id>` · `POST /messages` · `POST /messages/<id>/lu` · `GET /messages-non-lus` ·
`GET /notifications` · `POST /notifications/<id>/lu` · `POST /notifications/tout-lu`

### Exemple

```bash
curl -X POST http://127.0.0.1:1200/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@securite.cd","password":"Admin@2026"}'

curl http://127.0.0.1:1200/api/v1/users \
  -H "Authorization: Bearer <access_token>"
```

### Temps réel — Socket.IO

`python app.py` monte le middleware Engine.IO : l'endpoint `/socket.io/` répond
sur le **même port** que l'API (aucun broker requis, `async_mode=threading`).

```js
import { io } from 'socket.io-client';

const socket = io('http://192.168.x.x:1200', { auth: { token: accessToken } });

socket.on('connect', () => console.log('connecté'));
socket.on('alerte_nouvelle',  (d) => mappeNouvelleAlerte(d)); // salle commissariat:<id>
socket.on('alerte_assignee',  (d) => notifieLePolicier(d));   // salle user:<id> + commissariat
socket.on('alerte_mise_a_jour',(d) => rafraichitLaFiche(d));
socket.on('notification',     (d) => incLeBadge(d));          // toutes les notifications
socket.on('dossier_ouvert',   (d) => ouvreLeDossier(d));
socket.on('intervention_enregistree', (d) => rafraichitLeDossier(d));
```

Côté serveur, la connexion est **refusée** (`return False`) si le jeton est
absent, expiré, révoqué ou si le compte est inactif. Salles rejointes
automatiquement : `user:<id>` et, pour les membres des forces,
`commissariat:<id>`.

Les émissions sont programmées via `realtime.prevoir(...)` puis vidées sur
`after_commit` : **un rollback annule l'événement**, un client n'est jamais
prévenu d'un fait qui n'a pas été persisté.

### Limitation de débit

| Route | Clé | Défaut |
|---|---|---|
| `POST /auth/login` | IP + e-mail | 10 / 5 min |
| `POST /auth/register` | IP | 10 / h |
| `POST /auth/forgot-password`, `/reset-password` | IP + e-mail | 5 / 5 min |
| `POST /auth/send-verification`, `/verify` | IP | 10 / 5 min |

Réponse `429` `{ "code": "rate_limited" }` avec l'en-tête `Retry-After`.
Seuils ajustables dans `.env` (`LOGIN_MAX`, `INSCRIPTION_MAX`, …) et
désactivables avec `RATE_LIMIT_ENABLED=false`. Une connexion réussie remet le
compteur du compte à zéro.

---

## 4. Décisions d'architecture

| Sujet | Choix | Pourquoi |
|---|---|---|
| Accès aux données | **SQLAlchemy 2.0 typé** (`Mapped[...]`) | Pas de SQL en dur, plus aucune injection possible, requêtes navigables |
| Droits | Tables RBAC **seules** | `users.role` ENUM supprimé → plus de double source de vérité |
| Jetons | PyJWT maison + `token_denylist` | Logout réel et révocation après compromission |
| Suppressions | **Douces** (`deleted_at`) + `RESTRICT` sur alertes/objets/cas | Une preuve judiciaire ne doit jamais disparaître avec un compte |
| Validation | `Payload` collecte **toutes** les erreurs | Une seule réponse 422 avec le détail par champ |
| Périmètre | Chaque service applique son propre `scope` | Un citoyen ne voit que ses alertes/dossiers, un policier son commissariat |
| Proximité | Boîte englobante en SQL puis **Haversine** en Python | Indexable sans index spatial, précis au résultat près |
| Preuves | Liste blanche d'extensions + hash en lecture flux | Ni exécutable stocké, ni fichier entier en mémoire |
| Audit | Écrit dans la **même transaction** | Pas d'action sans trace, pas de trace orpheline |
| Débit | Fenêtre glissante en mémoire, clé `IP + identifiant` | Un attaquant ne bloque pas les autres comptes ; 429 + `Retry-After` |
| Temps réel | Socket.IO (`async_mode=threading`) + salles JWT | Push instantané, aucun broker requis pour une instance |
| Émissions | File d'attente vidée sur `after_commit` (et non sur `rollback`) | On ne prévient jamais un client d'un événement annulé |
| Dépendances | `.venv` dédié | Évite de casser le Python global (Werkzeug 3 / Flask 2.3 incompatibles) |

---

## 5. Ce qui reste à faire

Fait (cf. `tests/test_metier.py` et `tests/test_temps_reel.py`) :

- [x] `alertes` — déclenchement citoyen, affectation par proximité, file du commissariat, assignation, transitions de statut
- [x] `cas` + `interventions` — ouverture depuis une alerte, instruction, clôture
- [x] `preuves` — téléversement, SHA-256 en flux, vérification d'intégrité, liste blanche d'extensions
- [x] `objets` — déclaration, recherche (immat/châssis/série), transitions de statut
- [x] Géolocalisation — positions, dernières positions, commissariats/alertes autour de moi (Haversine)
- [x] Social — demandes d'amis (dans les deux sens), messages, notifications
- [x] **Temps réel Socket.IO** — auth par JWT, salles `user:<id>` et `commissariat:<id>`, push des alertes/notifications
- [x] **Rate limiting** — login, inscription, OTP, réinitialisation (429 + `Retry-After`)
- [x] **pytest** — `python -m pytest` lance les 3 suites + le lint

Reste :

- [ ] Migration des écrans mobiles vers `/api/v1` (`securite/Composant/ApiUrl*.js`)
- [ ] Mail réel (`MAIL_ENABLED=true`) et envoi SMS pour la vérification téléphone
- [ ] Export PDF des dossiers / procès-verbaux
- [ ] Statistiques par commissariat (tableau de bord)
- [ ] Requêtes spatiales MySQL (`POINT SRID 4326` + `SPATIAL INDEX`) si le volume explose
- [ ] **Production** : HTTPS, en-têtes de sécurité, rotation des secrets, sauvegardes chiffrées
  (le rate-limiting est en mémoire → passer sur Redis/MySQL en multi-nœud)

---

## 6. Sécurité — état des lieux

Fait :

- mots de passe bcrypt (coût 12), jamais renvoyés aux clients
- JWT signés, expirants, révocables ; `iss` vérifié
- rôles/permissions vérifiés côté serveur à chaque route
- SQL uniquement via l'ORM (requêtes paramétrées)
- audit IP + user-agent sur les actions sensibles
- politique de mot de passe (longueur + lettre + chiffre)
- OTP hashés en HMAC-SHA256, plafond de tentatives

Reste à faire : rate-limiting, HTTPS obligatoire, en-têtes de sécurité,
rotation des secrets, sauvegardes chiffrées.

---

## 7. Déploiement — PythonAnywhere (avec `ocr/` + `backend/`)

Structure retenue sur le serveur :

```text
/home/sindani/monapplication/
├── ocr/                      # projet OCR  → monté à la racine  « / »
├── backend/                  # CE projet   → monté sous        « /backend »
│   ├── app/                  #   package Flask (factory create_app)
│   ├── app.py                #   point d'entrée local + objet WSGI `app`
│   └── .env                  #   à créer sur place (jamais versionné)
├── venv/                     # virtualenv python3.10 partagé
└── securite_sociale_v2.sql   # schéma de la base
```

> Le dossier doit s'appeler exactement `backend` (minuscules) : le WSGI fait
> `import backend.app`, et la casse compte sur Linux.

### 7.1 Ce qu'il faut installer

Un seul virtualenv pour les deux projets — celui qui existe déjà (`venv`) :

```bash
cd /home/sindani/monapplication

# le code : git clone, ou téléversement du dépôt puis renommage Backend -> backend
ls backend/requirements.txt

python3.10 -m venv venv            # seulement si venv n'existe pas
venv/bin/pip install --upgrade pip
venv/bin/pip install -r backend/requirements.txt        # runtime (Flask, SQLAlchemy, Socket.IO, PyMySQL…)
venv/bin/pip install -r backend/requirements-dev.txt    # optionnel : ruff + pytest
```

Rien d'autre : `PyMySQL` est pur Python (aucun compilateur), MySQL et les
librairies système sont déjà fournis par PythonAnywhere (Python 3.10).

Le fichier `wsgi.py` ajoute `venv/lib/python3.10/site-packages` à `sys.path` :
c'est cette installation qui est lue au démarrage.

### 7.2 Base de données MySQL

1. Onglet **MySQL** du tableau de bord : créer une base et noter
   *host / user / password / name* (MySQL dépend du plan : vérifiez l'onglet).
2. Importer le schéma (23 tables, 6 vues, 4 triggers, seeds, compte admin) :

```bash
mysql -h <HOST> -u <USER> -p --default-character-set=utf8mb4 \
      < /home/sindani/monapplication/securite_sociale_v2.sql
```

Le fichier commence par `CREATE DATABASE IF NOT EXISTS securite_sociale_v2;`
puis `USE …` : nommez la base de la même façon, ou éditez ces deux lignes.

### 7.3 Fichier `.env` du backend (jamais versionné — à créer sur place)

```bash
cd /home/sindani/monapplication/backend
cp .env.example .env
```

Renseigner au minimum :

| Variable | Valeur |
|---|---|
| `FLASK_ENV` | `production` |
| `SECRET_KEY` / `JWT_SECRET_KEY` | deux valeurs **neuves** : `python3 -c "import secrets; print(secrets.token_urlsafe(48))"` |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | coordonnées de l'onglet MySQL |
| `CORS_ORIGINS` | `*` ou l'URL de l'application mobile |
| `MAIL_ENABLED` | `false` tant que le SMTP n'est pas configuré |

`app/__init__.py` charge ce `.env` automatiquement au démarrage (chemin absolu
dérivé de `__file__` : le `os.chdir` du WSGI n'a aucune incidence).

### 7.4 Configuration WSGI (onglet **Web**)

Fichier `/var/www/sindani_pythonanywhere_com_wsgi.py` — **les deux applications
côte à côte** :

```python
import sys
import os

path = '/home/sindani/monapplication'
if path not in sys.path:
    sys.path.insert(0, path)

os.chdir(path)

venv_site_packages = '/home/sindani/monapplication/venv/lib/python3.10/site-packages'
if venv_site_packages not in sys.path:
    sys.path.insert(0, venv_site_packages)

from ocr.app import app as ocr_app

# IMPORTANT : `backend.app` désigne le PACKAGE `backend/app/` (la factory),
# pas le fichier `backend/app.py` — Python donne la priorité au paquet.
from backend.app import create_app
backend_app = create_app('production')

from werkzeug.middleware.dispatcher import DispatcherMiddleware

application = DispatcherMiddleware(ocr_app, {
    '/backend': backend_app,
})
```

Ensuite **Reload** (onglet Web) et tester `https://sindani.pythonanywhere.com/backend/api/v1/health`.

Points clés :

- `create_app('production')` force `ProductionConfig` (indépendamment du `.env`).
- `DispatcherMiddleware` retire le préfixe `/backend` avant de router : Flask et
  `/socket.io/` du backend sont donc joignables à `/backend/…`, et la racine
  reste servie par l'OCR.
- **Ne pas écrire `from backend.app import app`** : le package `backend/app/`
  gagne face au fichier `backend/app.py`, et il n'expose pas `app` (seulement
  `create_app`). Le fichier `app.py` reste le point d'entrée **local**
  (`python app.py`).
- Onglet Web → *Virtualenv* : indiquer `venv` (ou laisser le `sys.path` ci-dessus).
- **Temps réel** : si l'hébergeur ne relaie pas les WebSocket, Flask-SocketIO
  (mode `threading`) bascule en *long-polling* : tout fonctionne, notifications
  légèrement moins instantanées.

### 7.5 Fichiers statiques (optionnel)

Sans configuration, Flask sert déjà `/backend/static/…`. Pour déléguer au
serveur de fichiers (plus rapide) :

| URL | Chemin |
|---|---|
| `/backend/static/` | `/home/sindani/monapplication/backend/static` |

### 7.6 Côté application mobile

Le préfixe `/backend` doit apparaître dans les deux URL
(`securite_flutter/.env`) :

```dotenv
API_BASE_URL=https://sindani.pythonanywhere.com/backend/api/v1
SOCKET_URL=https://sindani.pythonanywhere.com/backend
```

Puis `flutter build apk --release` et réinstallation de l'APK.

Le client Socket.IO déduit automatiquement `<SOCKET_URL>/socket.io` (préfixe
compris) : aucune configuration supplémentaire n'est nécessaire côté Flutter.
