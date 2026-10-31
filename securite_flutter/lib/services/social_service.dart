import '../models/reponse_api.dart';
import '../models/social.dart';
import '../models/utilisateur.dart';
import 'api_client.dart';

/// Demandes d'amis, messages privés et notifications.
class SocialService {
  SocialService._();

  static final SocialService instance = SocialService._();

  final ApiClient _api = ApiClient.instance;

  // ------------------------------------------------------------------ amis

  Future<List<Demande>> demandes({String? statut, String? sens}) async {
    final corps = await _api.get('/demandes', params: {
      if (statut != null && statut.isNotEmpty) 'statut': statut,
      if (sens != null && sens.isNotEmpty) 'sens': sens,
    });
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Demande.brut(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<Demande> demander(int idDestinataire) async {
    final corps =
        await _api.post('/demandes', data: {'id_destinataire': idDestinataire});
    final data = (corps as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Demande.brut(data);
  }

  Future<Demande> repondre(int idDemande, String decision) async {
    final corps = await _api.post('/demandes/$idDemande/repondre', data: {
      'statut': decision,
    });
    final data = (corps as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Demande.brut(data);
  }

  Future<void> annuler(int idDemande) => _api.delete('/demandes/$idDemande');

  Future<List<Utilisateur>> amis({String? q}) async {
    final corps = await _api.get('/amis', params: {
      if (q != null && q.isNotEmpty) 'q': q,
    });
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Utilisateur.brut(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  // -------------------------------------------------------------- messages

  Future<Page<Message>> conversation(int idAutre, {int page = 1, int perPage = 50}) async {
    final corps = await _api.get('/messages/$idAutre', params: {
      'page': page,
      'per_page': perPage,
    });
    return Page.brut(corps, Message.brut);
  }

  Future<Message> envoyerMessage(int idDestinataire, String texte) async {
    final corps = await _api.post('/messages', data: {
      'id_destinataire': idDestinataire,
      'messages': texte,
    });
    final data = (corps as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Message.brut(data);
  }

  Future<Message> marquerLu(int idMessage) async {
    final corps = await _api.post('/messages/$idMessage/lu');
    final data = (corps as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Message.brut(data);
  }

  Future<int> messagesNonLus() async {
    final corps = await _api.get('/messages-non-lus');
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! Map<String, dynamic>) return 0;
    return JsonAide.entierDefaut(data, 'non_lus');
  }

  // ---------------------------------------------------------- notifications

  Future<Page<NotificationApp>> notifications({
    int page = 1,
    int perPage = 20,
    bool nonLues = false,
  }) async {
    final corps = await _api.get('/notifications', params: {
      'page': page,
      'per_page': perPage,
      if (nonLues) 'non_lues': '1',
    });
    return Page.brut(corps, NotificationApp.brut);
  }

  Future<NotificationApp> marquerNotification(int id, {bool lu = true}) async {
    final corps = await _api.post('/notifications/$id/lu', data: {'lu': lu ? 1 : 0});
    final data = (corps as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return NotificationApp.brut(data);
  }

  Future<int> toutMarquerLu() async {
    final corps = await _api.post('/notifications/tout-lu');
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! Map<String, dynamic>) return 0;
    return JsonAide.entierDefaut(data, 'mises_a_jour');
  }
}
