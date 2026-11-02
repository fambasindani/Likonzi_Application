import 'reponse_api.dart';

/// SOS « minute de grâce » : déclenchement avec compte à rebours géré côté
/// serveur (la table `sos` et sa tâche de veille envoient le message même si
/// l'application est fermée).
class Sos {
  Sos({
    required this.id,
    required this.idUser,
    required this.statut,
    required this.dureeMinutes,
    required this.echeance,
    this.latitude,
    this.longitude,
    this.intermediaireAt,
    this.envoyeAt,
    this.idAlerte,
  });

  static const List<String> statuts = [
    'programme',
    'intermediaire',
    'envoye',
    'annule',
    'cloture',
  ];

  final int id;
  final int idUser;
  final String statut;
  final int dureeMinutes;
  final DateTime echeance;
  final double? latitude;
  final double? longitude;
  final DateTime? intermediaireAt;
  final DateTime? envoyeAt;
  final int? idAlerte;

  factory Sos.brut(Map<String, dynamic> j) => Sos(
        id: JsonAide.entierDefaut(j, 'id'),
        idUser: JsonAide.entierDefaut(j, 'id_user'),
        statut: JsonAide.texteDefaut(j, 'statut', 'programme'),
        dureeMinutes: JsonAide.entierDefaut(j, 'duree_minutes', 15),
        echeance: JsonAide.date(j, 'echeance') ?? DateTime.now(),
        latitude: JsonAide.decimal(j, 'latitude'),
        longitude: JsonAide.decimal(j, 'longitude'),
        intermediaireAt: JsonAide.date(j, 'intermediaire_at'),
        envoyeAt: JsonAide.date(j, 'envoye_at'),
        idAlerte: JsonAide.entier(j, 'id_alerte'),
      );

  /// En décompte (le minuteur tourne encore).
  bool get enCours => statut == 'programme' || statut == 'intermediaire';

  /// Message complet envoyé, en attente de « Je vais bien ».
  bool get envoye => statut == 'envoye';

  /// Terminé (annulé ou levé).
  bool get termine => statut == 'annule' || statut == 'cloture';

  /// Message d'alerte intermédiaire déjà transmis aux amis.
  bool get intermediaireEnvoye => intermediaireAt != null;

  /// Secondes restantes avant l'échéance (0 une fois dépassé).
  int get secondesRestantes {
    final delta = echeance.difference(DateTime.now()).inSeconds;
    return delta < 0 ? 0 : delta;
  }

  /// Affichage `MM:SS` du compte à rebours.
  String get minuteur {
    final s = secondesRestantes;
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  String get libelleStatut {
    switch (statut) {
      case 'programme':
        return 'SOS programmé';
      case 'intermediaire':
        return 'Alerte intermédiaire envoyée';
      case 'envoye':
        return 'SOS envoyé';
      case 'annule':
        return 'SOS annulé';
      case 'cloture':
        return 'SOS levé';
      default:
        return statut;
    }
  }
}
