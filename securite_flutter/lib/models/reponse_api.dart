/// Modèle de base : conversion JSON → Dart tolérante aux champs absents.
///
/// Le backend peut ajouter des champs sans casser l'application : on lit
/// toujours via ces helpers plutôt que par accès direct dynamique.
class JsonAide {
  JsonAide._();

  static int? entier(Map<String, dynamic>? j, String cle) {
    final v = j?[cle];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static int entierDefaut(Map<String, dynamic>? j, String cle, [int defaut = 0]) =>
      entier(j, cle) ?? defaut;

  static double? decimal(Map<String, dynamic>? j, String cle) {
    final v = j?[cle];
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }

  static String? texte(Map<String, dynamic>? j, String cle) {
    final v = j?[cle];
    if (v == null) return null;
    return v.toString();
  }

  static String texteDefaut(Map<String, dynamic>? j, String cle, [String defaut = '']) =>
      texte(j, cle) ?? defaut;

  static bool booleen(Map<String, dynamic>? j, String cle) {
    final v = j?[cle];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  static DateTime? date(Map<String, dynamic>? j, String cle) {
    final v = j?[cle];
    if (v == null || (v is String && v.isEmpty)) return null;
    return DateTime.tryParse(v.toString());
  }

  static Map<String, dynamic>? objet(Map<String, dynamic>? j, String cle) {
    final v = j?[cle];
    return v is Map<String, dynamic> ? v : null;
  }

  static List<Map<String, dynamic>> liste(Map<String, dynamic>? j, String cle) {
    final v = j?[cle];
    if (v is! List) return [];
    return v
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }
}

/// Enveloppe de réponse du backend : `{success, message, data, meta, errors}`.
class ReponseApi<T> {
  ReponseApi({
    required this.succes,
    this.message,
    this.donnees,
    this.meta,
    this.erreurs = const {},
  });

  final bool succes;
  final String? message;
  final T? donnees;
  final Map<String, dynamic>? meta;
  final Map<String, List<String>> erreurs;

  factory ReponseApi.brut(
    dynamic corps, {
    T Function(dynamic)? depuis,
  }) {
    if (corps is! Map<String, dynamic>) {
      return ReponseApi(succes: true, donnees: depuis?.call(corps));
    }
    final erreurs = <String, List<String>>{};
    final brut = corps['errors'];
    if (brut is Map<String, dynamic>) {
      brut.forEach((cle, valeur) {
        if (valeur is List) {
          erreurs[cle] = valeur.map((e) => e.toString()).toList();
        } else if (valeur != null) {
          erreurs[cle] = [valeur.toString()];
        }
      });
    }
    return ReponseApi(
      succes: corps['success'] == true,
      message: corps['message'] as String?,
      donnees: depuis == null ? corps['data'] as T? : depuis.call(corps['data']),
      meta: corps['meta'] is Map<String, dynamic> ? corps['meta'] as Map<String, dynamic> : null,
      erreurs: erreurs,
    );
  }

  bool get aMeta => meta != null;
}

/// Page de résultats paginés (`meta = {page, per_page, total, pages, …}`).
class Page<T> {
  Page({required this.elements, required this.page, required this.total, this.pages = 0});

  final List<T> elements;
  final int page;
  final int total;
  final int pages;

  bool get pageSuivante => page < pages;

  factory Page.brut(dynamic corps, T Function(Map<String, dynamic>) depuis) {
    final map = corps is Map<String, dynamic> ? corps : <String, dynamic>{};
    final meta = map['meta'] is Map<String, dynamic>
        ? map['meta'] as Map<String, dynamic>
        : <String, dynamic>{};
    final data = map['data'];
    final elements = <T>[];
    if (data is List) {
      for (final item in data) {
        if (item is Map) {
          elements.add(depuis(Map<String, dynamic>.from(item)));
        }
      }
    }
    return Page(
      elements: elements,
      page: JsonAide.entierDefaut(meta, 'page', 1),
      total: JsonAide.entierDefaut(meta, 'total', elements.length),
      pages: JsonAide.entierDefaut(meta, 'pages', 0),
    );
  }
}
