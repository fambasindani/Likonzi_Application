import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alerte.dart';
import '../providers/auth_provider.dart';
import '../theme/couleurs.dart';
import '../utils/formatage.dart';
import 'avatar.dart';
import 'badge.dart';
import 'carte_conteneur.dart';

/// Carte d'alerte utilisée dans les listes (citoyen comme policier).
class CarteAlerte extends StatelessWidget {
  const CarteAlerte({
    super.key,
    required this.alerte,
    this.onTap,
    this.distanceKm,
    this.afficherEmetteur = false,
    this.action,
    this.libelleAction,
  });

  final Alerte alerte;
  final VoidCallback? onTap;
  final double? distanceKm;
  final bool afficherEmetteur;
  final VoidCallback? action;
  final String? libelleAction;

  IconData get _iconeType => switch (alerte.typeCode ?? '') {
        'DANGER' => Icons.dangerous_outlined,
        'KULUNA' => Icons.mood_bad_outlined,
        'AGRESSION' => Icons.g_mobiledata,
        'ENLEVEMENT' => Icons.person_off_outlined,
        'VOL' => Icons.inventory_2_outlined,
        'INCENDIE' => Icons.local_fire_department_outlined,
        'ACCIDENT' => Icons.car_crash_outlined,
        'HOSPITALISATION' => Icons.local_hospital_outlined,
        'VIOLENCE_FEMME' => Icons.female_outlined,
        'AUTRE' => Icons.help_outline,
        _ => Icons.notifications_active_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final urgence = AppCouleurs.urgence(alerte.niveauUrgence);
    // Alerte reçue d'un contact : badge « Ami » (jamais sur ses propres alertes).
    final moiId = context.watch<AuthProvider>().utilisateur?.id;
    final alerteAmi =
        !afficherEmetteur && alerte.emetteurId != null && alerte.emetteurId != moiId;
    return CarteConteneur(
      onTap: onTap,
      bordure: alerte.estNouvelle ? urgence.withValues(alpha: 0.55) : AppCouleurs.bordure,
      enfant: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconeDomaine(
                icone: _iconeType,
                couleur: urgence,
                fond: AppCouleurs.urgenceFond(alerte.niveauUrgence),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alerte.typeLibelle ?? 'Alerte',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AppCouleurs.textePrimaire,
                            ),
                          ),
                        ),
                        if (distanceKm != null)
                          Text(
                            Formatage.distance(distanceKm!),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppCouleurs.bleu,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alerte.reference,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppCouleurs.grisBleu,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            alerte.contenu,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppCouleurs.textePrimaire,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              BadgeUrgence(niveau: alerte.niveauUrgence, compact: true),
              BadgeStatut(statut: alerte.statut, compact: true),
              if (alerteAmi)
                const BadgeSimple(
                  texte: 'Ami',
                  icone: Icons.people_outline,
                  compact: true,
                ),
              if (alerte.adressePrecise != null && alerte.adressePrecise!.isNotEmpty)
                BadgeSimple(
                  texte: alerte.adressePrecise!,
                  icone: Icons.place_outlined,
                  compact: true,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (afficherEmetteur && alerte.emetteur.isNotEmpty) ...[
                AvatarUtilisateur.noms(
                  nom: alerte.emetteurNom,
                  prenom: alerte.emetteurPrenom,
                  taille: 26,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    alerte.emetteur,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: AppCouleurs.texteSecondaire),
                  ),
                ),
              ] else ...[
                const Icon(Icons.schedule, size: 14, color: AppCouleurs.grisBleu),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    Formatage.relative(alerte.dateAlerte),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppCouleurs.texteSecondaire),
                  ),
                ),
              ],
              const Spacer(),
              if (alerte.assignee)
                Tooltip(
                  message: 'Assignée à ${alerte.policier}',
                  child: const Icon(Icons.shield_outlined, size: 16, color: AppCouleurs.bleu),
                ),
              if (action != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: action,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 34),
                    backgroundColor: AppCouleurs.bleuPastel,
                  ),
                  child: Text(
                    libelleAction ?? 'Ouvrir',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
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
