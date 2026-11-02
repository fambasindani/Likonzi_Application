import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/avatar.dart';
import '../../components/bouton.dart';
import '../../components/carte_alerte.dart';
import '../../components/carte_conteneur.dart';
import '../../components/liste.dart';
import '../../providers/alerte_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sos_provider.dart';
import '../../providers/social_provider.dart';
import '../../theme/couleurs.dart';
import '../../utils/formatage.dart';
import '../alertes/alerte_create_view.dart';
import '../alertes/alerte_detail_view.dart';
import '../alertes/alertes_view.dart';
import '../auth/login_view.dart';
import '../commissariats/commissariats_view.dart';
import '../objets/objet_create_view.dart';
import '../profil/profil_view.dart';
import '../../components/entete.dart';
import '../admin/administration_view.dart';
import '../objets/mes_biens_view.dart';
import '../objets/partages_view.dart';
import '../dossiers/dossiers_view.dart';
import '../sos/sos_view.dart';

/// Tableau de bord : alertes, compteurs, raccourcis.
class VueAccueil extends StatefulWidget {
  const VueAccueil({super.key});

  @override
  State<VueAccueil> createState() => _VueAccueilState();
}

class _VueAccueilState extends State<VueAccueil> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<AlerteProvider>().charger(forcer: true);
      if (mounted) await context.read<SocialProvider>().rafraichirCompteurs();
      if (mounted) await context.read<SosProvider>().rafraichir();
    });
  }

  String _salutation() {
    final heure = DateTime.now().hour;
    if (heure < 12) return 'Bonjour';
    if (heure < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final alertes = context.watch<AlerteProvider>();
    final social = context.watch<SocialProvider>();
    final sos = context.watch<SosProvider>();
    final utilisateur = auth.utilisateur;

    return Scaffold(
      body: SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await alertes.rafraichir();
          await social.rafraichirCompteurs();
        },
        color: AppCouleurs.bleu,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            // ----------------------------------------------------- bannière
            BanniereAccueil(
              titre: '${_salutation()},\n${utilisateur?.prenomAffiche ?? 'ami'}',
              message: utilisateur == null
                  ? configSloganTexte
                  : '${utilisateur.fonction}'
                      '${utilisateur.commissariatNom != null ? ' — ${utilisateur.commissariatNom}' : ''}',
              actions: [
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VueProfil()),
                  ),
                  icon: const Icon(Icons.person_outline, color: AppCouleurs.blanc),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
              ],
              elevee: _BarreRechercheRapide(
                onRecherche: (v) {
                  context.read<AlerteProvider>().definirRecherche(v);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VueAlertes()),
                  );
                },
              ),
            ),

            // --------------------------------------------------- statistiques
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Row(
                children: [
                  _Statistique(
                    valeur: '${alertes.total}',
                    libelle: 'Alertes',
                    icone: Icons.notifications_active_outlined,
                    couleur: AppCouleurs.bleu,
                  ),
                  const SizedBox(width: 10),
                  _Statistique(
                    valeur: '${alertes.nombreNouvelles}',
                    libelle: 'Nouvelles',
                    icone: Icons.fiber_new_outlined,
                    couleur: AppCouleurs.rouge,
                  ),
                  const SizedBox(width: 10),
                  _Statistique(
                    valeur: '${social.notificationsNonLues}',
                    libelle: 'Non lues',
                    icone: Icons.mark_chat_unread_outlined,
                    couleur: AppCouleurs.orange,
                  ),
                ],
              ),
            ),

            // ------------------------------------------------------------- SOS
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _BanniereSos(
                actif: sos.actif,
                minuteur: sos.enCours ? sos.minuteur : null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VueSos()),
                ),
              ),
            ),

            // ----------------------------------------------------- raccourcis
            TitreSection(
              titre: 'Que souhaitez-vous faire ?',
              icone: Icons.bolt_outlined,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  CarteLigne(
                    titre: 'Déclarer une alerte',
                    sousTitre: 'Signalez une situation urgente aux forces de l’ordre',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const VueCreationAlerte()),
                    ),
                    leading: const IconeDomaine(
                      icone: Icons.add_alert_outlined,
                      couleur: AppCouleurs.rouge,
                      fond: AppCouleurs.rougePastel,
                    ),
                    trailling: const Icon(Icons.chevron_right, color: AppCouleurs.gris),
                  ),
                  const SizedBox(height: 10),
                  CarteLigne(
                    titre: 'Déclarer un objet volé',
                    sousTitre: 'Véhicule, téléphone, ordinateur…',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const VueCreationObjet()),
                    ),
                    leading: const IconeDomaine(
                      icone: Icons.search_outlined,
                      couleur: AppCouleurs.orange,
                      fond: AppCouleurs.orangePastel,
                    ),
                    trailling: const Icon(Icons.chevron_right, color: AppCouleurs.gris),
                  ),
                  const SizedBox(height: 10),
                  CarteLigne(
                    titre: 'Mes biens',
                    sousTitre: 'Véhicules, ordinateurs, motos… pré-enregistrés',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const VueMesBiens()),
                    ),
                    leading: const IconeDomaine(
                      icone: Icons.inventory_2_outlined,
                      couleur: AppCouleurs.vert,
                      fond: AppCouleurs.vertPastel,
                    ),
                    trailling: const Icon(Icons.chevron_right, color: AppCouleurs.gris),
                  ),
                  const SizedBox(height: 10),
                  CarteLigne(
                    titre: 'Partages reçus',
                    sousTitre: 'Fiches et photos transmises par vos contacts',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const VuePartages()),
                    ),
                    leading: const IconeDomaine(
                      icone: Icons.share_outlined,
                      couleur: AppCouleurs.orange,
                      fond: AppCouleurs.orangePastel,
                    ),
                    trailling: const Icon(Icons.chevron_right, color: AppCouleurs.gris),
                  ),
                  if (auth.aPermission('users.lire') ||
                      auth.aPermission('rbac.gerer') ||
                      auth.aPermission('audit.lire')) ...[
                    const SizedBox(height: 10),
                    CarteLigne(
                      titre: 'Administration',
                      sousTitre: 'Comptes, rôles, permissions, journal d’audit',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const VueAdministration()),
                      ),
                      leading: const IconeDomaine(
                        icone: Icons.admin_panel_settings_outlined,
                        couleur: AppCouleurs.bleuNuit,
                        fond: AppCouleurs.bleuPastel,
                      ),
                      trailling:
                          const Icon(Icons.chevron_right, color: AppCouleurs.gris),
                    ),
                  ],
                  const SizedBox(height: 10),
                  CarteLigne(
                    titre: 'Commissariats autour de moi',
                    sousTitre: 'Trouver le poste le plus proche',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const VueCommissariats()),
                    ),
                    leading: const IconeDomaine(
                      icone: Icons.local_police_outlined,
                      couleur: AppCouleurs.bleu,
                    ),
                    trailling: const Icon(Icons.chevron_right, color: AppCouleurs.gris),
                  ),
                ],
              ),
            ),

            // ------------------------------------------------ dernières alertes
            TitreSection(
              titre: 'Dernières alertes',
              icone: Icons.history_outlined,
              action: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VueAlertes()),
              ),
            ),
            if (alertes.chargement && alertes.alertes.isEmpty)
              const EtatChargement(compact: true)
            else if (alertes.erreur != null && alertes.alertes.isEmpty)
              EtatErreur(
                message: alertes.erreur!,
                onReessayer: alertes.rafraichir,
              )
            else if (alertes.alertes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: EtatVide(
                  icone: Icons.notifications_none,
                  titre: 'Aucune alerte pour le moment',
                  message: 'Les alertes de votre périmètre apparaîtront ici.',
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (final a in alertes.alertes.take(4)) ...[
                      CarteAlerte(
                        alerte: a,
                        afficherEmetteur: auth.estPolice,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VueDetailAlerte(alerte: a),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),

            // ------------------------------------------------------ notifications
            if (social.recentes.isNotEmpty) ...[
              TitreSection(
                titre: 'Notifications',
                icone: Icons.notifications_outlined,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (final n in social.recentes.take(3))
                      CarteConteneur(
                        onTap: () {},
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        enfant: Row(
                          children: [
                            Icon(
                              n.lu ? Icons.notifications_none : Icons.notifications_active,
                              color: n.lu ? AppCouleurs.gris : AppCouleurs.bleu,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.titre,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    n.message,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppCouleurs.texteSecondaire,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              Formatage.relative(n.dateEnvoi),
                              style: const TextStyle(fontSize: 11, color: AppCouleurs.gris),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ],

            // -------------------------------------------------------- dossiers
            if (auth.estPolice) ...[
              TitreSection(
                titre: 'Mes dossiers',
                icone: Icons.folder_special_outlined,
                action: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VueDossiers()),
                ),
                libelleAction: 'Ouvrir',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: BoutonSecondaire(
                  texte: 'Accéder aux dossiers d’enquête',
                  icone: Icons.folder_open_outlined,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VueDossiers()),
                  ),
                ),
              ),
            ],

            // ---------------------------------------------------- pied de page
            const SizedBox(height: 24),
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  final confirmation = await confirmerDeconnexion(context);
                  if (confirmation == true && context.mounted) {
                    await context.read<AuthProvider>().deconnecter();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const VueConnexion()),
                        (_) => false,
                      );
                    }
                  }
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Se déconnecter'),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

const configSloganTexte = 'Protéger, alerter, intervenir.';

/// Bandeau rouge d'appel au SOS : toujours visible sur l'accueil.
class _BanniereSos extends StatelessWidget {
  const _BanniereSos({required this.actif, required this.onTap, this.minuteur});

  final bool actif;
  final String? minuteur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: actif
                  ? const [Color(0xFFB30000), Color(0xFFFF0000)]
                  : const [Color(0xFFFF0000), Color(0xFFD40000)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppCouleurs.rouge.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  actif ? Icons.timer_outlined : Icons.sos_outlined,
                  color: AppCouleurs.blanc,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      actif ? 'SOS EN COURS' : 'SOS URGENCE',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: AppCouleurs.blanc,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      actif
                          ? (minuteur != null
                              ? 'Envoi automatique dans $minuteur — appuyez pour gérer'
                              : 'Message envoyé — appuyez pour lever le SOS')
                          : 'Alertez vos amis et la police en un geste',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

class _Statistique extends StatelessWidget {
  const _Statistique({
    required this.valeur,
    required this.libelle,
    required this.icone,
    required this.couleur,
  });

  final String valeur;
  final String libelle;
  final IconData icone;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CarteConteneur(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        enfant: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 18, color: couleur),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              valeur,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: couleur,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              libelle,
              style: const TextStyle(fontSize: 12, color: AppCouleurs.texteSecondaire),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarreRechercheRapide extends StatelessWidget {
  const _BarreRechercheRapide({required this.onRecherche});

  final ValueChanged<String> onRecherche;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(Icons.search, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Rechercher une alerte, un dossier…',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13.5,
              ),
            ),
          ),
          IconButton(
            onPressed: () => onRecherche(''),
            icon: const Icon(Icons.tune, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

Future<bool?> confirmerDeconnexion(BuildContext context) async {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Se déconnecter ?'),
      content: const Text('Vous devrez vous reconnecter pour accéder à vos alertes.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Déconnecter'),
        ),
      ],
    ),
  );
}
