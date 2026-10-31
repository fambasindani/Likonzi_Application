import 'package:flutter/material.dart';

import '../theme/couleurs.dart';

/// Puce de filtre à contrastes explicites.
///
/// `ChoiceChip`/`FilterChip` héritaient d'un thème dont la couleur de texte
/// devenait illisible sur fond clair : ici, couleurs et libellés sont
/// imposés (blanc sur bleu quand c'est sélectionné, gris foncé sinon).
class PuceFiltre extends StatelessWidget {
  const PuceFiltre({
    super.key,
    required this.libelle,
    required this.selectionnee,
    required this.onChanged,
    this.icone,
    this.compteur,
  });

  final String libelle;
  final bool selectionnee;
  final ValueChanged<bool> onChanged;
  final IconData? icone;
  final int? compteur;

  @override
  Widget build(BuildContext context) {
    final couleurTexte = selectionnee ? AppCouleurs.blanc : AppCouleurs.textePrimaire;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(!selectionnee),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selectionnee ? AppCouleurs.bleu : AppCouleurs.blanc,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selectionnee ? AppCouleurs.bleu : AppCouleurs.bordure,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectionnee) ...[
                const Icon(Icons.check_circle, size: 14, color: AppCouleurs.blanc),
                const SizedBox(width: 5),
              ] else if (icone != null) ...[
                Icon(icone, size: 14, color: AppCouleurs.grisBleu),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  libelle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: couleurTexte,
                  ),
                ),
              ),
              if (compteur != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selectionnee
                        ? Colors.white.withValues(alpha: 0.25)
                        : AppCouleurs.bleuPastel,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$compteur',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: selectionnee ? AppCouleurs.blanc : AppCouleurs.bleu,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Groupe horizontal défilant de puces.
class GroupePuces extends StatelessWidget {
  const GroupePuces({super.key, required this.enfants});

  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 3),
        children: [
          for (final e in enfants) ...[
            e,
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
