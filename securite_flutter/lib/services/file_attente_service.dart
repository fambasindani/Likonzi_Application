import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// File d'attente hors ligne : alertes saisies sans réseau, rejouées dès le
/// retour de la connexion (persistance locale via SharedPreferences).
class FileAttenteService {
  FileAttenteService._();

  static const String _cle = 'file_alertes_hors_ligne';

  static Future<List<Map<String, dynamic>>> charger() async {
    final prefs = await SharedPreferences.getInstance();
    final brut = prefs.getString(_cle);
    if (brut == null || brut.isEmpty) return [];
    try {
      final liste = jsonDecode(brut);
      if (liste is! List) return [];
      return liste
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: true);
    } on FormatException {
      return [];
    }
  }

  static Future<void> ajouter(Map<String, dynamic> alerte) async {
    final liste = await charger()..add(alerte);
    await _ecrire(liste);
  }

  static Future<void> remplacer(List<Map<String, dynamic>> liste) => _ecrire(liste);

  static Future<void> vider() async => _ecrire(const []);

  static Future<void> _ecrire(List<Map<String, dynamic>> liste) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cle, jsonEncode(liste));
  }
}
