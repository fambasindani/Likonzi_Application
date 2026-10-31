import 'package:flutter/material.dart';

import '../theme/couleurs.dart';

/// Confirmation en feuille du bas — retourne `true` si l'utilisateur valide.
Future<bool> confirmer(
  BuildContext context, {
  required String titre,
  required String message,
  String libelleValider = 'Confirmer',
  String libelleAnnuler = 'Annuler',
  bool destructif = false,
  IconData icone = Icons.help_outline,
}) async {
  final resultat = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: AppCouleurs.blanc,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppCouleurs.grisClaire,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: destructif
                      ? AppCouleurs.rougePastel
                      : AppCouleurs.bleuPastel,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icone,
                  color: destructif ? AppCouleurs.rouge : AppCouleurs.bleu,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  titre,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppCouleurs.textePrimaire,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: AppCouleurs.texteSecondaire,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(libelleAnnuler),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: destructif
                      ? FilledButton.styleFrom(
                          backgroundColor: AppCouleurs.rouge,
                          foregroundColor: AppCouleurs.blanc,
                        )
                      : null,
                  child: Text(libelleValider),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return resultat ?? false;
}

/// Message de succès / erreur rapide en bas d'écran.
void notifier(
  BuildContext context, {
  required String message,
  bool succes = true,
  Duration duree = const Duration(seconds: 3),
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duree,
        backgroundColor: succes ? AppCouleurs.textePrimaire : AppCouleurs.rouge,
        content: Row(
          children: [
            Icon(
              succes ? Icons.check_circle_outline : Icons.error_outline,
              color: AppCouleurs.blanc,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Feuille de partage d'informations (copier une référence, appeler…).
Future<void> feuilleActions(
  BuildContext context, {
  required String titre,
  required List<FeuilleAction> actions,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppCouleurs.blanc,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              titre,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          for (final action in actions)
            ListTile(
              leading: Icon(action.icone, color: AppCouleurs.bleu),
              title: Text(action.libelle, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: action.sousTitre != null
                  ? Text(action.sousTitre!, style: const TextStyle(fontSize: 13))
                  : null,
              onTap: () {
                Navigator.of(context).pop();
                action.onTap();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class FeuilleAction {
  const FeuilleAction({
    required this.icone,
    required this.libelle,
    required this.onTap,
    this.sousTitre,
  });

  final IconData icone;
  final String libelle;
  final String? sousTitre;
  final VoidCallback onTap;
}
