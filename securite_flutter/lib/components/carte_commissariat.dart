import 'package:flutter/material.dart';

import '../../models/geographie.dart';
import '../../theme/couleurs.dart';
import '../../utils/formatage.dart';
import 'badge.dart';
import 'bouton.dart';
import 'carte_conteneur.dart';
import 'avatar.dart';

/// Fiche d'un commissariat : identité, adresse, distance, appeler / itinéraire.
///
/// Extrait dans un composant public pour être testable (débordements) hors réseau.
class CarteCommissariat extends StatelessWidget {
  const CarteCommissariat({
    super.key,
    required this.commissariat,
    required this.onAppeler,
    required this.onItineraire,
  });

  final Commissariat commissariat;
  final VoidCallback onAppeler;
  final VoidCallback onItineraire;

  @override
  Widget build(BuildContext context) {
    final c = commissariat;
    return CarteConteneur(
      enfant: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconeDomaine(
                icone: Icons.local_police_outlined,
                couleur: AppCouleurs.bleu,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.nom,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      c.code,
                      style: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 0.4,
                        color: AppCouleurs.grisBleu,
                      ),
                    ),
                  ],
                ),
              ),
              if (c.distanceKm != null)
                Flexible(
                  child: BadgeSimple(
                    texte: Formatage.distance(c.distanceKm!),
                    icone: Icons.near_me_outlined,
                  ),
                ),
            ],
          ),
          if (c.adresse != null && c.adresse!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place_outlined, size: 15, color: AppCouleurs.grisBleu),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      c.adresse!,
                      style: const TextStyle(fontSize: 13.5, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          if (c.commune != null || c.ville != null || c.province != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                [c.commune, c.ville, c.province]
                    .where((e) => e != null && e.isNotEmpty)
                    .join(' — '),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppCouleurs.texteSecondaire,
                ),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: BoutonSecondaire(
                  texte: 'Appeler',
                  icone: Icons.call_outlined,
                  onPressed: onAppeler,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BoutonSecondaire(
                  texte: 'Itinéraire',
                  icone: Icons.directions_outlined,
                  onPressed: onItineraire,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
