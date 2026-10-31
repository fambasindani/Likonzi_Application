import 'package:flutter/material.dart';

import '../theme/couleurs.dart';

/// Aperçu « rôle(s) → permissions » utilisé à la création et à la modification
/// d'un compte : l'administrateur voit EXACTEMENT ce qu'il accorde.
class ApercuRoles extends StatelessWidget {
  const ApercuRoles({
    super.key,
    required this.rolesChoisis,
    required this.rolesDisponibles,
    this.compact = false,
  });

  /// Noms de rôles retenus (ex. `['policier', 'enqueteur']`).
  final List<String> rolesChoisis;

  /// Référentiel complet, chargé depuis `GET /roles` (nom + permissions).
  final List<Map<String, dynamic>> rolesDisponibles;

  /// Version réduite : uniquement le décompte des permissions.
  final bool compact;

  List<String> get _permissions {
    final codes = <String>{};
    for (final role in rolesDisponibles) {
      final nom = '${role['nom'] ?? ''}';
      if (!rolesChoisis.contains(nom)) continue;
      for (final p in (role['permissions'] as List? ?? const [])) {
        final code = (p is Map ? '${p['code'] ?? ''}' : '$p').trim();
        if (code.isNotEmpty) codes.add(code);
      }
    }
    return codes.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    if (rolesChoisis.isEmpty) {
      return const Text(
        'Aucun rôle sélectionné : le compte sera « citoyen » par défaut.',
        style: TextStyle(fontSize: 12.5, color: AppCouleurs.texteSecondaire),
      );
    }

    final permissions = _permissions;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppCouleurs.blancCasse,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in rolesChoisis)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppCouleurs.bleu,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    r,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppCouleurs.blanc,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${permissions.length} autorisation(s) accordée(s)',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppCouleurs.textePrimaire,
            ),
          ),
          if (!compact && permissions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 5,
              children: [
                for (final code in permissions.take(compact ? 0 : 14))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppCouleurs.blanc,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppCouleurs.bordure),
                    ),
                    child: Text(
                      code,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppCouleurs.texteSecondaire,
                      ),
                    ),
                  ),
                if (permissions.length > 14)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppCouleurs.bleuPastel,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+${permissions.length - 14}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppCouleurs.bleu,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
