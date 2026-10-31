import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/badge.dart';
import '../../components/bouton.dart';
import '../../components/carte_conteneur.dart';
import '../../components/preuves_section.dart';
import '../../components/selecteur.dart';
import '../../components/selecteur_date.dart';
import '../../components/champ_texte.dart';
import '../../models/dossier.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/dossier_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/formatage.dart';
import '../../utils/messages.dart';
import '../../components/avatar.dart';

/// Fiche d'un dossier : informations, interventions, clôture.
class VueDetailDossier extends StatefulWidget {
  const VueDetailDossier({super.key, required this.dossier});

  final Dossier dossier;

  @override
  State<VueDetailDossier> createState() => _VueDetailDossierState();
}

class _VueDetailDossierState extends State<VueDetailDossier> {
  late Dossier _dossier;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _dossier = widget.dossier;
    _rafraichir();
  }

  Future<void> _rafraichir() async {
    try {
      final maj = await DossierService.instance.detail(_dossier.id);
      if (mounted) setState(() => _dossier = maj);
    } catch (_) {
      // Conserve l'affichage courant.
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
    final possibles = _dossier.statutsPossibles;
    if (possibles.isEmpty) {
      notifier(context, message: 'Dossier déjà clôturé.');
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
              child: Text('Statut du dossier',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
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

    if (choix == 'clos' || choix == 'classe') {
      await _cloturer(choix);
      return;
    }
    await _action(
      () => DossierService.instance.modifier(_dossier.id, {'statut': choix}),
      succes: 'Statut : ${AppCouleurs.libelle(choix)}.',
    );
  }

  Future<void> _cloturer([String statut = 'clos']) async {
    final controleur = TextEditingController();
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clôturer — ${AppCouleurs.libelle(statut)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controleur,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Résultat de l’enquête (facultatif)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    await _action(
      () => DossierService.instance.cloturer(
        _dossier.id,
        statut: statut,
        resultat: controleur.text.trim(),
      ),
      succes: 'Dossier ${AppCouleurs.libelle(statut).toLowerCase()}.',
    );
  }

  Future<void> _ajouterIntervention() async {
    final type = ValueNotifier<String>(ConstantesDossier.interventions.first);
    final description = TextEditingController();
    final lieu = TextEditingController();
    final duree = TextEditingController();
    DateTime date = DateTime.now();

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nouvelle intervention'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Selecteur<String>(
                  libelle: 'Type',
                  valeur: type.value,
                  options: [
                    for (final t in ConstantesDossier.interventions)
                      OptionSelecteur(
                        valeur: t,
                        libelle: Dossier.libelleIntervention(t),
                      ),
                  ],
                  onChanged: (v) => setStateDialog(() => type.value = v ?? t0()),
                ),
                const SizedBox(height: 14),
                ChampTexte(
                  libelle: 'Description',
                  controller: description,
                  maxLignes: 4,
                  hint: 'Déroulement de l’intervention…',
                ),
                const SizedBox(height: 14),
                SelecteurDateHeure(
                  libelle: 'Date et heure',
                  valeur: date,
                  onChanged: (v) => setStateDialog(() => date = v ?? DateTime.now()),
                ),
                const SizedBox(height: 14),
                ChampTexte(
                  libelle: 'Lieu',
                  controller: lieu,
                  icone: Icons.place_outlined,
                ),
                const SizedBox(height: 14),
                ChampTexte(
                  libelle: 'Durée (minutes)',
                  controller: duree,
                  icone: Icons.timer_outlined,
                  clavier: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (confirme != true || !mounted) return;

    await _action(
      () => DossierService.instance.creerIntervention(
        _dossier.id,
        typeIntervention: type.value,
        description: description.text.trim(),
        dateIntervention: date,
        dureeMinutes: int.tryParse(duree.text.trim()),
        lieu: lieu.text.trim(),
      ),
      succes: 'Intervention enregistrée.',
    );
  }

  String t0() => ConstantesDossier.interventions.first;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final peutAgir = auth.aPermission('interventions.creer');
    final peutCloturer = auth.aPermission('cas.cloturer');

    return Scaffold(
      appBar: AppBar(
        title: Text(_dossier.numeroDossier),
        actions: [
          if (peutCloturer && !_dossier.estTermine)
            IconButton(
              tooltip: 'Changer le statut',
              onPressed: _enCours ? null : _changerStatut,
              icon: const Icon(Icons.swap_horiz),
            ),
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: _rafraichir,
            icon: const Icon(Icons.refresh),
          ),
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
                    children: [
                      const IconeDomaine(
                        icone: Icons.folder_special_outlined,
                        couleur: AppCouleurs.bleu,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Dossier.libelleType(_dossier.typeCas),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Ouvert ${Formatage.relative(_dossier.dateOuverture)}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppCouleurs.texteSecondaire,
                              ),
                            ),
                          ],
                        ),
                      ),
                      BadgePriorite(priorite: _dossier.priorite),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      BadgeStatut(statut: _dossier.statut),
                      if (_dossier.commissariatNom != null)
                        BadgeSimple(texte: _dossier.commissariatNom!, icone: Icons.local_police),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Boite(
              titre: 'Description',
              icone: Icons.subject,
              enfant: Text(_dossier.description, style: const TextStyle(height: 1.5)),
            ),
            if (_dossier.lieu != null && _dossier.lieu!.isNotEmpty)
              _Boite(
                titre: 'Lieu',
                icone: Icons.place_outlined,
                enfant: Text(_dossier.lieu!),
              ),
            _Boite(
              titre: 'Chronologie',
              icone: Icons.schedule,
              enfant: Column(
                children: [
                  _LigneHoraire(
                    libelle: 'Faits',
                    valeur: Formatage.dateTime(_dossier.dateFaits),
                    icone: Icons.flag_outlined,
                    premier: true,
                  ),
                  _LigneHoraire(
                    libelle: 'Ouverture',
                    valeur: Formatage.dateTime(_dossier.dateOuverture),
                    icone: Icons.folder_open_outlined,
                  ),
                  if (_dossier.dateCloture != null)
                    _LigneHoraire(
                      libelle: 'Clôture',
                      valeur: Formatage.dateTime(_dossier.dateCloture),
                      icone: Icons.check_circle_outline,
                    ),
                ],
              ),
            ),
            _Boite(
              titre: 'Acteurs',
              icone: Icons.groups_outlined,
              enfant: Column(
                children: [
                  _Personne(
                    libelle: 'Victime',
                    valeur: _dossier.victime.isNotEmpty ? _dossier.victime : 'Non identifiée',
                    icone: Icons.person_outline,
                    premier: true,
                  ),
                  _Personne(
                    libelle: 'Enquêteur principal',
                    valeur: _dossier.enqueteur.isNotEmpty ? _dossier.enqueteur : 'Non affecté',
                    icone: Icons.search_outlined,
                  ),
                ],
              ),
            ),
            if (_dossier.resultat != null && _dossier.resultat!.isNotEmpty)
              _Boite(
                titre: 'Résultat',
                icone: Icons.verified_outlined,
                enfant: Text(_dossier.resultat!),
              ),

            // ------------------------------------------------ interventions
            const SizedBox(height: 22),
            Row(
              children: [
                const Icon(Icons.shield_outlined, size: 18, color: AppCouleurs.bleu),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Interventions (${_dossier.interventions.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                if (peutAgir)
                  TextButton.icon(
                    onPressed: _enCours ? null : _ajouterIntervention,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ajouter'),
                  ),
              ],
            ),
            if (_dossier.interventions.isEmpty)
              const BandeauInfo(
                message: 'Aucune intervention enregistrée sur ce dossier.',
              )
            else
              for (final i in _dossier.interventions) ...[
                CarteConteneur(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  enfant: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          BadgeSimple(texte: Dossier.libelleIntervention(i.typeIntervention)),
                          const Spacer(),
                          Text(
                            Formatage.relative(i.dateIntervention),
                            style: const TextStyle(fontSize: 11.5, color: AppCouleurs.gris),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(i.description, style: const TextStyle(height: 1.45)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: AppCouleurs.grisBleu),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              i.policier.isEmpty ? 'Agent' : i.policier,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppCouleurs.texteSecondaire,
                              ),
                            ),
                          ),
                          if (i.dureeMinutes != null)
                            Text(
                              Formatage.duree(i.dureeMinutes),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppCouleurs.bleu,
                              ),
                            ),
                        ],
                      ),
                      if (i.lieu != null && i.lieu!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            i.lieu!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppCouleurs.texteSecondaire,
                            ),
                          ),
                        ),
                      if (i.resultat != null && i.resultat!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppCouleurs.vertPastel,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              i.resultat!,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

            const SizedBox(height: 22),
            SectionPreuves(entiteType: 'cas', entiteId: _dossier.id),
            const SizedBox(height: 26),

            if (peutCloturer && !_dossier.estTermine)
              BoutonPrincipal(
                texte: 'Clôturer le dossier',
                icone: Icons.check_circle_outline,
                couleur: AppCouleurs.vert,
                enCharge: _enCours,
                onPressed: _enCours ? null : () => _cloturer('clos'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Boite extends StatelessWidget {
  const _Boite({required this.titre, required this.icone, required this.enfant});

  final String titre;
  final IconData icone;
  final Widget enfant;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: CarteConteneur(
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
            enfant,
          ],
        ),
      ),
    );
  }
}

class _LigneHoraire extends StatelessWidget {
  const _LigneHoraire({
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
          Flexible(
            child: Text(
              libelle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              valeur,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppCouleurs.texteSecondaire,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Personne extends StatelessWidget {
  const _Personne({
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
      padding: EdgeInsets.only(top: premier ? 0 : 14),
      child: Row(
        children: [
          IconeDomaine(icone: icone, taille: 36, tailleIcone: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  libelle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w700,
                    color: AppCouleurs.grisBleu,
                  ),
                ),
                Text(
                  valeur,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
