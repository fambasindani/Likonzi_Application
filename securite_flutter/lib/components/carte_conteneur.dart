import 'package:flutter/material.dart';

import '../theme/couleurs.dart';
import '../theme/theme.dart';

/// Carte générique : contour, rayon, ombre légère, tap optionnel.
class CarteConteneur extends StatelessWidget {
  const CarteConteneur({
    super.key,
    required this.enfant,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.couleur = AppCouleurs.blanc,
    this.bordure,
    this.ombre = false,
    this.rouleau,
  });

  final Widget enfant;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color couleur;
  final Color? bordure;
  final bool ombre;
  final BorderRadius? rouleau;

  @override
  Widget build(BuildContext context) {
    final deco = BoxDecoration(
      color: couleur,
      borderRadius: rouleau ?? AppEspacements.rayon,
      border: Border.all(color: bordure ?? AppCouleurs.bordure),
      boxShadow: ombre ? AppEspacements.ombreDouce : null,
    );
    final contenu = Padding(padding: padding, child: enfant);
    if (onTap == null) return DecoratedBox(decoration: deco, child: contenu);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: rouleau ?? AppEspacements.rayon,
        onTap: onTap,
        child: DecoratedBox(decoration: deco, child: contenu),
      ),
    );
  }
}

/// Carte « titre + sous-titre + chevron » utilisée dans les listes.
class CarteLigne extends StatelessWidget {
  const CarteLigne({
    super.key,
    required this.titre,
    this.sousTitre,
    this.leading,
    this.trailling,
    this.onTap,
    this.couleurFond,
  });

  final String titre;
  final String? sousTitre;
  final Widget? leading;
  final Widget? trailling;
  final VoidCallback? onTap;
  final Color? couleurFond;

  @override
  Widget build(BuildContext context) {
    return CarteConteneur(
      onTap: onTap,
      couleur: couleurFond ?? AppCouleurs.blanc,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enfant: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppCouleurs.textePrimaire,
                  ),
                ),
                if (sousTitre != null && sousTitre!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    sousTitre!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppCouleurs.texteSecondaire,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailling != null) ...[const SizedBox(width: 8), trailling!],
        ],
      ),
    );
  }
}

/// Ligne clé/valeur (fiches détaillées).
class LigneInfo extends StatelessWidget {
  const LigneInfo({
    super.key,
    required this.cle,
    required this.valeur,
    this.icone,
    this.premiere = false,
  });

  final String cle;
  final String valeur;
  final IconData? icone;
  final bool premiere;

  @override
  Widget build(BuildContext context) {
    final vide = valeur.isEmpty || valeur == '—';
    return Padding(
      padding: EdgeInsets.only(top: premiere ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cle.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
              color: AppCouleurs.grisBleu,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icone != null) ...[
                Icon(icone, size: 16, color: AppCouleurs.bleu),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  valeur,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: vide ? AppCouleurs.gris : AppCouleurs.textePrimaire,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bandeau d'information coloré (alerte, conseil, erreur).
class BandeauInfo extends StatelessWidget {
  const BandeauInfo({
    super.key,
    required this.message,
    this.type = 'info',
    this.action,
    this.libelleAction,
  });

  final String message;
  final String type; // info | succes | attention | erreur
  final VoidCallback? action;
  final String? libelleAction;

  @override
  Widget build(BuildContext context) {
    final (fond, icone, couleur) = switch (type) {
      'succes' => (AppCouleurs.vertPastel, Icons.check_circle_outline, AppCouleurs.vert),
      'attention' => (AppCouleurs.orangePastel, Icons.warning_amber_outlined, AppCouleurs.orange),
      'erreur' => (AppCouleurs.rougePastel, Icons.error_outline, AppCouleurs.rouge),
      _ => (AppCouleurs.bleuPastel, Icons.info_outline, AppCouleurs.bleu),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: AppEspacements.rayon,
        border: Border.all(color: couleur.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: couleur),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13.5, height: 1.4, color: AppCouleurs.textePrimaire),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: action,
              child: Text(libelleAction ?? 'OK', style: TextStyle(color: couleur)),
            ),
        ],
      ),
    );
  }
}

/// Bandeau « lecture seule » : explique pourquoi une action est indisponible.
class BandeauInfoLectureSeule extends StatelessWidget {
  const BandeauInfoLectureSeule({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppCouleurs.orangePastel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppCouleurs.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, size: 17, color: AppCouleurs.orange),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12.5, height: 1.4))),
        ],
      ),
    );
  }
}
