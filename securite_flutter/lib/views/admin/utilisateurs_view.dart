import 'package:flutter/material.dart';

import '../../components/avatar.dart';
import '../../components/carte_conteneur.dart';
import '../../components/champ_texte.dart';
import '../../components/liste.dart';
import '../../components/puce.dart';
import '../../models/utilisateur.dart';
import '../../services/api_client.dart';
import '../../services/utilisateur_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/formatage.dart';
import 'utilisateur_detail_view.dart';
import 'utilisateur_nouveau_view.dart';
import '../../components/badge.dart';

/// Administration des comptes : `GET/POST /users`, filtres, création, suspension.
class VueUtilisateurs extends StatefulWidget {
  const VueUtilisateurs({super.key});

  @override
  State<VueUtilisateurs> createState() => _VueUtilisateursState();
}

class _VueUtilisateursState extends State<VueUtilisateurs> {
  final UtilisateurService _service = UtilisateurService.instance;
  final _recherche = TextEditingController();

  List<Utilisateur> _utilisateurs = [];
  int _page = 1;
  int _pages = 0;
  int _total = 0;
  bool _chargement = true;
  bool _chargePlus = false;
  String? _erreur;
  String _role = '';
  String _statut = '';

  static const _roles = ['', 'citoyen', 'policier', 'enqueteur', 'admin', 'super_admin'];
  static const _statuts = ['', 'actif', 'suspendu', 'bloque', 'inactif'];

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

  Future<void> _charger({int page = 1}) async {
    setState(() {
      if (page == 1) _chargement = true;
      _erreur = null;
    });
    try {
      final resultat = await _service.lister(
        page: page,
        q: _recherche.text.trim(),
        role: _role.isEmpty ? null : _role,
        statut: _statut.isEmpty ? null : _statut,
      );
      setState(() {
        _utilisateurs = page == 1 ? resultat.elements : [..._utilisateurs, ...resultat.elements];
        _page = resultat.page;
        _pages = resultat.pages;
        _total = resultat.total;
      });
    } on ExceptionApi catch (e) {
      setState(() => _erreur = e.message);
    } catch (_) {
      setState(() => _erreur = 'Impossible de charger les comptes.');
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _ouvrirDetail(Utilisateur u) async {
    final modifie = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => VueDetailUtilisateur(utilisateur: u)),
    );
    if (modifie == true && mounted) _charger();
  }

  Future<void> _creerCompte() async {
    final cree = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const VueNouveauUtilisateur()),
    );
    if (cree == true && mounted) _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comptes'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => _charger(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creerCompte,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Créer'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: ChampRecherche(
              hint: 'Nom, e-mail, matricule…',
              controller: _recherche,
              onSoumis: (_) => _charger(),
            ),
          ),
          GroupePuces(
            enfants: [
              for (final r in _roles)
                PuceFiltre(
                  libelle: r.isEmpty ? 'Tous les rôles' : r,
                  selectionnee: _role == r,
                  onChanged: (_) {
                    setState(() => _role = r);
                    _charger();
                  },
                ),
              for (final s in _statuts.skip(1))
                PuceFiltre(
                  libelle: s,
                  selectionnee: _statut == s,
                  onChanged: (_) {
                    setState(() => _statut = _statut == s ? '' : s);
                    _charger();
                  },
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                BadgeSimple(texte: '$_total compte(s)', icone: Icons.people_outline),
                const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: _chargement && _utilisateurs.isEmpty
                ? const EtatChargement()
                : _erreur != null && _utilisateurs.isEmpty
                    ? EtatErreur(message: _erreur!, onReessayer: () => _charger())
                    : _utilisateurs.isEmpty
                        ? const EtatVide(
                            icone: Icons.people_outline,
                            titre: 'Aucun compte',
                            message: 'Aucun compte ne correspond à ces critères.',
                          )
                        : ListePaginee<Utilisateur>(
                            elements: _utilisateurs,
                            enCharge: false,
                            erreur: null,
                            aPlus: _page < _pages,
                            pageSuivanteEnCharge: _chargePlus,
                            onPageSuivante: () async {
                              if (_chargePlus || _page >= _pages) return;
                              setState(() => _chargePlus = true);
                              await _charger(page: _page + 1);
                              if (mounted) setState(() => _chargePlus = false);
                            },
                            onRafraichir: () => _charger(),
                            videTitre: 'Aucun compte',
                            construire: (context, index) {
                              final u = _utilisateurs[index];
                              return CarteConteneur(
                                onTap: () => _ouvrirDetail(u),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                enfant: Row(
                                  children: [
                                    AvatarUtilisateur.noms(
                                      nom: u.nom,
                                      prenom: u.prenom,
                                      url: u.urlAvatar,
                                      taille: 44,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            u.nomComplet,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            [
                                              if (u.roles.isNotEmpty) u.roles.join(', '),
                                              if (u.matriculePolice != null)
                                                u.matriculePolice!,
                                            ].join(' · '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppCouleurs.texteSecondaire,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        BadgeStatutRef(statut: u.statut),
                                        const SizedBox(height: 6),
                                        Text(
                                          Formatage.relative(u.derniereConnexion),
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            color: AppCouleurs.gris,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

/// Badge de statut de compte (les valeurs sont celles du backend).
class BadgeStatutRef extends StatelessWidget {
  const BadgeStatutRef({super.key, required this.statut});

  final String statut;

  @override
  Widget build(BuildContext context) {
    final (couleur, fond) = switch (statut) {
      'actif' => (AppCouleurs.vert, AppCouleurs.vertPastel),
      'suspendu' => (AppCouleurs.orange, AppCouleurs.orangePastel),
      'bloque' => (AppCouleurs.rouge, AppCouleurs.rougePastel),
      _ => (AppCouleurs.grisBleu, AppCouleurs.clair),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(999)),
      child: Text(
        statut,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: couleur),
      ),
    );
  }
}
