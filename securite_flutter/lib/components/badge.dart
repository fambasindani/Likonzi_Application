import 'package:flutter/material.dart';

import '../theme/couleurs.dart';

/// Pastille d'urgence (faible / moyen / élevé / critique).
class BadgeUrgence extends StatelessWidget {
  const BadgeUrgence({super.key, required this.niveau, this.compact = false});

  final String niveau;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final couleur = AppCouleurs.urgence(niveau);
    final fond = AppCouleurs.urgenceFond(niveau);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: couleur.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: compact ? 12 : 14, color: couleur),
          const SizedBox(width: 4),
          Text(
            AppCouleurs.libelle(niveau),
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille de statut générique (alerte, dossier, objet, demande).
class BadgeStatut extends StatelessWidget {
  const BadgeStatut({super.key, required this.statut, this.libelle, this.compact = false});

  final String statut;
  final String? libelle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final couleur = AppCouleurs.statut(statut);
    final fond = AppCouleurs.statutFond(statut);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: couleur.withValues(alpha: 0.45)),
      ),
      child: Text(
        libelle ?? AppCouleurs.libelle(statut),
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
          color: couleur.withValues(alpha: 1.0) == couleur ? couleur : couleur,
        ),
      ),
    );
  }
}

/// Pastille neutre (type de dossier, catégorie…).
class BadgeSimple extends StatelessWidget {
  const BadgeSimple({
    super.key,
    required this.texte,
    this.couleur = AppCouleurs.bleu,
    this.fond,
    this.icone,
    this.compact = false,
  });

  final String texte;
  final Color couleur;
  final Color? fond;
  final IconData? icone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: fond ?? AppCouleurs.bleuPastel,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: compact ? 12 : 14, color: couleur),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              texte,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: couleur,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge compteur (onglets, boutons de la barre de navigation).
class BadgeCompteur extends StatelessWidget {
  const BadgeCompteur({super.key, required this.valeur, this.enfant, this.couleur});

  final int valeur;
  final Widget? enfant;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        enfant ?? const SizedBox(),
        if (valeur > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: couleur ?? AppCouleurs.rouge,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppCouleurs.blanc, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                valeur > 99 ? '99+' : '$valeur',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppCouleurs.blanc,
                  height: 1.2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Étiquette de priorité (dossier).
class BadgePriorite extends StatelessWidget {
  const BadgePriorite({super.key, required this.priorite});

  final String priorite;

  @override
  Widget build(BuildContext context) {
    return switch (priorite) {
      'critique' => const BadgeSimple(
          texte: 'Critique',
          couleur: AppCouleurs.rouge,
          fond: AppCouleurs.rougePastel,
          icone: Icons.priority_high,
        ),
      'haute' => const BadgeSimple(
          texte: 'Haute',
          couleur: AppCouleurs.orange,
          fond: AppCouleurs.orangePastel,
          icone: Icons.arrow_upward,
        ),
      'basse' => const BadgeSimple(
          texte: 'Basse',
          couleur: AppCouleurs.vert,
          fond: AppCouleurs.vertPastel,
          icone: Icons.arrow_downward,
        ),
      _ => const BadgeSimple(texte: 'Normale'),
    };
  }
}
