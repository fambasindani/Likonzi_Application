import 'preuve.dart';
import 'reponse_api.dart';

/// Intervention policière rattachée à un dossier.
class Intervention {
  Intervention({
    required this.id,
    required this.idCas,
    required this.idPolicier,
    required this.typeIntervention,
    required this.description,
    required this.dateIntervention,
    this.dureeMinutes,
    this.lieu,
    this.resultat,
    this.policierNom,
    this.policierPrenom,
    this.matricule,
  });

  final int id;
  final int idCas;
  final int idPolicier;
  final String typeIntervention;
  final String description;
  final DateTime dateIntervention;
  final int? dureeMinutes;
  final String? lieu;
  final String? resultat;
  final String? policierNom;
  final String? policierPrenom;
  final String? matricule;

  factory Intervention.brut(Map<String, dynamic> j) {
    final policier = JsonAide.objet(j, 'policier');
    return Intervention(
      id: JsonAide.entierDefaut(j, 'id'),
      idCas: JsonAide.entierDefaut(j, 'id_cas'),
      idPolicier: JsonAide.entierDefaut(j, 'id_policier'),
      typeIntervention: JsonAide.texteDefaut(j, 'type_intervention'),
      description: JsonAide.texteDefaut(j, 'description'),
      dateIntervention:
          JsonAide.date(j, 'date_intervention') ?? DateTime.now(),
      dureeMinutes: JsonAide.entier(j, 'duree_minutes'),
      lieu: JsonAide.texte(j, 'lieu'),
      resultat: JsonAide.texte(j, 'resultat'),
      policierNom: JsonAide.texte(policier, 'nom'),
      policierPrenom: JsonAide.texte(policier, 'prenom'),
      matricule: JsonAide.texte(policier, 'matricule'),
    );
  }

  String get policier =>
      [policierNom, policierPrenom].where((e) => e != null && e.isNotEmpty).join(' ');
}

/// Dossier d'enquête (`cas`).
class Dossier {
  Dossier({
    required this.id,
    required this.numeroDossier,
    required this.typeCas,
    required this.description,
    required this.dateFaits,
    required this.statut,
    required this.priorite,
    required this.idCommissariat,
    this.idAlerte,
    this.idVictime,
    this.victimeNom,
    this.victimePrenom,
    this.victimeTel,
    this.lieu,
    this.latitude,
    this.longitude,
    this.dateOuverture,
    this.dateCloture,
    this.idEnqueteur,
    this.enqueteurNom,
    this.enqueteurPrenom,
    this.commissariatNom,
    this.resultat,
    this.interventions = const [],
    this.preuves = const [],
    this.nbInterventions,
    this.nbPreuves,
  });

  final int id;
  final String numeroDossier;
  final String typeCas;
  final String description;
  final DateTime dateFaits;
  final String statut;
  final String priorite;
  final int idCommissariat;
  final int? idAlerte;
  final int? idVictime;
  final String? victimeNom;
  final String? victimePrenom;
  final String? victimeTel;
  final String? lieu;
  final double? latitude;
  final double? longitude;
  final DateTime? dateOuverture;
  final DateTime? dateCloture;
  final int? idEnqueteur;
  final String? enqueteurNom;
  final String? enqueteurPrenom;
  final String? commissariatNom;
  final String? resultat;
  final List<Intervention> interventions;
  final List<Preuve> preuves;
  final int? nbInterventions;
  final int? nbPreuves;

