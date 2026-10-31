import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/carte_conteneur.dart';
import '../../components/liste.dart';
import '../../providers/auth_provider.dart';
import '../../theme/couleurs.dart';
import 'audit_view.dart';
import 'referentiels_view.dart';
import 'utilisateurs_view.dart';
import '../../components/avatar.dart';

/// Cœur d'administration : regroupe les écrans de gestion.
///
/// Chaque entrée n'apparaît que si l'utilisateur détient la permission
/// correspondante (`users.lire`, `rbac.gerer`, `audit.lire`).
class VueAdministration extends StatelessWidget {
  const VueAdministration({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final entrees = <_EntreeAdmin>[
      if (auth.aPermission('users.lire'))
        _EntreeAdmin(
          icone: Icons.manage_accounts_outlined,
          couleur: AppCouleurs.bleu,
          titre: 'Comptes utilisateurs',
          sousTitre: 'Créer, suspendre, attribuer les rôles, filtrer par rôle',
          chemin: '/utilisateurs',
          vue: const VueUtilisateurs(),
          badge: 'users.lire',
        ),
      if (auth.aPermission('rbac.gerer'))
        _EntreeAdmin(
          icone: Icons.folder_copy_outlined,
          couleur: AppCouleurs.orange,
          titre: 'Référentiels & rôles',
          sousTitre: 'Types d’alertes, types d’objets, rôles et permissions',
          chemin: '/referentiels',
          vue: const VueReferentiels(),
          badge: 'rbac.gerer',
        ),
      if (auth.aPermission('audit.lire'))
        _EntreeAdmin(
          icone: Icons.receipt_long_outlined,
          couleur: AppCouleurs.vert,
          titre: 'Journal d’audit',
          sousTitre: 'Qui a fait quoi, quand, depuis quelle adresse',
          chemin: '/audit',
          vue: const VueAudit(),
          badge: 'audit.lire',
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Administration')),
      body: entrees.isEmpty
          ? const EtatVide(
              icone: Icons.lock_outlined,
              titre: 'Aucune autorisation',
              message:
                  'Votre compte ne dispose d’aucune permission d’administration.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                BandeauInfoRef(
                  message: 'Vous êtes connecté en tant que '
                      '${(auth.utilisateur?.roles ?? const []).join(', ')}.',
                ),
                const SizedBox(height: 14),
                for (final e in entrees) ...[
                  CarteConteneur(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => e.vue),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    enfant: Row(
                      children: [
                        IconeDomaine(
                          icone: e.icone,
                          couleur: e.couleur,
                          taille: 48,
                          tailleIcone: 24,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.titre,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                e.sousTitre,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: AppCouleurs.texteSecondaire,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppCouleurs.gris),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _EntreeAdmin {
  _EntreeAdmin({
    required this.icone,
    required this.couleur,
    required this.titre,
    required this.sousTitre,
    required this.chemin,
    required this.vue,
    required this.badge,
  });

  final IconData icone;
  final Color couleur;
  final String titre;
  final String sousTitre;
  final String chemin;
  final Widget vue;
  final String badge;
}

/// Bandeau d'information local.
class BandeauInfoRef extends StatelessWidget {
  const BandeauInfoRef({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppCouleurs.bleuPastel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings_outlined,
              size: 17, color: AppCouleurs.bleu),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }
}
