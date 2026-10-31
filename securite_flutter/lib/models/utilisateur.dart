import '../utils/formatage.dart';
import 'reponse_api.dart';
import '../services/config_service.dart';

/// Rôle d'un utilisateur (RBAC côté backend).
class Role {
  Role({required this.id, required this.nom, this.description, this.permissions = const []});

  final int id;
  final String nom;
  final String? description;
  final List<String> permissions;

  factory Role.brut(Map<String, dynamic> j) => Role(
        id: JsonAide.entierDefaut(j, 'id'),
        nom: JsonAide.texteDefaut(j, 'nom'),
        description: JsonAide.texte(j, 'description'),
        permissions: JsonAide.liste(j, 'permissions')
            .map((p) => JsonAide.texteDefaut(p, 'code'))
            .where((c) => c.isNotEmpty)
            .toList(growable: false),
      );

  String get libelle {
    switch (nom) {
      case 'citoyen':
        return 'Citoyen';
      case 'policier':
        return 'Policier';
      case 'enqueteur':
        return 'Enquêteur';
      case 'admin':
        return 'Administrateur';
      case 'super_admin':
        return 'Super administrateur';
      default:
        return nom;
    }
  }
}

/// Utilisateur (miroir de `User.to_dict()` du backend).
class Utilisateur {
  Utilisateur({
    required this.id,
    required this.nom,
    required this.email,
    required this.telephone,
    this.postnom,
    this.prenom,
    this.avatar,
    this.statut = 'actif',
    this.adresse,
    this.dateNaissance,
    this.genre,
    this.idCommissariat,
    this.commissariatNom,
    this.matriculePolice,
    this.gradePolice,
    this.emailVerifie = false,
    this.telephoneVerifie = false,
    this.derniereConnexion,
    this.roles = const [],
    this.permissions = const [],
  });

  final int id;
  final String nom;
  final String? postnom;
  final String? prenom;
  final String email;
  final String telephone;
  final String? avatar;
  final String statut;
  final String? adresse;
  final DateTime? dateNaissance;
  final String? genre;
  final int? idCommissariat;
  final String? commissariatNom;
  final String? matriculePolice;
  final String? gradePolice;
  final bool emailVerifie;
  final bool telephoneVerifie;
  final DateTime? derniereConnexion;
  final List<String> roles;
  final List<String> permissions;

  factory Utilisateur.brut(Map<String, dynamic> j) {
    final commissariat = JsonAide.objet(j, 'commissariat');
    final roles = (j['roles'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    // Les permissions peuvent arriver en codes (`['alertes.lire']`) ou en
    // objets complets (`[{'code': 'alertes.lire'}]`) : on accepte les deux.
    final perms = (j['permissions'] as List?)
            ?.map((e) => (e is Map ? '${e['code'] ?? ''}' : '$e').trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    return Utilisateur(
      id: JsonAide.entierDefaut(j, 'id'),
      nom: JsonAide.texteDefaut(j, 'nom'),
      postnom: JsonAide.texte(j, 'postnom'),
      prenom: JsonAide.texte(j, 'prenom'),
      email: JsonAide.texteDefaut(j, 'email'),
      telephone: JsonAide.texteDefaut(j, 'telephone'),
      avatar: JsonAide.texte(j, 'avatar'),
      statut: JsonAide.texteDefaut(j, 'statut', 'actif'),
      adresse: JsonAide.texte(j, 'adresse'),
      dateNaissance: JsonAide.date(j, 'date_naissance'),
      genre: JsonAide.texte(j, 'genre'),
      idCommissariat: JsonAide.entier(j, 'id_commissariat'),
      commissariatNom: JsonAide.texte(commissariat, 'nom') ?? JsonAide.texte(j, 'commissariat_nom'),
      matriculePolice: JsonAide.texte(j, 'matricule_police'),
      gradePolice: JsonAide.texte(j, 'grade_police'),
      emailVerifie: JsonAide.booleen(j, 'email_verifie'),
      telephoneVerifie: JsonAide.booleen(j, 'telephone_verifie'),
      derniereConnexion: JsonAide.date(j, 'derniere_connexion'),
      roles: roles,
      permissions: perms,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nom': nom,
        'postnom': postnom,
        'prenom': prenom,
        'email': email,
        'telephone': telephone,
        'avatar': avatar,
        'statut': statut,
        'adresse': adresse,
        'date_naissance': dateNaissance?.toIso8601String(),
        'genre': genre,
        'id_commissariat': idCommissariat,
        'commissariat': idCommissariat == null
            ? null
            : {'id': idCommissariat, 'nom': commissariatNom},
        'matricule_police': matriculePolice,
        'grade_police': gradePolice,
        'email_verifie': emailVerifie,
        'telephone_verifie': telephoneVerifie,
        'derniere_connexion': derniereConnexion?.toIso8601String(),
        'roles': roles,
        'permissions': permissions,
      };

  // -------------------------------------------------------------- accesseurs

  String get prenomAffiche => (prenom?.isNotEmpty ?? false) ? prenom! : nom;

  String get nomComplet =>
      [nom, postnom, prenom].where((e) => e != null && e.isNotEmpty).join(' ');

  String get initiales => Formatage.initiales(nom, prenom);

  /// URL absolue : le backend renvoie un chemin relatif à `/static/`.
  String? get urlAvatar =>
      (avatar == null || avatar!.isEmpty) ? null : ConfigService.media(avatar);

  bool aRole(String r) => roles.contains(r);

  bool aPermission(String code) => permissions.contains(code);

  /// police / enquêteur / admin
  bool get estPolice =>
      aRole('policier') || aRole('enqueteur') || aRole('admin') || aRole('super_admin');

  bool get estAdmin => aRole('admin') || aRole('super_admin');
  bool get estSuperAdmin => aRole('super_admin');
  bool get estEnqueteur => aRole('enqueteur');
  bool get estCitoyen => !estPolice;
  bool get actif => statut == 'actif';
  bool get emailVerifieOk => emailVerifie;

  /// Libellé du grade/matrice pour l'écran profil.
  String get fonction {
    if (matriculePolice != null && matriculePolice!.isNotEmpty) {
      return gradePolice ?? matriculePolice!;
    }
    if (roles.isNotEmpty) {
      final premier = roles.first;
      switch (premier) {
        case 'citoyen':
          return 'Citoyen';
        case 'policier':
          return 'Agent de police';
        case 'enqueteur':
          return 'Enquêteur';
        case 'admin':
          return 'Administrateur';
        case 'super_admin':
          return 'Super administrateur';
      }
    }
    return 'Utilisateur';
  }

  Utilisateur copierAvec({List<String>? roles, List<String>? permissions, String? avatar, String? statut}) =>
      Utilisateur(
        id: id,
        nom: nom,
        postnom: postnom,
        prenom: prenom,
        email: email,
        telephone: telephone,
        avatar: avatar ?? this.avatar,
        statut: statut ?? this.statut,
        adresse: adresse,
        dateNaissance: dateNaissance,
        genre: genre,
        idCommissariat: idCommissariat,
        commissariatNom: commissariatNom,
        matriculePolice: matriculePolice,
        gradePolice: gradePolice,
        emailVerifie: emailVerifie,
        telephoneVerifie: telephoneVerifie,
        derniereConnexion: derniereConnexion,
        roles: roles ?? this.roles,
        permissions: permissions ?? this.permissions,
      );
}
