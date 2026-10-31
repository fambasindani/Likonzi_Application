import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/social.dart';
import '../services/api_client.dart';
import '../services/socket_service.dart';
import '../services/social_service.dart';

/// Compteurs sociaux + notifications temps réel.
class SocialProvider extends ChangeNotifier {
  SocialProvider() {
    _service = SocialService.instance;
    _abonnement = SocketService.instance.evenements.listen(_surEvenement);
  }

  late final SocialService _service;
  StreamSubscription<EvenementTempsReel>? _abonnement;

  int _notificationsNonLues = 0;
  int _demandesEnAttente = 0;
  int _messagesNonLus = 0;
  bool _chargement = false;
  String? _erreur;
  final List<NotificationApp> _recentes = [];

  /// Dernière alerte reçue en direct (pour le bandeau d'accueil).
  Object? derniereAlerteTempsReel;

  int get notificationsNonLues => _notificationsNonLues;
  int get demandesEnAttente => _demandesEnAttente;
  int get messagesNonLus => _messagesNonLus;
  bool get chargement => _chargement;
  String? get erreur => _erreur;
  List<NotificationApp> get recentes => List.unmodifiable(_recentes);

  int get totalNonLus => _notificationsNonLues + _messagesNonLus;

  Future<void> rafraichirCompteurs() async {
    try {
      final notifications = await _service.notifications(
        page: 1,
        perPage: 1,
        nonLues: true,
      );
      _notificationsNonLues = notifications.total;

      final demandes = await _service.demandes(statut: 'en_attente', sens: 'recues');
      _demandesEnAttente = demandes.length;

      _messagesNonLus = await _service.messagesNonLus();
      _erreur = null;
      notifyListeners();
    } on ExceptionApi catch (e) {
      _erreur = e.message;
    } catch (_) {
      _erreur = 'Impossible de charger les compteurs.';
    }
  }

  Future<void> chargerRecentes({int perPage = 15}) async {
    _chargement = true;
    notifyListeners();
    try {
      final page = await _service.notifications(page: 1, perPage: perPage);
      _recentes
        ..clear()
        ..addAll(page.elements);
      _notificationsNonLues = page.elements.where((n) => !n.lu).length;
      _erreur = null;
    } on ExceptionApi catch (e) {
      _erreur = e.message;
    } catch (_) {
      _erreur = 'Impossible de charger les notifications.';
    } finally {
      _chargement = false;
      notifyListeners();
    }
  }

  Future<void> marquerLue(NotificationApp notification) async {
    if (notification.lu) return;
    final index = _recentes.indexWhere((n) => n.id == notification.id);
    if (index >= 0) {
      _recentes[index] = await _service.marquerNotification(notification.id);
    }
    _notificationsNonLues = (_notificationsNonLues - 1).clamp(0, 1 << 31);
    notifyListeners();
  }

  Future<void> toutMarquerLu() async {
    final combien = await _service.toutMarquerLu();
    for (var i = 0; i < _recentes.length; i++) {
      if (!_recentes[i].lu) {
        _recentes[i] = _recentes[i].copierAvecLu(true);
      }
    }
    _notificationsNonLues = (_notificationsNonLues - combien).clamp(0, 1 << 31);
    notifyListeners();
  }

  void incrementerMessagesNonLus() {
    _messagesNonLus += 1;
    notifyListeners();
  }

  void _surEvenement(EvenementTempsReel evenement) {
    switch (evenement.type) {
      case 'notification':
        final notif = NotificationApp.brut(evenement.donnees);
        _notificationsNonLues += 1;
        _recentes.insert(0, notif);
        if (_recentes.length > 30) _recentes.removeRange(30, _recentes.length);
        notifyListeners();
      case 'alerte_nouvelle':
      case 'alerte_assignee':
      case 'alerte_mise_a_jour':
        derniereAlerteTempsReel = evenement.donnees;
        notifyListeners();
      default:
        break;
    }
  }

  @override
  void dispose() {
    _abonnement?.cancel();
    super.dispose();
  }
}
