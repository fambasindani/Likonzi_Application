import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/bouton.dart';
import '../../components/carte_objet.dart';
import '../../components/champ_texte.dart';
import '../../components/liste.dart';
import '../../models/objet.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/objet_service.dart';
import 'objet_create_view.dart';
import 'objet_detail_view.dart';
import 'objet_recherche_view.dart';
import '../shell_view.dart';
import 'mes_biens_view.dart';
import 'partages_view.dart';

/// Fichier des objets volés.
class VueObjets extends StatefulWidget {
  const VueObjets({super.key});

  @override
  State<VueObjets> createState() => _VueObjetsState();
}

class _VueObjetsState extends State<VueObjets> {
  final ObjetService _service = ObjetService.instance;
  final _recherche = TextEditingController();

  List<Objet> _objets = [];
  int _page = 1;
  int _pages = 0;
  int _total = 0;
  // false : un `true` ici rendait le PREMIER appel (onglet « Tous »)
  // avant même denvoyer la requête -> chargement bloqué à linfini.
  bool _chargement = false;
  bool _chargePlus = false;
  String? _erreur;
  String _statut = '';

  static const _segments = ['Tous', 'Recherchés', 'Retrouvés'];

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

  List<String>? get _filtre => switch (_statut) {
        'Recherchés' => ['declare_vol', 'recherche'],
        'Retrouvés' => ['retrouve', 'restitue'],
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
        statuts: _filtre,
        q: _recherche.text.trim(),
      ).timeout(const Duration(seconds: 20));
      setState(() {
        if (page == 1) {
          _objets = resultat.elements;
        } else {
          _objets.addAll(resultat.elements);
        }
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
      setState(() => _erreur = 'Impossible de charger les objets.');
    } finally {
      // Le drapeau est TOUJOURS libéré par la requête qui l'a posé.
      if (monTour == _sequence) {
        _chargement = false;
        if (mounted) setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final peutCreer = auth.aPermission('objets.creer');

    return Scaffold(
      body: SafeArea(
      child: Column(
        children: [
          EnteteListe(
            titre: 'Objets volés',
            sousTitre: '$_total objet(s) déclarés',
            actions: [
              IconButton(
                tooltip: 'Mes biens (pré-enregistrés)',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VueMesBiens()),
                ),
                icon: const Icon(Icons.inventory_2_outlined),
              ),
              IconButton(
                tooltip: 'Partages reçus',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VuePartages()),
                ),
                icon: const Icon(Icons.share_outlined),
              ),
              IconButton(
                tooltip: 'Recherche ciblée (immatriculation, châssis…)',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VueRechercheObjet()),
                ),
                icon: const Icon(Icons.document_scanner_outlined),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: ChampRecherche(
              hint: 'Marque, modèle, immatriculation…',
              controller: _recherche,
              onChanged: (_) => _charger(page: 1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Segment(
              libelles: _segments,
              selection: _segments.indexOf(_statut.isEmpty ? 'Tous' : _statut),
              onChanged: (i) {
                setState(() => _statut = _segments[i]);
                _charger(page: 1, forcer: true);
              },
            ),
          ),
          Expanded(
            child: ListePaginee<Objet>(
              elements: _objets,
              enCharge: _chargement,
              erreur: _erreur,
              aPlus: _page < _pages,
              pageSuivanteEnCharge: _chargePlus,
              onPageSuivante: () async {
                if (_chargePlus || _page >= _pages) return;
                setState(() => _chargePlus = true);
                await _charger(page: _page + 1);
                if (mounted) setState(() => _chargePlus = false);
              },
              onRafraichir: () => _charger(page: 1, forcer: true),
              videTitre: 'Aucun objet',
              videMessage: 'Déclarez un objet volé ou lancez une recherche ciblée.',
              videIcone: Icons.search_off_outlined,
              construire: (context, index) => CarteObjet(
                objet: _objets[index],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VueDetailObjet(objet: _objets[index]),
                  ),
                ),
              ),
            ),
          ),
          if (peutCreer)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: BoutonPrincipal(
                texte: 'Déclarer un objet volé',
                icone: Icons.add_shopping_cart_outlined,
                onPressed: () async {
                  final cree = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const VueCreationObjet()),
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
