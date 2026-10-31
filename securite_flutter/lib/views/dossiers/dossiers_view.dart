import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/bouton.dart';
import '../../components/carte_dossier.dart';
import '../../components/champ_texte.dart';
import '../../components/liste.dart';
import '../../models/dossier.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/dossier_service.dart';
import 'dossier_create_view.dart';
import 'dossier_detail_view.dart';
import '../shell_view.dart';
import 'mes_interventions_view.dart';

/// Liste des dossiers d'enquête.
class VueDossiers extends StatefulWidget {
  const VueDossiers({super.key});

  @override
  State<VueDossiers> createState() => _VueDossiersState();
}

class _VueDossiersState extends State<VueDossiers> {
  final DossierService _service = DossierService.instance;
  final _recherche = TextEditingController();

  List<Dossier> _dossiers = [];
  int _page = 1;
  int _pages = 0;
  int _total = 0;
  // false : un `true` ici rendait le PREMIER appel (onglet « Tous »)
  // avant même denvoyer la requête -> chargement bloqué à linfini.
  bool _chargement = false;
  bool _chargePlus = false;
  String? _erreur;
  String _statut = '';

  static const _segments = ['Tous', 'Ouverts', 'En cours', 'Clos'];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  List<String>? get _statutsFiltres => switch (_statut) {
        'Ouverts' => ['ouvert', 'en_attente'],
        'En cours' => ['en_cours'],
        'Clos' => ['clos', 'classe'],
        _ => null,
      };

  int _sequence = 0;

  Future<void> _charger({int page = 1, bool forcer = false}) async {
    if (_chargement && !forcer) return;
    // Seule la dernière requête a le droit de fermer l'indicateur :
    // une réponse lente ou périmée laissait `_chargement` bloqué à true
    // (chargement infini sur l'onglet « Tous »).
    final monTour = ++_sequence;
    setState(() {
      if (page == 1) _chargement = true;
      _erreur = null;
    });
    try {
      final resultat = await _service.lister(
        page: page,
        statuts: _statutsFiltres,
        q: _recherche.text.trim(),
      ).timeout(const Duration(seconds: 20));
      setState(() {
        if (page == 1) _dossiers = resultat.elements;
        _dossiers.addAll(page == 1 ? [] : resultat.elements);
        _page = resultat.page;
        _pages = resultat.pages;
        _total = resultat.total;
      });
    } on TimeoutException {
      if (!mounted || monTour != _sequence) return;
      setState(() => _erreur = 'Le serveur met trop de temps à répondre. Réessayez dans un instant.');
    } on ExceptionApi catch (e) {
      if (!mounted || monTour != _sequence) return;
      setState(() => _erreur = e.message);
    } catch (_) {
      if (!mounted || monTour != _sequence) return;
      setState(() => _erreur = 'Impossible de charger les dossiers.');
    } finally {
      // Le drapeau est TOUJOURS libéré par la requête qui l'a posé.
      if (monTour == _sequence) {
        _chargement = false;
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _pageSuivante() async {
    if (_chargePlus || _page >= _pages) return;
    setState(() => _chargePlus = true);
    await _charger(page: _page + 1);
    if (mounted) setState(() => _chargePlus = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final peutCreer = auth.aPermission('cas.creer');

    return Scaffold(
      body: SafeArea(
      child: Column(
        children: [
          EnteteListe(
            titre: 'Dossiers',
            sousTitre: '$_total dossier(s) dans votre périmètre',
            actions: [
              IconButton(
                tooltip: 'Mes interventions',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VueMesInterventions()),
                ),
                icon: const Icon(Icons.shield_outlined),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: ChampRecherche(
              hint: 'Numéro de dossier, description, lieu…',
              controller: _recherche,
              onChanged: (_) => _charger(page: 1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Segment(
              libelles: _segments,
              selection: ['Tous', 'Ouverts', 'En cours', 'Clos'].indexOf(_statut.isEmpty ? 'Tous' : _statut),
              onChanged: (i) {
                setState(() => _statut = _segments[i]);
                _charger(page: 1, forcer: true);
              },
            ),
          ),
          Expanded(
            child: ListePaginee<Dossier>(
              elements: _dossiers,
              enCharge: _chargement,
              erreur: _erreur,
              aPlus: _page < _pages,
              pageSuivanteEnCharge: _chargePlus,
              onPageSuivante: _pageSuivante,
              onRafraichir: () => _charger(page: 1, forcer: true),
              videTitre: 'Aucun dossier',
              videMessage: auth.estPolice
                  ? 'Aucun dossier d’enquête ne correspond à ces critères.'
                  : 'Aucun dossier ne vous est rattaché.',
              videIcone: Icons.folder_open_outlined,
              construire: (context, index) => CarteDossier(
                dossier: _dossiers[index],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VueDetailDossier(dossier: _dossiers[index]),
                  ),
                ),
              ),
            ),
          ),
          if (peutCreer)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: BoutonPrincipal(
                texte: 'Ouvrir un dossier',
                icone: Icons.create_new_folder_outlined,
                onPressed: () async {
                  final cree = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const VueCreationDossier()),
                  );
                  if (cree == true && mounted) _charger(page: 1, forcer: true);
                },
              ),
            ),
        ],
      ),
    ),
    );
  }
}
