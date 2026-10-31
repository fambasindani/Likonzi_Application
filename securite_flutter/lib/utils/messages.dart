import 'package:flutter/material.dart';

import '../components/confirmation.dart';
export '../components/confirmation.dart';

import '../services/api_client.dart';

/// Affiche une erreur normalisée (`ExceptionApi` ou message générique).
/// Affiche une erreur normalisée.
///
/// Accepte aussi un simple `String` : `AuthProvider.erreur` (et les états
/// d'erreur des services) portent déjà un message lisible — les convertir
/// en « Une erreur est survenue. » masquait le vrai motif (ex. un
/// identifiant incorrect lors de la connexion).
void montrerErreur(BuildContext context, Object erreur) {
  final String message;
  if (erreur is ExceptionApi) {
    message = _messageApi(erreur);
  } else if (erreur is String && erreur.trim().isNotEmpty) {
    message = erreur.trim();
  } else {
    message = 'Une erreur est survenue.';
  }
  notifier(context, message: message, succes: false);
}

String _messageApi(ExceptionApi erreur) {
  var message = erreur.message;
  if (erreur.erreurs.isNotEmpty) {
    final premier = erreur.erreurs.values.first.join(' ');
    if (premier.isNotEmpty) message = '$message $premier';
  }
  if (erreur.limiteAtteinte && erreur.retryAfter != null) {
    message = '$message Réessayez dans ${erreur.retryAfter} s.';
  }
  return message;
}

/// Affiche un message de succès.
void montrerSucces(BuildContext context, String message) {
  notifier(context, message: message, succes: true);
}
