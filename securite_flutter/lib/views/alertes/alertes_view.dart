import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/badge.dart';
import '../../components/bouton.dart';
import '../../components/carte_alerte.dart';
import '../../components/champ_texte.dart';
import '../../components/liste.dart';
import '../../providers/alerte_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/couleurs.dart';
import 'alerte_create_view.dart';
import 'alerte_detail_view.dart';
import '../shell_view.dart';

/// File des alertes avec recherche et filtres.
class VueAlertes extends StatefulWidget {
  const VueAlertes({super.key});

  @override
  State<VueAlertes> createState() => _VueAlertesState();
}

class _VueAlertesState extends State<VueAlertes> {
  final _recherche = TextEditingController();
  int _segment = 0;

  static const _segments = ['Toutes', 'Nouvelles', 'En cours', 'Terminées'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AlerteProvider>().charger(forcer: true);
    });
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  void _appliquerSegment(int index) {
    setState(() => _segment = index);
    final provider = context.read<AlerteProvider>();
    switch (index) {
      case 1:
        provider.definirStatuts(const ['nouvelle']);
      case 2:
        provider.definirStatuts(const ['prise_en_compte', 'en_cours']);
      case 3:
        provider.definirStatuts(const ['resolue', 'classe', 'fausse_alerte']);
      default:
        provider.definirStatuts(const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlerteProvider>();
    final auth = context.watch<AuthProvider>();
    final peutCreer = auth.aPermission('alertes.creer');
    final estPolice = auth.estPolice;

    return Scaffold(
      body: SafeArea(
      child: Column(
        children: [
          EnteteListe(
            titre: 'Alertes',
            sousTitre: estPolice
                ? 'File de traitement de votre périmètre'
                : 'Vos signalements et leur suivi',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: ChampRecherche(
              hint: 'Référence, contenu, adresse…',
              controller: _recherche,
              onChanged: (v) => context.read<AlerteProvider>().definirRecherche(v),
              action: _recherche.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _recherche.clear();
                        context.read<AlerteProvider>().definirRecherche('');
                        setState(() {});
                      },
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Segment(
              libelles: _segments,
              selection: _segment,
              onChanged: _appliquerSegment,
            ),
          ),
          Expanded(
            child: ListePaginee(
              elements: provider.alertes,
              enCharge: provider.chargement,
              erreur: provider.erreur,
              aPlus: provider.aPlus,
              pageSuivanteEnCharge: provider.chargePlus,
              onPageSuivante: () async => provider.chargerPageSuivante(),
              onRafraichir: provider.rafraichir,
              videTitre: 'Aucune alerte',
              videMessage: _segment == 0
                  ? (estPolice
                      ? 'Aucune alerte dans votre commissariat pour le moment.'
                      : 'Vous n’avez encore signalé aucune alerte.')
                  : 'Aucune alerte dans cette catégorie.',
              videIcone: Icons.notifications_none,
              construire: (context, index) {
                final alerte = provider.alertes[index];
                return CarteAlerte(
                  alerte: alerte,
                  afficherEmetteur: estPolice,
                  libelleAction: estPolice && !alerte.estTerminee ? 'Traiter' : null,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => VueDetailAlerte(alerte: alerte)),
                  ),
                );
              },
            ),
          ),
          if (peutCreer)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: BoutonPrincipal(
                texte: 'Déclarer une alerte',
                icone: Icons.add_alert_outlined,
                onPressed: () async {
                  final cree = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const VueCreationAlerte()),
                  );
                  if (cree == true && context.mounted) {
                    context.read<AlerteProvider>().rafraichir();
                  }
                },
              ),
            ),
        ],
      ),
    ),
    );
  }
}

/// Badge résumé affiché dans l'en-tête.
class ResumeAlertes extends StatelessWidget {
  const ResumeAlertes({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlerteProvider>();
    return Wrap(
      spacing: 8,
      children: [
        BadgeSimple(texte: '${provider.total} au total', icone: Icons.list_alt),
        if (provider.nombreNouvelles > 0)
          BadgeSimple(
            texte: '${provider.nombreNouvelles} nouvelles',
            icone: Icons.fiber_new,
            couleur: AppCouleurs.rouge,
            fond: AppCouleurs.rougePastel,
          ),
      ],
    );
  }
}
