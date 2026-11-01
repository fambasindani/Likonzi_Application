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

  Future<List<Map<String, dynamic>>> _liste(
    String chemin, {
    Map<String, dynamic>? params,
  }) async {
    final corps = await _api.get(chemin, params: params);
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  // ----------------------------------------------------- référentiel géographique

  /// `GET /provinces` — 26 provinces de la RDC.
  Future<List<Map<String, dynamic>>> provinces() => _liste('/provinces');

  /// `GET /villes` — villes, filtrables par province.
  Future<List<Map<String, dynamic>>> villes({int? idProvince}) => _liste(
        '/villes',
        params: {if (idProvince != null) 'id_province': idProvince},
      );

  /// `GET /communes` — communes d'une ville (`?id_ville=`).
  Future<List<Map<String, dynamic>>> communes({int? idVille}) => _liste(
        '/communes',
        params: {if (idVille != null) 'id_ville': idVille},
      );

  /// `GET /commissariats` — commissariats actifs (permission
  /// `commissariats.lire`).
  Future<List<Map<String, dynamic>>> commissariats({int? idProvince}) => _liste(
        '/commissariats',
        params: {if (idProvince != null) 'id_province': idProvince},
      );

  Future<Map<String, dynamic>> _ecrire(
    String methode,
    String chemin, {
    Map<String, dynamic>? corps,
  }) async {
    final dynamic reponse;
    switch (methode) {
      case 'POST':
        reponse = await _api.post(chemin, data: corps);
      case 'PATCH':
        reponse = await _api.patch(chemin, data: corps);
      default:
        await _api.delete(chemin);
        return const {};
    }
    final data = reponse is Map<String, dynamic> ? reponse['data'] : null;
    return data is Map<String, dynamic> ? data : const {};
  }

  Future<Map<String, dynamic>> creerProvince(Map<String, dynamic> corps) =>
      _ecrire('POST', '/provinces', corps: corps);
  Future<Map<String, dynamic>> majProvince(int id, Map<String, dynamic> corps) =>
      _ecrire('PATCH', '/provinces/$id', corps: corps);
  Future<void> supprimerProvince(int id) =>
      _ecrire('DELETE', '/provinces/$id').then((_) {});

  Future<Map<String, dynamic>> creerVille(Map<String, dynamic> corps) =>
      _ecrire('POST', '/villes', corps: corps);
  Future<Map<String, dynamic>> majVille(int id, Map<String, dynamic> corps) =>
      _ecrire('PATCH', '/villes/$id', corps: corps);
  Future<void> supprimerVille(int id) =>
      _ecrire('DELETE', '/villes/$id').then((_) {});

  Future<Map<String, dynamic>> creerCommune(Map<String, dynamic> corps) =>
      _ecrire('POST', '/communes', corps: corps);
  Future<Map<String, dynamic>> majCommune(int id, Map<String, dynamic> corps) =>
      _ecrire('PATCH', '/communes/$id', corps: corps);
  Future<void> supprimerCommune(int id) =>
      _ecrire('DELETE', '/communes/$id').then((_) {});

  Future<Map<String, dynamic>> creerCommissariat(Map<String, dynamic> corps) =>
      _ecrire('POST', '/commissariats', corps: corps);
  Future<Map<String, dynamic>> majCommissariat(
    int id,
    Map<String, dynamic> corps,
  ) =>
      _ecrire('PATCH', '/commissariats/$id', corps: corps);
  Future<void> supprimerCommissariat(int id) =>
      _ecrire('DELETE', '/commissariats/$id').then((_) {});
}
