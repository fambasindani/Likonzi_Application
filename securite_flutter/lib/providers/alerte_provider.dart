import 'package:flutter/foundation.dart';

import '../models/alerte.dart';
import '../services/alerte_service.dart';
import '../services/api_client.dart';
import '../services/file_attente_service.dart';

/// File des alertes (citoyen : les siennes — policier : son commissariat).
class AlerteProvider extends ChangeNotifier {
  AlerteProvider() {
    _service = AlerteService.instance;
  }

  late final AlerteService _service;

  final List<Alerte> _alertes = [];
  List<TypeAlerte> _types = [];
  int _page = 1;
  int _total = 0;
  int _pages = 0;
  bool _chargement = false;
  bool _chargePlus = false;
  String? _erreur;

  // Filtres
  final List<String> _statuts = [];
  String? _urgence;
  String _recherche = '';

  List<Alerte> get alertes => List.unmodifiable(_alertes);
  List<TypeAlerte> get types => List.unmodifiable(_types);
  int get total => _total;
  bool get chargement => _chargement;
  bool get chargePlus => _chargePlus;
  String? get erreur => _erreur;
  bool get aPlus => _page < _pages;
  List<String> get statutsFiltres => List.unmodifiable(_statuts);
  String? get urgenceFiltre => _urgence;
  String get recherche => _recherche;

  int get nombreNouvelles => _alertes.where((a) => a.estNouvelle).length;

  Future<void> charger({bool forcer = false}) async {
    if (_chargement) return;
    if (_alertes.isNotEmpty && !forcer) return;
    _chargement = true;
    _erreur = null;
    notifyListeners();
    try {
      final page = await _service.lister(
        page: 1,
        perPage: 20,
        statuts: _statuts.isEmpty ? null : _statuts,
        urgence: _urgence,
        q: _recherche.isEmpty ? null : _recherche,
      );
      _alertes
        ..clear()
        ..addAll(page.elements);
      _page = page.page;
      _pages = page.pages;
      _total = page.total;
    } on ExceptionApi catch (e) {
      _erreur = e.message;
    } catch (e) {
      _erreur = 'Impossible de charger les alertes.';
    } finally {
      _chargement = false;
      notifyListeners();
    }
  }

  Future<void> rafraichir() => charger(forcer: true);

  Future<bool> chargerPageSuivante() async {
    if (_chargement || _chargePlus || !aPlus) return false;
    _chargePlus = true;
    notifyListeners();
    try {
      final page = await _service.lister(
        page: _page + 1,
        perPage: 20,
        statuts: _statuts.isEmpty ? null : _statuts,
        urgence: _urgence,
        q: _recherche.isEmpty ? null : _recherche,
      );
      _alertes.addAll(page.elements);
      _page = page.page;
      _pages = page.pages;
      _total = page.total;
      return true;
    } catch (_) {
      return false;
    } finally {
      _chargePlus = false;
      notifyListeners();
    }
  }

  Future<List<TypeAlerte>> chargerTypes({bool forcer = false}) async {
    if (_types.isNotEmpty && !forcer) return _types;
    try {
      _types = await _service.types();
      notifyListeners();
    } catch (_) {
      // Les types resteront vides : l'écran affichera une erreur.
    }
    return _types;
  }

  void definirStatuts(List<String> statuts) {
    _statuts
      ..clear()
      ..addAll(statuts);
    charger(forcer: true);
  }

  void definirUrgence(String? urgence) {
    _urgence = (urgence == null || urgence.isEmpty) ? null : urgence;
    charger(forcer: true);
  }

  void definirRecherche(String valeur) {
    _recherche = valeur.trim();
    charger(forcer: true);
  }

  // ------------------------------------------------------------- mutations

  Future<Alerte> creer({
    required int idTypeAlerte,
    required String contenu,
    String? niveauUrgence,
    double? latitude,
    double? longitude,
    String? adressePrecise,
    int? idCommissariat,
  }) async {
    try {
      final alerte = await _service.creer(
        idTypeAlerte: idTypeAlerte,
        contenu: contenu,
        niveauUrgence: niveauUrgence,
        latitude: latitude,
        longitude: longitude,
        adressePrecise: adressePrecise,
        idCommissariat: idCommissariat,
      );
      _alertes.insert(0, alerte);
      _total += 1;
      notifyListeners();
      // Le réseau vient de répondre : on rejoue ce qui était en attente.
      await viderFileAttente();
      return alerte;
    } on ExceptionApi catch (e) {
      if (!e.reseau) rethrow;
      // Hors ligne : la saisie est conservée et partira dès le retour réseau.
      return _mettreEnAttente(
        idTypeAlerte: idTypeAlerte,
        contenu: contenu,
        niveauUrgence: niveauUrgence,
        latitude: latitude,
        longitude: longitude,
        adressePrecise: adressePrecise,
        idCommissariat: idCommissariat,
      );
    }
  }

