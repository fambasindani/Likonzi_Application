import 'package:flutter/material.dart';

import '../models/objet.dart';
import '../theme/couleurs.dart';
import '../utils/formatage.dart';
import '../utils/icone_objet.dart';
import 'badge.dart';
import 'carte_conteneur.dart';

/// Carte d'objet volé / recherché.
class CarteObjet extends StatelessWidget {
  const CarteObjet({super.key, required this.objet, this.onTap});

  final Objet objet;
  final VoidCallback? onTap;

  IconData get _iconeType => iconeTypeObjet(objet.typeCode);

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
                child: Icon(_iconeType, color: AppCouleurs.bleu, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      objet.designation,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppCouleurs.textePrimaire,
                      ),
                    ),
                    if (objet.typeLibelle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        objet.typeLibelle!,
                        style: const TextStyle(fontSize: 12.5, color: AppCouleurs.grisBleu),
                      ),
                    ],
                  ],
                ),
              ),
              BadgeStatut(statut: objet.statut, compact: true),
            ],
          ),
          if (objet.identifiantPrincipal != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppCouleurs.blancCasse,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.confirmation_number_outlined,
                      size: 16, color: AppCouleurs.grisBleu),
                  const SizedBox(width: 8),
                  Text(
                    objet.identifiantPrincipal!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: AppCouleurs.textePrimaire,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: AppCouleurs.grisBleu),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  objet.dateVol != null
                      ? 'Volé ${Formatage.relative(objet.dateVol)}'
                      : 'Date non renseignée',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12.5, color: AppCouleurs.texteSecondaire),
                ),
              ),
              const Spacer(),
              if (objet.lieuVol != null && objet.lieuVol!.isNotEmpty)
                Flexible(
                  child: Text(
                    objet.lieuVol!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: AppCouleurs.texteSecondaire),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
