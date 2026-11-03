import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Lecture de la configuration depuis l'asset `.env`.
///
/// Aucune valeur n'est codée en dur dans le code : tout se pilote depuis `.env`
/// (voir `.env.example`). Ce fichier ne doit contenir **aucun secret** puisqu'il
/// est embarqué dans le binaire.
class ConfigService {
  ConfigService._();

  static bool _charge = false;

  /// À appeler avant `runApp` : `await ConfigService.charger()`.
  static Future<void> charger() async {
    if (_charge) return;
    await dotenv.load();
    _charge = true;
  }

  static String _lit(String cle, String defaut) {
    final v = dotenv.env[cle]?.trim();
    return (v == null || v.isEmpty) ? defaut : v;
  }

  static String get apiBaseUrl =>
      _lit('API_BASE_URL', 'http://10.0.2.2:1200/api/v1').replaceAll(RegExp(r'/$'), '');

  /// Hôte Socket.IO, **sans** le préfixe `/api/v1`.
  static String get socketUrl {
    final brut = _lit('SOCKET_URL', 'http://10.0.2.2:1200').replaceAll(RegExp(r'/$'), '');
    if (brut.endsWith('/api/v1')) {
      return brut.substring(0, brut.length - '/api/v1'.length);
    }
    return brut;
  }

  static String get mapProvider => _lit('MAP_PROVIDER', 'osm').toLowerCase();
  static bool get utiliserGoogleMap => mapProvider == 'google';

  static String get tuileUrl =>
      _lit('OSM_TILE_URL', 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
  static String get tuileUtilisateur => _lit('OSM_USER_AGENT', 'securite_rdc/1.0');

  static String get nomApp => _lit('APP_NOM', 'Kebat');
  static String get slogan => _lit('APP_SLOGAN', 'Protéger, alerter, intervenir');

  static bool get debugReseau => _lit('DEBUG_RESEAU', 'false').toLowerCase() == 'true';
  static int get parPage => int.tryParse(_lit('PAR_PAGE', '20')) ?? 20;

  /// Résumé affichable dans l'écran « À propos » / débogage.
  /// Construit l'URL absolue d'un média renvoyé par le backend.
  ///
  /// Le serveur renvoie soit un chemin relatif à `/static/`
  /// (`uploads/avatars/x.png`), soit un simple nom de fichier historique
  /// stocké dans `static/Image/` (`k.jpg`). `Image.network` exige une URL
  /// absolue : d'où ce centralisateur.
  static String media(String? valeur) {
    if (valeur == null || valeur.isEmpty) return '';
    if (valeur.startsWith('http://') || valeur.startsWith('https://')) return valeur;
    final propre = valeur.startsWith('/') ? valeur : '/$valeur';
    if (propre.contains('/')) return '$socketUrl/static$propre';
    return '$socketUrl/static/Image/$propre';
  }


  static Map<String, String> resume() => {
        'API_BASE_URL': apiBaseUrl,
        'SOCKET_URL': socketUrl,
        'MAP_PROVIDER': mapProvider,
        'APP_NOM': nomApp,
      };
}
