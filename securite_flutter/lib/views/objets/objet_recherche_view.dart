import 'package:flutter/material.dart';

import '../../components/bouton.dart';
import '../../components/carte_objet.dart';
import '../../components/champ_texte.dart';
import '../../components/liste.dart';
import '../../models/objet.dart';
import '../../services/api_client.dart';
import '../../services/objet_service.dart';
import '../../utils/messages.dart';
import 'objet_detail_view.dart';

/// Recherche ciblée : immatriculation, châssis, n° de série, marque…
class VueRechercheObjet extends StatefulWidget {
  const VueRechercheObjet({super.key});

  @override
  State<VueRechercheObjet> createState() => _VueRechercheObjetState();
}

class _VueRechercheObjetState extends State<VueRechercheObjet> {
  final _terme = TextEditingController();
  final _focus = FocusNode();

  List<Objet> _resultats = [];
  bool _rechercheLancee = false;
  bool _enCours = false;
  String? _erreur;

  static const _suggestions = [
    'Immatriculation',
    'N° de châssis',
    'N° de série',
    'Marque',
    'Couleur',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _terme.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _lancer([String? suggestion]) async {
    final terme = (suggestion ?? _terme.text).trim();
    if (terme.isEmpty) {
      notifier(context, message: 'Saisissez un élément à rechercher.', succes: false);
      return;
    }
    if (suggestion != null) _terme.text = terme;
    setState(() {
      _enCours = true;
      _erreur = null;
      _rechercheLancee = true;
    });
    try {
      _resultats = await ObjetService.instance.rechercher(terme);
    } on ExceptionApi catch (e) {
      _resultats = [];
      _erreur = e.message;
    } catch (_) {
      _resultats = [];
      _erreur = 'La recherche a échoué.';
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recherche d’objet')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: ChampRecherche(
              hint: 'Ex. CD 4521 AB, JT8H1234567, Toyota…',
              controller: _terme,
              focusNode: _focus,
              onSoumis: (_) => _lancer(),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                for (final s in _suggestions)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(s),
                      onPressed: () => _lancer(s),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: BoutonPrincipal(
                    texte: 'Rechercher',
                    icone: Icons.search,
                    enCharge: _enCours,
                    onPressed: _enCours ? null : () => _lancer(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: !_rechercheLancee
                ? const EtatVide(
                    icone: Icons.document_scanner_outlined,
                    titre: 'Recherchez un objet volé',
                    message:
                        'Saisissez une immatriculation, un n° de châssis ou un n° de série. '
                        'Les objets en recherche publique sont accessibles à tous.',
                  )
                : _enCours
                    ? const EtatChargement()
                    : _erreur != null
                        ? EtatErreur(message: _erreur!, onReessayer: () => _lancer())
                        : ListePaginee<Objet>(
                            elements: _resultats,
                            enCharge: false,
                            onRafraichir: () => _lancer(),
                            videTitre: 'Aucun résultat',
                            videMessage:
                                'Aucun objet ne correspond à « ${_terme.text.trim()} ».',
                            videIcone: Icons.search_off_outlined,
                            construire: (context, index) => CarteObjet(
                              objet: _resultats[index],
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      VueDetailObjet(objet: _resultats[index]),
                                ),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
