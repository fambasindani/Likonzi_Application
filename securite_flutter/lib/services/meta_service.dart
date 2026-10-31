import '../models/reponse_api.dart';
import 'api_client.dart';

/// Métadonnées exposées par le backend :
/// santé, configuration publique, schéma des routes d'auth, référentiels
/// (types d'alertes / d'objets, rôles) et journal d'audit.
class MetaService {
  MetaService._();

  static final MetaService instance = MetaService._();

  final ApiClient _api = ApiClient.instance;

  /// `GET /health` — état du service et de la base.
  Future<Map<String, dynamic>> health() async {
    final corps = await _api.get('/health');
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    return data is Map<String, dynamic> ? data : const {};
  }

  /// `GET /config-public` — paramètres non sensibles côté serveur.
  Future<Map<String, dynamic>> configPublic() async {
    final corps = await _api.get('/config-public');
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    return data is Map<String, dynamic> ? data : const {};
  }

  /// `GET /auth/_schema` — routes d'authentification exposées.
  Future<List<Map<String, dynamic>>> schemaAuth() async {
    final corps = await _api.get('/auth/_schema');
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  /// `GET /type-alertes` — référentiel complet (admin).
  Future<List<Map<String, dynamic>>> typeAlertes() async =>
      _liste('/type-alertes');

  /// `GET /type-objets` — référentiel complet (admin).
  Future<List<Map<String, dynamic>>> typeObjets() async =>
      _liste('/type-objets');

  /// `GET /roles` — rôles et leurs permissions.
  Future<List<Map<String, dynamic>>> roles() async => _liste('/roles');

  /// `GET /audit` — journal d'audit paginé (permission `audit.lire`).
  Future<Page<Map<String, dynamic>>> audit({
    int page = 1,
    int perPage = 50,
    String? action,
  }) async {
    final corps = await _api.get('/audit', params: {
      'page': page,
      'per_page': perPage,
      if (action != null && action.isNotEmpty) 'action': action,
    });
    return Page.brut(
      corps,
      (j) => j,
    );
  }

  Future<List<Map<String, dynamic>>> _liste(String chemin) async {
    final corps = await _api.get(chemin);
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }
}
