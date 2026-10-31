import 'package:intl/intl.dart';

/// Formatage des dates, durées, distances et nombres en `fr_FR`.
class Formatage {
  Formatage._();

  static final DateFormat _jour = DateFormat('dd/MM/yyyy');
  static final DateFormat _heure = DateFormat('HH:mm');
  static final DateFormat _complet = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _long = DateFormat('d MMMM yyyy à HH:mm', 'fr_FR');
  static final DateFormat _moisAnnee = DateFormat('MMMM yyyy', 'fr_FR');

  /// `30/10/2026 19:04`
  static String dateTime(DateTime? valeur) =>
      valeur == null ? '—' : _complet.format(valeur.toLocal());

  /// `30/10/2026`
  static String date(DateTime? valeur) => valeur == null ? '—' : _jour.format(valeur.toLocal());

  /// `19:04`
  static String heure(DateTime? valeur) => valeur == null ? '—' : _heure.format(valeur.toLocal());

  /// `30 octobre 2026 à 19:04`
  static String dateLongue(DateTime? valeur) =>
      valeur == null ? '—' : _long.format(valeur.toLocal());

  /// `octobre 2026`
  static String moisAnnee(DateTime? valeur) =>
      valeur == null ? '—' : _moisAnnee.format(valeur.toLocal());

  /// « il y a 5 min », « hier », « il y a 3 jours »…
  static String relative(DateTime? valeur) {
    if (valeur == null) return '—';
    final ecart = DateTime.now().difference(valeur);
    if (ecart.isNegative) return dateTime(valeur);
    if (ecart.inSeconds < 60) return "à l'instant";
    if (ecart.inMinutes < 60) return 'il y a ${ecart.inMinutes} min';
    if (ecart.inHours < 24) return 'il y a ${ecart.inHours} h';
    if (ecart.inDays == 1) return 'hier';
    if (ecart.inDays < 7) return 'il y a ${ecart.inDays} jours';
    if (ecart.inDays < 31) return 'il y a ${(ecart.inDays / 7).floor()} sem.';
    return date(valeur);
  }

  /// « il y a 45 min » / « dans 2 h » pour les durées signées.
  static String duree(int? minutes) {
    if (minutes == null) return '—';
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m';
  }

  /// `1 234,5 km`
  static String distance(double kilometres) {
    final fmt = NumberFormat('#,##0.0', 'fr_FR');
    if (kilometres < 1) {
      return '${NumberFormat('#,##0', 'fr_FR').format(kilometres * 1000)} m';
    }
    return '${fmt.format(kilometres)} km';
  }

  /// `1,2 Mo` / `856 Ko`
  static String taille(int octets) {
    if (octets < 1024) return '$octets o';
    if (octets < 1024 * 1024) return '${NumberFormat('#,##0', 'fr_FR').format(octets / 1024)} Ko';
    if (octets < 1024 * 1024 * 1024) {
      return '${NumberFormat('#,##0.0', 'fr_FR').format(octets / (1024 * 1024))} Mo';
    }
    return '${NumberFormat('#,##0.0', 'fr_FR').format(octets / (1024 * 1024 * 1024))} Go';
  }

  static String nombre(int valeur) => NumberFormat.decimalPattern('fr_FR').format(valeur);

  /// `+243 810 000 000`
  static String telephone(String? brut) {
    if (brut == null || brut.isEmpty) return '—';
    final chiffres = brut.replaceAll(RegExp(r'[^\d+]'), '');
    if (chiffres.startsWith('+243')) {
      final n = chiffres.substring(4).replaceAll(RegExp(r'\D'), '');
      final parts = <String>[];
      for (var i = 0; i < n.length; i += 3) {
        parts.add(n.substring(i, i + 3 > n.length ? n.length : i + 3));
      }
      return '+243 ${parts.join(' ')}';
    }
    return brut;
  }

  /// Première lettre d'un nom pour l'avatar.
  static String initiales(String? nom, String? prenom) {
    final n = (nom ?? '').trim();
    final p = (prenom ?? '').trim();
    if (n.isEmpty && p.isEmpty) return '?';
    final a = n.isNotEmpty ? n[0].toUpperCase() : '';
    final b = p.isNotEmpty ? p[0].toUpperCase() : '';
    return '$a$b';
  }
}
