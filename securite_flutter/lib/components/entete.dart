import 'package:flutter/material.dart';

import '../theme/couleurs.dart';

/// Barre d'application standard avec retour automatique.
class EntetePage extends StatelessWidget implements PreferredSizeWidget {
  const EntetePage({
    super.key,
    required this.titre,
    this.sousTitre,
    this.actions = const [],
    this.metreEnAvant = false,
    this.retourAuto = true,
    this.couleurFond,
    this.icone,
  });

  final String titre;
  final String? sousTitre;
  final List<Widget> actions;

  /// true → titre centré (style Material classique).
  final bool metreEnAvant;
  final bool retourAuto;
  final Color? couleurFond;
  final IconData? icone;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final peutRevenir = retourAuto && Navigator.of(context).canPop();
    return AppBar(
      backgroundColor: couleurFond ?? AppCouleurs.blanc,
      automaticallyImplyLeading: peutRevenir,
      titleSpacing: peutRevenir ? 0 : 16,
      centerTitle: metreEnAvant,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 22, color: AppCouleurs.bleu),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: metreEnAvant ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppCouleurs.textePrimaire,
                  ),
                ),
                if (sousTitre != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    sousTitre!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppCouleurs.texteSecondaire,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      actions: actions,
      elevation: 0,
      scrolledUnderElevation: 1,
    );
  }
}

/// Grande bannière d'accueil (titre + message + dégradé).
class BanniereAccueil extends StatelessWidget {
  const BanniereAccueil({
    super.key,
    required this.titre,
    required this.message,
    this.sousTitre,
    this.elevee,
    this.actions = const [],
  });

  final String titre;
  final String message;

  /// Ligne d'état sous le message (ex. « Position activée »).
  final String? sousTitre;
  final Widget? elevee;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppCouleurs.bleu, AppCouleurs.bleuNuit],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppCouleurs.blanc,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppCouleurs.blanc.withValues(alpha: 0.9),
                      ),
                    ),
                    if (sousTitre != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: AppCouleurs.blanc.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              sousTitre!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppCouleurs.blanc.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              ...actions.map((a) => Padding(padding: const EdgeInsets.only(left: 8), child: a)),
            ],
          ),
          if (elevee != null) ...[const SizedBox(height: 16), elevee!],
        ],
      ),
    );
  }
}
