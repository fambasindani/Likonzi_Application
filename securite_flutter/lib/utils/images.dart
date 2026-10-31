import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Règle « une image pèse au maximum 200 Ko » (configurable via `.env` :
/// `IMAGE_MAX_OCTETS`).
class Images {
  Images._();

  static const Set<String> extensionsImage = {
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'bmp',
    'heic',
    'tiff',
  };

  /// Plafond en octets — 200 Ko par défaut.
  static int get maxOctets {
    final brut = dotenv.env['IMAGE_MAX_OCTETS'];
    final valeur = int.tryParse((brut ?? '').trim());
    return (valeur == null || valeur <= 0) ? 200 * 1024 : valeur;
  }

  static String extensionDe(String chemin) =>
      (chemin.split('.').length > 1 ? chemin.split('.').last : '').toLowerCase();

  static bool estImage(String chemin) => extensionsImage.contains(extensionDe(chemin));

  static int poids(String chemin) {
    try {
      return File(chemin).lengthSync();
    } catch (_) {
      return 0;
    }
  }

  static String formatPoids(int octets) {
    if (octets < 1024) return '$octets o';
    if (octets < 1024 * 1024) return '${(octets / 1024).toStringAsFixed(0)} Ko';
    return '${(octets / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  /// `null` si le fichier est conforme, sinon un message d'erreur lisible.
  ///
  /// La règle ne vaut que pour les images ; les documents et vidéos suivent
  /// la limite générale du serveur (`MAX_CONTENT_LENGTH`).
  static String? controler(String chemin) {
    if (!estImage(chemin)) return null;
    final octets = poids(chemin);
    if (octets == 0) return 'Fichier illisible.';
    if (octets > maxOctets) {
      return 'Image trop lourde : ${formatPoids(octets)} — '
          'maximum ${formatPoids(maxOctets)}. Prenez-la avec une résolution '
          'plus faible ou recadrez-la.';
    }
    return null;
  }
}
