import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/avatar.dart';
import '../../components/badge.dart';
import '../../components/carte_conteneur.dart';
import '../../providers/auth_provider.dart';
import '../../services/utilisateur_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/formatage.dart';
import '../auth/login_view.dart';
import 'changer_mdp_view.dart';
import 'modifier_profil_view.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/messages.dart';
import '../admin/audit_view.dart';
import '../admin/referentiels_view.dart';
import '../admin/utilisateurs_view.dart';
import 'apropos_view.dart';
import 'verification_view.dart';
import '../../services/api_client.dart';
import '../../utils/images.dart';

/// Profil : identité, rôles, réglages et déconnexion.
class VueProfil extends StatelessWidget {
  const VueProfil({super.key});

  Future<void> _afficherRoles(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final u = auth.utilisateur;
    if (u == null) return;
    Map<String, dynamic> donnees = {'roles': u.roles, 'permissions': u.permissions};
    try {
      // GET /users/moi/roles : version fraîche depuis le serveur.
      donnees = await UtilisateurService.instance.rolesUtilisateur();
    } catch (_) {
      // On retombe sur les rôles déjà connus localement.
    }
    if (!context.mounted) return;
    final roles = (donnees['roles'] as List? ?? const []).map((e) => '$e').toList();
    final permissions =
        (donnees['permissions'] as List? ?? const []).map((e) => '$e').toList();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rôles et permissions'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in roles)
                      BadgeSimple(texte: _libelleRole(r), icone: Icons.verified_user_outlined),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Autorisations (${permissions.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 8),
                for (final p in permissions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 15, color: AppCouleurs.vert),
                        const SizedBox(width: 8),
                        Expanded(child: Text(p, style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  static String _libelleRole(String brut) => switch (brut) {
        'citoyen' => 'Citoyen',
        'policier' => 'Policier',
        'enqueteur' => 'Enquêteur',
        'admin' => 'Administrateur',
        'super_admin' => 'Super administrateur',
        _ => brut,
      };

  Future<void> _changerAvatar(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final u = auth.utilisateur;
    if (u == null) return;
    final choix = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppCouleurs.blanc,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text('Photo de profil',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppCouleurs.bleu),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.of(context).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppCouleurs.bleu),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.of(context).pop('galerie'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choix == null || !context.mounted) return;

    final picker = ImagePicker();
    final fichier = await picker.pickImage(
      source: choix == 'camera' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 70, // cible < 200 Ko
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (fichier == null || !context.mounted) return;
    final probleme = Images.controler(fichier.path);
    if (probleme != null) {
      montrerErreur(context, probleme);
      return;
    }

    try {
      await UtilisateurService.instance.avatar(u.id, fichier.path, nomFichier: fichier.name);
      await auth.rafraichirProfil();
      if (context.mounted) montrerSucces(context, 'Photo de profil mise à jour.');
    } on ExceptionApi catch (e) {
      if (context.mounted) montrerErreur(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final u = auth.utilisateur;

    if (u == null) {
      return const Scaffold(
        body: Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        actions: [
          IconButton(
            tooltip: 'Rôles et permissions',
            onPressed: () => _afficherRoles(context),
            icon: const Icon(Icons.verified_user_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          CarteConteneur(
            enfant: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AvatarUtilisateur.noms(
                      nom: u.nom,
                      prenom: u.prenom,
                      url: u.urlAvatar,
                      taille: 84,
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Material(
                        color: AppCouleurs.bleu,
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _changerAvatar(context),
                          child: const SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(Icons.camera_alt_outlined,
                                size: 17, color: AppCouleurs.blanc),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  u.nomComplet,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  u.fonction,
                  style: const TextStyle(fontSize: 13.5, color: AppCouleurs.texteSecondaire),
                ),
                if (u.commissariatNom != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    u.commissariatNom!,
                    style: const TextStyle(fontSize: 13, color: AppCouleurs.grisBleu),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final r in u.roles) BadgeSimple(texte: _libelleRole(r)),
                    BadgeStatut(statut: u.statut),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _PastilleVerification(
                      libelle: 'E-mail',
                      verifie: u.emailVerifie,
                      icone: Icons.mail_outline,
                      onTap: u.emailVerifie
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const VueVerification(typeInitial: 'email'),
                                ),
                              ),
                    ),
                    const SizedBox(width: 10),
                    _PastilleVerification(
                      libelle: 'Téléphone',
                      verifie: u.telephoneVerifie,
                      icone: Icons.phone_iphone,
                      onTap: u.telephoneVerifie
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const VueVerification(typeInitial: 'telephone'),
                                ),
                              ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          CarteConteneur(
            padding: EdgeInsets.zero,
            enfant: Column(
              children: [
                _Entree(
                  icone: Icons.badge_outlined,
                  libelle: 'Informations personnelles',
                  sousTitre: 'Nom, coordonnées, genre, date de naissance',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VueModifierProfil()),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _Entree(
                  icone: Icons.lock_reset_outlined,
                  libelle: 'Changer le mot de passe',
                  sousTitre: 'Au moins 8 caractères, une lettre et un chiffre',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VueChangerMotDePasse()),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _Entree(
                  icone: Icons.shield_outlined,
                  libelle: 'Rôles et permissions',
                  sousTitre: '${u.roles.length} rôle(s) · ${u.permissions.length} autorisation(s)',
                  onTap: () => _afficherRoles(context),
                ),
                if (auth.aPermission('users.lire')) ...[
                  const Divider(height: 1, indent: 56),
                  _Entree(
                    icone: Icons.manage_accounts_outlined,
                    libelle: 'Administration des comptes',
                    sousTitre: 'Créer, suspendre, attribuer les rôles',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const VueUtilisateurs()),
                    ),
                  ),
                ],
                if (auth.aPermission('rbac.gerer')) ...[
                  const Divider(height: 1, indent: 56),
                  _Entree(
                    icone: Icons.folder_copy_outlined,
                    libelle: 'Référentiels',
                    sousTitre: 'Types d’alertes, types d’objets, rôles, permissions',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const VueReferentiels()),
                    ),
                  ),
                ],
                if (auth.aPermission('audit.lire')) ...[
                  const Divider(height: 1, indent: 56),
                  _Entree(
                    icone: Icons.receipt_long_outlined,
                    libelle: 'Journal d’audit',
                    sousTitre: 'Qui a fait quoi, quand, depuis où',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const VueAudit()),
                    ),
                  ),
                ],
                const Divider(height: 1, indent: 56),
                _Entree(
                  icone: Icons.info_outline,
                  libelle: 'À propos et configuration',
                  sousTitre: 'Santé du service, routes, paramètres',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VueAPropos()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          CarteConteneur(
            enfant: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ACTIVITÉ',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w800,
                    color: AppCouleurs.grisBleu,
                  ),
                ),
                const SizedBox(height: 12),
                _InfoStatut(
                  libelle: 'Dernière connexion',
                  valeur: Formatage.relative(u.derniereConnexion),
                  icone: Icons.schedule,
                ),
                const SizedBox(height: 10),
                _InfoStatut(
                  libelle: 'Matricule',
                  valeur: u.matriculePolice ?? 'Non attribué',
                  icone: Icons.pin_outlined,
                ),
                const SizedBox(height: 10),
                _InfoStatut(
                  libelle: 'Grade',
                  valeur: u.gradePolice ?? '—',
                  icone: Icons.military_tech_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              final confirme = await confirmer(
                context,
                titre: 'Se déconnecter ?',
                message: 'Vous devrez vous reconnecter pour accéder à vos alertes.',
                libelleValider: 'Déconnecter',
                destructif: true,
                icone: Icons.logout,
              );
              if (!confirme || !context.mounted) return;
              await context.read<AuthProvider>().deconnecter();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const VueConnexion()),
                  (_) => false,
                );
              }
            },
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Se déconnecter'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppCouleurs.rouge,
              side: const BorderSide(color: AppCouleurs.rouge),
            ),
          ),
        ],
      ),
    );
  }

}

