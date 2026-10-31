import '../models/utilisateur.dart';
import 'api_client.dart';
import 'stockage_service.dart';

/// Jetons + profil renvoyés par les endpoints d'authentification.
class Session {
  Session({required this.utilisateur, required this.accessToken, required this.refreshToken});

  final Utilisateur utilisateur;
  final String accessToken;
  final String refreshToken;
}

/// Flux d'authentification (miroir de `/api/v1/auth/*`).
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final ApiClient _api = ApiClient.instance;

  Session _depuis(dynamic corps) {
    final map = corps is Map<String, dynamic> ? corps['data'] : null;
    if (map is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    final utilisateur = Utilisateur.brut(map['user'] as Map<String, dynamic>? ?? const {});
    return Session(
      utilisateur: utilisateur,
      accessToken: map['access_token'] as String? ?? '',
      refreshToken: map['refresh_token'] as String? ?? '',
    );
  }

  /// Inscription libre — rôle citoyen uniquement (cf. backend).
  Future<Session> inscrire({
    required String nom,
    String? postnom,
    String? prenom,
    required String email,
    required String telephone,
    required String password,
    String? genre,
    String? adresse,
    DateTime? dateNaissance,
    int? idCommissariat,
    String? matriculePolice,
    String? gradePolice,
    List<String>? roles,
  }) async {
    final corps = await _api.post('/auth/register', data: {
      'nom': nom,
      if (postnom != null && postnom.isNotEmpty) 'postnom': postnom,
      if (prenom != null && prenom.isNotEmpty) 'prenom': prenom,
      'email': email,
      'telephone': telephone,
      'password': password,
      if (genre != null && genre.isNotEmpty) 'genre': genre,
      if (adresse != null && adresse.isNotEmpty) 'adresse': adresse,
      if (dateNaissance != null)
        'date_naissance': dateNaissance.toIso8601String().split('T').first,
      if (idCommissariat != null) 'id_commissariat': idCommissariat,
      if (matriculePolice != null && matriculePolice.isNotEmpty)
        'matricule_police': matriculePolice,
      if (gradePolice != null && gradePolice.isNotEmpty) 'grade_police': gradePolice,
      if (roles != null && roles.isNotEmpty) 'roles': roles,
    });
    final session = _depuis(corps);
    await StockageService.enregistrerSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      utilisateur: session.utilisateur,
    );
    return session;
  }

  Future<Session> connecter({required String email, required String password}) async {
    final corps = await _api.post('/auth/login', data: {'email': email, 'password': password});
    final session = _depuis(corps);
    await StockageService.enregistrerSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      utilisateur: session.utilisateur,
    );
    return session;
  }

  Future<void> deconnecter() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // Même si l'API échoue, on purge la session locale.
    }
    await StockageService.effacerSession();
  }

  /// Profil complet (rôles + permissions) — `GET /auth/me`.
  Future<Utilisateur> profil() async {
    final corps = await _api.get('/auth/me');
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    final utilisateur = Utilisateur.brut(data);
    await StockageService.sauvegarderUtilisateur(utilisateur);
    return utilisateur;
  }

  Future<void> changerMotDePasse({required String actuel, required String nouveau}) async {
    await _api.post('/auth/change-password', data: {
      'current_password': actuel,
      'password': nouveau,
    });
  }

  /// Demande un code de vérification (`email` ou `telephone`).
  /// Retourne le code en clair uniquement si `MAIL_ENABLED=false` côté backend.
  Future<Map<String, dynamic>> demanderVerification(String type) async {
    final corps = await _api.post('/auth/send-verification', data: {'type': type});
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    return data is Map<String, dynamic> ? data : const {};
  }

  Future<void> confirmerVerification({required String type, required String code}) async {
    await _api.post('/auth/verify', data: {'type': type, 'code': code});
  }

  Future<Map<String, dynamic>> motDePasseOublie(String email) async {
    final corps = await _api.post('/auth/forgot-password', data: {'email': email});
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    return data is Map<String, dynamic> ? data : const {};
  }

  Future<void> reinitialiserMotDePasse({
    required String email,
    required String code,
    required String nouveau,
  }) async {
    await _api.post('/auth/reset-password', data: {
      'email': email,
      'code': code,
      'password': nouveau,
    });
  }
}
