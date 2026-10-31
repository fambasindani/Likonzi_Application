import '../models/alerte.dart';
import '../models/dossier.dart';
import '../models/reponse_api.dart';
import 'api_client.dart';

/// Alerte à proximité, avec la distance calculée par le serveur (Haversine).
class AlerteProche {
  AlerteProche(this.alerte, this.distanceKm);

  final Alerte alerte;
  final double distanceKm;

  factory AlerteProche.brut(Map<String, dynamic> j) => AlerteProche(
        Alerte.brut(j),
        JsonAide.decimal(j, 'distance_km') ?? 0,
      );
}

/// Niveaux d'urgence et statuts — miroir des ENUM du backend.
class ConstantesAlerte {
  static const List<String> urgences = ['faible', 'moyen', 'eleve', 'critique'];
  static const List<String> statuts = [
    'nouvelle',
    'prise_en_compte',
    'en_cours',
    'resolue',
    'classe',
    'fausse_alerte',
  ];
}

/// Flux des alertes : déclenchement citoyen et file policière.
class AlerteService {
  AlerteService._();

  static final AlerteService instance = AlerteService._();

  final ApiClient _api = ApiClient.instance;

  Future<List<TypeAlerte>> types() async {
    final corps = await _api.get('/alertes/types');
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => TypeAlerte.brut(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<Alerte> creer({
    required int idTypeAlerte,
    required String contenu,
    String? niveauUrgence,
    double? latitude,
    double? longitude,
    String? adressePrecise,
    int? idCommissariat,
  }) async {
    final corps = await _api.post('/alertes', data: {
      'id_type_alerte': idTypeAlerte,
      'contenu': contenu,
      if (niveauUrgence != null) 'niveau_urgence': niveauUrgence,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (adressePrecise != null && adressePrecise.isNotEmpty)
        'adresse_precise': adressePrecise,
      if (idCommissariat != null) 'id_commissariat': idCommissariat,
    });
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Alerte.brut(data);
  }

  Future<Page<Alerte>> lister({
    int page = 1,
    int perPage = 20,
    List<String>? statuts,
    String? urgence,
    int? idCommissariat,
    String? q,
  }) async {
    final corps = await _api.get('/alertes', params: {
      'page': page,
      'per_page': perPage,
      if (statuts != null && statuts.isNotEmpty) 'statut': statuts.join(','),
      if (urgence != null && urgence.isNotEmpty) 'niveau_urgence': urgence,
      if (idCommissariat != null) 'id_commissariat': idCommissariat,
      if (q != null && q.isNotEmpty) 'q': q,
    });
    return Page.brut(corps, Alerte.brut);
  }

  Future<Alerte> detail(int id) async {
    final corps = await _api.get('/alertes/$id');
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Alerte introuvable.', statut: 404, code: 'not_found');
    }
    return Alerte.brut(data);
  }

  Future<Alerte> prendreEnCharge(int id) async {
    final corps = await _api.post('/alertes/$id/prendre-en-charge');
    return Alerte.brut((corps as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<Alerte> assigner(int id, int idPolicier) async {
    final corps = await _api.post('/alertes/$id/assigner', data: {
      'id_policier_assignee': idPolicier,
    });
    return Alerte.brut((corps as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<Alerte> changerStatut(int id, String statut, {String? observation}) async {
    final corps = await _api.patch('/alertes/$id/statut', data: {
      'statut': statut,
      if (observation != null && observation.isNotEmpty) 'observation': observation,
    });
    return Alerte.brut((corps as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<Dossier> ouvrirCas(int idAlerte, Map<String, dynamic> donnees) async {
    final corps = await _api.post('/alertes/$idAlerte/ouvrir-cas', data: donnees);
    final data = (corps as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Dossier.brut(data);
  }

  Future<void> supprimer(int id) => _api.delete('/alertes/$id');

  /// Alertes autour d'une position (`GET /alertes/autour-de-moi`).
  Future<List<AlerteProche>> autourDeMoi({
    required double latitude,
    required double longitude,
    double rayonKm = 10,
    List<String>? statuts,
    int limite = 50,
  }) async {
    final corps = await _api.get('/alertes/autour-de-moi', params: {
      'lat': latitude,
      'lon': longitude,
      'rayon_km': rayonKm,
      if (statuts != null && statuts.isNotEmpty) 'statuts': statuts.join(','),
      'limite': limite,
    });
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => AlerteProche.brut(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }
}
