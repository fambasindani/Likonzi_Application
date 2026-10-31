import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/preuve.dart';
import '../services/api_client.dart';
import '../services/preuve_service.dart';
import '../theme/couleurs.dart';
import '../utils/formatage.dart';
import '../utils/messages.dart';
import 'bouton.dart';
import '../../components/carte_conteneur.dart';
import '../../components/liste.dart';
import '../../utils/images.dart';

/// Bloc « preuves » : liste, ajout (caméra / fichier), vérification d'intégrité.
class SectionPreuves extends StatefulWidget {
  const SectionPreuves({
    super.key,
    required this.entiteType,
    required this.entiteId,
    this.peutAjouter = true,
  });

  final String entiteType;
  final int entiteId;
  final bool peutAjouter;

  @override
  State<SectionPreuves> createState() => _SectionPreuvesState();
}

class _SectionPreuvesState extends State<SectionPreuves> {
  final PreuveService _service = PreuveService.instance;
  final ImagePicker _imagePicker = ImagePicker();

  List<Preuve> _preuves = [];
  Map<String, dynamic> _regles = {};
  bool _chargement = true;
  bool _envoi = false;
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
    if (_regles.isEmpty) {
      // GET /preuves/types-autorises : extensions + limite serveur.
      _service.typesAutorises().then((v) {
        if (mounted) setState(() => _regles = v);
      }).catchError((_) => null);
    }
    try {
      final page = await _service.lister(
        entiteType: widget.entiteType,
        entiteId: widget.entiteId,
        perPage: 50,
      );
      _preuves = page.elements;
    } on ExceptionApi catch (e) {
      _erreur = e.message;
    } catch (_) {
      _erreur = 'Impossible de charger les preuves.';
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _ajouterDepuis(ImageSource source) async {
    try {
      final fichier = await _imagePicker.pickImage(
        source: source,
        imageQuality: 60, // cible < 200 Ko
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (!mounted || fichier == null) return;
      final chemin = fichier.path;
      if (chemin.isEmpty) {
        montrerErreur(context, 'Fichier non accessible sur appareil.');
        return;
      }
      final probleme = Images.controler(chemin);
      if (probleme != null) {
        montrerErreur(context, probleme);
        return;
      }
      await _envoyer(chemin, fichier.name, 'photo');
    } catch (e) {
      if (mounted) montrerErreur(context, e);
    }
  }

  Future<void> _ajouterFichier() async {
    try {
      final resultat = await FilePicker.pickFiles(type: FileType.any);
      final fichier = resultat?.files.singleOrNull;
      if (fichier == null || fichier.path == null) return;
      final nom = fichier.name.toLowerCase();
      String type = 'document';
      if (['jpg', 'jpeg', 'png', 'gif', 'webp'].any((e) => nom.endsWith('.$e'))) {
        type = 'photo';
      } else if (['mp4', 'mov', 'avi', 'mkv', 'webm'].any((e) => nom.endsWith('.$e'))) {
        type = 'video';
      } else if (['mp3', 'wav', 'm4a', 'ogg', 'flac'].any((e) => nom.endsWith('.$e'))) {
        type = 'audio';
      }
      if (type == 'photo') {
        final probleme = Images.controler(fichier.path!);
        if (probleme != null) {
          if (mounted) montrerErreur(context, probleme);
          return;
        }
      }
      await _envoyer(fichier.path!, fichier.name, type);
    } catch (e) {
      if (mounted) montrerErreur(context, e);
    }
  }

  Future<void> _envoyer(String chemin, String nom, String type) async {
    setState(() => _envoi = true);
    try {
      final preuve = await _service.televerser(
        entiteType: widget.entiteType,
        entiteId: widget.entiteId,
        typePreuve: type,
        cheminFichier: chemin,
        nomFichier: nom,
      );
      if (!mounted) return;
      setState(() => _preuves = [preuve, ..._preuves]);
      montrerSucces(context, 'Preuve enregistrée (empreinte calculée).');
    } on ExceptionApi catch (e) {
      if (mounted) montrerErreur(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _details(Preuve preuve) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppCouleurs.blanc,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          child: _DetailsPreuve(
            preuve: preuve,
            onVerifier: () async {
              final verif = await _service.verifier(preuve.id);
              if (context.mounted) {
                await showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text(verif.conforme ? 'Intégrité vérifiée' : 'Altération détectée'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          verif.conforme ? Icons.verified_outlined : Icons.broken_image_outlined,
                          size: 44,
                          color: verif.conforme ? AppCouleurs.vert : AppCouleurs.rouge,
                        ),
                        const SizedBox(height: 12),
                        Text(verif.message ?? ''),
                        const SizedBox(height: 12),
                        _LigneHachage(libelle: 'Enregistré', valeur: verif.hashEnregistre),
                        _LigneHachage(libelle: 'Calculé', valeur: verif.hashCalcule),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Fermer'),
                      ),
                    ],
                  ),
                );
              }
            },
            onSupprimer: () async {
              final ok = await confirmer(
                context,
                titre: 'Supprimer cette preuve ?',
                message: 'Le fichier restera conservé pour l’audit, mais sera marqué supprimé.',
                libelleValider: 'Supprimer',
                destructif: true,
                icone: Icons.delete_outline,
              );
              if (!ok) return;
              await _service.supprimer(preuve.id);
              if (context.mounted) {
                Navigator.of(context).pop();
                montrerSucces(context, 'Preuve supprimée.');
                _charger();
              }
            },
          ),
        ),
      ),
    );
  }

  Future<void> _visualiser(Preuve preuve) async {
    if (!preuve.estImage) {
      await _details(preuve);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: FutureBuilder<Uint8List>(
                future: _service.octets(preuve.id),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.all(30),
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white70, size: 48),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(30),
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InteractiveViewer(
                      child: Image.memory(snapshot.data!, fit: BoxFit.contain),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      preuve.nomOriginal,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _details(preuve);
                    },
                    child: const Text('Détails'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.attach_file, size: 18, color: AppCouleurs.bleu),
            const SizedBox(width: 8),
            Text(
              'Preuves (${_preuves.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            if (widget.peutAjouter && _envoi)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (_erreur != null)
          BandeauInfo(type: 'erreur', message: _erreur!)
        else if (_chargement)
          const EtatChargement(compact: true)
        else if (_preuves.isEmpty)
          const BandeauInfo(
            message: 'Aucune preuve. Ajoutez une photo, une vidéo ou un document.',
          )
        else
          Column(
            children: [
              for (final p in _preuves) ...[
                _LignePreuve(preuve: p, onTap: () => _visualiser(p)),
                const SizedBox(height: 8),
              ],
            ],
          ),
        if (widget.peutAjouter && _regles.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Images : ${Images.formatPoids(Images.maxOctets)} maximum'
            '${(_regles['extensions'] as List? ?? const []).isNotEmpty ? ' · formats : ${(_regles['extensions'] as List).take(6).join(', ')}…' : ''}',
            style: const TextStyle(fontSize: 11.5, color: AppCouleurs.texteSecondaire),
          ),
        ],
        if (widget.peutAjouter) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BoutonMedia(
                  libelle: 'Caméra',
                  icone: Icons.photo_camera_outlined,
                  onPressed: _envoi ? null : () => _ajouterDepuis(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BoutonMedia(
                  libelle: 'Galerie',
                  icone: Icons.photo_library_outlined,
                  onPressed: _envoi ? null : () => _ajouterDepuis(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BoutonMedia(
                  libelle: 'Fichier',
                  icone: Icons.upload_file_outlined,
                  onPressed: _envoi ? null : _ajouterFichier,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LignePreuve extends StatelessWidget {
  const _LignePreuve({required this.preuve, required this.onTap});

  final Preuve preuve;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icone = preuve.estImage
        ? Icons.image_outlined
        : preuve.estVideo
            ? Icons.videocam_outlined
            : preuve.estAudio
                ? Icons.mic_none
                : Icons.insert_drive_file_outlined;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppCouleurs.blancCasse,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icone, size: 20, color: AppCouleurs.bleu),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preuve.nomOriginal,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${preuve.typeLibelle} · ${Formatage.taille(preuve.tailleOctets)}'
                    '${preuve.dateCreation != null ? ' · ${Formatage.relative(preuve.dateCreation)}' : ''}',
                    style: const TextStyle(fontSize: 11.5, color: AppCouleurs.texteSecondaire),
                  ),
                ],
              ),
            ),
            if (preuve.hashSha256 != null)
              const Tooltip(
                message: 'Empreinte SHA-256 enregistrée',
                child: Icon(Icons.verified_user_outlined, size: 17, color: AppCouleurs.vert),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailsPreuve extends StatelessWidget {
  const _DetailsPreuve({
    required this.preuve,
    required this.onVerifier,
    required this.onSupprimer,
  });

  final Preuve preuve;
  final Future<void> Function() onVerifier;
  final Future<void> Function() onSupprimer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppCouleurs.grisClaire,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          preuve.nomOriginal,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '${preuve.typeLibelle} · ${Formatage.taille(preuve.tailleOctets)}'
          '${preuve.dateCreation != null ? ' · ${Formatage.dateTime(preuve.dateCreation)}' : ''}',
          style: const TextStyle(fontSize: 13, color: AppCouleurs.texteSecondaire),
        ),
        if (preuve.description != null && preuve.description!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(preuve.description!),
        ],
        const SizedBox(height: 16),
        if (preuve.hashSha256 != null)
          _LigneHachage(libelle: 'Empreinte SHA-256', valeur: preuve.hashSha256),
        if (preuve.uploadeur.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Ajoutée par ${preuve.uploadeur}',
            style: const TextStyle(fontSize: 12.5, color: AppCouleurs.texteSecondaire),
          ),
        ],
        const SizedBox(height: 22),
        BoutonPrincipal(
          texte: 'Vérifier l’intégrité',
          icone: Icons.shield_outlined,
          onPressed: onVerifier,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onSupprimer,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Supprimer la preuve'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppCouleurs.rouge,
            side: const BorderSide(color: AppCouleurs.rouge),
          ),
        ),
      ],
    );
  }
}

class _LigneHachage extends StatelessWidget {
  const _LigneHachage({required this.libelle, required this.valeur});

  final String libelle;
  final String? valeur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppCouleurs.blancCasse,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            libelle.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w800,
              color: AppCouleurs.grisBleu,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            valeur ?? '—',
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: AppCouleurs.textePrimaire,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton média compact : texte réduit pour tenir sur les petits écrans.
class _BoutonMedia extends StatelessWidget {
  const _BoutonMedia({
    required this.libelle,
    required this.icone,
    required this.onPressed,
  });

  final String libelle;
  final IconData icone;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icone, size: 15),
      label: Text(
        libelle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppCouleurs.bleu,
        side: const BorderSide(color: AppCouleurs.bleu, width: 1.2),
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
