import 'package:dio/dio.dart';

import 'config_service.dart';
import 'stockage_service.dart';

/// Erreur métier normalisée, lisible par l'utilisateur.
class ExceptionApi implements Exception {
  ExceptionApi({
    required this.message,
    this.statut = 0,
    this.code = 'erreur',
    this.erreurs = const {},
    this.retryAfter,
  });

  final String message;
  final int statut;
  final String code;

  /// Erreurs par champ (`{"email": ["…"]}`) — miroir de la 422 du backend.
  final Map<String, List<String>> erreurs;

  /// Secondes d'attente en cas de 429 (en-tête `Retry-After`).
  final int? retryAfter;

  bool get reseau => statut == 0;
  bool get sessionExpiree => statut == 401;
  bool get refuse => statut == 403;
  bool get introuvable => statut == 404;
  bool get limiteAtteinte => statut == 429;

  String? premierChamp() => erreurs.isEmpty ? null : erreurs.keys.first;
  List<String>? messageChamp(String champ) => erreurs[champ];

  @override
  String toString() => 'ExceptionApi($statut $code) $message';
}

/// Client HTTP unique : baseURL depuis `.env`, JWT injecté, renouvellement
/// automatique du jeton sur 401, erreurs traduites en français.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;
  bool _initialise = false;

  /// Appelée quand la session est définitivement perdue (refresh refusé).
  Future<void> Function()? onSessionExpiree;

  void initialiser() {
    if (_initialise) return;
    _initialise = true;

    _dio = Dio(
      BaseOptions(
        baseUrl: ConfigService.apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 60),
        responseType: ResponseType.json,
        headers: {'Accept': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = StockageService.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final statut = error.response?.statusCode ?? 0;
          final chemin = error.requestOptions.path;

          // Session expirée : on tente UN renouvellement, puis on rejoue.
          if (statut == 401 && !chemin.contains('/auth/refresh') && !_enCoursDeRefresh) {
            final rafraichi = await _rafraichirSession();
            if (rafraichi) {
              try {
                final reponse = await _dio.fetch(error.requestOptions);
                return handler.resolve(reponse);
              } on DioException catch (e) {
                return handler.next(e);
              }
            }
          }
          return handler.next(error);
        },
      ),
    );

    if (ConfigService.debugReseau) {
      _dio.interceptors.add(LogInterceptor(requestBody: false, responseBody: false));
    }
  }

  bool _enCoursDeRefresh = false;

  Future<bool> _rafraichirSession() async {
    final refresh = StockageService.refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    _enCoursDeRefresh = true;
    try {
      final reponse = await Dio(
        BaseOptions(baseUrl: ConfigService.apiBaseUrl, responseType: ResponseType.json),
      ).post('/auth/refresh', data: {'refresh_token': refresh});

      final corps = reponse.data is Map<String, dynamic> ? reponse.data['data'] : null;
      if (corps is Map<String, dynamic> && corps['access_token'] != null) {
        final access = corps['access_token'] as String;
        final refreshNouveau = corps['refresh_token'] as String? ?? refresh;
        await StockageService.enregistrerSession(
          accessToken: access,
          refreshToken: refreshNouveau,
          utilisateur: StockageService.utilisateur,
        );
        return true;
      }
      return false;
    } catch (_) {
      await StockageService.effacerSession();
      final cb = onSessionExpiree;
      if (cb != null) await cb();
      return false;
    } finally {
      _enCoursDeRefresh = false;
    }
  }

  // ----------------------------------------------------------------- requêtes

  Future<dynamic> get(String chemin, {Map<String, dynamic>? params}) async {
    initialiser();
    try {
      final r = await _dio.get(chemin, queryParameters: params);
      return r.data;
    } on DioException catch (e) {
      throw _versException(e);
    }
  }

  Future<dynamic> post(String chemin, {Object? data, Map<String, dynamic>? params}) async {
    initialiser();
    try {
      final r = await _dio.post(chemin, data: data, queryParameters: params);
      return r.data;
    } on DioException catch (e) {
      throw _versException(e);
    }
  }

  Future<dynamic> put(String chemin, {Object? data}) async {
    initialiser();
    try {
      final r = await _dio.put(chemin, data: data);
      return r.data;
    } on DioException catch (e) {
      throw _versException(e);
    }
  }

  Future<dynamic> patch(String chemin, {Object? data}) async {
    initialiser();
    try {
      final r = await _dio.patch(chemin, data: data);
      return r.data;
    } on DioException catch (e) {
      throw _versException(e);
    }
  }

  Future<dynamic> delete(String chemin) async {
    initialiser();
    try {
      final r = await _dio.delete(chemin);
      return r.data;
    } on DioException catch (e) {
      throw _versException(e);
    }
  }

  /// Téléversement multipart (photos, vidéos, documents).
  Future<dynamic> televersement(
    String chemin, {
    required Map<String, String> champs,
    required Map<String, dynamic> fichier,
  }) async {
    initialiser();
    final form = FormData.fromMap({
      ...champs,
      ...fichier, // {'fichier': MultipartFile(...)}
    });
    try {
      final r = await _dio.post(chemin, data: form);
      return r.data;
    } on DioException catch (e) {
      throw _versException(e);
    }
  }

  Dio get brut => _dio;

  // ------------------------------------------------------------------ erreurs

  ExceptionApi _versException(DioException e) {
    final statut = e.response?.statusCode ?? 0;
    final corps = e.response?.data;

    if (statut == 0) {
      return ExceptionApi(
        message: 'Impossible de contacter le serveur. Vérifiez votre connexion.',
        statut: 0,
        code: 'reseau',
      );
    }

    if (corps is Map<String, dynamic>) {
      final erreursBrutes = corps['errors'];
      final map = <String, List<String>>{};
      if (erreursBrutes is Map<String, dynamic>) {
        erreursBrutes.forEach((cle, valeur) {
          if (valeur is List) {
            map[cle] = valeur.map((v) => v.toString()).toList();
          } else if (valeur != null) {
            map[cle] = [valeur.toString()];
          }
        });
      }
      final retry = int.tryParse(
        e.response?.headers.value('retry-after') ?? '',
      );
      return ExceptionApi(
        message: (corps['message'] as String?) ?? _messageParDefaut(statut),
        statut: statut,
        code: (corps['code'] as String?) ?? 'erreur',
        erreurs: map,
        retryAfter: retry,
      );
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return ExceptionApi(
        message: 'Le serveur met trop de temps à répondre.',
        statut: 0,
        code: 'timeout',
      );
    }

    return ExceptionApi(message: _messageParDefaut(statut), statut: statut, code: 'http');
  }

  String _messageParDefaut(int statut) {
    switch (statut) {
      case 400:
        return 'Requête invalide.';
      case 401:
        return 'Session expirée, reconnectez-vous.';
      case 403:
        return 'Accès refusé.';
      case 404:
        return 'Ressource introuvable.';
      case 409:
        return 'Conflit : cette opération existe déjà.';
      case 413:
        return 'Fichier trop volumineux.';
      case 422:
        return 'Données invalides.';
      case 429:
        return 'Trop de tentatives, réessayez plus tard.';
      case 503:
        return 'Service momentanément indisponible.';
      default:
        if (statut >= 500) return 'Erreur interne du serveur.';
        return 'Une erreur est survenue.';
    }
  }
}
