import '../models/objet.dart';
import '../models/reponse_api.dart';
import 'api_client.dart';

/// Objet volé / recherché / retrouvé.
class ObjetService {
  ObjetService._();

  static final ObjetService instance = ObjetService._();

  final ApiClient _api = ApiClient.instance;

  Future<List<TypeObjet>> types() async {
    final corps = await _api.get('/objets/types');
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => TypeObjet.brut(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<Objet> creer({
    required int idType,
    String? marque,
    String? modele,
    String? numeroChassis,
    String? immatriculation,
    String? numeroSerie,
    String? couleur,
    String? description,
    DateTime? dateVol,
    String? lieuVol,
    double? latitude,
    double? longitude,
    int? idCas,
    int? idProprietaire,
    String? statut,
  }) async {
    final corps = await _api.post('/objets', data: {
      'id_type': idType,
      if (marque != null && marque.isNotEmpty) 'marque': marque,
      if (modele != null && modele.isNotEmpty) 'model': modele,
      if (numeroChassis != null && numeroChassis.isNotEmpty) 'numero_chassis': numeroChassis,
      if (immatriculation != null && immatriculation.isNotEmpty)
        'immatriculation': immatriculation,
      if (numeroSerie != null && numeroSerie.isNotEmpty) 'numero_serie': numeroSerie,
      if (couleur != null && couleur.isNotEmpty) 'couleur': couleur,
      if (description != null && description.isNotEmpty) 'description': description,
      if (dateVol != null) 'date_vol': dateVol.toIso8601String(),
      if (lieuVol != null && lieuVol.isNotEmpty) 'lieu_vol': lieuVol,
      if (latitude != null) 'latitude_vol': latitude,
      if (longitude != null) 'longitude_vol': longitude,
      if (idCas != null) 'id_cas': idCas,
      if (idProprietaire != null) 'id_user_proprietaire': idProprietaire,
      if (statut != null) 'statut': statut,
    });
    final data = (corps as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Objet.brut(data);
  }

  Future<Page<Objet>> lister({
    int page = 1,
    int perPage = 20,
    List<String>? statuts,
    int? idType,
    String? q,
  }) async {
    final corps = await _api.get('/objets', params: {
      'page': page,
      'per_page': perPage,
      if (statuts != null && statuts.isNotEmpty) 'statut': statuts.join(','),
      if (idType != null) 'id_type': idType,
      if (q != null && q.isNotEmpty) 'q': q,
    });
    return Page.brut(corps, Objet.brut);
  }

  /// Recherche ciblée (immatriculation, châssis, n° de série, marque…).
  Future<List<Objet>> rechercher(String terme, {String? statut, int limite = 50}) async {
    final corps = await _api.get('/objets/recherche', params: {
      'q': terme,
      if (statut != null && statut.isNotEmpty) 'statut': statut,
      'limite': limite,
    });
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Objet.brut(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<Objet> detail(int id) async {
    final corps = await _api.get('/objets/$id');
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Objet introuvable.', statut: 404, code: 'not_found');
    }
    return Objet.brut(data);
  }

  Future<Objet> modifier(int id, Map<String, dynamic> donnees) async {
    final corps = await _api.patch('/objets/$id', data: donnees);
    final data = (corps as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Objet.brut(data);
  }

  Future<Objet> changerStatut(int id, String statut, {String? motif}) async {
    final corps = await _api.post('/objets/$id/statut', data: {
      'statut': statut,
      if (motif != null && motif.isNotEmpty) 'motif': motif,
    });
    final data = (corps as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Objet.brut(data);
  }

  Future<void> supprimer(int id) => _api.delete('/objets/$id');

  // -------------------------------------------------------------------- partage

  /// Transmet l'objet (et donc ses images) à des destinataires.
  Future<Map<String, dynamic>> partager(
    int objetId, {
    required List<int> destinataires,
    String? message,
  }) async {
    final corps = await _api.post('/objets/$objetId/partager', data: {
      'destinataires': destinataires,
      if (message != null && message.isNotEmpty) 'message': message,
    });
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    return data is Map<String, dynamic> ? data : const {};
  }

  /// Objets reçus via un partage (`GET /partages`).
  Future<Page<Partage>> partages({
    int page = 1,
    int perPage = 20,
    bool nonLues = false,
  }) async {
    final corps = await _api.get('/partages', params: {
      'page': page,
      'per_page': perPage,
      if (nonLues) 'non_lues': '1',
    });
    return Page.brut(corps, Partage.brut);
  }

  Future<int> partagesNonLus() async {
    final corps = await _api.get('/partages/non-lus');
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! Map<String, dynamic>) return 0;
    return JsonAide.entierDefaut(data, 'non_lus');
  }

  Future<Partage> marquerPartageLu(int partageId) async {
    final corps = await _api.post('/partages/$partageId/lu');
    final data = (corps as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Partage.brut(data);
  }

  Future<void> retirerPartage(int partageId) => _api.delete('/partages/$partageId');
}
