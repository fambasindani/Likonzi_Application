import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../components/bouton.dart';
import '../../components/champ_texte.dart';
import '../../components/selecteur.dart';
import '../../components/selecteur_date.dart';
import '../../models/objet.dart';
import '../../services/api_client.dart';
import '../../services/preuve_service.dart';
import '../../services/objet_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/messages.dart';
import 'objet_detail_view.dart';
import '../../components/carte_conteneur.dart';
import '../../utils/images.dart';

/// Déclaration d'un objet volé.
class VueCreationObjet extends StatefulWidget {
  const VueCreationObjet({
    super.key,
    this.statutInitial = 'declare_vol',
    this.objet,
  });

  /// `declare_vol` (déclaration classique) ou `en_possession` (bien pré-enregistré).
  final String statutInitial;

  /// Présent => mode MODIFICATION d'un objet existant.
  final Objet? objet;

  @override
  State<VueCreationObjet> createState() => _VueCreationObjetState();
}

class _VueCreationObjetState extends State<VueCreationObjet> {
  final _formKey = GlobalKey<FormState>();
  final _marque = TextEditingController();
  final _modele = TextEditingController();
  final _couleur = TextEditingController();
  final _immat = TextEditingController();
  final _chassis = TextEditingController();
  final _serie = TextEditingController();
  final _lieu = TextEditingController();
  final _description = TextEditingController();

  List<TypeObjet> _types = [];
  int? _idType;
  DateTime? _dateVol;
  bool _chargementTypes = true;
  bool _enCours = false;

  /// Photos choisies AVANT l'enregistrement : elles seront téléversées
  /// juste après la création du bien (entité `objet`).
  final List<_PhotoBien> _photos = [];

  /// Champs visibles selon le type d'objet sélectionné.
  String? get _codeType => _types.where((t) => t.id == _idType).firstOrNull?.code;

  /// Véhicules : immatriculation + n° de châssis.
  bool get _estVehicule => const {'VOITURE', 'MOTO'}.contains(_codeType);

  /// Biens numériques : n° de série uniquement.
  bool get _avecNumeroSerie =>
      const {'ORDINATEUR', 'TELEPHONE', 'ELECTROMENAGER', 'AUTRE'}.contains(_codeType);

  bool get _champsIdentification => _estVehicule || _avecNumeroSerie;

