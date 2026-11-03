import 'reponse_api.dart';

/// Demande d'ami entre deux utilisateurs.
class Demande {
  Demande({
    required this.id,
    required this.receveurId,
    required this.emetteurId,
    required this.statut,
    this.dateDemande,
    this.dateReponse,
    this.emetteurNom,
    this.emetteurPrenom,
    this.emetteurAvatar,
    this.receveurNom,
    this.receveurPrenom,
    this.receveurAvatar,
  });

  final int id;
  final int receveurId;
  final int emetteurId;
  final String statut;
  final DateTime? dateDemande;
  final DateTime? dateReponse;
  final String? emetteurNom;
  final String? emetteurPrenom;
  final String? emetteurAvatar;
  final String? receveurNom;
  final String? receveurPrenom;
  final String? receveurAvatar;

  factory Demande.brut(Map<String, dynamic> j) {
    final emetteur = JsonAide.objet(j, 'emetteur');
    final receveur = JsonAide.objet(j, 'destinataire');
    return Demande(
      id: JsonAide.entierDefaut(j, 'id'),
      receveurId: JsonAide.entierDefaut(j, 'recev_id'),
      emetteurId: JsonAide.entierDefaut(j, 'envoi_id'),
      statut: JsonAide.texteDefaut(j, 'statut', 'en_attente'),
      dateDemande: JsonAide.date(j, 'date_demande'),
      dateReponse: JsonAide.date(j, 'date_reponse'),
      emetteurNom: JsonAide.texte(emetteur, 'nom'),
      emetteurPrenom: JsonAide.texte(emetteur, 'prenom'),
      emetteurAvatar: JsonAide.texte(emetteur, 'avatar'),
      receveurNom: JsonAide.texte(receveur, 'nom'),
      receveurPrenom: JsonAide.texte(receveur, 'prenom'),
      receveurAvatar: JsonAide.texte(receveur, 'avatar'),
    );
  }

  /// Personne en face, vue depuis `moiId`.
  String nomDe(int moiId) {
    final coteAutre = emetteurId == moiId ? (receveurNom, receveurPrenom) : (emetteurNom, emetteurPrenom);
    return [coteAutre.$1, coteAutre.$2].where((e) => e != null && e.isNotEmpty).join(' ');
  }

  int idDe(int moiId) => emetteurId == moiId ? receveurId : emetteurId;

  bool estRecue(int moiId) => receveurId == moiId;
}

/// Message privé (`notes`).
class Message {
  Message({
    required this.id,
    required this.idDestinataire,
    required this.idExpediteur,
    required this.contenu,
    required this.lu,
    this.dateEnvoi,
    this.nomExpediteur,
    this.prenomExpediteur,
    this.avatarExpediteur,
    this.telephoneExpediteur,
  });

  final int id;
  final int idDestinataire;
  final int idExpediteur;
  final String contenu;
  final bool lu;
  final DateTime? dateEnvoi;

  /// Identité de l'émetteur (photo + appel) renvoyée par le backend.
  final String? nomExpediteur;
  final String? prenomExpediteur;
  final String? avatarExpediteur;
  final String? telephoneExpediteur;

  factory Message.brut(Map<String, dynamic> j) {
    final expediteur = JsonAide.objet(j, 'emetteur');
    return Message(
      id: JsonAide.entierDefaut(j, 'id'),
      idDestinataire: JsonAide.entierDefaut(j, 'id_rec'),
      idExpediteur: JsonAide.entierDefaut(j, 'id_sender'),
      contenu: JsonAide.texteDefaut(j, 'messages'),
      lu: JsonAide.booleen(j, 'lu'),
      dateEnvoi: JsonAide.date(j, 'created_at'),
      nomExpediteur: JsonAide.texte(expediteur, 'nom'),
      prenomExpediteur: JsonAide.texte(expediteur, 'prenom'),
      avatarExpediteur: JsonAide.texte(expediteur, 'avatar'),
      telephoneExpediteur: JsonAide.texte(expediteur, 'telephone'),
    );
  }

  /// Nom complet de l'émetteur.
  String get nomExpediteurAffiche => [nomExpediteur, prenomExpediteur]
      .where((e) => e != null && e.isNotEmpty)
      .join(' ');
}

/// Notification applicative.
class NotificationApp {
  NotificationApp({
    required this.id,
    required this.idDestinataire,
    required this.type,
    required this.titre,
    required this.message,
    required this.lu,
    this.idExpediteur,
    this.entiteType,
    this.entiteId,
    this.lien,
    this.dateEnvoi,
    this.dateLecture,
  });

  final int id;
  final int idDestinataire;
  final String type;
  final String titre;
  final String message;
  final bool lu;
  final int? idExpediteur;
  final String? entiteType;
  final int? entiteId;
  final String? lien;
  final DateTime? dateEnvoi;
  final DateTime? dateLecture;

  factory NotificationApp.brut(Map<String, dynamic> j) => NotificationApp(
        id: JsonAide.entierDefaut(j, 'id'),
        idDestinataire: JsonAide.entierDefaut(j, 'id_user'),
        type: JsonAide.texteDefaut(j, 'type', 'systeme'),
        titre: JsonAide.texteDefaut(j, 'titre'),
        message: JsonAide.texteDefaut(j, 'message'),
        lu: JsonAide.booleen(j, 'lu'),
        idExpediteur: JsonAide.entier(j, 'id_sender'),
        entiteType: JsonAide.texte(j, 'entite_type'),
        entiteId: JsonAide.entier(j, 'entite_id'),
        lien: JsonAide.texte(j, 'lien'),
        dateEnvoi: JsonAide.date(j, 'date_envoi'),
        dateLecture: JsonAide.date(j, 'date_lecture'),
      );

  /// Libellé court du type (icône + couleur).
  String get cleIcone {
    switch (type) {
      case 'demande_ami':
        return 'person_add';
      case 'message':
        return 'chat';
      case 'alerte_creee':
      case 'alerte_assignee':
      case 'alerte_resolue':
        return 'notifications_active';
      case 'cas_maj':
        return 'folder_special';
      case 'objet_retrouve':
        return 'search';
      case 'objet_declare':
        return 'inventory';
      case 'sos':
        return 'sos';
      case 'preuve_ajoutee':
        return 'attach_file';
      default:
        return 'info';
    }
  }

  NotificationApp copierAvecLu(bool valeur) => NotificationApp(
        id: id,
        idDestinataire: idDestinataire,
        type: type,
        titre: titre,
        message: message,
        lu: valeur,
        idExpediteur: idExpediteur,
        entiteType: entiteType,
        entiteId: entiteId,
        lien: lien,
        dateEnvoi: dateEnvoi,
        dateLecture: valeur ? (dateLecture ?? DateTime.now()) : null,
      );
}
