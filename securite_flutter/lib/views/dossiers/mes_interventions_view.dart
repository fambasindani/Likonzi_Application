import 'package:flutter/material.dart';

import '../../components/badge.dart';
import '../../components/carte_conteneur.dart';
import '../../components/champ_texte.dart';
import '../../components/liste.dart';
import '../../components/selecteur.dart';
import '../../components/selecteur_date.dart';
import '../../models/dossier.dart';
import '../../services/api_client.dart';
import '../../services/dossier_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/formatage.dart';
import '../../utils/messages.dart';

/// Mes interventions — `GET /interventions` + édition `PATCH /interventions/<id>`.
class VueMesInterventions extends StatefulWidget {
  const VueMesInterventions({super.key});

  @override
  State<VueMesInterventions> createState() => _VueMesInterventionsState();
}

class _VueMesInterventionsState extends State<VueMesInterventions> {
  final DossierService _service = DossierService.instance;

  List<Intervention> _interventions = [];
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
      final resultat = await _service.mesInterventions(page: page);
      setState(() {
        _interventions = page == 1 ? resultat.elements : [..._interventions, ...resultat.elements];
        _page = resultat.page;
        _pages = resultat.pages;
        _total = resultat.total;
      });
    } on ExceptionApi catch (e) {
      setState(() => _erreur = e.message);
    } catch (_) {
      setState(() => _erreur = 'Impossible de charger vos interventions.');
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _modifier(Intervention i) async {
    // `GET /interventions/<id>` : on repart de la version serveur.
    Intervention courante = i;
    try {
      courante = await _service.intervention(i.id);
    } on ExceptionApi catch (e) {
      if (!mounted) return;
      montrerErreur(context, e);
      return;
    }

    if (!mounted) return;

    final type = ValueNotifier<String>(courante.typeIntervention);
    final description = TextEditingController(text: courante.description);
    final lieu = TextEditingController(text: courante.lieu ?? '');
    final resultat = TextEditingController(text: courante.resultat ?? '');
    final duree = TextEditingController(text: '${courante.dureeMinutes ?? ''}');
    DateTime date = courante.dateIntervention;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Modifier l’intervention'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Selecteur<String>(
                  libelle: 'Type',
                  valeur: type.value,
                  options: [
                    for (final t in ConstantesDossier.interventions)
                      OptionSelecteur(valeur: t, libelle: Dossier.libelleIntervention(t)),
                  ],
                  onChanged: (v) => setStateDialog(() => type.value = v ?? type.value),
                ),
                const SizedBox(height: 14),
                ChampTexte(
                  libelle: 'Description',
                  controller: description,
                  maxLignes: 4,
                  requis: true,
                ),
                const SizedBox(height: 14),
                SelecteurDateHeure(
                  libelle: 'Date et heure',
                  valeur: date,
                  onChanged: (v) => setStateDialog(() => date = v ?? date),
                ),
                const SizedBox(height: 14),
                ChampTexte(libelle: 'Lieu', controller: lieu, icone: Icons.place_outlined),
                const SizedBox(height: 14),
                ChampTexte(
                  libelle: 'Durée (minutes)',
                  controller: duree,
                  icone: Icons.timer_outlined,
                  clavier: TextInputType.number,
                ),
                const SizedBox(height: 14),
                ChampTexte(libelle: 'Résultat', controller: resultat, maxLignes: 3),
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

    setState(() => _chargePlus = true);
    try {
      await _service.modifierIntervention(courante.id, {
        'type_intervention': type.value,
        'description': description.text.trim(),
        'date_intervention': date.toIso8601String(),
        'lieu': lieu.text.trim(),
        if (int.tryParse(duree.text.trim()) != null)
          'duree_minutes': int.parse(duree.text.trim()),
        'resultat': resultat.text.trim(),
      });
      await _charger();
      if (!mounted) return;
      montrerSucces(context, 'Intervention mise à jour.');
    } on ExceptionApi catch (e) {
      if (!mounted) return;
      montrerErreur(context, e);
    } finally {
      if (mounted) setState(() => _chargePlus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes interventions'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => _charger(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _chargement && _interventions.isEmpty
          ? const EtatChargement()
          : _erreur != null && _interventions.isEmpty
              ? EtatErreur(message: _erreur!, onReessayer: () => _charger())
              : _interventions.isEmpty
                  ? const EtatVide(
                      icone: Icons.shield_outlined,
                      titre: 'Aucune intervention',
                      message:
                          'Les interventions que vous enregistrez sur un dossier apparaîtront ici.',
                    )
                  : RefreshIndicator(
                      onRefresh: () => _charger(),
                      color: AppCouleurs.bleu,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _interventions.length + (_page < _pages ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index >= _interventions.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: _chargePlus
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2.5),
                                      )
                                    : TextButton(
                                        onPressed: () async {
                                          setState(() => _chargePlus = true);
                                          await _charger(page: _page + 1);
                                          if (mounted) setState(() => _chargePlus = false);
                                        },
                                        child: const Text('Charger plus'),
                                      ),
                              ),
                            );
                          }
                          final i = _interventions[index];
                          return CarteConteneur(
                            onTap: () => _modifier(i),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            enfant: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    BadgeSimple(
                                      texte: Dossier.libelleIntervention(i.typeIntervention),
                                    ),
                                    const Spacer(),
                                    Text(
                                      Formatage.dateTime(i.dateIntervention),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppCouleurs.gris,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  i.description,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(height: 1.4),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(Icons.shield_outlined,
                                        size: 15, color: AppCouleurs.bleu),
                                    const SizedBox(width: 6),
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
                                      BadgeSimple(
                                        texte: Formatage.duree(i.dureeMinutes),
                                        icone: Icons.timer_outlined,
                                        compact: true,
                                      ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.edit_outlined,
                                        size: 16, color: AppCouleurs.grisBleu),
                                  ],
                                ),
                                if (i.lieu != null && i.lieu!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      i.lieu!,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppCouleurs.texteSecondaire,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            '$_total intervention(s) · touchez une carte pour la modifier',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppCouleurs.texteSecondaire),
          ),
        ),
      ),
    );
  }
}
