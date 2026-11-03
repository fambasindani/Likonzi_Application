import 'package:flutter/services.dart';

/// Routes demandées depuis l'extérieur de l'application.
///
/// Le widget d'accueil Android (« SOS ») ouvre l'application directement sur
/// l'écran SOS : `MainActivity` transmet la route via ce canal.
class RouteService {
  RouteService._();

  static const MethodChannel _canal = MethodChannel('cd.securite.securite/route');
  static bool _ecoute = false;

  /// Lit la route demandée au lancement puis écoute les appels ultérieurs
  /// (application déjà ouverte). À appeler une seule fois.
  static Future<void> initialiser({required void Function(String route) ouvrir}) async {
    if (_ecoute) return;
    _ecoute = true;

    _canal.setMethodCallHandler((call) async {
      if (call.method == 'ouvrirRoute' && call.arguments is String) {
        ouvrir(call.arguments as String);
      }
    });

    try {
      final route = await _canal.invokeMethod<String>('routeInitiale');
      if (route != null && route.isNotEmpty) ouvrir(route);
    } on PlatformException {
      // Canal absent (hors Android) : rien à faire.
    } on MissingPluginException {
      // Tests / iOS : aucun widget natif.
    }
  }
}