  Future<void> _prendrePhoto(ImageSource source) async {
    try {
      final fichier = await ImagePicker().pickImage(
        source: source,
        imageQuality: 60, // cible < 200 Ko
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (fichier == null || !mounted) return;
      final probleme = Images.controler(fichier.path);
      if (probleme != null) {
        notifier(context, message: probleme, succes: false);
        return;
      }
      setState(() => _photos.add(_PhotoBien(fichier.path, fichier.name, true)));
    } catch (e) {
      if (mounted) montrerErreur(context, e);
    }
  }

  Future<void> _ajouterFichier() async {
    try {
      final resultat = await FilePicker.pickFiles(type: FileType.any);
      final fichier = resultat == null || resultat.files.isEmpty ? null : resultat.files.first;
      if (fichier == null || fichier.path == null || !mounted) return;
      final estImage = Images.estImage(fichier.path!);
      if (estImage) {
        final probleme = Images.controler(fichier.path!);
        if (probleme != null) {
          notifier(context, message: probleme, succes: false);
          return;
        }
      }
      setState(() => _photos.add(_PhotoBien(fichier.path!, fichier.name, estImage)));
    } catch (e) {
      if (mounted) montrerErreur(context, e);
    }
  }

  void _retirerPhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  /// Téléverse les photos sur le bien fraîchement créé.
  Future<int> _envoyerPhotos(int idObjet) async {
    var envoyees = 0;
    for (final photo in _photos) {
      try {
        await PreuveService.instance.televerser(
          entiteType: 'objet',
          entiteId: idObjet,
          typePreuve: photo.image ? 'photo' : 'document',
          cheminFichier: photo.chemin,
          nomFichier: photo.nom,
        );
        envoyees += 1;
      } catch (_) {
        // Un échec d'une photo n'annule pas l'enregistrement du bien :
        // l'utilisateur pourra la reprendre depuis la fiche.
      }
    }
    return envoyees;
  }

  /// Mode modification de l'objet en cours.
  bool get _estModification => widget.objet != null;

  @override
  void initState() {
    super.initState();
    _preRemplir();
    _chargerTypes();
  }

  /// Mode modification : on repart des valeurs enregistrées.
  void _preRemplir() {
    final o = widget.objet;
    if (o == null) return;
    _idType = o.idType;
    _marque.text = o.marque ?? '';
    _modele.text = o.modele ?? '';
    _couleur.text = o.couleur ?? '';
    _immat.text = o.immatriculation ?? '';
    _chassis.text = o.numeroChassis ?? '';
    _serie.text = o.numeroSerie ?? '';
    _lieu.text = o.lieuVol ?? '';
    _description.text = o.description ?? '';
    _dateVol = o.dateVol;
  }

  Future<void> _chargerTypes() async {
    try {
      final types = await ObjetService.instance.types();
      if (mounted) {
        setState(() {
          _types = types;
          _idType ??= types.isNotEmpty ? types.first.id : null;
          _chargementTypes = false;
        });
      }
    } on ExceptionApi catch (e) {
      if (mounted) {
        setState(() => _chargementTypes = false);
        montrerErreur(context, e);
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _marque,
      _modele,
      _couleur,
      _immat,
      _chassis,
      _serie,
      _lieu,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _envoyer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_idType == null) {
      notifier(context, message: 'Choisissez un type d’objet.', succes: false);
      return;
    }
    setState(() => _enCours = true);
    try {
      final Objet objet;
      if (_estModification) {
        // ------------------------------------------------------ modification
        objet = await ObjetService.instance.modifier(widget.objet!.id, {
          'id_type': _idType!,
          'marque': _marque.text.trim(),
          'model': _modele.text.trim(),
          'couleur': _couleur.text.trim(),
          'immatriculation': _immat.text.trim(),
          'numero_chassis': _chassis.text.trim(),
          'numero_serie': _serie.text.trim(),
          'description': _description.text.trim(),
          'date_vol': _dateVol?.toIso8601String(),
          'lieu_vol': _lieu.text.trim(),
        });
      } else {
        // ------------------------------------------------------ création
        objet = await ObjetService.instance.creer(
          idType: _idType!,
          marque: _marque.text.trim(),
          modele: _modele.text.trim(),
          couleur: _couleur.text.trim(),
          immatriculation: _immat.text.trim(),
          numeroChassis: _chassis.text.trim(),
          numeroSerie: _serie.text.trim(),
          description: _description.text.trim(),
          dateVol: _dateVol,
          lieuVol: _lieu.text.trim(),
          statut: widget.statutInitial,
        );
      }
      if (!mounted) return;

      // Les photos du formulaire sont téléversées sur le bien (création ET modification).
      final envoyees = await _envoyerPhotos(objet.id);
      if (!mounted) return;

      final libellePhotos = envoyees > 0 ? ' avec $envoyees photo(s)' : '';
      if (_estModification) {
        if (envoyees > 0 && envoyees != _photos.length) {
          notifier(
            context,
            message:
                'Fiche mise à jour ($envoyees/${_photos.length} photo(s) ajoutée(s)).',
            succes: false,
          );
        } else {
          montrerSucces(context, 'Fiche mise à jour$libellePhotos.');
        }
        Navigator.of(context).pop(true);
        return;
      }
      if (envoyees == _photos.length && envoyees > 0) {
        montrerSucces(
          context,
          _bien ? 'Bien enregistré$libellePhotos.' : 'Objet déclaré$libellePhotos.',
        );
      } else if (envoyees > 0) {
        notifier(
          context,
          message:
              'Enregistré ($envoyees/${_photos.length} photo(s)) — les autres ont '
              'échoué, reprenez-les depuis la fiche.',
          succes: false,
        );
      } else {
        montrerSucces(
          context,
          _bien ? 'Bien enregistré dans votre inventaire.' : 'Objet déclaré.',
        );
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => VueDetailObjet(objet: objet)),
      );
    } on ExceptionApi catch (e) {
      if (mounted) montrerErreur(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  bool get _bien => widget.statutInitial == 'en_possession';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _estModification
              ? 'Modifier la fiche'
              : (_bien ? 'Ajouter un bien' : 'Déclarer un objet volé'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BandeauInfo(
                message: _bien
                    ? 'Enregistrez votre véhicule, ordinateur, moto… dès maintenant : '
                        'en cas de vol, une seule action suffira pour les transmettre '
                        'à la police et à vos amis.'
                    : 'Plus l’identification est précise (immatriculation, châssis, n° de série), '
                        'plus la recherche est efficace.',
              ),
              const SizedBox(height: 20),
              if (_chargementTypes)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: EtatChargementRef(),
                )
              else
                Selecteur<int>(
                  libelle: 'Type d’objet',
                  requis: true,
                  valeur: _idType,
                  icone: Icons.category_outlined,
                  options: [
                    for (final t in _types)
                      OptionSelecteur(valeur: t.id, libelle: t.description),
                  ],
                  onChanged: (v) => setState(() => _idType = v),
                ),
              const SizedBox(height: 18),
              ChampTexte(
                libelle: 'Marque',
                controller: _marque,
                icone: Icons.branding_watermark_outlined,
                hint: 'Toyota, Samsung…',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ChampTexte(
                      libelle: 'Modèle',
                      controller: _modele,
                      hint: 'Hilux, Galaxy…',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChampTexte(
                      libelle: 'Couleur',
                      controller: _couleur,
                    ),
                  ),
                ],
              ),
              // Champs d'identification AFFICHÉS SELON LE TYPE :
              // - véhicule (voiture, moto) : immatriculation + n° de châssis ;
              // - biens numériques : n° de série ;
              // - les autres (vêtement, document…) : ni l'un ni l'autre.
              if (_champsIdentification) ...[
                const SizedBox(height: 26),
                Text(
                  _estVehicule ? 'Identification du véhicule' : 'Numéro de série',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                if (_estVehicule) ...[
                  ChampTexte(
                    libelle: 'Immatriculation',
                    controller: _immat,
                    icone: Icons.confirmation_number_outlined,
                    hint: 'CD 4521 AB',
                  ),
                  const SizedBox(height: 16),
                  ChampTexte(
                    libelle: 'N° de châssis',
                    controller: _chassis,
                    icone: Icons.pin_outlined,
                  ),
                ] else if (_avecNumeroSerie)
                  ChampTexte(
                    libelle: 'N° de série',
                    controller: _serie,
                    icone: Icons.qr_code_outlined,
                    hint: 'Numéro gravé ou étiqueté sur l’appareil',
                  ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Ce type d’objet ne dispose d’aucun numéro d’identification '
                    ' : la marque, le modèle et la description suffiront.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppCouleurs.texteSecondaire.withValues(alpha: 1),
                    ),
                  ),
                ),
              const SizedBox(height: 26),
              const Text(
                'Circonstances',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              SelecteurDateHeure(
                libelle: _bien ? 'Date d’acquisition' : 'Date du vol',
                valeur: _dateVol,
                onChanged: (v) => setState(() => _dateVol = v),
              ),
              const SizedBox(height: 16),
              ChampTexte(
                libelle: _bien ? 'Lieu d’acquisition / de stockage' : 'Lieu du vol',
                controller: _lieu,
                icone: Icons.place_outlined,
                hint: 'Parking, avenue, ville',
                maxLignes: 2,
              ),
              const SizedBox(height: 16),
              ChampTexte(
                libelle: 'Description complémentaire',
                controller: _description,
                maxLignes: 4,
                hint: 'Circonstances, particularités…',
                capitale: TextCapitalization.sentences,
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  const Text(
                    'Photos',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    '${_photos.length} photo(s)',
                    style: const TextStyle(fontSize: 13, color: AppCouleurs.texteSecondaire),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Ajoutez les photos de votre bien : elles seront transmises avec '
                'la déclaration en cas de vol. ${Images.formatPoids(Images.maxOctets)} maximum par image.',
                style: const TextStyle(fontSize: 12.5, color: AppCouleurs.texteSecondaire),
              ),
              const SizedBox(height: 12),
              if (_photos.isNotEmpty) ...[
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final photo = _photos[index];
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              color: AppCouleurs.blancCasse,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppCouleurs.bordure),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: photo.image
                                ? Image.file(File(photo.chemin), fit: BoxFit.cover)
                                : const Center(
                                    child: Icon(Icons.description_outlined,
                                        size: 30, color: AppCouleurs.grisBleu),
                                  ),
                          ),
                          Positioned(
                            right: -6,
                            top: -6,
                            child: InkWell(
                              onTap: () => _retirerPhoto(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppCouleurs.rouge,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 13, color: AppCouleurs.blanc),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: _BoutonPhoto(
                      libelle: 'Caméra',
                      icone: Icons.photo_camera_outlined,
                      onPressed:
                          _enCours ? null : () => _prendrePhoto(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BoutonPhoto(
                      libelle: 'Galerie',
                      icone: Icons.photo_library_outlined,
                      onPressed:
                          _enCours ? null : () => _prendrePhoto(ImageSource.gallery),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BoutonPhoto(
                      libelle: 'Fichier',
                      icone: Icons.upload_file_outlined,
                      onPressed: _enCours ? null : _ajouterFichier,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              BoutonPrincipal(
                texte: _estModification
                    ? 'Enregistrer les modifications'
                    : (_bien ? 'Enregistrer le bien' : 'Enregistrer la déclaration'),
                icone: _bien ? Icons.add_task_outlined : Icons.gavel_outlined,
                enCharge: _enCours,
                onPressed: _enCours ? null : _envoyer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Petit indicateur aligné sur le reste du formulaire.
class EtatChargementRef extends StatelessWidget {
  const EtatChargementRef({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Flexible(
            child: Text(
              'Chargement des types…',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppCouleurs.texteSecondaire),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton de sélection de photo (taille compacte).
class _BoutonPhoto extends StatelessWidget {
  const _BoutonPhoto({
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

/// Une photo sélectionnée localement, avant téléversement.
class _PhotoBien {
  _PhotoBien(this.chemin, this.nom, this.image);

  final String chemin;
  final String nom;
  final bool image;
}
