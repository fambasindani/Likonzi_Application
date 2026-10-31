import 'preuve.dart';
import 'reponse_api.dart';

/// Type d'alerte proposé au citoyen (`GET /alertes/types`).
class TypeAlerte {
  TypeAlerte({
    required this.id,
    required this.code,
    required this.contenu,
    this.niveauDefaut = 'moyen',
    this.necessitePolice = true,
    this.icone,
    this.actif = true,
  });

  final int id;
  final String code;
  final String contenu;
  final String niveauDefaut;
  final bool necessitePolice;
  final String? icone;
  final bool actif;

  factory TypeAlerte.brut(Map<String, dynamic> j) => TypeAlerte(
        id: JsonAide.entierDefaut(j, 'id'),
        code: JsonAide.texteDefaut(j, 'code'),
        contenu: JsonAide.texteDefaut(j, 'contenu'),
        niveauDefaut: JsonAide.texteDefaut(j, 'niveau_urgence_defaut', 'moyen'),
        necessitePolice: JsonAide.booleen(j, 'necessite_police'),
        icone: JsonAide.texte(j, 'icone'),
        actif: JsonAide.booleen(j, 'statut'),
      );
}

/// Alerte déclarée par un citoyen.
class Alerte {
  Alerte({
    required this.id,
    required this.reference,
    required this.idUser,
    required this.idTypeAlerte,
    required this.contenu,
    this.niveauUrgence = 'moyen',
    this.statut = 'nouvelle',
    this.idCommissariat,
    this.idPolicierAssignee,
    this.latitude,
    this.longitude,
    this.adressePrecise,
    this.dateAlerte,
    this.datePriseEnCompte,
    this.dateResolution,
    this.observation,
    this.typeCode,
    this.typeLibelle,
    this.emetteurId,
    this.emetteurNom,
    this.emetteurPrenom,
    this.emetteurTel,
    this.commissariatNom,
    this.policierNom,
    this.policierPrenom,
    this.preuves = const [],
  });

  final int id;
  final String reference;
  final int idUser;
  final int idTypeAlerte;
  final String contenu;
  final String niveauUrgence;
  final String statut;
  final int? idCommissariat;
  final int? idPolicierAssignee;
  final double? latitude;
  final double? longitude;
  final String? adressePrecise;
  final DateTime? dateAlerte;
  final DateTime? datePriseEnCompte;
  final DateTime? dateResolution;
  final String? observation;

  final String? typeCode;
  final String? typeLibelle;
  final int? emetteurId;
  final String? emetteurNom;
  final String? emetteurPrenom;
  final String? emetteurTel;
  final String? commissariatNom;
  final String? policierNom;
  final String? policierPrenom;
  final List<Preuve> preuves;

  factory Alerte.brut(Map<String, dynamic> j) {
    final type = JsonAide.objet(j, 'type');
    final emetteur = JsonAide.objet(j, 'emetteur');
    final policier = JsonAide.objet(j, 'policier');
    return Alerte(
      id: JsonAide.entierDefaut(j, 'id'),
      reference: JsonAide.texteDefaut(j, 'reference'),
      idUser: JsonAide.entierDefaut(j, 'id_user'),
      idTypeAlerte: JsonAide.entierDefaut(j, 'id_type_alerte'),
      contenu: JsonAide.texteDefaut(j, 'contenu'),
      niveauUrgence: JsonAide.texteDefaut(j, 'niveau_urgence', 'moyen'),
      statut: JsonAide.texteDefaut(j, 'statut', 'nouvelle'),
      idCommissariat: JsonAide.entier(j, 'id_commissariat'),
      idPolicierAssignee: JsonAide.entier(j, 'id_policier_assignee'),
      latitude: JsonAide.decimal(j, 'latitude'),
      longitude: JsonAide.decimal(j, 'longitude'),
      adressePrecise: JsonAide.texte(j, 'adresse_precise'),
      dateAlerte: JsonAide.date(j, 'date_alerte'),
      datePriseEnCompte: JsonAide.date(j, 'date_prise_en_compte'),
      dateResolution: JsonAide.date(j, 'date_resolution'),
      observation: JsonAide.texte(j, 'observation'),
      typeCode: JsonAide.texte(type, 'code') ?? JsonAide.texte(j, 'type_code'),
      typeLibelle: JsonAide.texte(type, 'contenu') ?? JsonAide.texte(j, 'type_libelle'),
      emetteurId: JsonAide.entier(emetteur, 'id') ?? JsonAide.entier(j, 'id_emetteur'),
      emetteurNom: JsonAide.texte(emetteur, 'nom') ?? JsonAide.texte(j, 'emetteur_nom'),
      emetteurPrenom: JsonAide.texte(emetteur, 'prenom') ?? JsonAide.texte(j, 'emetteur_prenom'),
      emetteurTel: JsonAide.texte(emetteur, 'telephone') ?? JsonAide.texte(j, 'emetteur_tel'),
      commissariatNom: JsonAide.texte(j, 'commissariat_nom'),
      policierNom: JsonAide.texte(policier, 'nom') ?? JsonAide.texte(j, 'policier_nom'),
      policierPrenom: JsonAide.texte(policier, 'prenom') ?? JsonAide.texte(j, 'policier_prenom'),
      preuves: JsonAide.liste(j, 'preuves').map(Preuve.brut).toList(growable: false),
    );
  }

  bool get aCoordonnees => latitude != null && longitude != null;
  bool get estTerminee =>
      statut == 'resolue' || statut == 'classe' || statut == 'fausse_alerte';
  bool get estNouvelle => statut == 'nouvelle';
  bool get assignee => idPolicierAssignee != null;

  String get emetteur =>
      [emetteurNom, emetteurPrenom].where((e) => e != null && e.isNotEmpty).join(' ');

  String get policier =>
      [policierNom, policierPrenom].where((e) => e != null && e.isNotEmpty).join(' ');

  /// Transitions permises (miroir de `alerte_service.TRANSITIONS`).
  List<String> get statutsPossibles {
    switch (statut) {
      case 'nouvelle':
        return const [
          'prise_en_compte',
          'en_cours',
          'resolue',
          'classe',
          'fausse_alerte',
        ];
      case 'prise_en_compte':
        return const ['en_cours', 'resolue', 'classe', 'fausse_alerte'];
      case 'en_cours':
        return const ['resolue', 'classe', 'fausse_alerte'];
      default:
        return const [];
    }
  }
}
