import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../components/avatar.dart';
import '../../components/badge.dart';
import '../../components/bouton.dart';
import '../../components/carte_conteneur.dart';
import '../../components/fiche_identite.dart';
import '../../components/liste.dart';
import '../../components/preuves_section.dart';
import '../../models/alerte.dart';
import '../../providers/alerte_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/alerte_service.dart';
import '../../services/api_client.dart';
import '../../services/config_service.dart';
import '../../services/utilisateur_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/formatage.dart';
import '../../utils/messages.dart';
import '../dossiers/dossier_detail_view.dart';

/// Fiche détaillée d'une alerte + actions métier.
class VueDetailAlerte extends StatefulWidget {
  const VueDetailAlerte({super.key, required this.alerte});

  final Alerte alerte;

  @override
  State<VueDetailAlerte> createState() => _VueDetailAlerteState();
}

class _VueDetailAlerteState extends State<VueDetailAlerte> {
  late Alerte _alerte;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _alerte = widget.alerte;
    WidgetsBinding.instance.addPostFrameCallback((_) => _rafraichir());
  }

  Future<void> _rafraichir() async {
    try {
      final maj = await AlerteService.instance.detail(_alerte.id);
      if (mounted) setState(() => _alerte = maj);
    } catch (_) {
      // On conserve les données déjà affichées.
    }
  }

  Future<void> _agir(Future<void> Function() action, {String succes = 'Mise à jour effectuée.'}) async {
    setState(() => _enCours = true);
    try {
      await action();
      await _rafraichir();
      if (mounted) montrerSucces(context, succes);
    } on ExceptionApi catch (e) {
      if (mounted) montrerErreur(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _prendreEnCharge() async {
    await _agir(
      () async {
        await context.read<AlerteProvider>().prendreEnCharge(_alerte.id);
      },
      succes: 'Alerte prise en charge.',
    );
  }

  Future<void> _assigner() async {
    final police = await showModalBottomSheet<List<int>>(
      context: context,
      backgroundColor: AppCouleurs.blanc,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const _ChoixPolicier(),
    );
    if (police == null || !mounted) return;
    await _agir(
      () async {
        await AlerteService.instance.assigner(_alerte.id, police.first);
      },
      succes: 'Alerte assignée.',
    );
  }

  Future<void> _changerStatut() async {
    final possibles = _alerte.statutsPossibles;
    if (possibles.isEmpty) {
      notifier(context, message: 'Cette alerte est déjà finalisée.');
      return;
    }
    final choix = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppCouleurs.blanc,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 6),
              child: Text(
                'Changer le statut',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            for (final s in possibles)
              ListTile(
                leading: BadgeStatut(statut: s),
                title: Text(AppCouleurs.libelle(s)),
                trailing: const Icon(Icons.chevron_right, color: AppCouleurs.gris),
                onTap: () => Navigator.of(context).pop(s),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choix == null || !mounted) return;

    String? observation;
    if (choix == 'fausse_alerte' || choix == 'resolue' || choix == 'classe') {
      final controleur = TextEditingController();
      final valider = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Motif — ${AppCouleurs.libelle(choix)}'),
          content: TextField(
            controller: controleur,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Observation (facultatif)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Valider'),
            ),
          ],
        ),
      );
      if (valider != true) return;
      observation = controleur.text.trim();
    }

    await _agir(
      () async {
        await context
            .read<AlerteProvider>()
            .changerStatut(_alerte.id, choix, observation: observation);
      },
      succes: 'Statut : ${AppCouleurs.libelle(choix)}.',
    );
  }

  Future<void> _ouvrirDossier() async {
    final confirme = await confirmer(
      context,
      titre: 'Ouvrir un dossier ?',
      message:
          'Un dossier d’enquête sera créé à partir de cette alerte. La victime sera notifiée.',
      libelleValider: 'Ouvrir le dossier',
      icone: Icons.folder_special_outlined,
    );
    if (!confirme || !mounted) return;

    await _agir(
      () async {
        final dossier = await AlerteService.instance.ouvrirCas(_alerte.id, {
          'type_cas': _typeDossierSelonAlerte(),
          'description': _alerte.contenu,
          'date_faits': (_alerte.dateAlerte ?? DateTime.now()).toIso8601String(),
          if (_alerte.adressePrecise != null) 'lieu': _alerte.adressePrecise,
        });
        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => VueDetailDossier(dossier: dossier)),
          );
        }
      },
      succes: 'Dossier ouvert.',
    );
  }

  String _typeDossierSelonAlerte() => switch (_alerte.typeCode ?? '') {
        'ENLEVEMENT' => 'enlevement',
        'VOL' => 'vol_objet',
        'AGRESSION' => 'agression',
        'KULUNA' => 'agression',
        _ => 'autre',
      };

  Future<void> _supprimer() async {
    final confirme = await confirmer(
      context,
      titre: 'Supprimer cette alerte ?',
      message: 'La suppression est douce : la trace reste dans le journal d’audit.',
      libelleValider: 'Supprimer',
      destructif: true,
      icone: Icons.delete_outline,
    );
    if (!confirme || !mounted) return;
    await _agir(
      () async => context.read<AlerteProvider>().supprimer(_alerte.id),
      succes: 'Alerte supprimée.',
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final estPolice = auth.estPolice;

    return Scaffold(
      appBar: AppBar(
        title: Text(_alerte.reference),
        actions: [
          if (auth.aPermission('alertes.traiter') && !_alerte.estTerminee)
            IconButton(
              tooltip: 'Changer le statut',
              onPressed: _enCours ? null : _changerStatut,
              icon: const Icon(Icons.swap_horiz),
            ),
          PopupMenuButton<String>(
            onSelected: (valeur) {
              switch (valeur) {
                case 'rafraichir':
                  _rafraichir();
                case 'supprimer':
                  _supprimer();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rafraichir', child: Text('Rafraîchir')),
              if (auth.aPermission('alertes.supprimer'))
                const PopupMenuItem(
                  value: 'supprimer',
                  child: Text('Supprimer', style: TextStyle(color: AppCouleurs.rouge)),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _rafraichir,
        color: AppCouleurs.bleu,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ------------------------------------------------------- en-tête
            CarteConteneur(
              bordure: AppCouleurs.urgence(_alerte.niveauUrgence).withValues(alpha: 0.5),
              enfant: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconeDomaine(
                        icone: Icons.notifications_active_outlined,
                        couleur: AppCouleurs.urgence(_alerte.niveauUrgence),
                        fond: AppCouleurs.urgenceFond(_alerte.niveauUrgence),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _alerte.typeLibelle ?? 'Alerte',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              Formatage.dateLongue(_alerte.dateAlerte),
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppCouleurs.texteSecondaire,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      BadgeUrgence(niveau: _alerte.niveauUrgence),
                      BadgeStatut(statut: _alerte.statut),
                      if (_alerte.typeCode != null) BadgeSimple(texte: _alerte.typeCode!),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            _Section(titre: 'Description', icone: Icons.subject,
                contenu: Text(_alerte.contenu, style: const TextStyle(height: 1.5))),

            if (_alerte.adressePrecise != null && _alerte.adressePrecise!.isNotEmpty)
              _Section(
                titre: 'Lieu',
                icone: Icons.place_outlined,
                contenu: Text(_alerte.adressePrecise!),
              ),

            if (_alerte.aCoordonnees) ...[
              const SizedBox(height: 14),
              _Section(
                titre: 'Position',
                icone: Icons.gps_fixed_outlined,
                contenu: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_alerte.latitude!.toStringAsFixed(5)}, '
                      '${_alerte.longitude!.toStringAsFixed(5)}',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(_alerte.latitude!, _alerte.longitude!),
                            initialZoom: 16,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: ConfigService.tuileUrl,
                              userAgentPackageName: 'cd.securite.securite',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(_alerte.latitude!, _alerte.longitude!),
                                  width: 46,
                                  height: 46,
                                  child: const Icon(
                                    Icons.location_pin,
                                    color: AppCouleurs.rouge,
                                    size: 46,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            _Section(
              titre: 'Acteurs',
              icone: Icons.groups_outlined,
              contenu: Column(
                children: [
                  if (_alerte.emetteurId != null &&
                      _alerte.emetteurId != auth.utilisateur?.id)
                    // Un ami consulte mon alerte : identité détaillée avec
                    // grande photo, nom complet, fonction et appel direct.
                    FicheIdentite(
                      libelle: "Auteur de l'alerte",
                      nom: _alerte.emetteurNom,
                      postnom: _alerte.emetteurPostnom,
                      prenom: _alerte.emetteurPrenom,
                      fonction: _alerte.emetteurFonction,
                      telephone: _alerte.emetteurTel,
                      avatar: _alerte.emetteurAvatar,
                      accent: AppCouleurs.rouge,
                    )
                  else
                    _LigneActeur(
                      nom: _alerte.emetteur.isNotEmpty ? _alerte.emetteur : '—',
                      fonction: 'Émetteur (vous)',
                      nomPrenom: (_alerte.emetteurNom, _alerte.emetteurPrenom),
                      url: _alerte.emetteurAvatar,
                      icone: Icons.person_outline,
                    ),
                  const Divider(height: 18),
                  _LigneActeur(
                    nom: _alerte.commissariatNom ?? 'Non affecté',
                    fonction: 'Commissariat',
                    icone: Icons.local_police_outlined,
                  ),
                  if (estPolice) ...[
                    const Divider(height: 18),
                    _LigneActeur(
                      nom: _alerte.policier.isNotEmpty ? _alerte.policier : 'Non assigné',
                      fonction: 'Policier en charge',
                      nomPrenom: (_alerte.policierNom, _alerte.policierPrenom),
                      icone: Icons.shield_outlined,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),
            _Section(
              titre: 'Chronologie',
              icone: Icons.schedule,
              contenu: Column(
                children: [
                  _LigneTemps(
                    libelle: 'Déclenchée',
                    valeur: Formatage.dateTime(_alerte.dateAlerte),
                    icone: Icons.notification_important_outlined,
                    premier: true,
                  ),
                  if (_alerte.datePriseEnCompte != null)
                    _LigneTemps(
                      libelle: 'Prise en charge',
                      valeur: Formatage.dateTime(_alerte.datePriseEnCompte),
                      icone: Icons.shield_outlined,
                    ),
                  if (_alerte.dateResolution != null)
                    _LigneTemps(
                      libelle: 'Clôturée',
                      valeur: Formatage.dateTime(_alerte.dateResolution),
                      icone: Icons.check_circle_outline,
                    ),
                ],
              ),
            ),

            if (_alerte.observation != null && _alerte.observation!.isNotEmpty) ...[
              const SizedBox(height: 14),
              _Section(
                titre: 'Observation',
                icone: Icons.notes_outlined,
                contenu: Text(_alerte.observation!),
              ),
            ],

            const SizedBox(height: 22),
            SectionPreuves(entiteType: 'alerte', entiteId: _alerte.id),
            const SizedBox(height: 26),

            // ------------------------------------------------------- actions
            if (estPolice && !_alerte.estTerminee) ...[
              if (!_alerte.assignee || _alerte.estNouvelle)
                BoutonPrincipal(
                  texte: 'Prendre en charge',
                  icone: Icons.pan_tool_alt_outlined,
                  enCharge: _enCours,
                  onPressed: _enCours ? null : _prendreEnCharge,
                ),
              if (estPolice) ...[
                const SizedBox(height: 10),
                BoutonSecondaire(
                  texte: 'Assigner à un policier',
                  icone: Icons.group_add_outlined,
                  onPressed: _enCours ? null : _assigner,
                ),
              ],
              if (auth.aPermission('cas.creer')) ...[
                const SizedBox(height: 10),
                BoutonSecondaire(
                  texte: 'Ouvrir un dossier d’enquête',
                  icone: Icons.folder_special_outlined,
                  onPressed: _enCours ? null : _ouvrirDossier,
                ),
              ],
            ],
            if (_alerte.estTerminee && estPolice && auth.aPermission('cas.creer')) ...[
              const BandeauInfo(
                type: 'succes',
                message: 'Alerte finalisée — le dossier reste consultable.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.titre, required this.icone, required this.contenu});

  final String titre;
  final IconData icone;
  final Widget contenu;

  @override
  Widget build(BuildContext context) {
    return CarteConteneur(
      enfant: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 17, color: AppCouleurs.bleu),
              const SizedBox(width: 8),
              Text(
                titre.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w800,
                  color: AppCouleurs.grisBleu,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          contenu,
        ],
      ),
    );
  }
}

class _LigneActeur extends StatelessWidget {
  const _LigneActeur({
    required this.nom,
    required this.fonction,
    required this.icone,
    this.nomPrenom,
    this.url,
  });

  final String nom;
  final String fonction;
  final IconData icone;
  final (String?, String?)? nomPrenom;

  /// Photo réelle de l'émetteur (sinon initiales).
  final String? url;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (nomPrenom != null && (nomPrenom!.$1?.isNotEmpty ?? false))
          AvatarUtilisateur.noms(
            nom: nomPrenom!.$1,
            prenom: nomPrenom!.$2,
            url: url,
            taille: 38,
          )
        else
          IconeDomaine(icone: icone, taille: 38, tailleIcone: 19),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nom,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
              Text(
                fonction,
                style: const TextStyle(fontSize: 12.5, color: AppCouleurs.texteSecondaire),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LigneTemps extends StatelessWidget {
  const _LigneTemps({
    required this.libelle,
    required this.valeur,
    required this.icone,
    this.premier = false,
  });

  final String libelle;
  final String valeur;
  final IconData icone;
  final bool premier;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: premier ? 0 : 12),
      child: Row(
        children: [
          Icon(icone, size: 16, color: AppCouleurs.bleu),
          const SizedBox(width: 8),
          Text(libelle, style: const TextStyle(fontSize: 13.5)),
          const Spacer(),
          Text(
            valeur,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppCouleurs.texteSecondaire,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sélecteur de policier (membres des forces).
class _ChoixPolicier extends StatefulWidget {
  const _ChoixPolicier();

  @override
  State<_ChoixPolicier> createState() => _ChoixPolicierState();
}

class _ChoixPolicierState extends State<_ChoixPolicier> {
  List<Map<String, dynamic>> _policiers = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final page = await UtilisateurService.instance.lister(role: 'policier', perPage: 50);
      _policiers = page.elements
          .map((u) => {
                'id': u.id,
                'nom': u.nomComplet,
                'commissariat': u.commissariatNom ?? '',
              })
          .toList();
    } on ExceptionApi catch (e) {
      _erreur = e.message;
    } catch (_) {
      _erreur = 'Impossible de charger les policiers.';
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                'Assigner à…',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            if (_chargement)
              const Expanded(child: EtatChargement())
            else if (_erreur != null)
              Expanded(child: EtatErreur(message: _erreur!, onReessayer: _charger))
            else if (_policiers.isEmpty)
              const Expanded(
                child: EtatVide(
                  icone: Icons.security_outlined,
                  titre: 'Aucun policier disponible',
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _policiers.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final p = _policiers[index];
                    return ListTile(
                      leading: AvatarUtilisateur(
                        initiales: Formatage.initiales(p['nom'] as String?, null),
                        taille: 40,
                      ),
                      title: Text(p['nom'] as String),
                      subtitle: (p['commissariat'] as String).isEmpty
                          ? null
                          : Text(p['commissariat'] as String),
                      trailing: const Icon(Icons.chevron_right, color: AppCouleurs.gris),
                      onTap: () => Navigator.of(context).pop([p['id'] as int]),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