  factory Dossier.brut(Map<String, dynamic> j) {
    final victime = JsonAide.objet(j, 'victime');
    final enqueteur = JsonAide.objet(j, 'enqueteur');
    return Dossier(
      id: JsonAide.entierDefaut(j, 'id'),
      numeroDossier: JsonAide.texteDefaut(j, 'numero_dossier'),
      typeCas: JsonAide.texteDefaut(j, 'type_cas'),
      description: JsonAide.texteDefaut(j, 'description'),
      dateFaits: JsonAide.date(j, 'date_faits') ?? DateTime.now(),
      statut: JsonAide.texteDefaut(j, 'statut', 'ouvert'),
      priorite: JsonAide.texteDefaut(j, 'priorite', 'normale'),
      idCommissariat: JsonAide.entierDefaut(j, 'id_commissariat'),
      idAlerte: JsonAide.entier(j, 'id_alerte'),
      idVictime: JsonAide.entier(j, 'id_victime') ?? JsonAide.entier(victime, 'id'),
      victimeNom: JsonAide.texte(victime, 'nom') ?? JsonAide.texte(j, 'victime_nom'),
      victimePrenom: JsonAide.texte(victime, 'prenom') ?? JsonAide.texte(j, 'victime_prenom'),
      victimeTel: JsonAide.texte(victime, 'telephone') ?? JsonAide.texte(j, 'victime_tel'),
      lieu: JsonAide.texte(j, 'lieu'),
      latitude: JsonAide.decimal(j, 'latitude'),
      longitude: JsonAide.decimal(j, 'longitude'),
      dateOuverture: JsonAide.date(j, 'date_ouverture'),
      dateCloture: JsonAide.date(j, 'date_cloture'),
      idEnqueteur:
          JsonAide.entier(j, 'id_enqueteur_principal') ?? JsonAide.entier(enqueteur, 'id'),
      enqueteurNom: JsonAide.texte(enqueteur, 'nom') ?? JsonAide.texte(j, 'enqueteur_nom'),
      enqueteurPrenom:
          JsonAide.texte(enqueteur, 'prenom') ?? JsonAide.texte(j, 'enqueteur_prenom'),
      commissariatNom: JsonAide.texte(j, 'commissariat_nom'),
      resultat: JsonAide.texte(j, 'resultat'),
      interventions:
          JsonAide.liste(j, 'interventions').map(Intervention.brut).toList(growable: false),
      preuves: JsonAide.liste(j, 'preuves').map(Preuve.brut).toList(growable: false),
      nbInterventions: JsonAide.entier(j, 'nb_interventions'),
      nbPreuves: JsonAide.entier(j, 'nb_preuves'),
    );
  }

  bool get estOuvert => statut == 'ouvert';
  bool get estTermine => statut == 'clos' || statut == 'classe';

  String get victime =>
      [victimeNom, victimePrenom].where((e) => e != null && e.isNotEmpty).join(' ');

  String get enqueteur =>
      [enqueteurNom, enqueteurPrenom].where((e) => e != null && e.isNotEmpty).join(' ');

  /// Transitions permises (miroir de `cas_service.TRANSITIONS_CAS`).
  List<String> get statutsPossibles {
    switch (statut) {
      case 'ouvert':
        return const ['en_cours', 'en_attente', 'clos', 'classe'];
      case 'en_cours':
        return const ['en_attente', 'clos', 'classe'];
      case 'en_attente':
        return const ['en_cours', 'clos', 'classe'];
      default:
        return const [];
    }
  }

  /// Libellés métier des types de dossier.
  static String libelleType(String brut) {
    switch (brut) {
      case 'enlevement':
        return 'Enlèvement';
      case 'vol_vehicule':
        return 'Vol de véhicule';
      case 'vol_objet':
        return "Vol d'objet";
      case 'agression':
        return 'Agression';
      case 'disparition':
        return 'Disparition';
      case 'autre':
        return 'Autre';
      default:
        return brut;
    }
  }

  static String libelleIntervention(String brut) {
    switch (brut) {
      case 'patrouille':
        return 'Patrouille';
      case 'perquisition':
        return 'Perquisition';
      case 'audition':
        return 'Audition';
      case 'arrestation':
        return 'Arrestation';
      case 'perquisition_domicile':
        return 'Perquisition au domicile';
      case 'convocation':
        return 'Convocation';
      default:
        return 'Autre';
    }
  }
}

/// Constantes de référence partagées (filtres et sélecteurs).
class ConstantesDossier {
  static const List<String> types = [
    'enlevement',
    'vol_vehicule',
    'vol_objet',
    'agression',
    'disparition',
    'autre',
  ];

  static const List<String> statuts = ['ouvert', 'en_cours', 'en_attente', 'clos', 'classe'];

  static const List<String> priorites = ['basse', 'normale', 'haute', 'critique'];

  static const List<String> interventions = [
    'patrouille',
    'perquisition',
    'audition',
    'arrestation',
    'perquisition_domicile',
    'convocation',
    'autre',
  ];
}
