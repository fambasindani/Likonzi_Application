import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/sos.dart';
import '../services/api_client.dart';
import '../services/sos_service.dart';
import '../services/socket_service.dart';

/// État du SOS courant + compte à rebours local (recalé sur l'échéance serveur).
class SosProvider extends ChangeNotifier {
  SosProvider() {
    _service = SosService.instance;
    _abonnement = SocketService.instance.evenements.listen(_surEvenement);
  }

  late final SosService _service;
  StreamSubscription<EvenementTempsReel>? _abonnement;
  Timer? _minuteur;

  Sos? _sos;
  bool _chargement = false;
  bool _enAction = false;
  String? _erreur;
  int _secondes = 0;

  Sos? get sos => _sos;

  /// Un SOS est en décompte ou déjà envoyé (à lever avec « Je vais bien »).
  bool get actif => _sos != null && (_sos!.enCours || _sos!.envoye);
  bool get enCours => _sos?.enCours ?? false;
  bool get envoye => _sos?.envoye ?? false;
  bool get chargement => _chargement;
  bool get enAction => _enAction;
  String? get erreur => _erreur;

  /// Secondes restantes (0 = échéance atteinte, le serveur envoie).
  int get secondes => _secondes;

  String get minuteur {
    final s = _secondes;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  /// Progression 0 → 1 du décompte (pour l'anneau visuel).
  double get progression {
    final total = (_sos?.dureeMinutes ?? 15) * 60;
    if (total <= 0) return 0;
    final reste = _secondes / total;
    return reste.clamp(0.0, 1.0);
  }

  // ------------------------------------------------------------- cycle de vie

  /// Recharge l'état serveur (et relance le minuteur).
  Future<void> rafraichir() async {
    _chargement = true;
    notifyListeners();
    try {
      _sos = await _service.etat();
      _erreur = null;
    } on ExceptionApi catch (e) {
      _erreur = e.message;
    } catch (_) {
      _erreur = 'Impossible de vérifier l’état du SOS.';
    } finally {
      _chargement = false;
      _resynchroniser();
      notifyListeners();
    }
  }

  Future<void> programmer({double? latitude, double? longitude, int dureeMinutes = 15}) async {
    _enAction = true;
    _erreur = null;
    notifyListeners();
    try {
      _sos = await _service.programmer(
        dureeMinutes: dureeMinutes,
        latitude: latitude,
        longitude: longitude,
      );
      _resynchroniser();
    } on ExceptionApi catch (e) {
      _erreur = e.message;
      rethrow;
    } finally {
      _enAction = false;
      notifyListeners();
    }
  }

  Future<void> annuler() => _action(() => _service.annuler());
  Future<void> envoyer() => _action(() => _service.envoyer());
  Future<void> cloturer() => _action(() => _service.cloturer());

  Future<void> _action(Future<Sos> Function() appel) async {
    _enAction = true;
    _erreur = null;
    notifyListeners();
    try {
      _sos = await appel();
      _resynchroniser();
    } on ExceptionApi catch (e) {
      _erreur = e.message;
      rethrow;
    } finally {
      _enAction = false;
      notifyListeners();
    }
  }

  /// Minuteur local aligné sur le TEMPS RESTANT fourni par le serveur.
  ///
  /// On ne compare jamais les heures absolues (serveur UTC, téléphone UTC+1) :
  /// le serveur dit « il reste N secondes », le téléphone décrémente depuis
  /// cette base — le chrono tourne alors quelle que soit l'heure de l'appareil.
  DateTime? _depart;
  int _baseSecondes = 0;

  void _resynchroniser() {
    _minuteur?.cancel();
    _minuteur = null;
    final sos = _sos;
    if (sos == null || !sos.enCours) {
      _secondes = 0;
      _depart = null;
      return;
    }
    _baseSecondes = sos.restantSecondes ?? sos.secondesRestantes;
    _depart = DateTime.now();
    _secondes = _baseSecondes;
    if (_baseSecondes <= 0) {
      // Échéance déjà atteinte : envoi automatique immédiat.
      notifyListeners();
      Timer(const Duration(seconds: 2), _envoyerApresEcheance);
      return;
    }
    _minuteur = Timer.periodic(const Duration(seconds: 1), (timer) {
      final ecoule =
          _depart == null ? 0 : DateTime.now().difference(_depart!).inSeconds;
      final restant = _baseSecondes - ecoule;
      if (restant <= 0) {
        timer.cancel();
        _secondes = 0;
        notifyListeners();
        // Échéance atteinte : envoi automatique (la veille serveur fait de
        // même — double sécurité pour que le SOS parte TOUJOURS).
        Timer(const Duration(seconds: 2), _envoyerApresEcheance);
      } else {
        _secondes = restant;
        notifyListeners();
      }
    });
  }

  /// Le compte à rebours est à zéro : on envoie le SOS tout de suite.
  /// Si la veille serveur l'a déjà fait (404), on se contente de resynchroniser.
  Future<void> _envoyerApresEcheance() async {
    final sos = _sos;
    if (sos == null || !sos.enCours) return; // déjà envoyé ou levé
    try {
      _sos = await _service.envoyer();
    } on ExceptionApi catch (e) {
      if (!e.introuvable) _erreur = e.message;
    } catch (_) {
      // Réseau indisponible : la veille serveur s'en charge.
    }
    _resynchroniser();
    notifyListeners();
  }

  /// Tout événement SOS reçu (le sien ou celui d'un ami) resynchronise l'état.
  void _surEvenement(EvenementTempsReel evenement) {
    switch (evenement.type) {
      case 'sos':
      case 'sos_intermediaire':
      case 'sos_envoye':
      case 'sos_cloture':
        unawaited(rafraichir());
      default:
        break;
    }
  }

  /// Alimente le provider avec des données de test (hors réseau).
  @visibleForTesting
  void ensemencerPourTest({Sos? sos, bool chargement = false, String? erreur}) {
    _sos = sos;
    _chargement = chargement;
    _erreur = erreur;
    _resynchroniser();
    notifyListeners();
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _abonnement?.cancel();
    super.dispose();
  }
}
