import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/alerte.dart';
import '../models/social.dart';
import 'config_service.dart';
import 'stockage_service.dart';

/// Événement temps réel poussé par le backend (`app/realtime.py`).
class EvenementTempsReel {
  EvenementTempsReel(this.type, this.donnees);

  final String type;
  final Map<String, dynamic> donnees;
}

/// Client Socket.IO : connexion authentifiée par JWT, écoute des salles
/// `user:<id>` et `commissariat:<id>`.
class SocketService {
  SocketService._();

  static final SocketService instance = SocketService._();

  io.Socket? _socket;
  final _controleur = StreamController<EvenementTempsReel>.broadcast();
  final _controleurConnexion = StreamController<bool>.broadcast();

  /// Flux des événements (alertes, notifications, dossiers…).
  Stream<EvenementTempsReel> get evenements => _controleur.stream;

  /// Flux d'état de la connexion.
  Stream<bool> get connexion => _controleurConnexion.stream;

  bool get connecte => _socket?.connected ?? false;

  void _emettre(String type, dynamic donnees) {
    if (_controleur.isClosed) return;
    _controleur.add(
      EvenementTempsReel(
        type,
        donnees is Map<String, dynamic> ? donnees : const <String, dynamic>{},
      ),
    );
  }

  /// Établit la connexion. `forcerReconnexion` gère les changements de réseau.
  void connecter({bool forcerReconnexion = false}) {
    final token = StockageService.accessToken;
    if (token == null || token.isEmpty) return;
    if (_socket != null && !forcerReconnexion) {
      if (_socket!.connected) return;
      _socket!.connect();
      return;
    }

    _socket?.dispose();
    final url = ConfigService.socketUrl;
    // Montage sous un préfixe (DispatcherMiddleware, ex. `/backend`) : le
    // chemin Engine.IO doit être `<préfixe>/socket.io` — socket.io ne le
    // déduit pas de l'hôte. Sans cela la requête part vers `/socket.io` à la
    // racine, servi par une autre application du même hébergeur.
    final prefixe =
        (Uri.tryParse(url)?.path ?? '').replaceAll(RegExp(r'/+$'), '');
    final options = io.OptionBuilder()
        .enableAutoConnect()
        .enableReconnection()
        .setTransports(['websocket', 'polling'])
        .setAuth({'token': token})
        .setExtraHeaders({'Authorization': 'Bearer $token'});
    if (prefixe.isNotEmpty) options.setPath('$prefixe/socket.io');
    _socket = io.io(url, options.build());

    _socket!
      ..onConnect((_) {
        if (!_controleurConnexion.isClosed) _controleurConnexion.add(true);
      })
      ..onDisconnect((_) {
        if (!_controleurConnexion.isClosed) _controleurConnexion.add(false);
      })
      ..onConnectError((erreur) {
        if (!_controleurConnexion.isClosed) _controleurConnexion.add(false);
        // ignore: avoid_print
        print('Socket.IO erreur de connexion : $erreur');
      })
      ..onError((erreur) {
        // ignore: avoid_print
        print('Socket.IO erreur : $erreur');
      });

    // Événements métier poussés par le backend.
    const evenements = <String>[
      'notification',
      'alerte_nouvelle',
      'alerte_assignee',
      'alerte_mise_a_jour',
      'dossier_ouvert',
      'dossier_mis_a_jour',
      'intervention_enregistree',
      'sos',
      'sos_intermediaire',
      'sos_envoye',
      'sos_cloture',
      'ping_client',
    ];
    for (final nom in evenements) {
      _socket!.on(nom, (donnees) {
        _emettre(
          nom,
          donnees is Map
              ? Map<String, dynamic>.from(donnees)
              : <String, dynamic>{'valeur': donnees},
        );
      });
    }
  }

  void deconnecter() {
    _socket?.dispose();
    _socket = null;
    if (!_controleurConnexion.isClosed) _controleurConnexion.add(false);
  }

  /// Rafraîchit le jeton après un renouvellement (sinon le socket est refusé).
  void rafraichirJeton() {
    if (_socket == null) return;
    deconnecter();
    connecter();
  }

  void liberer() {
    deconnecter();
    _controleur.close();
    _controleurConnexion.close();
  }

  // ------------------------------------------------------------ helpers UI

  /// Traduit un événement en modèle exploitable.
  Object? versModele(EvenementTempsReel e) {
    switch (e.type) {
      case 'alerte_nouvelle':
      case 'alerte_assignee':
      case 'alerte_mise_a_jour':
        return Alerte.brut(e.donnees);
      case 'notification':
        return NotificationApp.brut(e.donnees);
      default:
        return e.donnees;
    }
  }
}
