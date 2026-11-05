import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/avatar.dart';
import '../../components/badge.dart';
import '../../components/bouton.dart';
import '../../components/carte_conteneur.dart';
import '../../components/carte_notification.dart';
import '../../components/champ_texte.dart';
import '../../components/liste.dart';
import '../../models/social.dart';
import '../../models/utilisateur.dart';
import '../../providers/auth_provider.dart';
import '../../providers/social_provider.dart';
import '../../services/api_client.dart';
import '../../services/social_service.dart';
import '../../services/utilisateur_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/formatage.dart';
import '../../utils/messages.dart';
import 'conversation_view.dart';
import '../shell_view.dart';

/// Boîte de réception : notifications, amis, demandes d'ami.
class VueBoite extends StatefulWidget {
  const VueBoite({super.key});

  @override
  State<VueBoite> createState() => _VueBoiteState();
}

class _VueBoiteState extends State<VueBoite> {
  int _segment = 0;
  static const _segments = ['Notifications', 'Amis', 'Demandes'];

  // Amis
  List<Utilisateur> _amis = [];
  bool _chargementAmis = true;
  String? _erreurAmis;

  // Suggestions (personnes à connaître)
  List<Suggestion> _suggestions = [];
  bool _chargementSugg = true;

  // Demandes
  List<Demande> _demandes = [];
  bool _chargementDemandes = true;
  String? _erreurDemandes;

