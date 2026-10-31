import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/carte_objet.dart';
import '../../components/champ_texte.dart';
import '../../components/liste.dart';
import '../../models/objet.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/objet_service.dart';
import '../../theme/couleurs.dart';
import 'objet_create_view.dart';
import 'objet_detail_view.dart';

/// Inventaire personnel : véhicules, ordinateurs, motos… pré-enregistrés.
///
/// Ce sont les objets au statut `en_possession` : au moindre vol, une action
/// suffit pour les transmettre à la police et aux amis.
class VueMesBiens extends StatefulWidget {
  const VueMesBiens({super.key});

  @override
  State<VueMesBiens> createState() => _VueMesBiensState();
}

class _VueMesBiensState extends State<VueMesBiens> {
  final ObjetService _service = ObjetService.instance;
  final _recherche = TextEditingController();

  List<Objet> _biens = [];
  bool _chargement = true;
  String? _erreur;

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

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final page = await _service.lister(statuts: const ['en_possession']);
      _biens = page.elements;
    } on ExceptionApi catch (e) {
      _erreur = e.message;
    } catch (_) {
      _erreur = 'Impossible de charger votre inventaire.';
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  List<Objet> get _filtres {
    final terme = _recherche.text.trim().toLowerCase();
    if (terme.isEmpty) return _biens;
    return _biens.where((o) {
      final champs = [
        o.marque,
        o.modele,
        o.immatriculation,
        o.numeroChassis,
        o.numeroSerie,
        o.couleur,
        o.description,
      ].where((e) => e != null).join(' ').toLowerCase();
      return champs.contains(terme);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final elements = _filtres;
    final peutAjouter = context.select<AuthProvider, bool>(
      (a) => a.aPermission('objets.creer'),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes biens'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _charger,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: peutAjouter
          ? FloatingActionButton.extended(
              onPressed: () async {
                final cree = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const VueCreationObjet(statutInitial: 'en_possession'),
                  ),
                );
                if (cree == true && mounted) _charger();
              },
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: BandeauInfoRef(
              message:
                  'Pré-enregistrez vos biens avec leurs photos : en cas de vol, '
                  'un seul geste les transmet à la police et à vos amis.',
            ),
          ),
          if (_biens.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ChampRecherche(
                hint: 'Marque, modèle, immatriculation…',
                controller: _recherche,
                onChanged: (_) => setState(() {}),
              ),
            ),
          Expanded(
            child: _chargement
                ? const EtatChargement()
                : _erreur != null
                    ? EtatErreur(message: _erreur!, onReessayer: _charger)
                    : elements.isEmpty
                        ? EtatVide(
                            icone: Icons.inventory_2_outlined,
                            titre: _recherche.text.isEmpty
                                ? 'Aucun bien enregistré'
                                : 'Aucun résultat',
                            message: _recherche.text.isEmpty
                                ? 'Ajoutez votre véhicule, ordinateur, moto… '
                                    'pour pouvoir les déclarer volés instantanément.'
                                : 'Aucun bien ne correspond à cette recherche.',
                            libelleAction: _recherche.text.isEmpty ? null : 'Effacer',
                            onAction: _recherche.text.isEmpty
                                ? null
                                : () => setState(() => _recherche.clear()),
                          )
                        : RefreshIndicator(
                            onRefresh: _charger,
                            color: AppCouleurs.bleu,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
                              itemCount: elements.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final bien = elements[index];
                                return CarteObjet(
                                  objet: bien,
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => VueDetailObjet(objet: bien),
                                      ),
                                    );
                                    if (mounted) _charger();
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            '${_biens.length} bien(s) dans votre inventaire · '
            'touchez une fiche pour la modifier, la partager, la déclarer volée '
            'ou la supprimer',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppCouleurs.texteSecondaire),
          ),
        ),
      ),
    );
  }
}

/// Bandeau d'information local (évite un import lourd dans ce fichier).
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 17, color: AppCouleurs.bleu),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12.5, height: 1.4))),
        ],
      ),
    );
  }
}
