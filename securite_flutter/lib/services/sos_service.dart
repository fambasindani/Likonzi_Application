import '../models/sos.dart';
import 'api_client.dart';

/// Appels SOS — miroir de `/api/v1/sos`.
class SosService {
  SosService._();

  static final SosService instance = SosService._();

  final ApiClient _api = ApiClient.instance;

  /// État du SOS actif de l'utilisateur (compte à rebours à relancer).
  Future<Sos?> etat() async {
    final corps = await _api.get('/sos');
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! Map<String, dynamic>) return null;
    final sos = data['sos'];
    if (sos is! Map<String, dynamic>) return null;
    return Sos.brut(Map<String, dynamic>.from(sos));
  }

  /// Lance le décompte (5 à 60 minutes).
  Future<Sos> programmer({
    int dureeMinutes = 15,
    double? latitude,
    double? longitude,
  }) async {
    final corps = await _api.post('/sos', data: {
      'duree_minutes': dureeMinutes,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return _versSos(corps);
  }

  /// Annule avant l'échéance (fausse alerte, personne n'est prévenu).
  Future<Sos> annuler() => _post('/sos/annuler');

  /// Envoie sans attendre l'échéance.
  Future<Sos> envoyer() => _post('/sos/envoyer');

  /// « Je vais bien » : lève le SOS.
  Future<Sos> cloturer() => _post('/sos/cloturer');

  Future<Sos> _post(String chemin) async => _versSos(await _api.post(chemin));

  Sos _versSos(dynamic corps) {
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    final sos = data is Map<String, dynamic> ? data['sos'] : null;
    if (sos is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Sos.brut(Map<String, dynamic>.from(sos));
  }
}
