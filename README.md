# Likonzi_Application

Application mobile **LIKONZI** (Sécurité Sociale RDC) : citoyens et police
dans la même application — alertes d'urgence, dossiers d'enquête, objets volés,
preuves photo/vidéo, cartes OpenStreetMap, messagerie et notifications en
temps réel.

## Structure du dépôt

| Dossier | Contenu |
|---|---|
| `securite_flutter/` | Application Flutter (Android), `models` / `services` / `components` / `views` |
| `Backend/` | API Flask + SQLAlchemy + Socket.IO (`/api/v1`), voir `Backend/README.md` |
| `securite/` | Ancienne application React Native (archive, non maintenue) |
| `securite_sociale_v2.sql` | Schéma MySQL : 23 tables, 6 vues, 4 triggers, seeds (provinces, villes, commissariats, rôles, permissions) |

## Démarrage rapide

### 1. Base de données

```bash
mysql -u root < securite_sociale_v2.sql
```

### 2. Backend (port 1200)

```bash
cd Backend
python -m venv .venv
.venv\Scripts\pip install -r requirements.txt
copy .env.example .env        # puis renseigner SECRET_KEY, JWT_SECRET_KEY
.venv\Scripts\python run.py
```

Compte de démonstration : `admin@securite.cd` / `12345678`.

### 3. Application mobile

```bash
cd securite_flutter
flutter pub get
flutter run
```

`securite_flutter/.env` porte l'URL du backend (`API_BASE_URL`,
`SOCKET_URL`) : adapter l'IP à votre réseau.

## Sécurité

- `Backend/.env` n'est **jamais** versionné (clés JWT, mot de passe BDD).
- Les preuves judiciaires ne sont pas stockées dans le dépôt
  (`Backend/static/uploads/` ignoré), leur empreinte SHA-256 est calculée
  en flux côté serveur.
