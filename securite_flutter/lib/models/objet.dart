import 'reponse_api.dart';

/// Type d'objet volé (`GET /objets/types`).
class TypeObjet {
  TypeObjet({required this.id, required this.code, required this.description, this.icone});

  final int id;
  final String code;
  final String description;
  final String? icone;

  factory TypeObjet.brut(Map<String, dynamic> j) => TypeObjet(
        id: JsonAide.entierDefaut(j, 'id'),
        code: JsonAide.texteDefaut(j, 'code'),
        description: JsonAide.texteDefaut(j, 'description'),
        icone: JsonAide.texte(j, 'icone'),
      );
}

/// Objet déclaré volé / recherché / retrouvé.
class Objet {
  Objet({
    required this.id,
    required this.idType,
    required this.idProprietaire,
    this.marque,
    this.modele,
    this.numeroChassis,
    this.immatriculation,
    this.numeroSerie,
    this.couleur,
    this.description,
    this.dateVol,
    this.lieuVol,
    this.latitudeVol,
    this.longitudeVol,
    this.statut = 'declare_vol',
    this.idCas,
    this.typeCode,
    this.typeLibelle,
    this.proprietaireNom,
    this.proprietairePrenom,
    this.proprietaireTel,
    this.preuves = const [],
  });

  final int id;
  final int idType;
  final int idProprietaire;
  final String? marque;
  final String? modele;
  final String? numeroChassis;
  final String? immatriculation;
  final String? numeroSerie;
  final String? couleur;
  final String? description;
  final DateTime? dateVol;
  final String? lieuVol;
  final double? latitudeVol;
  final double? longitudeVol;
  final String statut;
  final int? idCas;
  final String? typeCode;
  final String? typeLibelle;
  final String? proprietaireNom;
  final String? proprietairePrenom;
  final String? proprietaireTel;
  final List<String> preuves;

  factory Objet.brut(Map<String, dynamic> j) {
    final type = JsonAide.objet(j, 'type');
    final proprio = JsonAide.objet(j, 'proprietaire');
    return Objet(
      id: JsonAide.entierDefaut(j, 'id'),
      idType: JsonAide.entierDefaut(j, 'id_type'),
      idProprietaire: JsonAide.entierDefaut(j, 'id_user_proprietaire'),
      marque: JsonAide.texte(j, 'marque'),
      modele: JsonAide.texte(j, 'model'),
      numeroChassis: JsonAide.texte(j, 'numero_chassis'),
      immatriculation: JsonAide.texte(j, 'immatriculation'),
      numeroSerie: JsonAide.texte(j, 'numero_serie'),
      couleur: JsonAide.texte(j, 'couleur'),
      description: JsonAide.texte(j, 'description'),
      dateVol: JsonAide.date(j, 'date_vol'),
      lieuVol: JsonAide.texte(j, 'lieu_vol'),
      latitudeVol: JsonAide.decimal(j, 'latitude_vol'),
      longitudeVol: JsonAide.decimal(j, 'longitude_vol'),
      statut: JsonAide.texteDefaut(j, 'statut', 'declare_vol'),
      idCas: JsonAide.entier(j, 'id_cas'),
      typeCode: JsonAide.texte(type, 'code') ?? JsonAide.texte(j, 'type_code'),
      typeLibelle: JsonAide.texte(type, 'description') ?? JsonAide.texte(j, 'type_libelle'),
      proprietaireNom: JsonAide.texte(proprio, 'nom') ?? JsonAide.texte(j, 'proprietaire_nom'),
      proprietairePrenom:
          JsonAide.texte(proprio, 'prenom') ?? JsonAide.texte(j, 'proprietaire_prenom'),
      proprietaireTel:
          JsonAide.texte(proprio, 'telephone') ?? JsonAide.texte(j, 'proprietaire_tel'),
      preuves: JsonAide.liste(j, 'preuves')
          .map((e) => JsonAide.texteDefaut(e, 'id'))
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
    );
  }

  /// Désignation courte : « Toyota Hilux — CD 4521 AB ».
  String get designation {
    final parts = [
      if (marque != null && marque!.isNotEmpty) marque!,
      if (modele != null && modele!.isNotEmpty) modele!,
    ];
    if (parts.isEmpty) return typeLibelle ?? 'Objet';
    return parts.join(' ');
  }

  String? get identifiantPrincipal => immatriculation ?? numeroChassis ?? numeroSerie;

  String? get proprietaire =>
      [proprietaireNom, proprietairePrenom].where((e) => e != null && e.isNotEmpty).join(' ');

  bool get estMien => statut == 'declare_vol' || statut == 'recherche';

  /// Transitions ouvertes au propriétaire (miroir de `objet_service`).
  List<String> get statutsPossiblesProprietaire {
    switch (statut) {
      case 'en_possession':
        // Bien pré-enregistré : seul passage possible = déclarer le vol.
        return const ['declare_vol'];
      case 'declare_vol':
        return const ['recherche', 'retrouve'];
      case 'recherche':
        return const ['recherche', 'retrouve'];
      case 'retrouve':
        return const [];
      default:
        return const [];
    }
  }

  List<String> get statutsPolice {
    switch (statut) {
      case 'declare_vol':
        return const ['recherche', 'retrouve', 'classe'];
      case 'recherche':
        return const ['retrouve', 'en_fourriere', 'classe'];
      case 'retrouve':
        return const ['restitue', 'en_fourriere'];
      case 'en_fourriere':
        return const ['restitue', 'retrouve'];
      default:
        return const [];
    }
  }

  static const List<String> tousStatuts = [
    'en_possession',
    'declare_vol',
    'recherche',
    'retrouve',
    'restitue',
    'en_fourriere',
    'classe',
  ];
}


/// Transmission d'un objet (et de ses images) — `GET/POST /partages`.
class Partage {
  Partage({
    required this.id,
    required this.idObjet,
    required this.idProprietaire,
    required this.idDestinataire,
    this.message,
    this.lu = false,
    this.datePartage,
    this.objet,
    this.proprietaireNom,
    this.proprietairePrenom,
    this.proprietaireAvatar,
  });

  final int id;
  final int idObjet;
  final int idProprietaire;
  final int idDestinataire;
  final String? message;
  final bool lu;
  final DateTime? datePartage;
  final Objet? objet;
  final String? proprietaireNom;
  final String? proprietairePrenom;
  final String? proprietaireAvatar;

  factory Partage.brut(Map<String, dynamic> j) {
    final objetJson = j['objet'] is Map<String, dynamic> ? j['objet'] as Map<String, dynamic> : null;
    final proprio = j['proprietaire'] is Map<String, dynamic>
        ? j['proprietaire'] as Map<String, dynamic>
        : null;
    return Partage(
      id: JsonAide.entierDefaut(j, 'id'),
      idObjet: JsonAide.entierDefaut(j, 'id_objet'),
      idProprietaire: JsonAide.entierDefaut(j, 'id_proprietaire'),
      idDestinataire: JsonAide.entierDefaut(j, 'id_destinataire'),
      message: JsonAide.texte(j, 'message'),
      lu: JsonAide.booleen(j, 'lu'),
      datePartage: JsonAide.date(j, 'date_partage'),
      objet: objetJson == null ? null : Objet.brut(objetJson),
      proprietaireNom: JsonAide.texte(proprio, 'nom'),
      proprietairePrenom: JsonAide.texte(proprio, 'prenom'),
      proprietaireAvatar: JsonAide.texte(proprio, 'avatar'),
    );
  }

  String get proprietaire =>
      [proprietaireNom, proprietairePrenom].where((e) => e != null && e.isNotEmpty).join(' ');
}

