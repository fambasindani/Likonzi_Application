import 'package:dio/dio.dart';

import '../models/reponse_api.dart';
import '../models/utilisateur.dart';
import 'api_client.dart';

/// Gestion des comptes (profil, avatar, rôles, statuts) — `/api/v1/users/*`.
class UtilisateurService {
  UtilisateurService._();

  static final UtilisateurService instance = UtilisateurService._();

  final ApiClient _api = ApiClient.instance;

  Future<Page<Utilisateur>> lister({
    int page = 1,
    int perPage = 20,
    String? q,
    String? role,
    String? statut,
    int? idCommissariat,
  }) async {
    final corps = await _api.get('/users', params: {
      'page': page,
      'per_page': perPage,
      if (q != null && q.isNotEmpty) 'q': q,
      if (role != null && role.isNotEmpty) 'role': role,
      if (statut != null && statut.isNotEmpty) 'statut': statut,
      if (idCommissariat != null) 'id_commissariat': idCommissariat,
    });
    return Page.brut(corps, Utilisateur.brut);
  }

  Future<Utilisateur> detail(int id) async {
    final corps = await _api.get('/users/$id');
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Utilisateur introuvable.', statut: 404, code: 'not_found');
    }
    return Utilisateur.brut(data);
  }

  /// Création d'un compte par un administrateur (n'importe quel rôle).
  Future<Utilisateur> creer({
    required String nom,
    String? postnom,
    String? prenom,
    required String email,
    required String telephone,
    required String password,
    required List<String> roles,
    int? idCommissariat,
    String? matriculePolice,
    String? gradePolice,
    String? genre,
    String? adresse,
    DateTime? dateNaissance,
  }) async {
    final corps = await _api.post('/users', data: {
      'nom': nom,
      if (postnom != null && postnom.isNotEmpty) 'postnom': postnom,
      if (prenom != null && prenom.isNotEmpty) 'prenom': prenom,
      'email': email,
      'telephone': telephone,
      'password': password,
      'roles': roles,
      if (idCommissariat != null) 'id_commissariat': idCommissariat,
      if (matriculePolice != null && matriculePolice.isNotEmpty)
        'matricule_police': matriculePolice,
      if (gradePolice != null && gradePolice.isNotEmpty) 'grade_police': gradePolice,
      if (genre != null && genre.isNotEmpty) 'genre': genre,
      if (adresse != null && adresse.isNotEmpty) 'adresse': adresse,
      if (dateNaissance != null)
        'date_naissance': dateNaissance.toIso8601String().split('T').first,
    });
    final data = (corps as Map<String, dynamic>)['data'];
    final map = data is Map<String, dynamic> ? data['user'] : null;
    if (map is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Utilisateur.brut(map);
  }

  Future<Utilisateur> modifier(int id, Map<String, dynamic> donnees) async {
    final corps = await _api.patch('/users/$id', data: donnees);
    final data = (corps as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Utilisateur.brut(data);
  }

  /// Téléversement d'avatar (multipart, champ `image`).
  Future<Map<String, dynamic>> avatar(int id, String cheminFichier, {String? nomFichier}) async {
    final fichier = await MultipartFile.fromFile(
      cheminFichier,
      filename: nomFichier ?? cheminFichier.split(RegExp(r'[\\/]+')).last,
    );
    final corps = await _api.televersement(
      '/users/$id/avatar',
      champs: const {},
      fichier: {'image': fichier},
    );
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    return data is Map<String, dynamic> ? data : const {};
  }

  Future<Utilisateur> changerStatut(int id, String statut) async {
    final corps = await _api.post('/users/$id/statut', data: {'statut': statut});
    final data = (corps as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Utilisateur.brut(data);
  }

  Future<void> supprimer(int id) => _api.delete('/users/$id');

  Future<Utilisateur> attribuerRoles(int id, List<String> roles) async {
    final corps = await _api.put('/users/$id/roles', data: {'roles': roles});
    final data = (corps as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Utilisateur.brut(data);
  }

  /// Recherche de personnes pour initier une demande d'ami.
  /// Champs volontairement réduits (e-mail/téléphone des tiers non exposés).
  Future<Page<Utilisateur>> annuaire(String terme, {int limite = 30}) async {
    final corps = await _api.get('/annuaire', params: {'q': terme, 'limite': limite});
    return Page.brut(corps, Utilisateur.brut);
  }

  // --------------------------------------------------------- référentiels RBAC

  /// Rôles + permissions de l'utilisateur courant (`GET /users/moi/roles`).
  Future<Map<String, dynamic>> rolesUtilisateur() async {
    final corps = await _api.get('/users/moi/roles');
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! Map<String, dynamic>) return const {};
    return data;
  }

  Future<List<Map<String, dynamic>>> permissions() async {
    final corps = await _api.get('/permissions');
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

}