class _PastilleVerification extends StatelessWidget {
  const _PastilleVerification({
    required this.libelle,
    required this.verifie,
    required this.icone,
    this.onTap,
  });

  final String libelle;
  final bool verifie;
  final IconData icone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final contenu = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: verifie ? AppCouleurs.vertPastel : AppCouleurs.jaunePastel,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 15, color: verifie ? AppCouleurs.vert : AppCouleurs.orange),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$libelle ${verifie ? 'vérifié' : 'à vérifier'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: verifie ? AppCouleurs.vert : AppCouleurs.orange,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return contenu;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(999), child: contenu);
  }
}

class _Entree extends StatelessWidget {
  const _Entree({
    required this.icone,
    required this.libelle,
    required this.sousTitre,
    required this.onTap,
  });

  final IconData icone;
  final String libelle;
  final String sousTitre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconeDomaine(icone: icone, taille: 40, tailleIcone: 19),
      title: Text(libelle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
      subtitle: Text(sousTitre, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right, color: AppCouleurs.gris),
      onTap: onTap,
    );
  }
}

class _InfoStatut extends StatelessWidget {
  const _InfoStatut({required this.libelle, required this.valeur, required this.icone});

  final String libelle;
  final String valeur;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, size: 16, color: AppCouleurs.bleu),
        const SizedBox(width: 8),
        Text(libelle, style: const TextStyle(fontSize: 13.5)),
        const Spacer(),
        Text(
          valeur,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppCouleurs.texteSecondaire,
          ),
        ),
      ],
    );
  }
}
