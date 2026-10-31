import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/utilisateur.dart';

/// Persistance locale de la session (JWT + profil).
///
/// `shared_preferences` est volontairement choisi : aucune configuration
/// native requise, il fonctionne sur Android, iOS, web et bureau.
/// Le jeton reste en mémoire côté Dart ; en production, migrer vers
/// `flutter_secure_storage` pour le chiffrement au repos.
class StockageService {
  StockageService._();

  static const _cleToken = 'access_token';
  static const _cleRefresh = 'refresh_token';
  static const _cleUtilisateur = 'utilisateur';

  static SharedPreferences? _prefs;

  static Future<void> initialiser() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<SharedPreferences> _p() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ------------------------------------------------------------------ jetons

  static Future<void> enregistrerSession({
    required String accessToken,
    required String refreshToken,
    Utilisateur? utilisateur,
  }) async {
    final p = await _p();
    await p.setString(_cleToken, accessToken);
    await p.setString(_cleRefresh, refreshToken);
    if (utilisateur != null) {
      await p.setString(_cleUtilisateur, jsonEncode(utilisateur.toJson()));
    }
  }

  static Future<void> enregistrerAccessToken(String token) async {
    final p = await _p();
    await p.setString(_cleToken, token);
  }

  static String? get accessToken => _prefs?.getString(_cleToken);
  static String? get refreshToken => _prefs?.getString(_cleRefresh);

  static Utilisateur? get utilisateur {
    final brut = _prefs?.getString(_cleUtilisateur);
    if (brut == null || brut.isEmpty) return null;
    try {
      return Utilisateur.brut(jsonDecode(brut) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static bool get connecte =>
      (accessToken?.isNotEmpty ?? false) && (refreshToken?.isNotEmpty ?? false);

  static Future<void> sauvegarderUtilisateur(Utilisateur u) async {
    final p = await _p();
    await p.setString(_cleUtilisateur, jsonEncode(u.toJson()));
  }

  static Future<void> effacerSession() async {
    final p = await _p();
    await p.remove(_cleToken);
    await p.remove(_cleRefresh);
    await p.remove(_cleUtilisateur);
  }
}
