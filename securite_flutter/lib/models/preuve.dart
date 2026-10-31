import 'reponse_api.dart';

/// Preuve téléversée (photo, vidéo, audio, document) avec empreinte SHA-256.
class Preuve {
  Preuve({
    required this.id,
    required this.entiteType,
    required this.entiteId,
    required this.typePreuve,
    required this.nomOriginal,
    required this.nomStocke,
    required this.extension,
    required this.typeMime,
    required this.tailleOctets,
    required this.cheminStockage,
    this.hashSha256,
    this.description,
    this.idUpload,
    this.uploadNom,
    this.uploadPrenom,
    this.dateCreation,
    this.url,
  });

  final int id;
  final String entiteType;
  final int entiteId;
  final String typePreuve;
  final String nomOriginal;
  final String nomStocke;
  final String extension;
  final String typeMime;
  final int tailleOctets;
  final String cheminStockage;
  final String? hashSha256;
  final String? description;
  final int? idUpload;
  final String? uploadNom;
  final String? uploadPrenom;
  final DateTime? dateCreation;
  final String? url;

  factory Preuve.brut(Map<String, dynamic> j) {
    final uploadeur = JsonAide.objet(j, 'uploadeur');
    return Preuve(
      id: JsonAide.entierDefaut(j, 'id'),
      entiteType: JsonAide.texteDefaut(j, 'entite_type'),
      entiteId: JsonAide.entierDefaut(j, 'entite_id'),
      typePreuve: JsonAide.texteDefaut(j, 'type_preuve', 'document'),
      nomOriginal: JsonAide.texteDefaut(j, 'nom_original'),
      nomStocke: JsonAide.texteDefaut(j, 'nom_stocke'),
      extension: JsonAide.texteDefaut(j, 'extension'),
      typeMime: JsonAide.texteDefaut(j, 'type_mime', 'application/octet-stream'),
      tailleOctets: JsonAide.entierDefaut(j, 'taille_octets'),
      cheminStockage: JsonAide.texteDefaut(j, 'chemin_stockage'),
      hashSha256: JsonAide.texte(j, 'hash_sha256'),
      description: JsonAide.texte(j, 'description'),
      idUpload: JsonAide.entier(j, 'id_user_upload'),
      uploadNom: JsonAide.texte(uploadeur, 'nom'),
      uploadPrenom: JsonAide.texte(uploadeur, 'prenom'),
      dateCreation: JsonAide.date(j, 'created_at'),
      url: JsonAide.texte(j, 'url'),
    );
  }

  bool get estImage =>
      typeMime.startsWith('image/') || const {'png', 'jpg', 'jpeg', 'gif', 'webp'}.contains(extension);
  bool get estVideo => typeMime.startsWith('video/') || const {'mp4', 'mov', 'avi', 'mkv', 'webm'}.contains(extension);
  bool get estAudio => typeMime.startsWith('audio/');
  bool get estDocument => !estImage && !estVideo && !estAudio;

  String get typeLibelle {
    switch (typePreuve) {
      case 'photo':
        return 'Photo';
      case 'video':
        return 'Vidéo';
      case 'audio':
        return 'Audio';
      case 'document':
        return 'Document';
      default:
        return 'Autre';
    }
  }

  String get uploadeur =>
      [uploadNom, uploadPrenom].where((e) => e != null && e.isNotEmpty).join(' ');

  /// Résultat d'une vérification d'intégrité (`GET /preuves/<id>/verifier`).
  static VerificationIntegrite verification(Map<String, dynamic> j) => VerificationIntegrite(
        conforme: JsonAide.booleen(j, 'conforme'),
        fichierPresent: JsonAide.booleen(j, 'fichier_present'),
        message: JsonAide.texte(j, 'message'),
        hashEnregistre: JsonAide.texte(j, 'hash_enregistre'),
        hashCalcule: JsonAide.texte(j, 'hash_calcule'),
        tailleAttendue: JsonAide.entier(j, 'taille_attendue'),
        tailleCalculee: JsonAide.entier(j, 'taille_calculee'),
      );
}

class VerificationIntegrite {
  VerificationIntegrite({
    required this.conforme,
    required this.fichierPresent,
    this.message,
    this.hashEnregistre,
    this.hashCalcule,
    this.tailleAttendue,
    this.tailleCalculee,
  });

  final bool conforme;
  final bool fichierPresent;
  final String? message;
  final String? hashEnregistre;
  final String? hashCalcule;
  final int? tailleAttendue;
  final int? tailleCalculee;
}

/// Constantes pour les écrans de téléversement.
class ConstantesPreuve {
  static const List<String> types = ['photo', 'video', 'audio', 'document', 'autre'];
  static const List<String> entites = ['alerte', 'cas', 'objet', 'intervention'];

  static const List<String> extensions = [
    '3gp', '7z', 'aac', 'avi', 'bmp', 'csv', 'doc', 'docx', 'flac', 'gif', 'heic',
    'jpeg', 'jpg', 'json', 'm4a', 'mkv', 'mov', 'mp3', 'mp4', 'odt', 'ods', 'ogg',
    'pdf', 'png', 'ppt', 'pptx', 'rar', 'txt', 'wav', 'webm', 'webp', 'xlsx', 'zip',
  ];
}
