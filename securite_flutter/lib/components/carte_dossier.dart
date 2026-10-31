import 'package:flutter/material.dart';

import '../models/dossier.dart';
import '../theme/couleurs.dart';
import '../utils/formatage.dart';
import 'badge.dart';
import 'carte_conteneur.dart';

/// Carte de dossier d'enquête.
class CarteDossier extends StatelessWidget {
  const CarteDossier({super.key, required this.dossier, this.onTap});

  final Dossier dossier;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CarteConteneur(
      onTap: onTap,
      enfant: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppCouleurs.bleuPastel,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.folder_special_outlined,
                    color: AppCouleurs.bleu, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Dossier.libelleType(dossier.typeCas),
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppCouleurs.textePrimaire,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dossier.numeroDossier,
                      style: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 0.3,
                        color: AppCouleurs.grisBleu,
                      ),
                    ),
                  ],
                ),
              ),
              BadgePriorite(priorite: dossier.priorite),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            dossier.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, height: 1.4, color: AppCouleurs.textePrimaire),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              BadgeStatut(statut: dossier.statut, compact: true),
              if (dossier.lieu != null && dossier.lieu!.isNotEmpty)
                BadgeSimple(
                  texte: dossier.lieu!,
                  icone: Icons.place_outlined,
                  compact: true,
                ),
              if (dossier.victime.isNotEmpty)
                BadgeSimple(
                  texte: dossier.victime,
                  icone: Icons.person_outline,
                  couleur: AppCouleurs.grisBleu,
                  fond: AppCouleurs.clair,
                  compact: true,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.event_available_outlined, size: 14, color: AppCouleurs.grisBleu),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  'Ouvert ${Formatage.relative(dossier.dateOuverture)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12.5, color: AppCouleurs.texteSecondaire),
                ),
              ),
              const Spacer(),
              if (dossier.nbInterventions != null || dossier.interventions.isNotEmpty) ...[
                const Icon(Icons.shield_outlined, size: 14, color: AppCouleurs.bleu),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${dossier.interventions.isNotEmpty ? dossier.interventions.length : dossier.nbInterventions} intervention(s)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppCouleurs.bleu,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
