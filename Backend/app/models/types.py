"""Types MySQL typés (mirroir exact du schéma : INT UNSIGNED, ENUM, DATETIME…)."""
from __future__ import annotations

from sqlalchemy.dialects import mysql

# Colonnes identifiants
UInt = mysql.INTEGER(unsigned=True)
UBigInt = mysql.BIGINT(unsigned=True)

# Booléens métier stockés en TINYINT
TinyBool = mysql.TINYINT()
UTinyInt = mysql.TINYINT(unsigned=True)

# Géolocalisation
LatLon = mysql.DECIMAL(precision=10, scale=7)
PrecisionGeo = mysql.DECIMAL(precision=8, scale=2)

# Identifiants polymorphes (preuves, notifications)
BigInt = mysql.BIGINT()

# Fichiers
TailleFichier = mysql.BIGINT(unsigned=True)
Hash64 = mysql.CHAR(length=64)
