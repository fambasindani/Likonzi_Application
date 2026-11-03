import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/badge.dart';
import '../models/alerte.dart';
import '../providers/alerte_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/carte_provider.dart';
import '../providers/social_provider.dart';
import '../services/socket_service.dart';
import '../theme/couleurs.dart';
import '../utils/formatage.dart';
import 'accueil/accueil_view.dart';
import 'alertes/alertes_view.dart';
import 'boite/boite_view.dart';
import 'carte/carte_view.dart';
import 'dossiers/dossiers_view.dart';

/// Coquille principale : barre de navigation en 5 onglets + temps réel.
class ShellView extends StatefulWidget {
  const ShellView({super.key});

  static const chemin = '/shell';

  @override
  State<ShellView> createState() => _ShellViewState();
}

class _ShellViewState extends State<ShellView> {
  int _index = 0;
  final List<StreamSubscription<dynamic>> _abonnements = [];

  // Onglets construits À LA DEMANDÉE : avec IndexedStack, les 5 écrans étaient
  // montés dès le démarrage (5 appels API + géolocalisation + tuiles de carte
  // simultanés), ce qui rendait l'affichage — notamment des dossiers — très lent.
  final List<Widget?> _ongletsCache = List<Widget?>.filled(5, null);

  Widget _fabriquerOnglet(int i) => switch (i) {
        1 => const VueAlertes(),
        2 => const VueCarte(),
        3 => const VueDossiers(),
        4 => const VueBoite(),
        _ => const VueAccueil(),
      };


  static const List<_Onglet> _onglets = [
    _Onglet('Accueil', Icons.dashboard_outlined, Icons.dashboard),
    _Onglet('Alertes', Icons.notifications_none, Icons.notifications_active),
    _Onglet('Carte', Icons.map_outlined, Icons.map),
    _Onglet('Dossiers', Icons.folder_outlined, Icons.folder),
    _Onglet('Messages', Icons.mail_outline, Icons.mail),
  ];

  @override
  void initState() {
    super.initState();
    _ongletsCache[0] = const VueAccueil();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialiser());

    _abonnements.add(
      SocketService.instance.evenements.listen(_surEvenementTempsReel),
    );
  }

  Future<void> _initialiser() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final alertes = context.read<AlerteProvider>();
    final social = context.read<SocialProvider>();

    SocketService.instance.connecter();

    // Localisation continue : la position reste à jour pendant les déplacements.
    unawaited(context.read<CarteProvider>().demarrerSuivi());

    await Future.wait([
      alertes.charger(forcer: true),
      social.rafraichirCompteurs(),
    ]);

    // Les rôles arrivent parfois après la restauration locale : on adapte.
    if (auth.utilisateur != null) {
      await alertes.chargerTypes();
    }
  }

  void _surEvenementTempsReel(EvenementTempsReel evenement) {
    if (!mounted) return;
    switch (evenement.type) {
      case 'alerte_nouvelle':
        final alerte = Alerte.brut(evenement.donnees);
        context.read<AlerteProvider>().insererTempsReel(alerte);
        _annoncer(
          'Nouvelle alerte ${alerte.reference}',
          '${AppCouleurs.libelle(alerte.niveauUrgence)} — ${alerte.contenu}',
          Icons.notifications_active_outlined,
          AppCouleurs.urgence(alerte.niveauUrgence),
          allerA: 1,
        );
      case 'alerte_assignee':
        final alerte = Alerte.brut(evenement.donnees);
        context.read<AlerteProvider>().mettreAJour(alerte);
        _annoncer(
          'Alerte assignée',
          '${alerte.reference} — ${alerte.policier}',
          Icons.shield_outlined,
          AppCouleurs.bleu,
        );
      case 'alerte_mise_a_jour':
        final alerte = Alerte.brut(evenement.donnees);
        context.read<AlerteProvider>().mettreAJour(alerte);
        _annoncer(
          'Alerte mise à jour',
          '${alerte.reference} → ${AppCouleurs.libelle(alerte.statut)}',
          Icons.sync_outlined,
          AppCouleurs.orange,
        );
      case 'dossier_ouvert':
        _annoncer(
          'Dossier ouvert',
          evenement.donnees['numero_dossier']?.toString() ?? '',
          Icons.folder_special_outlined,
          AppCouleurs.bleu,
          allerA: 3,
        );
      case 'intervention_enregistree':
        _annoncer(
          'Intervention enregistrée',
          evenement.donnees['numero_dossier']?.toString() ?? '',
          Icons.shield_outlined,
          AppCouleurs.vert,
          allerA: 3,
        );
      default:
        break;
    }
  }

  void _annoncer(
    String titre,
    String message,
    IconData icone,
    Color couleur, {
    int? allerA,
  }) {
    if (message.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          backgroundColor: AppCouleurs.textePrimaire,
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              Icon(icone, color: couleur, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppCouleurs.blanc,
                      ),
                    ),
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppCouleurs.blanc.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          action: allerA == null
              ? null
              : SnackBarAction(
                  label: 'Voir',
                  textColor: couleur,
                  onPressed: () => setState(() => _index = allerA),
                ),
        ),
      );
  }

  @override
  void dispose() {
    for (final a in _abonnements) {
      a.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>();
    final alertes = context.read<AlerteProvider>();

    final pages = [
      for (var i = 0; i < 5; i++) _ongletsCache[i] ?? const SizedBox.shrink(),
    ];

    Widget icon(int i, bool selectionne) {
      final base = _onglets[i];
      Widget icone = Icon(
        selectionne ? base.iconeActif : base.icone,
        size: 24,
      );
      if (i == 1 && alertes.nombreNouvelles > 0) {
        icone = BadgeCompteur(valeur: alertes.nombreNouvelles, enfant: icone);
      }
      if (i == 4 && social.totalNonLus > 0) {
        icone = BadgeCompteur(valeur: social.totalNonLus, enfant: icone);
      }
      return icone;
    }

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() {
            _index = i;
            _ongletsCache[i] ??= _fabriquerOnglet(i);
          });
        },
        backgroundColor: AppCouleurs.blanc,
        indicatorColor: AppCouleurs.bleuPastel,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (var i = 0; i < _onglets.length; i++)
            NavigationDestination(
              icon: icon(i, false),
              selectedIcon: icon(i, true),
              label: _onglets[i].libelle,
            ),
        ],
      ),
    );
  }
}

class _Onglet {
  const _Onglet(this.libelle, this.icone, this.iconeActif);

  final String libelle;
  final IconData icone;
  final IconData iconeActif;
}

/// En-tête réutilisable des listes (titre + recherche + actions).
class EnteteListe extends StatelessWidget {
  const EnteteListe({
    super.key,
    required this.titre,
    this.sousTitre,
    this.actions = const [],
  });

  final String titre;
  final String? sousTitre;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: AppCouleurs.textePrimaire,
                  ),
                ),
                if (sousTitre != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    sousTitre!,
                    style: const TextStyle(fontSize: 13, color: AppCouleurs.texteSecondaire),
                  ),
                ],
              ],
            ),
          ),
          ...actions,
          if (auth.utilisateur != null) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: auth.utilisateur!.nomComplet,
              child: CircleAvatar(
                radius: 19,
                backgroundColor: AppCouleurs.bleuPastel,
                child: Text(
                  auth.utilisateur!.initiales,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppCouleurs.bleu,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Formatage partagé pour les écrans.
String heureCourte(DateTime? d) => d == null ? '—' : Formatage.heure(d);