  /// Alerte conservée localement en attendant le réseau (id négatif).
  Future<Alerte> _mettreEnAttente({
    required int idTypeAlerte,
    required String contenu,
    String? niveauUrgence,
    double? latitude,
    double? longitude,
    String? adressePrecise,
    int? idCommissariat,
  }) async {
    await FileAttenteService.ajouter({
      'id_type_alerte': idTypeAlerte,
      'contenu': contenu,
      'niveau_urgence': niveauUrgence,
      'latitude': latitude,
      'longitude': longitude,
      'adresse_precise': adressePrecise,
      'id_commissariat': idCommissariat,
      'enregistre_le': DateTime.now().toIso8601String(),
    });

    TypeAlerte? type;
    for (final t in _types) {
      if (t.id == idTypeAlerte) {
        type = t;
        break;
      }
    }

    final locale = Alerte.brut({
      'id': -DateTime.now().millisecondsSinceEpoch,
      'reference': 'ALT-HORS-LIGNE',
      'id_type_alerte': idTypeAlerte,
      'contenu': contenu,
      'niveau_urgence': niveauUrgence ?? 'moyen',
      'statut': 'nouvelle',
      'latitude': latitude,
      'longitude': longitude,
      'adresse_precise': adressePrecise,
      'date_alerte': DateTime.now().toIso8601String(),
      if (type != null) 'type': {'code': type.code, 'contenu': type.contenu},
    });
    _alertes.insert(0, locale);
    _total += 1;
    notifyListeners();
    return locale;
  }

  /// Rejoue la file hors ligne. Renvoie le nombre d'alertes réellement envoyées.
  Future<int> viderFileAttente() async {
    final file = await FileAttenteService.charger();
    if (file.isEmpty) return 0;

    final restants = <Map<String, dynamic>>[];
    var envoyees = 0;
    for (final item in file) {
      try {
        await _service.creer(
          idTypeAlerte: item['id_type_alerte'] as int,
          contenu: item['contenu'] as String,
          niveauUrgence: item['niveau_urgence'] as String?,
          latitude: (item['latitude'] as num?)?.toDouble(),
          longitude: (item['longitude'] as num?)?.toDouble(),
          adressePrecise: item['adresse_precise'] as String?,
          idCommissariat: item['id_commissariat'] as int?,
        );
        envoyees += 1;
      } on ExceptionApi catch (e) {
        if (e.reseau) {
          // Toujours hors ligne : on arrête et on conserve le reste.
          restants.add(item);
          break;
        }
        // Erreur métier définitive (422…) : cet élément ne partira jamais.
      } catch (_) {
        restants.add(item);
        break;
      }
    }
    await FileAttenteService.remplacer(restants);

    if (envoyees > 0) {
      // Les alertes locales sont remplacées par les vraies (id serveur).
      await charger(forcer: true);
    }
    return envoyees;
  }

  Future<Alerte> mettreAJour(Alerte alerte) async {
    final maj = await _service.detail(alerte.id);
    final index = _alertes.indexWhere((a) => a.id == maj.id);
    if (index >= 0) {
      _alertes[index] = maj;
      notifyListeners();
    }
    return maj;
  }

  Future<Alerte> changerStatut(int id, String statut, {String? observation}) async {
    final maj = await _service.changerStatut(id, statut, observation: observation);
    final index = _alertes.indexWhere((a) => a.id == id);
    if (index >= 0) {
      _alertes[index] = maj;
      notifyListeners();
    }
    return maj;
  }

  Future<Alerte> prendreEnCharge(int id) async {
    final maj = await _service.prendreEnCharge(id);
    final index = _alertes.indexWhere((a) => a.id == id);
    if (index >= 0) {
      _alertes[index] = maj;
      notifyListeners();
    }
    return maj;
  }

  Future<void> supprimer(int id) async {
    await _service.supprimer(id);
    _alertes.removeWhere((a) => a.id == id);
    _total = (_total - 1).clamp(0, 1 << 31);
    notifyListeners();
  }

  /// Alimente le provider avec des données de test (hors réseau).
  @visibleForTesting
  void ensemencerPourTest({
    required List<Alerte> alertes,
    List<TypeAlerte> types = const [],
    int total = 0,
    String? erreur,
  }) {
    _alertes
      ..clear()
      ..addAll(alertes);
    _types = types;
    _total = total == 0 ? alertes.length : total;
    _page = 1;
    _pages = 1;
    _chargement = false;
    _erreur = erreur;
    notifyListeners();
  }

  /// Insère une alerte reçue en temps réel (salle du commissariat).
  void insererTempsReel(Alerte alerte) {
    _alertes.removeWhere((a) => a.id == alerte.id);
    _alertes.insert(0, alerte);
    _total += 1;
    notifyListeners();
  }
}
