import 'package:flutter/material.dart';

import '../models/social.dart';
import '../theme/couleurs.dart';
import '../utils/formatage.dart';
import 'carte_conteneur.dart';

/// Carte de notification (liste du centre de notifications).
class CarteNotification extends StatelessWidget {
  const CarteNotification({
    super.key,
    required this.notification,
    this.onTap,
    this.onToutMarquer,
  });

  final NotificationApp notification;
  final VoidCallback? onTap;
  final VoidCallback? onToutMarquer;

  Color get _couleur => switch (notification.type) {
        'alerte_creee' || 'alerte_assignee' => AppCouleurs.rouge,
        'alerte_resolue' => AppCouleurs.vert,
        'demande_ami' => AppCouleurs.bleu,
        'message' => AppCouleurs.bleu,
        'cas_maj' => AppCouleurs.orange,
        'objet_retrouve' => AppCouleurs.vert,
        _ => AppCouleurs.grisBleu,
      };

  IconData get _icone => switch (notification.cleIcone) {
        'person_add' => Icons.person_add_alt_1_outlined,
        'chat' => Icons.chat_bubble_outline,
        'notifications_active' => Icons.notifications_active_outlined,
        'folder_special' => Icons.folder_special_outlined,
        'search' => Icons.search,
        'attach_file' => Icons.attach_file,
        _ => Icons.info_outline,
      };

  @override
  Widget build(BuildContext context) {
    final nonLue = !notification.lu;
    return CarteConteneur(
      onTap: onTap,
      couleur: nonLue ? AppCouleurs.bleuPastel.withValues(alpha: 0.45) : AppCouleurs.blanc,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enfant: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _couleur.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_icone, size: 20, color: _couleur),
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
                        notification.titre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: nonLue ? FontWeight.w800 : FontWeight.w700,
                          color: AppCouleurs.textePrimaire,
                        ),
                      ),
                    ),
                    if (nonLue)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: const BoxDecoration(
                          color: AppCouleurs.bleu,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: AppCouleurs.texteSecondaire,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  Formatage.relative(notification.dateEnvoi),
                  style: const TextStyle(fontSize: 11.5, color: AppCouleurs.gris),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte de conversation (liste des amis / messages).
class CarteConversation extends StatelessWidget {
  const CarteConversation({
    super.key,
    required this.nom,
    required this.sousTitre,
    this.initiales,
    this.urlAvatar,
    this.nonLus = 0,
    this.heure,
    this.onTap,
    this.enLigne = false,
    this.trailing,
  });

  final String nom;
  final String sousTitre;
  final String? initiales;
  final String? urlAvatar;
  final int nonLus;
  final String? heure;
  final VoidCallback? onTap;
  final bool enLigne;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return CarteConteneur(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enfant: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppCouleurs.bleuPastel,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppCouleurs.bordure),
                ),
                alignment: Alignment.center,
                child: urlAvatar != null && urlAvatar!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          urlAvatar!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Text(
                            initiales ?? '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppCouleurs.bleu,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        initiales ?? '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppCouleurs.bleu,
                        ),
                      ),
              ),
              if (enLigne)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: AppCouleurs.vert,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppCouleurs.blanc, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppCouleurs.textePrimaire,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sousTitre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppCouleurs.texteSecondaire,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: 4),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (heure != null)
                Text(
                  heure!,
                  style: const TextStyle(fontSize: 11.5, color: AppCouleurs.gris),
                ),
              if (nonLus > 0) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppCouleurs.bleu,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$nonLus',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppCouleurs.blanc,
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
