/// Validations côté client — miroir des règles du backend (422 groupées).
class Validations {
  Validations._();

  static final RegExp _email = RegExp(r"^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$");
  static final RegExp _telephone = RegExp(r'^\+?[0-9][0-9\s\-]{6,19}$');

  static String? email(String? valeur, {bool requis = true}) {
    final v = (valeur ?? '').trim();
    if (v.isEmpty) return requis ? 'Adresse e-mail requise.' : null;
    if (!_email.hasMatch(v)) return 'Adresse e-mail invalide.';
    return null;
  }

  static String? telephone(String? valeur, {bool requis = true}) {
    final v = (valeur ?? '').trim();
    if (v.isEmpty) return requis ? 'Numéro de téléphone requis.' : null;
    if (!_telephone.hasMatch(v)) return 'Numéro invalide (ex. +243810000000).';
    return null;
  }

  /// Politique alignée sur le backend : longueur minimale + un chiffre.
  static String? motDePasse(String? valeur, {int longueurMin = 8}) {
    final v = valeur ?? '';
    if (v.isEmpty) return 'Mot de passe requis.';
    if (v.length < longueurMin) return 'Au moins $longueurMin caractères.';
    if (!v.contains(RegExp(r'[0-9]'))) return 'Doit contenir au moins un chiffre.';
    return null;
  }

  static String? motDePasseIdentique(String? actuel, String? nouveau) {
    final erreur = motDePasse(nouveau);
    if (erreur != null) return erreur;
    if (actuel != null && actuel == nouveau) return 'Identique au mot de passe actuel.';
    return null;
  }

  static String? requis(String? valeur, {String champ = 'Ce champ', int longueurMin = 1, int longueurMax = 5000}) {
    final v = (valeur ?? '').trim();
    if (v.isEmpty) return '$champ est requis.';
    if (v.length < longueurMin) return '$champ : au moins $longueurMin caractère(s).';
    if (v.length > longueurMax) return '$champ : $longueurMax caractères maximum.';
    return null;
  }

  static String? entier(String? valeur, {bool requis = false, int? min, int? max}) {
    final v = (valeur ?? '').trim();
    if (v.isEmpty) return requis ? 'Valeur requise.' : null;
    final n = int.tryParse(v);
    if (n == null) return 'Nombre entier attendu.';
    if (min != null && n < min) return 'Valeur minimale : $min.';
    if (max != null && n > max) return 'Valeur maximale : $max.';
    return null;
  }

  static String? decimal(String? valeur, {bool requis = false, double? min, double? max}) {
    final v = (valeur ?? '').trim().replaceAll(',', '.');
    if (v.isEmpty) return requis ? 'Valeur requise.' : null;
    final n = double.tryParse(v);
    if (n == null) return 'Nombre attendu.';
    if (min != null && n < min) return 'Valeur minimale : $min.';
    if (max != null && n > max) return 'Valeur maximale : $max.';
    return null;
  }

  static String? dansIntervalle(double? valeur, double min, double max, String message) {
    if (valeur == null) return null;
    if (valeur < min || valeur > max) return message;
    return null;
  }
}
