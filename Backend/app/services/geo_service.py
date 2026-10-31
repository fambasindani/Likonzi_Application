"""Géolocalisation : distances, boîtes englobantes, positions et proximité."""
from __future__ import annotations

import math
from datetime import datetime, timedelta
from decimal import Decimal

from sqlalchemy import func

from ..extensions import db
from ..models import Alerte, Commissariat, Localisation, User
from .validators import Payload

RAYON_TERRE_KM = 6371.0088


# --------------------------------------------------------------------------- mathématiques


def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Distance en kilomètres entre deux points GPS."""
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * RAYON_TERRE_KM * math.asin(min(1.0, math.sqrt(a)))


def boite_englobante(lat: float, lon: float, rayon_km: float) -> tuple[float, float, float, float]:
    """Bornes (lat_min, lat_max, lon_min, lon_max) pour filtrer en SQL avant Haversine."""
    dlat = rayon_km / 110.574
    cos_lat = max(abs(math.cos(math.radians(lat))), 1e-6)
    dlon = rayon_km / (111.320 * cos_lat)
    # Gestion du passage par le méridien 180°
    return (lat - dlat, lat + dlat, lon - dlon, lon + dlon)


# --------------------------------------------------------------------------- positions


def enregistrer_position(data: dict, acteur) -> Localisation:
    """Insère une position (l'historique est conservé : la table n'est pas une mise à jour)."""
    p = Payload(data)
    latitude = p.decimal("latitude", requis=True, min_val=-90.0, max_val=90.0)
    longitude = p.decimal("longitude", requis=True, min_val=-180.0, max_val=180.0)
    delta_lat = p.decimal("latitude_delta", min_val=0, max_val=180)
    delta_lon = p.decimal("longitude_delta", min_val=0, max_val=180)
    precision = p.decimal("precision_metres", min_val=0, max_val=1_000_000)
    source = p.enum("source", ["gps", "reseau", "manuel"], default="gps")
    date_pos = p.datetime_("date_localisation")
    p.fail_if_errors()

    position = Localisation(
        id_user=acteur.id,
        latitude=Decimal(str(latitude)),
        longitude=Decimal(str(longitude)),
        latitude_delta=Decimal(str(delta_lat)) if delta_lat is not None else None,
        longitude_delta=Decimal(str(delta_lon)) if delta_lon is not None else None,
        precision_metres=Decimal(str(precision)) if precision is not None else None,
        source=source or "gps",
        date_localisation=date_pos or datetime.now(),
    )
    db.session.add(position)
    db.session.commit()
    return position


def derniere_position(id_user: int) -> Localisation | None:
    return (
        db.session.query(Localisation)
        .filter(Localisation.id_user == id_user)
        .order_by(Localisation.date_localisation.desc())
        .first()
    )


def lister_positions(
    page: int = 1,
    per_page: int = 50,
    id_user: int | None = None,
    depuis: datetime | None = None,
) -> tuple[list[Localisation], int]:
    query = db.session.query(Localisation)
    if id_user:
        query = query.filter(Localisation.id_user == id_user)
    if depuis:
        query = query.filter(Localisation.date_localisation >= depuis)
    total = query.count()
    items = (
        query.order_by(Localisation.date_localisation.desc())
        .offset((max(page, 1) - 1) * per_page)
        .limit(min(max(per_page, 1), 200))
        .all()
    )
    return items, total


# ------------------------------------------------------------------------- proximité


def _filtre_geo(query, modele, lat: float, lon: float, rayon_km: float):
    lat_min, lat_max, lon_min, lon_max = boite_englobante(lat, lon, rayon_km)
    return query.filter(
        modele.latitude.isnot(None),
        modele.longitude.isnot(None),
        modele.latitude >= lat_min,
        modele.latitude <= lat_max,
        modele.longitude >= lon_min,
        modele.longitude <= lon_max,
    )


def commissariats_proches(
    lat: float, lon: float, rayon_km: float = 25.0, limite: int = 20
) -> list[dict]:
    query = _filtre_geo(
        db.session.query(Commissariat),
        Commissariat,
        lat,
        lon,
        rayon_km,
    ).filter(Commissariat.deleted_at.is_(None), Commissariat.statut == 1)

    resultats = []
    for c in query.all():
        distance = haversine(lat, lon, float(c.latitude), float(c.longitude))
        if distance <= rayon_km:
            data = c.to_dict()
            data["distance_km"] = round(distance, 3)
            resultats.append(data)
    resultats.sort(key=lambda d: d["distance_km"])
    return resultats[:limite]


def commissariat_le_plus_proche(lat: float, lon: float, rayon_km: float = 80.0):
    proches = commissariats_proches(lat, lon, rayon_km=rayon_km, limite=1)
    if not proches:
        return None
    return db.session.get(Commissariat, proches[0]["id"])


def alertes_proches(
    lat: float,
    lon: float,
    rayon_km: float = 10.0,
    limite: int = 50,
    statuts: list[str] | None = None,
) -> list[dict]:
    query = _filtre_geo(db.session.query(Alerte), Alerte, lat, lon, rayon_km)
    query = query.filter(Alerte.deleted_at.is_(None))
    if statuts:
        query = query.filter(Alerte.statut.in_(statuts))
    else:
        query = query.filter(Alerte.statut.in_(["nouvelle", "prise_en_compte", "en_cours"]))

    resultats = []
    for a in query.order_by(Alerte.date_alerte.desc()).limit(500).all():
        distance = haversine(lat, lon, float(a.latitude), float(a.longitude))
        if distance <= rayon_km:
            data = a.to_dict()
            data["distance_km"] = round(distance, 3)
            resultats.append(data)
    resultats.sort(key=lambda d: d["date_alerte"] or "", reverse=True)
    resultats.sort(key=lambda d: d["distance_km"])
    return resultats[:limite]


# ------------------------------------------------------------------- statistiques


def cartographie_positions(plusieurs_jours: int = 7) -> list[dict]:
    """Dernière position connue de chaque utilisateur actif (vue `v_dernieres_positions`)."""
    limite = datetime.now() - timedelta(days=plusieurs_jours)
    sous = (
        db.session.query(
            Localisation.id_user.label("id_user"),
            func.max(Localisation.date_localisation).label("dmax"),
        )
        .group_by(Localisation.id_user)
        .subquery()
    )
    rows = (
        db.session.query(Localisation, User)
        .join(sous, sous.c.id_user == Localisation.id_user)
        .join(User, User.id == Localisation.id_user)
        .filter(
            sous.c.dmax == Localisation.date_localisation,
            Localisation.date_localisation >= limite,
            User.deleted_at.is_(None),
        )
        .all()
    )
    return [
        {
            "id_user": pos.id_user,
            "nom": user.nom,
            "prenom": user.prenom,
            "roles": user.role_names,
            "latitude": float(pos.latitude),
            "longitude": float(pos.longitude),
            "precision_metres": float(pos.precision_metres) if pos.precision_metres else None,
            "source": pos.source,
            "date_localisation": pos.date_localisation.isoformat(),
        }
        for pos, user in rows
    ]
