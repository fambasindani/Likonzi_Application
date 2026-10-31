import 'package:flutter/material.dart';

import '../theme/couleurs.dart';
import '../theme/theme.dart';

/// Bouton plein — hauteur fixe, rayon `AppEspacements.rayon`.
class BoutonPrincipal extends StatelessWidget {
  const BoutonPrincipal({
    super.key,
    required this.texte,
    this.onPressed,
    this.icone,
    this.enCharge = false,
    this.largeur = double.infinity,
    this.couleur,
    this.couleurTexte,
  });

  final String texte;
  final VoidCallback? onPressed;
  final IconData? icone;
  final bool enCharge;
  final double largeur;
  final Color? couleur;
  final Color? couleurTexte;

  @override
  Widget build(BuildContext context) {
    final actif = onPressed != null && !enCharge;
    return SizedBox(
      width: largeur,
      child: FilledButton.icon(
        onPressed: actif ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: couleur ?? AppCouleurs.bleu,
          foregroundColor: couleurTexte ?? AppCouleurs.blanc,
          disabledBackgroundColor: AppCouleurs.grisClaire,
          disabledForegroundColor: AppCouleurs.blanc,
        ),
        icon: enCharge
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppCouleurs.blanc,
                ),
              )
            : (icone != null ? Icon(icone, size: 20) : const SizedBox.shrink()),
        label: Text(texte),
      ),
    );
  }
}

/// Bouton contour — même gabarit que le bouton principal.
class BoutonSecondaire extends StatelessWidget {
  const BoutonSecondaire({
    super.key,
    required this.texte,
    this.onPressed,
    this.icone,
    this.largeur = double.infinity,
  });

  final String texte;
  final VoidCallback? onPressed;
  final IconData? icone;
  final double largeur;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: largeur,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icone != null ? Icon(icone, size: 20) : const SizedBox.shrink(),
        label: Text(texte),
      ),
    );
  }
}

/// Lien d'action discret (« Mot de passe oublié ? »).
class BoutonTexte extends StatelessWidget {
  const BoutonTexte({super.key, required this.texte, this.onPressed, this.couleur});

  final String texte;
  final VoidCallback? onPressed;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(texte, style: TextStyle(color: couleur ?? AppCouleurs.bleu)),
    );
  }
}

/// Bouton circulaire surélevé (icône seule).
class BoutonRond extends StatelessWidget {
  const BoutonRond({
    super.key,
    required this.icone,
    this.onPressed,
    this.couleur = AppCouleurs.bleu,
    this.couleurIcone = AppCouleurs.blanc,
    this.taille = 48,
    this.infole,
  });

  final IconData icone;
  final VoidCallback? onPressed;
  final Color couleur;
  final Color couleurIcone;
  final double taille;
  final String? infole;

  @override
  Widget build(BuildContext context) {
    final bouton = Material(
      color: couleur,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: taille,
          height: taille,
          child: Icon(icone, color: couleurIcone, size: taille * 0.45),
        ),
      ),
    );
    if (infole == null) return bouton;
    return Tooltip(message: infole!, child: bouton);
  }
}

/// Groupe de boutons segmentés (ex. filtres « Toutes / Nouvelles / … »).
class Segment extends StatelessWidget {
  const Segment({
    super.key,
    required this.libelles,
    required this.selection,
    required this.onChanged,
    this.etendu = true,
  });

  final List<String> libelles;
  final int selection;
  final ValueChanged<int> onChanged;
  final bool etendu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppCouleurs.blancCasse,
        borderRadius: AppEspacements.pilule,
      ),
      child: Row(
        mainAxisAlignment: etendu ? MainAxisAlignment.spaceEvenly : MainAxisAlignment.start,
        children: [
          for (var i = 0; i < libelles.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                  decoration: BoxDecoration(
                    color: selection == i ? AppCouleurs.blanc : Colors.transparent,
                    borderRadius: AppEspacements.pilule,
                    boxShadow: selection == i ? AppEspacements.ombreDouce : null,
                  ),
                  child: Text(
                    libelles[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selection == i ? FontWeight.w700 : FontWeight.w500,
                      color: selection == i ? AppCouleurs.bleu : AppCouleurs.grisBleu,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
