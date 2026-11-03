import 'package:flutter/material.dart';

import '../../components/badge.dart';
import '../../components/bouton.dart';
import '../../components/carte_conteneur.dart';
import '../../components/fiche_identite.dart';
import '../../components/liste.dart';
import '../../components/preuves_section.dart';
import 'objet_create_view.dart';
import '../../models/objet.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/objet_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/formatage.dart';
import '../../utils/messages.dart';
import 'package:provider/provider.dart';
import '../../components/avatar.dart';
import '../../services/social_service.dart';
import '../../models/utilisateur.dart';

/// Fiche d'un objet volé + gestion du statut.
class VueDetailObjet extends StatefulWidget {
  const VueDetailObjet({super.key, required this.objet});

  final Objet objet;

  @override
  State<VueDetailObjet> createState() => _VueDetailObjetState();
}

class _VueDetailObjetState extends State<VueDetailObjet> {
  late Objet _objet;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _objet = widget.objet;
    _rafraichir();
  }

  Future<void> _rafraichir() async {
    try {
      final maj = await ObjetService.instance.detail(_objet.id);
      if (mounted) setState(() => _objet = maj);
    } catch (_) {
      // Conserve l'affichage.
    }
  }

  Future<void> _action(Future<void> Function() a, {String succes = 'Mise à jour effectuée.'}) async {
    setState(() => _enCours = true);
    try {
      await a();
      await _rafraichir();
      if (mounted) montrerSucces(context, succes);
    } on ExceptionApi catch (e) {
      if (mounted) montrerErreur(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _changerStatut() async {
    final auth = context.read<AuthProvider>();
    final estPolice = auth.estPolice;
    final possibles =
        estPolice ? _objet.statutsPolice : _objet.statutsPossiblesProprietaire;
    if (possibles.isEmpty) {
      notifier(context, message: 'Aucune transition possible depuis ce statut.');
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
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text('Changer le statut',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            if (!estPolice)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: BandeauInfo(
                  type: 'info',
                  message: 'En tant que propriétaire, vous pouvez signaler qu’un objet est '
                      'recherché ou retrouvé.',
                ),
              ),
            for (final s in possibles)
              ListTile(
                leading: BadgeStatut(statut: s),
                title: Text(AppCouleurs.libelle(s)),
                onTap: () => Navigator.of(context).pop(s),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choix == null || !mounted) return;

    String? motif;
    if (choix == 'retrouve' || choix == 'restitue' || choix == 'classe') {
      final controleur = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Motif — ${AppCouleurs.libelle(choix)}'),
          content: TextField(
            controller: controleur,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Précisions (facultatif)'),
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
      if (ok != true) return;
      motif = controleur.text.trim();
    }

    await _action(
      () => ObjetService.instance.changerStatut(_objet.id, choix, motif: motif),
      succes: 'Statut : ${AppCouleurs.libelle(choix)}.',
    );
  }

  Future<void> _supprimer() async {
    final confirme = await confirmer(
      context,
      titre: 'Supprimer cet objet ?',
      message: 'La déclaration restera tracée dans le journal d’audit.',
      libelleValider: 'Supprimer',
      destructif: true,
      icone: Icons.delete_outline,
    );
    if (!confirme || !mounted) return;
    await _action(
      () => ObjetService.instance.supprimer(_objet.id),
      succes: 'Objet supprimé.',
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _partager() async {
    List<Utilisateur> amis;
    try {
      amis = await SocialService.instance.amis();
    } on ExceptionApi catch (e) {
      if (mounted) montrerErreur(context, e);
      return;
    }
    if (!mounted) return;
    if (amis.isEmpty) {
      notifier(
        context,
        message: 'Aucun contact : ajoutez d’abord des amis dans la Boîte.',
        succes: false,
      );
      return;
    }

    final selection = Set<int>.from(amis.map((a) => a.id));
    final message = TextEditingController(
      text: '${_objet.designation} — volé le '
          '${_objet.dateVol != null ? Formatage.date(_objet.dateVol) : "récemment"}.',
    );
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Partager cet objet'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Destinataires (votre photo et les images du bien leur seront transmises) :',
                    style: const TextStyle(fontSize: 13, color: AppCouleurs.texteSecondaire),
                  ),
                  const SizedBox(height: 8),
                  for (final a in amis)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(a.nomComplet, maxLines: 1, overflow: TextOverflow.ellipsis),
                      value: selection.contains(a.id),
                      onChanged: (ok) => setStateDialog(() {
                        ok == true ? selection.add(a.id) : selection.remove(a.id);
                      }),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: message,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Message (facultatif)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Partager'),
            ),
          ],
        ),
      ),
    );
    if (confirme != true || selection.isEmpty || !mounted) return;
    if (confirme == true && selection.isEmpty) return;

    try {
      final resultat = await ObjetService.instance.partager(
        _objet.id,
        destinataires: selection.toList(),
        message: message.text.trim(),
      );
      if (!mounted) return;
      montrerSucces(
        context,
        'Objet transmis à ${(resultat['total'] ?? 0)} destinataire(s).',
      );
    } on ExceptionApi catch (e) {
      if (mounted) montrerErreur(context, e);
    }
  }

  /// Ouvre le formulaire en mode modification puis rafraîchit la fiche.
  Future<void> _modifier() async {
    final modifie = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => VueCreationObjet(objet: _objet)),
    );
    if (modifie == true && mounted) await _rafraichir();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final estProprietaire = auth.utilisateur?.id == _objet.idProprietaire;
    final estPolice = auth.estPolice;
    final peutSupprimer = auth.aPermission('objets.supprimer');
    final peutMaj = auth.aPermission('objets.maj');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Objet déclaré'),
        actions: [
          if (auth.aPermission('objets.maj'))
            IconButton(
              tooltip: 'Partager (amis / forces)',
              onPressed: _enCours ? null : _partager,
              icon: const Icon(Icons.share_outlined),
            ),
          if (estProprietaire || estPolice)
            IconButton(
              tooltip: 'Modifier la fiche',
              onPressed: _enCours ? null : _modifier,
              icon: const Icon(Icons.edit_outlined),
            ),
          if ((estProprietaire || estPolice) && peutMaj)
            IconButton(
              tooltip: 'Changer le statut',
              onPressed: _enCours ? null : _changerStatut,
              icon: const Icon(Icons.swap_horiz),
            ),
          IconButton(tooltip: 'Rafraîchir', onPressed: _rafraichir, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _rafraichir,
        color: AppCouleurs.bleu,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            CarteConteneur(
              enfant: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const IconeDomaine(
                        icone: Icons.inventory_2_outlined,
                        couleur: AppCouleurs.bleu,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _objet.designation,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (_objet.typeLibelle != null)
                              Text(
                                _objet.typeLibelle!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppCouleurs.texteSecondaire,
                                ),
                              ),
                          ],
                        ),
                      ),
                      BadgeStatut(statut: _objet.statut),
                    ],
                  ),
                  if (_objet.identifiantPrincipal != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppCouleurs.blancCasse,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'IDENTIFICATION',
                            style: TextStyle(
                              fontSize: 10.5,
                              letterSpacing: 0.7,
                              fontWeight: FontWeight.w800,
                              color: AppCouleurs.grisBleu,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _objet.identifiantPrincipal!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Un ami consulte mon bien : identité détaillée du propriétaire.
            if (!estProprietaire && _objet.proprietaireComplet.isNotEmpty) ...[
              FicheIdentite(
                libelle: 'Propriétaire du bien',
                nom: _objet.proprietaireNom,
                postnom: _objet.proprietairePostnom,
                prenom: _objet.proprietairePrenom,
                fonction: _objet.proprietaireMatricule,
                telephone: _objet.proprietaireTel,
                avatar: _objet.proprietaireAvatar,
                accent: AppCouleurs.orange,
              ),
              const SizedBox(height: 14),
            ],
            TitreSection(titre: 'Caractéristiques', icone: Icons.info_outline, padding: EdgeInsets.zero),
            CarteConteneur(
              enfant: Column(
                children: [
                  if (_objet.marque != null && _objet.marque!.isNotEmpty)
                    LigneInfo(cle: 'Marque', valeur: _objet.marque!, icone: Icons.branding_watermark_outlined, premiere: true),
                  if (_objet.modele != null && _objet.modele!.isNotEmpty)
                    LigneInfo(cle: 'Modèle', valeur: _objet.modele!),
                  if (_objet.couleur != null && _objet.couleur!.isNotEmpty)
                    LigneInfo(cle: 'Couleur', valeur: _objet.couleur!),
                  if (_objet.numeroChassis != null && _objet.numeroChassis!.isNotEmpty)
                    LigneInfo(cle: 'N° de châssis', valeur: _objet.numeroChassis!),
                  if (_objet.immatriculation != null && _objet.immatriculation!.isNotEmpty)
                    LigneInfo(cle: 'Immatriculation', valeur: _objet.immatriculation!),
                  if (_objet.numeroSerie != null && _objet.numeroSerie!.isNotEmpty)
                    LigneInfo(cle: 'N° de série', valeur: _objet.numeroSerie!),
                  LigneInfo(
                    cle: 'Date du vol',
                    valeur: _objet.dateVol != null
                        ? Formatage.dateTime(_objet.dateVol)
                        : 'Non renseignée',
                    icone: Icons.event_outlined,
                  ),
                  if (_objet.lieuVol != null && _objet.lieuVol!.isNotEmpty)
                    LigneInfo(cle: 'Lieu du vol', valeur: _objet.lieuVol!, icone: Icons.place_outlined),
                  if (_objet.proprietaire != null)
                    LigneInfo(
                      cle: 'Propriétaire',
                      valeur: _objet.proprietaire!,
                      icone: Icons.person_outline,
                    ),
                  if (_objet.description != null && _objet.description!.isNotEmpty)
                    LigneInfo(cle: 'Description', valeur: _objet.description!),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SectionPreuves(entiteType: 'objet', entiteId: _objet.id),
            const SizedBox(height: 26),
            if (estProprietaire || estPolice) ...[
              BoutonPrincipal(
                texte: 'Modifier la fiche',
                icone: Icons.edit_outlined,
                onPressed: _enCours ? null : _modifier,
              ),
              const SizedBox(height: 10),
            ],
            if ((estProprietaire || estPolice) && auth.aPermission('objets.maj')) ...[
              BoutonPrincipal(
                texte: 'Partager cette fiche et ses images',
                icone: Icons.share_outlined,
                onPressed: _enCours ? null : _partager,
              ),
              const SizedBox(height: 10),
            ],
            if ((estProprietaire || estPolice) && peutMaj)
              BoutonPrincipal(
                texte: 'Changer le statut',
                icone: Icons.swap_horiz,
                enCharge: _enCours,
                onPressed: _enCours ? null : _changerStatut,
              ),
            if (peutSupprimer &&
                (estProprietaire || auth.estEnqueteur || auth.estAdmin)) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _enCours ? null : _supprimer,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Supprimer la déclaration'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppCouleurs.rouge,
                  side: const BorderSide(color: AppCouleurs.rouge),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
