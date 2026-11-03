import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../components/avatar.dart';
import '../../components/badge.dart';
import '../../components/carte_conteneur.dart';
import '../../components/liste.dart';
import '../../models/objet.dart';
import '../../services/api_client.dart';
import '../../services/objet_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/formatage.dart';
import '../../utils/icone_objet.dart';
import '../../utils/messages.dart';
import 'objet_detail_view.dart';

/// Objets reçus via un partage (amis ou forces de l'ordre) — `GET /partages`.
class VuePartages extends StatefulWidget {
  const VuePartages({super.key});

  @override
  State<VuePartages> createState() => _VuePartagesState();
}

class _VuePartagesState extends State<VuePartages> {
  final ObjetService _service = ObjetService.instance;

  List<Partage> _partages = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final page = await _service.partages(perPage: 100);
      _partages = page.elements;
    } on ExceptionApi catch (e) {
      _erreur = e.message;
    } catch (_) {
      _erreur = 'Impossible de charger les partages.';
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _ouvrir(Partage partage) async {
    if (!partage.lu) {
      try {
        final maj = await _service.marquerPartageLu(partage.id);
        if (!mounted) return;
        {
          setState(() {
            final i = _partages.indexWhere((p) => p.id == partage.id);
            if (i >= 0) _partages[i] = maj;
          });
        }
      } catch (_) {
        // Le marquage échoue : on ouvre quand même la fiche.
      }
    }
    if (!mounted || partage.objet == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VueDetailObjet(objet: partage.objet!)),
    );
    if (mounted) _charger();
  }

  Future<void> _retirer(Partage partage) async {
    final confirme = await confirmer(
      context,
      titre: 'Retirer ce partage ?',
      message: 'La fiche ne vous sera plus accessible.',
      libelleValider: 'Retirer',
      destructif: true,
      icone: Icons.folder_delete_outlined,
    );
    if (!confirme || !mounted) return;
    try {
      await _service.retirerPartage(partage.id);
      if (!mounted) return;
      setState(() => _partages.removeWhere((p) => p.id == partage.id));
      montrerSucces(context, 'Partage retiré.');
    } on ExceptionApi catch (e) {
      if (mounted) montrerErreur(context, e);
    }
  }

  /// Appelle l'expéditeur du partage (photo + numéro renvoyés par l'API).
  Future<void> _appeler(Partage p) async {
    final numero = (p.proprietaireTel ?? '').replaceAll(RegExp(r'[^\d+]'), '');
    if (numero.isEmpty) {
      montrerErreur(context, 'Aucun numéro renseigné pour cet expéditeur.');
      return;
    }
    try {
      await launchUrl(Uri(scheme: 'tel', path: numero));
    } catch (_) {
      if (mounted) montrerErreur(context, 'Impossible de passer l’appel.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final nonLus = _partages.where((p) => !p.lu).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partages reçus'),
        actions: [
          if (nonLus > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: BadgeCompteur(valeur: nonLus)),
            ),
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _charger,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _chargement
          ? const EtatChargement()
          : _erreur != null
              ? EtatErreur(message: _erreur!, onReessayer: _charger)
              : _partages.isEmpty
                  ? const EtatVide(
                      icone: Icons.share_outlined,
                      titre: 'Aucun partage reçu',
                      message:
                          'Quand un ami ou une unité de police vous transmet une fiche '
                          '(véhicule, ordinateur…), elle apparaît ici.',
                    )
                  : RefreshIndicator(
                      onRefresh: _charger,
                      color: AppCouleurs.bleu,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _partages.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final p = _partages[index];
                          final objet = p.objet;
                          return CarteConteneur(
                            onTap: () => _ouvrir(p),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            enfant: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    AvatarUtilisateur.noms(
                                      nom: p.proprietaireNom,
                                      prenom: p.proprietairePrenom,
                                      url: p.proprietaireAvatar,
                                      taille: 40,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.proprietaire.isEmpty
                                                ? 'Expéditeur'
                                                : p.proprietaire,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            Formatage.relative(p.datePartage),
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: AppCouleurs.gris,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!p.lu)
                                      Container(
                                        width: 9,
                                        height: 9,
                                        margin: const EdgeInsets.only(left: 8),
                                        decoration: const BoxDecoration(
                                          color: AppCouleurs.rouge,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    if ((p.proprietaireTel ?? '')
                                        .replaceAll(RegExp(r'[^\d+]'), '')
                                        .isNotEmpty)
                                      IconButton(
                                        tooltip:
                                            'Appeler ${p.proprietaire.isEmpty ? 'l\'expéditeur' : p.proprietaire}',
                                        icon: const Icon(Icons.call_outlined,
                                            size: 19, color: AppCouleurs.vert),
                                        onPressed: () => _appeler(p),
                                      ),
                                    IconButton(
                                      tooltip: 'Retirer',
                                      icon: const Icon(Icons.close,
                                          size: 18, color: AppCouleurs.gris),
                                      onPressed: () => _retirer(p),
                                    ),
                                  ],
                                ),
                                if (objet != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppCouleurs.blancCasse,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  iconeTypeObjet(objet.typeCode),
                                                  size: 18,
                                                  color: AppCouleurs.bleu,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    objet.designation,
                                                    style: const TextStyle(
                                                      fontSize: 14.5,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                        if (objet.identifiantPrincipal != null)
                                          Text(
                                            objet.identifiantPrincipal!,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontFamily: 'monospace',
                                              color: AppCouleurs.grisBleu,
                                            ),
                                          ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            BadgeStatut(statut: objet.statut, compact: true),
                                            if (objet.lieuVol != null)
                                              BadgeSimple(
                                                texte: objet.lieuVol!,
                                                icone: Icons.place_outlined,
                                                compact: true,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (p.message != null && p.message!.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.chat_bubble_outline,
                                          size: 15, color: AppCouleurs.grisBleu),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          p.message!,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontStyle: FontStyle.italic,
                                            color: AppCouleurs.texteSecondaire,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: () => _ouvrir(p),
                                      icon: const Icon(Icons.visibility_outlined,
                                          size: 17),
                                      label: const Text('Consulter la fiche'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