  // Annuaire
  final _recherche = TextEditingController();
  List<Utilisateur> _trouves = [];
  bool _rechercheActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    await Future.wait([_chargerAmis(), _chargerDemandes(), _chargerSuggestions()]);
    if (mounted) await context.read<SocialProvider>().chargerRecentes();
  }

  Future<void> _chargerSuggestions() async {
    setState(() => _chargementSugg = true);
    try {
      _suggestions = await SocialService.instance.suggestions();
    } catch (_) {
      _suggestions = [];
    } finally {
      if (mounted) setState(() => _chargementSugg = false);
    }
  }

  Future<void> _chargerAmis() async {
    setState(() {
      _chargementAmis = true;
      _erreurAmis = null;
    });
    try {
      _amis = await SocialService.instance.amis();
    } on ExceptionApi catch (e) {
      _erreurAmis = e.message;
    } catch (_) {
      _erreurAmis = 'Impossible de charger vos amis.';
    } finally {
      if (mounted) setState(() => _chargementAmis = false);
    }
  }

  Future<void> _chargerDemandes() async {
    setState(() {
      _chargementDemandes = true;
      _erreurDemandes = null;
    });
    try {
      _demandes = await SocialService.instance.demandes();
    } on ExceptionApi catch (e) {
      _erreurDemandes = e.message;
    } catch (_) {
      _erreurDemandes = 'Impossible de charger les demandes.';
    } finally {
      if (mounted) setState(() => _chargementDemandes = false);
    }
  }

  Future<void> _rechercherPersonnes() async {
    final terme = _recherche.text.trim();
    if (terme.isEmpty) return;
    setState(() {
      _rechercheActive = true;
      _trouves = [];
    });
    try {
      final page = await UtilisateurService.instance.annuaire(terme);
      setState(() => _trouves = page.elements);
    } on ExceptionApi catch (e) {
      if (mounted) montrerErreur(context, e);
    } catch (_) {
      if (mounted) montrerErreur(context, 'La recherche a échoué.');
    }
  }

  Future<void> _envoyerDemande(Utilisateur personne) async {
    try {
      await SocialService.instance.demander(personne.id);
      if (mounted) {
        montrerSucces(context, 'Demande envoyée à ${personne.nomComplet}.');
        _recherche.clear();
        setState(() => _rechercheActive = false);
        _chargerDemandes();
      }
    } on ExceptionApi catch (e) {
      if (mounted) montrerErreur(context, e);
    }
  }

  Future<void> _annulerDemande(Demande demande) async {
    try {
      await SocialService.instance.annuler(demande.id);
      if (!mounted) return;
      montrerSucces(context, 'Demande annulée.');
      await _chargerDemandes();
    } on ExceptionApi catch (e) {
      if (!mounted) return;
      montrerErreur(context, e);
    }
  }

  Future<void> _repondre(Demande demande, String decision) async {
    try {
      await SocialService.instance.repondre(demande.id, decision);
      if (mounted) {
        montrerSucces(
          context,
          decision == 'acceptee' ? 'Demande acceptée.' : 'Demande refusée.',
        );
        _chargerDemandes();
        if (decision == 'acceptee') _chargerAmis();
        context.read<SocialProvider>().rafraichirCompteurs();
      }
    } on ExceptionApi catch (e) {
      if (mounted) montrerErreur(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>();
    final auth = context.watch<AuthProvider>();
    final moiId = auth.utilisateur?.id ?? -1;

    return Scaffold(
      body: SafeArea(
      child: Column(
        children: [
          EnteteListe(
            titre: 'Boîte',
            sousTitre: '${social.totalNonLus} élément(s) non lu(s)',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Segment(
              libelles: _segments,
              selection: _segment,
              onChanged: (i) => setState(() => _segment = i),
            ),
          ),
          Expanded(
            child: switch (_segment) {
              0 => _notifications(social),
              1 => _amisTab(),
              _ => _demandesTab(moiId),
            },
          ),
        ],
      ),
    ),
    );
  }

  // ------------------------------------------------------------ notifications

  Widget _notifications(SocialProvider social) {
    if (social.chargement && social.recentes.isEmpty) {
      return const EtatChargement();
    }
    if (social.erreur != null && social.recentes.isEmpty) {
      return EtatErreur(
        message: social.erreur!,
        onReessayer: () => context.read<SocialProvider>().chargerRecentes(),
      );
    }
    return Column(
      children: [
        if (social.notificationsNonLues > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                BadgeSimple(
                  texte: '${social.notificationsNonLues} non lue(s)',
                  icone: Icons.mark_chat_unread_outlined,
                  couleur: AppCouleurs.rouge,
                  fond: AppCouleurs.rougePastel,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.read<SocialProvider>().toutMarquerLu(),
                  child: const Text('Tout marquer lu'),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<SocialProvider>().chargerRecentes(),
            color: AppCouleurs.bleu,
            child: social.recentes.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 60),
                      EtatVide(
                        icone: Icons.notifications_none,
                        titre: 'Aucune notification',
                        message: 'Vous serez prévenu des prises en charge et des réponses.',
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: social.recentes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final n = social.recentes[index];
                      return CarteNotification(
                        notification: n,
                        onTap: () => context.read<SocialProvider>().marquerLue(n),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------- amis

  Widget _amisTab() {
    if (_chargementAmis) return const EtatChargement();
    if (_erreurAmis != null) {
      return EtatErreur(message: _erreurAmis!, onReessayer: _chargerAmis);
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: ChampRecherche(
            hint: 'Trouver une personne (nom, e-mail, téléphone)…',
            controller: _recherche,
            onSoumis: (_) => _rechercherPersonnes(),
            action: IconButton(
              icon: const Icon(Icons.person_search_outlined, size: 20),
              onPressed: _rechercherPersonnes,
            ),
          ),
        ),
        if (_rechercheActive)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: BandeauInfo(
              message: _trouves.isEmpty
                  ? 'Aucune personne trouvée pour « ${_recherche.text.trim()} ».'
                  : '${_trouves.length} personne(s) trouvée(s).',
              action: () => setState(() {
                _rechercheActive = false;
                _trouves = [];
                _recherche.clear();
              }),
              libelleAction: 'Fermer',
            ),
          ),
        Expanded(
          child: _rechercheActive
              ? _listePersonnes(_trouves, avecBoutonDemande: true)
              : _listeAmisEtSuggestions(),
        ),
      ],
    );
  }

  /// Onglet Amis : « Mes amis » puis « Suggestions pour vous » (style Facebook).
  Widget _listeAmisEtSuggestions() {
    if (_chargementAmis && _amis.isEmpty && _suggestions.isEmpty) {
      return const EtatChargement();
    }
    if (_erreurAmis != null && _amis.isEmpty && _suggestions.isEmpty) {
      return EtatErreur(message: _erreurAmis!, onReessayer: _chargerAmis);
    }
    return RefreshIndicator(
      onRefresh: _charger,
      color: AppCouleurs.bleu,
      child: Container(
        color: AppCouleurs.blanc,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (_amis.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: EtatVide(
                  icone: Icons.people_outline,
                  titre: 'Aucun ami pour le moment',
                  message:
                      'Consultez les suggestions ci-dessous, ou trouvez un contact '
                      'via la recherche.',
                ),
              )
            else ...[
              _enteteSection('Mes amis · ${_amis.length}'),
              for (final p in _amis) ...[
                _lignePersonne(p),
                _separateur(),
              ],
            ],
            _enteteSection('Suggestions pour vous'),
            if (_chargementSugg)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: EtatChargement(compact: true),
              )
            else if (_suggestions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'Aucune suggestion pour le moment — revenez plus tard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppCouleurs.texteSecondaire),
                ),
              )
            else
              for (final s in _suggestions) ...[
                _lignePersonne(
                  s.personne,
                  sousTitre: s.amisCommuns > 0
                      ? '${s.amisCommuns} ami(s) en commun'
                      : s.personne.fonction,
                  trailing: _boutonAjouter(s.personne),
                ),
                _separateur(),
              ],
          ],
        ),
      ),
    );
  }

  /// Résultats de recherche (la barre de recherche reste au-dessus).
  Widget _listePersonnes(List<Utilisateur> personnes, {bool avecBoutonDemande = false}) {
    return RefreshIndicator(
      onRefresh: _chargerAmis,
      color: AppCouleurs.bleu,
      child: Container(
        color: AppCouleurs.blanc,
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: personnes.length,
          separatorBuilder: (_, __) => _separateur(),
          itemBuilder: (context, index) {
            final p = personnes[index];
            final dejaAmi = _amis.any((a) => a.id == p.id);
            return _lignePersonne(
              p,
              trailing: avecBoutonDemande && !dejaAmi ? _boutonAjouter(p) : null,
            );
          },
        ),
      ),
    );
  }

  /// Ligne type Facebook : grande photo ronde, nom en gras, sous-titre.
  Widget _lignePersonne(Utilisateur p, {String? sousTitre, Widget? trailing}) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VueConversation(destinataire: p)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            AvatarUtilisateur.noms(
              nom: p.nom,
              prenom: p.prenom,
              url: p.urlAvatar,
              taille: 56,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nomComplet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppCouleurs.textePrimaire,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sousTitre ?? p.fonction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppCouleurs.texteSecondaire,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chat_bubble_outline,
                  color: AppCouleurs.grisBleu,
                  size: 22,
                ),
          ],
        ),
      ),
    );
  }

  Widget _boutonAjouter(Utilisateur p) => TextButton(
        onPressed: () => _envoyerDemande(p),
        style: TextButton.styleFrom(
          backgroundColor: AppCouleurs.bleuPastel,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 34),
        ),
        child: const Text(
          'Ajouter',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppCouleurs.bleu,
          ),
        ),
      );

  Widget _enteteSection(String titre) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(
          titre,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: AppCouleurs.texteSecondaire,
          ),
        ),
      );

  Widget _separateur() => const Padding(
        padding: EdgeInsets.only(left: 86),
        child: Divider(height: 1, thickness: 1, color: AppCouleurs.bordure),
      );

  // --------------------------------------------------------------- demandes

  Widget _demandesTab(int moiId) {
    if (_chargementDemandes) return const EtatChargement();
    if (_erreurDemandes != null) {
      return EtatErreur(message: _erreurDemandes!, onReessayer: _chargerDemandes);
    }
    final recues =
        _demandes.where((d) => d.estRecue(moiId) && d.statut == 'en_attente').toList();
    final autres = _demandes.where((d) => !d.estRecue(moiId) || d.statut != 'en_attente').toList();

    if (_demandes.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: 50),
          EtatVide(
            icone: Icons.person_add_alt_outlined,
            titre: 'Aucune demande',
            message: 'Les demandes d’ami reçues et envoyées apparaîtront ici.',
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _chargerDemandes,
      color: AppCouleurs.bleu,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: [
          if (recues.isNotEmpty) ...[
            const TitreSection(
              titre: 'Demandes reçues',
              icone: Icons.call_received,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            for (final d in recues) ...[
              CarteConteneur(
                enfant: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            d.nomDe(moiId),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        BadgeSimple(texte: 'En attente', couleur: AppCouleurs.orange),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Formatage.relative(d.dateDemande),
                      style: const TextStyle(fontSize: 12, color: AppCouleurs.texteSecondaire),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _repondre(d, 'refusee'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppCouleurs.rouge,
                              side: const BorderSide(color: AppCouleurs.rouge),
                              minimumSize: const Size(0, 42),
                            ),
                            child: const Text('Refuser'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _repondre(d, 'acceptee'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 42),
                            ),
                            child: const Text('Accepter'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
          if (autres.isNotEmpty) ...[
            const TitreSection(
              titre: 'Historique',
              icone: Icons.history,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            for (final d in autres) ...[
              CarteConteneur(
                enfant: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.nomDe(moiId),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (!d.estRecue(moiId) && d.statut == 'en_attente')
                            const Text(
                              'Demande envoyée — en attente de réponse',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppCouleurs.texteSecondaire,
                              ),
                            ),
                        ],
                      ),
                    ),
                    BadgeStatut(statut: d.statut),
                    if (!d.estRecue(moiId) && d.statut == 'en_attente')
                      IconButton(
                        tooltip: 'Annuler la demande',
                        icon: const Icon(Icons.close, size: 18, color: AppCouleurs.rouge),
                        onPressed: () => _annulerDemande(d),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}
