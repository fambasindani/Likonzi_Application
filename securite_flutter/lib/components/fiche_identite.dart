import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/couleurs.dart';
import 'avatar.dart';

/// Fiche d'identité détaillée : **grande photo**, nom complet (nom + postnom +
/// prénom), fonction et téléphone avec appel direct.
///
/// Utilisée quand un ami consulte mon alerte ou mon objet déclaré : il voit
/// clairement qui a publié.
class FicheIdentite extends StatelessWidget {
  const FicheIdentite({
    super.key,
    required this.libelle,
    this.nom,
    this.postnom,
    this.prenom,
    this.fonction,
    this.telephone,
    this.avatar,
    this.accent = AppCouleurs.bleu,
    this.photoTaille = 96,
  });

  final String libelle;
  final String? nom;
  final String? postnom;
  final String? prenom;
  final String? fonction;
  final String? telephone;
  final String? avatar;
  final Color accent;
  final double photoTaille;

  String get _nomComplet => [nom, postnom, prenom]
      .where((e) => e != null && e.trim().isNotEmpty)
      .join(' ');

  String get _numero => (telephone ?? '').replaceAll(RegExp(r'[^\d+]'), '');

  Future<void> _appeler() async {
    if (_numero.isEmpty) return;
    try {
      await launchUrl(Uri(scheme: 'tel', path: _numero));
    } catch (_) {
      // Aucune application d'appel sur l'appareil.
    }
  }

  @override
  Widget build(BuildContext context) {
    final fonctionOk = fonction != null && fonction!.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppCouleurs.blanc,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        boxShadow: const [
          BoxShadow(color: AppCouleurs.ombre, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarUtilisateur.noms(
            nom: nom,
            prenom: prenom,
            url: avatar,
            taille: photoTaille,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  libelle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _nomComplet.isEmpty ? '—' : _nomComplet,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: AppCouleurs.textePrimaire,
                  ),
                ),
                if (fonctionOk) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.badge_outlined, size: 15, color: AppCouleurs.grisBleu),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          fonction!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppCouleurs.texteSecondaire,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_numero.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 15, color: AppCouleurs.grisBleu),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          telephone!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppCouleurs.texteSecondaire,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _appeler,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppCouleurs.vert,
                        foregroundColor: AppCouleurs.textePrimaire,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      icon: const Icon(Icons.call_outlined, size: 18),
                      label: const Text(
                        'Appeler',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
