import '../models/dossier.dart';
import '../models/geographie.dart';
import '../models/reponse_api.dart';
import 'api_client.dart';

/// Dossiers (`cas`) et interventions policières.
class DossierService {
  DossierService._();

  static final DossierService instance = DossierService._();

  final ApiClient _api = ApiClient.instance;

  Future<Dossier> creer({
    required String typeCas,
    required String description,
    required DateTime dateFaits,
    String? lieu,
    double? latitude,
    double? longitude,
    String? priorite,
    int? idVictime,
    int? idCommissariat,
    int? idAlerte,
    int? idEnqueteur,
  }) async {
    final corps = await _api.post('/cas', data: {
      'type_cas': typeCas,
      'description': description,
      'date_faits': dateFaits.toIso8601String(),
      if (lieu != null && lieu.isNotEmpty) 'lieu': lieu,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (priorite != null) 'priorite': priorite,
      if (idVictime != null) 'id_victime': idVictime,
      if (idCommissariat != null) 'id_commissariat': idCommissariat,
      if (idAlerte != null) 'id_alerte': idAlerte,
      if (idEnqueteur != null) 'id_enqueteur_principal': idEnqueteur,
    });
    final data = (corps as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Dossier.brut(data);
  }

  Future<Page<Dossier>> lister({
    int page = 1,
    int perPage = 20,
    List<String>? statuts,
    String? priorite,
    String? typeCas,
    int? idCommissariat,
    String? q,
  }) async {
    final corps = await _api.get('/cas', params: {
      'page': page,
      'per_page': perPage,
      if (statuts != null && statuts.isNotEmpty) 'statut': statuts.join(','),
      if (priorite != null && priorite.isNotEmpty) 'priorite': priorite,
      if (typeCas != null && typeCas.isNotEmpty) 'type_cas': typeCas,
      if (idCommissariat != null) 'id_commissariat': idCommissariat,
      if (q != null && q.isNotEmpty) 'q': q,
    });
    return Page.brut(corps, Dossier.brut);
  }

  Future<Dossier> detail(int id) async {
    final corps = await _api.get('/cas/$id');
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Dossier introuvable.', statut: 404, code: 'not_found');
    }
    return Dossier.brut(data);
  }

  Future<Dossier> modifier(int id, Map<String, dynamic> donnees) async {
    final corps = await _api.patch('/cas/$id', data: donnees);
    final data = (corps as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Dossier.brut(data);
  }

  Future<Dossier> cloturer(
    int id, {
    String statut = 'clos',
    String? resultat,
    String? observation,
  }) async {
    final corps = await _api.post('/cas/$id/cloturer', data: {
      'statut': statut,
      if (resultat != null && resultat.isNotEmpty) 'resultat': resultat,
      if (observation != null && observation.isNotEmpty) 'observation': observation,
    });
    final data = (corps as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Dossier.brut(data);
  }

  Future<void> supprimer(int id) => _api.delete('/cas/$id');

  // ------------------------------------------------------------ interventions

  Future<Intervention> creerIntervention(
    int idCas, {
    required String typeIntervention,
    required String description,
    DateTime? dateIntervention,
    int? dureeMinutes,
    String? lieu,
    String? resultat,
    int? idPolicier,
  }) async {
    final corps = await _api.post('/cas/$idCas/interventions', data: {
      'type_intervention': typeIntervention,
      'description': description,
      if (dateIntervention != null)
        'date_intervention': dateIntervention.toIso8601String(),
      if (dureeMinutes != null) 'duree_minutes': dureeMinutes,
      if (lieu != null && lieu.isNotEmpty) 'lieu': lieu,
      if (resultat != null && resultat.isNotEmpty) 'resultat': resultat,
      if (idPolicier != null) 'id_policier': idPolicier,
    });
    final data = (corps as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Intervention.brut(data);
  }

  Future<Page<Intervention>> mesInterventions({int page = 1, int perPage = 20}) async {
    final corps = await _api.get('/interventions', params: {
      'page': page,
      'per_page': perPage,
    });
    return Page.brut(corps, Intervention.brut);
  }

  /// Détail d'une intervention — `GET /interventions/<id>`.
  Future<Intervention> intervention(int id) async {
    final corps = await _api.get('/interventions/$id');
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Intervention introuvable.', statut: 404, code: 'not_found');
    }
    return Intervention.brut(data);
  }

  Future<Intervention> modifierIntervention(
    int id,
    Map<String, dynamic> donnees,
  ) async {
    final corps = await _api.patch('/interventions/$id', data: donnees);
    final data = (corps as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Intervention.brut(data);
  }
}

/// Référentiels géographiques : provinces, villes, commissariats.
class CommissariatService {
  CommissariatService._();

  static final CommissariatService instance = CommissariatService._();

  final ApiClient _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> _liste(String chemin, {Map<String, dynamic>? params}) async {
    final corps = await _api.get(chemin, params: params);
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! List) return const [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  Future<List<Province>> provinces() async {
    final brut = await _liste('/provinces');
    return brut.map(Province.brut).toList(growable: false);
  }

  Future<List<Ville>> villes({int? idProvince}) async {
    final brut = await _liste('/villes', params: {
      if (idProvince != null) 'id_province': idProvince,
    });
    return brut.map(Ville.brut).toList(growable: false);
  }

  Future<List<Commissariat>> commissariats({int? idProvince}) async {
    final brut = await _liste('/commissariats', params: {
      if (idProvince != null) 'id_province': idProvince,
    });
    return brut.map(Commissariat.brut).toList(growable: false);
  }
}
