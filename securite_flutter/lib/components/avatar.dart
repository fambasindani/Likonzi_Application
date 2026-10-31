import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/couleurs.dart';
import '../utils/formatage.dart';
import '../services/config_service.dart';

/// Avatar rond : image réseau (avec jeton implicite impossible → fallback),
/// fichier local, ou initiales sur fond coloré.
class AvatarUtilisateur extends StatelessWidget {
  const AvatarUtilisateur({
    super.key,
    this.url,
    this.cheminLocal,
    this.initiales,
    this.taille = 44,
    this.couleurFond,
    this.couleurTexte,
    this.bordure,
    this.onTap,
  });

  final String? url;
  final String? cheminLocal;
  final String? initiales;
  final double taille;
  final Color? couleurFond;
  final Color? couleurTexte;
  final Color? bordure;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fond = couleurFond ?? AppCouleurs.bleuPastel;
    final texte = couleurTexte ?? AppCouleurs.bleu;

    Widget contenu;

    final urlAbsolu = ConfigService.media(url);
    if (cheminLocal != null && cheminLocal!.isNotEmpty && File(cheminLocal!).existsSync()) {
      contenu = Image.file(File(cheminLocal!), fit: BoxFit.cover);
    } else if (urlAbsolu.isNotEmpty && !urlAbsolu.startsWith('assets/')) {
      contenu = Image.network(
        urlAbsolu,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _initiales(fond, texte),
        loadingBuilder: (context, child, progression) {
          if (progression == null) return child;
          return Center(
            child: SizedBox(
              width: taille * 0.4,
              height: taille * 0.4,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(texte),
              ),
            ),
          );
        },
      );
    } else if (urlAbsolu.startsWith('assets/')) {
      contenu = Image.asset(urlAbsolu, fit: BoxFit.cover);
    } else {
      contenu = _initiales(fond, texte);
    }

    final cercle = Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        color: fond,
        shape: BoxShape.circle,
        border: bordure != null ? Border.all(color: bordure!, width: 2) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: contenu,
    );

    if (onTap == null) return cercle;
    return InkWell(customBorder: const CircleBorder(), onTap: onTap, child: cercle);
  }

  Widget _initiales(Color fond, Color texte) {
    return Center(
      child: Text(
        initiales ?? '?',
        style: TextStyle(
          color: texte,
          fontWeight: FontWeight.w800,
          fontSize: (taille * 0.36).clamp(10, 32),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Avatar à partir d'un nom/prénom.
  factory AvatarUtilisateur.noms({
    Key? key,
    required String? nom,
    required String? prenom,
    String? url,
    double taille = 44,
  }) {
    return AvatarUtilisateur(
      key: key,
      url: url,
      initiales: Formatage.initiales(nom, prenom),
      taille: taille,
    );
  }
}

/// Icône de domaine (alerte, dossier, objet…) dans un carré arrondi.
class IconeDomaine extends StatelessWidget {
  const IconeDomaine({
    super.key,
    required this.icone,
    this.couleur = AppCouleurs.bleu,
    this.fond,
    this.taille = 42,
    this.tailleIcone = 22,
  });

  final IconData icone;
  final Color couleur;
  final Color? fond;
  final double taille;
  final double tailleIcone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        color: fond ?? couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icone, color: couleur, size: tailleIcone),
    );
  }
}
