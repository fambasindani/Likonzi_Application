import 'package:geolocator/geolocator.dart';

import '../models/geographie.dart';
import '../models/reponse_api.dart';
import 'api_client.dart';

/// Lieu : résultat du géocodage inverse (`GET /lieu`).
class Lieu {
  Lieu({this.ville, this.commune, this.province, this.distanceKm});

  final String? ville;
  final String? commune;
  final String? province;
  final double? distanceKm;

  factory Lieu.brut(Map<String, dynamic> j) => Lieu(
        ville: JsonAide.texte(j, 'ville'),
        commune: JsonAide.texte(j, 'commune'),
        province: JsonAide.texte(j, 'province'),
        distanceKm: JsonAide.decimal(j, 'distance_km'),
      );

  /// Libellé affiché dans l'en-tête : la commune si elle est connue, sinon la ville.
  String get affichage => (commune?.isNotEmpty ?? false) ? commune! : (ville ?? '');
}

/// Position de l'appareil + endpoints de proximité.
class GeoService {
  GeoService._();

  static final GeoService instance = GeoService._();

  final ApiClient _api = ApiClient.instance;

  // ------------------------------------------------------- position appareil

  /// Vérifie/obtient les permissions puis lit la position courante.
  Future<Position?> positionAppareil({bool exacte = true}) async {
    final serviceActif = await Geolocator.isLocationServiceEnabled();
    if (!serviceActif) {
      throw ExceptionApi(
        message: 'Le service de localisation est désactivé. Activez-le dans les réglages.',
        code: 'localisation_desactivee',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw ExceptionApi(
        message: 'Permission de localisation refusée définitivement.',
        code: 'localisation_refusee',
      );
    }
    if (permission == LocationPermission.denied) {
      throw ExceptionApi(
        message: 'Permission de localisation refusée.',
        code: 'localisation_refusee',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: exacte
          ? const LocationSettings(accuracy: LocationAccuracy.high)
          : const LocationSettings(accuracy: LocationAccuracy.medium),
    ).timeout(const Duration(seconds: 20), onTimeout: () => throw ExceptionApi(
          message: "Impossible d'obtenir la position (délai dépassé).",
          code: 'localisation_timeout',
        ));
  }

  // ------------------------------------------------------------ API backend

  /// Géocodage inverse : nom de la ville/commune pour un point GPS.
  Future<Lieu?> lieu({required double latitude, required double longitude}) async {
    final corps = await _api.get('/lieu', params: {'lat': latitude, 'lon': longitude});
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! Map<String, dynamic>) return null;
    return Lieu.brut(Map<String, dynamic>.from(data));
  }

  Future<Localisation> enregistrerPosition({
    required double latitude,
    required double longitude,
    double? precisionMetres,
    String source = 'gps',
  }) async {
    final corps = await _api.post('/positions', data: {
      'latitude': latitude,
      'longitude': longitude,
      if (precisionMetres != null) 'precision_metres': precisionMetres,
      'source': source,
    });
    final data = (corps as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Localisation.brut(data);
  }

  Future<Localisation?> maPosition() async {
    final corps = await _api.get('/positions/moi');
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! Map<String, dynamic>) return null;
    return Localisation.brut(data);
  }

  /// Cartographie policière : dernière position de chaque utilisateur (`geo.lire`).
  Future<List<Localisation>> cartographie({int jours = 7}) async {
    final corps = await _api.get('/positions', params: {'vue': 'derniere', 'jours': jours});
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Localisation.brut(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  /// Historique paginé des positions (`geo.lire`).
  Future<Page<Localisation>> positions({int page = 1, int perPage = 50, int? idUser}) async {
    final corps = await _api.get('/positions', params: {
      'page': page,
      'per_page': perPage,
      if (idUser != null) 'id_user': idUser,
    });
    return Page.brut(corps, Localisation.brut);
  }

  Future<List<Commissariat>> commissariatsProches({
    required double latitude,
    required double longitude,
    double rayonKm = 25,
    int limite = 20,
  }) async {
    final corps = await _api.get('/proximite/commissariats', params: {
      'lat': latitude,
      'lon': longitude,
      'rayon_km': rayonKm,
      'limite': limite,
    });
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Commissariat.brut(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }
}
