import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/preuve.dart';
import '../models/reponse_api.dart';
import 'api_client.dart';

/// Téléversement, consultation et vérification d'intégrité des preuves.
class PreuveService {
  PreuveService._();

  static final PreuveService instance = PreuveService._();

  ApiClient get _api => ApiClient.instance;

  /// Extensions / limites annoncées par le backend (`/preuves/types-autorises`).
  Future<Map<String, dynamic>> typesAutorises() async {
    final corps = await _api.get('/preuves/types-autorises');
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    return data is Map<String, dynamic> ? data : const {};
  }

  Future<Preuve> televerser({
    required String entiteType,
    required int entiteId,
    required String typePreuve,
    required String cheminFichier,
    String? nomFichier,
    String? description,
  }) async {
    final fichier = await MultipartFile.fromFile(
      cheminFichier,
      filename: nomFichier ?? cheminFichier.split(RegExp(r'[\\/]+')).last,
    );
    final corps = await _api.televersement(
      '/preuves',
      champs: {
        'entite_type': entiteType,
        'entite_id': '$entiteId',
        'type_preuve': typePreuve,
        if (description != null && description.isNotEmpty) 'description': description,
      },
      fichier: {'fichier': fichier},
    );
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Preuve.brut(data);
  }

  Future<Page<Preuve>> lister({
    String? entiteType,
    int? entiteId,
    int page = 1,
    int perPage = 20,
  }) async {
    final corps = await _api.get('/preuves', params: {
      'page': page,
      'per_page': perPage,
      if (entiteType != null) 'entite_type': entiteType,
      if (entiteId != null) 'entite_id': entiteId,
    });
    return Page.brut(corps, Preuve.brut);
  }

  Future<Preuve> detail(int id) async {
    final corps = await _api.get('/preuves/$id');
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Preuve introuvable.', statut: 404, code: 'not_found');
    }
    return Preuve.brut(data);
  }

  /// Recalcule le SHA-256 côté serveur et le compare à l'empreinte en base.
  Future<VerificationIntegrite> verifier(int id) async {
    final corps = await _api.get('/preuves/$id/verifier');
    final data = corps is Map<String, dynamic> ? corps['data'] : null;
    if (data is! Map<String, dynamic>) {
      throw ExceptionApi(message: 'Réponse invalide du serveur.', code: 'format');
    }
    return Preuve.verification(data);
  }

  /// Contenu binaire d'une preuve (le téléchargement impose le JWT :
  /// `Image.network` ne peut pas joindre l'en-tête d'autorisation).
  Future<Uint8List> octets(int id) async {
    final reponse = await _api.brut.get<List<int>>(
      '/preuves/$id/telecharger',
      options: Options(responseType: ResponseType.bytes),
    );
    final data = reponse.data;
    if (data == null || data.isEmpty) {
      throw ExceptionApi(message: 'Fichier vide ou introuvable.', code: 'vide');
    }
    return Uint8List.fromList(data);
  }

  Future<void> supprimer(int id) => _api.delete('/preuves/$id');
}
