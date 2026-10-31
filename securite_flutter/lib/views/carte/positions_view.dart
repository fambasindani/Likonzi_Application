import 'package:flutter/material.dart';

import '../../components/carte_conteneur.dart';
import '../../components/liste.dart';
import '../../models/geographie.dart';
import '../../services/api_client.dart';
import '../../services/geo_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/formatage.dart';
import '../../components/avatar.dart';

/// Historique des positions enregistrées — `GET /positions`.
///
/// Sans paramètre : toutes les positions (permission `geo.lire`) ;
/// avec `?id_user=` : celles d'un utilisateur.
class VuePositions extends StatefulWidget {
  const VuePositions({super.key, this.idUtilisateur, this.titre});

  final int? idUtilisateur;
  final String? titre;

  @override
  State<VuePositions> createState() => _VuePositionsState();
}

class _VuePositionsState extends State<VuePositions> {
  final GeoService _service = GeoService.instance;

  List<Localisation> _positions = [];
  int _page = 1;
  int _pages = 0;
  int _total = 0;
  bool _chargement = true;
  bool _chargePlus = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger({int page = 1}) async {
    setState(() {
      if (page == 1) _chargement = true;
      _erreur = null;
    });
    try {
      final resultat = await _service.positions(
        page: page,
        idUser: widget.idUtilisateur,
      );
      setState(() {
        _positions = page == 1
            ? resultat.elements
            : [..._positions, ...resultat.elements];
        _page = resultat.page;
        _pages = resultat.pages;
        _total = resultat.total;
      });
    } on ExceptionApi catch (e) {
      setState(() => _erreur = e.message);
    } catch (_) {
      setState(() => _erreur = 'Impossible de charger les positions.');
    } finally {
      if (mounted) setState(() => _chargement = false);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titre ?? 'Historique des positions'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => _charger(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _chargement && _positions.isEmpty
          ? const EtatChargement()
          : _erreur != null && _positions.isEmpty
              ? EtatErreur(message: _erreur!, onReessayer: () => _charger())
              : ListePaginee<Localisation>(
                  elements: _positions,
                  enCharge: false,
                  erreur: null,
                  aPlus: _page < _pages,
                  pageSuivanteEnCharge: _chargePlus,
                  onPageSuivante: _pageSuivante,
                  onRafraichir: () => _charger(),
                  videTitre: 'Aucune position',
                  videMessage: 'Aucun point d’origine enregistré.',
                  videIcone: Icons.gps_off_outlined,
                  construire: (context, index) {
                    final p = _positions[index];
                    return CarteConteneur(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      enfant: Row(
                        children: [
                          const IconeDomaine(
                            icone: Icons.location_on_outlined,
                            couleur: AppCouleurs.bleu,
                            taille: 40,
                            tailleIcone: 19,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (p.nom != null || p.prenom != null)
                                  Text(
                                    [p.nom, p.prenom].where((e) => e != null).join(' '),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                Text(
                                  '${p.latitude.toStringAsFixed(5)}, '
                                  '${p.longitude.toStringAsFixed(5)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                    color: AppCouleurs.texteSecondaire,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    Formatage.dateTime(p.dateLocalisation),
                                    if (p.source != null) 'source ${p.source}',
                                    if (p.precisionMetres != null)
                                      '±${p.precisionMetres!.toStringAsFixed(0)} m',
                                  ].join(' · '),
                                  style: const TextStyle(fontSize: 11.5, color: AppCouleurs.gris),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            '$_total position(s) enregistrée(s)',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppCouleurs.texteSecondaire),
          ),
        ),
      ),
    );
  }
}
