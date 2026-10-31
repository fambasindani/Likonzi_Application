import 'package:flutter/foundation.dart';

import '../models/utilisateur.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/stockage_service.dart';

/// Session de l'application : profil, rôles, permissions.
class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    ApiClient.instance.initialiser();
    ApiClient.instance.onSessionExpiree = () async {
      await deconnexionInterne();
    };
  }

  Utilisateur? _utilisateur;
  bool _pret = false;
  bool _chargement = false;
  String? _erreur;

  Utilisateur? get utilisateur => _utilisateur;
  bool get pret => _pret;
  bool get chargement => _chargement;
  String? get erreur => _erreur;

  /// Session locale présente (jetons stockés).
  bool get sessionLocale => StockageService.connecte;

  /// Connecté = jetons + profil connu.
  bool get connecte => _utilisateur != null && StockageService.connecte;

  bool get estPolice => _utilisateur?.estPolice ?? false;
  bool get estAdmin => _utilisateur?.estAdmin ?? false;
  bool get estEnqueteur => _utilisateur?.estEnqueteur ?? false;

  bool aRole(String r) => _utilisateur?.aRole(r) ?? false;
  bool aPermission(String c) => _utilisateur?.aPermission(c) ?? false;

  /// Restore la session locale puis recharge le profil auprès du serveur.
  Future<void> initialiser() async {
    await StockageService.initialiser();
    _utilisateur = StockageService.utilisateur;
    _pret = true;
    notifyListeners();

    if (StockageService.connecte) {
      try {
        await rafraichirProfil();
      } catch (_) {
        // Jeton expiré/révoqué : on laisse la session locale en place,
        // le prochain appel API déclenchera le renouvellement ou la purge.
      }
    }
  }

  Future<void> rafraichirProfil() async {
    final profil = await AuthService.instance.profil();
    _utilisateur = profil;
    notifyListeners();
  }

  Future<void> _appliquerSession(Session session) async {
    _utilisateur = session.utilisateur;
    _erreur = null;
    notifyListeners();
    // On recharge le profil complet (rôles + permissions détaillés).
    try {
      await rafraichirProfil();
    } catch (_) {
      // Le token vient d'être émis : les rôles de la réponse login suffisent.
    }
  }

  Future<bool> connecter({required String email, required String password}) async {
    _chargement = true;
    _erreur = null;
    notifyListeners();
    try {
      final session =
          await AuthService.instance.connecter(email: email, password: password);
      await _appliquerSession(session);
      return true;
    } on ExceptionApi catch (e) {
      _erreur = e.message;
      return false;
    } catch (e) {
      _erreur = 'Une erreur est survenue.';
      return false;
    } finally {
      _chargement = false;
      notifyListeners();
    }
  }

  Future<bool> inscrire(Map<String, dynamic> donnees) async {
    _chargement = true;
    _erreur = null;
    notifyListeners();
    try {
      final session = await AuthService.instance.inscrire(
        nom: donnees['nom'] as String,
        postnom: donnees['postnom'] as String?,
        prenom: donnees['prenom'] as String?,
        email: donnees['email'] as String,
        telephone: donnees['telephone'] as String,
        password: donnees['password'] as String,
        genre: donnees['genre'] as String?,
        adresse: donnees['adresse'] as String?,
        dateNaissance: donnees['date_naissance'] as DateTime?,
        idCommissariat: donnees['id_commissariat'] as int?,
        matriculePolice: donnees['matricule_police'] as String?,
        gradePolice: donnees['grade_police'] as String?,
      );
      await _appliquerSession(session);
      return true;
    } on ExceptionApi catch (e) {
      _erreur = e.message;
      return false;
    } catch (e) {
      _erreur = 'Une erreur est survenue.';
      return false;
    } finally {
      _chargement = false;
      notifyListeners();
    }
  }

  Future<void> deconnecter() async {
    await AuthService.instance.deconnecter();
    await deconnexionInterne();
  }

  /// Purge locale sans appel réseau (session révoquée côté serveur).
  Future<void> deconnexionInterne() async {
    await StockageService.effacerSession();
    _utilisateur = null;
    notifyListeners();
  }

  /// Met à jour le profil après `PATCH /auth/me`.
  void appliquerProfil(Utilisateur maj) {
    _utilisateur = maj;
    StockageService.sauvegarderUtilisateur(maj);
    notifyListeners();
  }

  Future<bool> changerMotDePasse({required String actuel, required String nouveau}) async {
    try {
      await AuthService.instance.changerMotDePasse(actuel: actuel, nouveau: nouveau);
      _erreur = null;
      return true;
    } on ExceptionApi catch (e) {
      _erreur = e.message;
      return false;
    }
  }

  void nettoyerErreur() {
    if (_erreur != null) {
      _erreur = null;
      notifyListeners();
    }
  }
}
