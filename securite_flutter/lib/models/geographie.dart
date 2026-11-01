import 'reponse_api.dart';

/// Province de la RDC.
class Province {
  Province({required this.id, required this.code, required this.nom, this.chefLieu});

  final int id;
  final String code;
  final String nom;
  final String? chefLieu;

  factory Province.brut(Map<String, dynamic> j) => Province(
        id: JsonAide.entierDefaut(j, 'id'),
        code: JsonAide.texteDefaut(j, 'code'),
        nom: JsonAide.texteDefaut(j, 'nom'),
        chefLieu: JsonAide.texte(j, 'chef_lieu'),
      );
}

/// Ville / commune.
class Ville {
  Ville({
    required this.id,
    required this.idProvince,
    required this.nom,
    this.latitude,
    this.longitude,
    this.provinceNom,
  });

  final int id;
  final int idProvince;
  final String nom;
  final double? latitude;
  final double? longitude;
  final String? provinceNom;

  factory Ville.brut(Map<String, dynamic> j) => Ville(
        id: JsonAide.entierDefaut(j, 'id'),
        idProvince: JsonAide.entierDefaut(j, 'id_province'),
        nom: JsonAide.texteDefaut(j, 'nom'),
        latitude: JsonAide.decimal(j, 'latitude'),
        longitude: JsonAide.decimal(j, 'longitude'),
        provinceNom: JsonAide.objet(j, 'province') != null
            ? JsonAide.texte(JsonAide.objet(j, 'province'), 'nom')
            : null,
      );
}

/// Commune : sous-division d'une ville (ex. Limete, Masina à Kinshasa).
class Commune {
  Commune({
    required this.id,
    required this.idVille,
    required this.nom,
    this.code,
    this.latitude,
    this.longitude,
    this.ville,
    this.province,
  });

  final int id;
  final int idVille;
  final String nom;
  final String? code;
  final double? latitude;
  final double? longitude;
  final String? ville;
  final String? province;

  factory Commune.brut(Map<String, dynamic> j) => Commune(
        id: JsonAide.entierDefaut(j, 'id'),
        idVille: JsonAide.entierDefaut(j, 'id_ville'),
        nom: JsonAide.texteDefaut(j, 'nom'),
        code: JsonAide.texte(j, 'code'),
        latitude: JsonAide.decimal(j, 'latitude'),
        longitude: JsonAide.decimal(j, 'longitude'),
        ville: JsonAide.texte(j, 'ville'),
        province: JsonAide.texte(j, 'province'),
      );

  /// Libellé hiérarchique : « Kinshasa — Limete ».
  String get libelleHierarchie {
    final parents = [ville, province].where((n) => n != null && n.isNotEmpty);
    return parents.isEmpty ? nom : '${parents.join(' — ')} — $nom';
  }
}

/// Commissariat de police.
class Commissariat {
  Commissariat({
    required this.id,
    required this.code,
    required this.nom,
    this.adresse,
    this.telephone,
    this.email,
    this.latitude,
    this.longitude,
    this.idProvince,
    this.idVille,
    this.idCommune,
    this.province,
    this.ville,
    this.commune,
    this.statut = true,
    this.responsableId,
    this.distanceKm,
  });

  final int id;
  final String code;
  final String nom;
  final String? adresse;
  final String? telephone;
  final String? email;
  final double? latitude;
  final double? longitude;
  final int? idProvince;
  final int? idVille;
  final int? idCommune;
  final String? province;
  final String? ville;
  final String? commune;
  final bool statut;
  final int? responsableId;

  /// Renseigné uniquement par les endpoints de proximité.
  final double? distanceKm;

  factory Commissariat.brut(Map<String, dynamic> j) => Commissariat(
        id: JsonAide.entierDefaut(j, 'id'),
        code: JsonAide.texteDefaut(j, 'code'),
        nom: JsonAide.texteDefaut(j, 'nom'),
        adresse: JsonAide.texte(j, 'adresse'),
        telephone: JsonAide.texte(j, 'telephone'),
        email: JsonAide.texte(j, 'email'),
        latitude: JsonAide.decimal(j, 'latitude'),
        longitude: JsonAide.decimal(j, 'longitude'),
        idProvince: JsonAide.entier(j, 'id_province'),
        idVille: JsonAide.entier(j, 'id_ville'),
        idCommune: JsonAide.entier(j, 'id_commune'),
        province: JsonAide.texte(j, 'province'),
        ville: JsonAide.texte(j, 'ville'),
        commune: JsonAide.texte(j, 'commune'),
        statut: JsonAide.booleen(j, 'statut'),
        responsableId: JsonAide.entier(j, 'responsable_id'),
        distanceKm: JsonAide.decimal(j, 'distance_km'),
      );

  bool get aCoordonnees => latitude != null && longitude != null;
}

/// Dernière position connue d'un utilisateur.
class Localisation {
  Localisation({
    required this.idUser,
    required this.latitude,
    required this.longitude,
    this.precisionMetres,
    this.source,
    this.dateLocalisation,
    this.nom,
    this.prenom,
    this.roles = const [],
  });

  final int idUser;
  final double latitude;
  final double longitude;
  final double? precisionMetres;
  final String? source;
  final DateTime? dateLocalisation;
  final String? nom;
  final String? prenom;
  final List<String> roles;

  factory Localisation.brut(Map<String, dynamic> j) => Localisation(
        idUser: JsonAide.entierDefaut(j, 'id_user'),
        latitude: JsonAide.decimal(j, 'latitude') ?? 0,
        longitude: JsonAide.decimal(j, 'longitude') ?? 0,
        precisionMetres: JsonAide.decimal(j, 'precision_metres'),
        source: JsonAide.texte(j, 'source'),
        dateLocalisation: JsonAide.date(j, 'date_localisation'),
        nom: JsonAide.texte(j, 'nom'),
        prenom: JsonAide.texte(j, 'prenom'),
        roles: (j['roles'] as List?)?.map((e) => e.toString()).toList(growable: false) ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        if (precisionMetres != null) 'precision_metres': precisionMetres,
        if (source != null) 'source': source,
      };
}
