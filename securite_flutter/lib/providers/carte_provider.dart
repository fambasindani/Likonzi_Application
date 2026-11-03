import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/geographie.dart';
import '../services/alerte_service.dart';
import '../services/api_client.dart';
import '../services/geo_service.dart';

/// Position courante, commissariats et alertes autour de moi.
class CarteProvider extends ChangeNotifier {
  CarteProvider()
      : _geo = GeoService.instance,
        _alertes = AlerteService.instance;

  final GeoService _geo;
  final AlerteService _alertes;

  Position? _position;
  LatLng? _centre;
  Lieu? _lieu;
  List<Commissariat> _commissariats = [];
  List<AlerteProche> _alertesProches = [];
  bool _chargement = false;
  bool _positionEnCours = false;
  String? _erreur;

  Position? get position => _position;
  LatLng? get centre => _centre;

  /// Ville/commune la plus proche de la position (en-tête de l'accueil).
  Lieu? get lieu => _lieu;
  String? get ville => (_lieu?.affichage.isNotEmpty ?? false) ? _lieu!.affichage : null;
  List<Commissariat> get commissariats => List.unmodifiable(_commissariats);
  List<AlerteProche> get alertesProches => List.unmodifiable(_alertesProches);
  bool get chargement => _chargement;
  bool get positionEnCours => _positionEnCours;
  String? get erreur => _erreur;

  /// Centre par défaut si la position est refusée : Kinshasa / Gombe.
  static const LatLng centreParDefaut = LatLng(-4.3250, 15.3100);

  LatLng get pointCentral => _centre ?? centreParDefaut;

  /// Lit la position de l'appareil (aucun enregistrement serveur).
  Future<bool> localiserAppareil({bool forcer = false}) async {
    if (_positionEnCours) return false;
    if (_position != null && !forcer) return true;
    _positionEnCours = true;
    _erreur = null;
    notifyListeners();
    try {
      final position = await _geo.positionAppareil();
      _position = position;
      if (position != null) {
        _centre = LatLng(position.latitude, position.longitude);
        await _chargerLieu(position);
      }
      return position != null;
    } on ExceptionApi catch (e) {
      _erreur = e.message;
      return false;
    } catch (e) {
      _erreur = "Impossible d'obtenir la position.";
      return false;
    } finally {
      _positionEnCours = false;
      notifyListeners();
    }
  }

  /// Résout la ville/commune depuis le GPS (géocodage inverse du serveur).
  Future<void> _chargerLieu(Position position) async {
    try {
      _lieu = await _geo.lieu(latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      // Sans réseau : la ville reste inconnue, l'en-tête affiche le défaut.
    }
  }

  StreamSubscription<Position>? _suiviPosition;
  DateTime? _dernierePublication;

  /// Suit la position pendant le déplacement : l'en-tête, la carte et les
  /// alertes proches restent à jour ; la position est publiée au serveur au
  /// plus une fois toutes les 30 s (et après 25 m de déplacement).
  Future<void> demarrerSuivi() async {
    if (_suiviPosition != null) return;
    final ok = await localiserAppareil();
    if (!ok) return;
    _suiviPosition = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      ),
    ).listen((position) {
      _position = position;
      _centre = LatLng(position.latitude, position.longitude);
      notifyListeners();

      final maintenant = DateTime.now();
      final dernier = _dernierePublication;
      if (dernier == null || maintenant.difference(dernier).inSeconds >= 30) {
        _dernierePublication = maintenant;
        publierMaPosition(); // best effort : un échec réseau n'arrête pas le suivi
      }
    });
  }

  void arreterSuivi() {
    _suiviPosition?.cancel();
    _suiviPosition = null;
  }

  @override
  void dispose() {
    _suiviPosition?.cancel();
    super.dispose();
  }

  /// Enregistre la position côté backend (`POST /positions`).
  Future<void> publierMaPosition() async {
    final position = _position ?? await _geo.positionAppareil();
    if (position == null) return;
    _position = position;
    _centre = LatLng(position.latitude, position.longitude);
    try {
      await _geo.enregistrerPosition(
        latitude: position.latitude,
        longitude: position.longitude,
        precisionMetres: position.accuracy,
        source: 'gps',
      );
    } catch (_) {
      // Non bloquant : la position reste affichée localement.
    }
    notifyListeners();
  }

  /// Charge commissariats + alertes autour du point donné.
  Future<void> chargerAutour({
    double rayonKm = 15,
    bool avecAlertes = true,
    LatLng? centre,
  }) async {
    final point = centre ?? pointCentral;
    _chargement = true;
    _erreur = null;
    notifyListeners();
    try {
      _commissariats = await _geo.commissariatsProches(
        latitude: point.latitude,
        longitude: point.longitude,
        rayonKm: rayonKm,
      );
      if (avecAlertes) {
        _alertesProches = await _alertes.autourDeMoi(
          latitude: point.latitude,
          longitude: point.longitude,
          rayonKm: rayonKm,
        );
      }
    } on ExceptionApi catch (e) {
      _erreur = e.message;
    } catch (_) {
      _erreur = 'Impossible de charger les données de proximité.';
    } finally {
      _chargement = false;
      notifyListeners();
    }
  }

  void deplacerCentre(LatLng point) {
    _centre = point;
    notifyListeners();
  }

  void effacerAlertes() {
    _alertesProches = [];
    notifyListeners();
  }
}
