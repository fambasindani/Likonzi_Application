import 'package:flutter/material.dart';

import '../theme/couleurs.dart';

/// Une option d'un sélecteur.
class OptionSelecteur<T> {
  const OptionSelecteur({required this.valeur, required this.libelle, this.icone});

  final T valeur;
  final String libelle;
  final IconData? icone;
}

/// Liste déroulante stylée (Material 3 `DropdownButtonFormField`).
class Selecteur<T> extends StatelessWidget {
  const Selecteur({
    super.key,
    required this.libelle,
    required this.options,
    required this.valeur,
    required this.onChanged,
    this.hint = 'Sélectionnez…',
    this.icone,
    this.requis = false,
    this.erreur,
    this.actif = true,
    this.texteVide = '—',
  });

  final String libelle;
  final List<OptionSelecteur<T>> options;
  final T? valeur;
  final ValueChanged<T?> onChanged;
  final String hint;
  final IconData? icone;
  final bool requis;
  final String? erreur;
  final bool actif;
  final String texteVide;

  OptionSelecteur<T>? get _optionCourante {
    for (final o in options) {
      if (o.valeur == valeur) return o;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final courante = _optionCourante;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 2,
          children: [
            Text(
              libelle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppCouleurs.textePrimaire,
              ),
            ),
            if (requis)
              const Text(' *', style: TextStyle(color: AppCouleurs.rouge, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: valeur,
          isExpanded: true,
          onChanged: actif ? onChanged : null,
          style: const TextStyle(
            fontSize: 15,
            color: AppCouleurs.textePrimaire,
            fontWeight: FontWeight.w500,
          ),
          dropdownColor: AppCouleurs.blanc,
          icon: const Icon(Icons.expand_more, color: AppCouleurs.grisBleu),
          decoration: InputDecoration(
            hintText: hint,
            errorText: erreur,
            prefixIcon: icone != null
                ? Icon(icone, size: 20, color: AppCouleurs.grisBleu)
                : null,
            suffixIcon: options.isEmpty
                ? const Tooltip(
                    message: 'Aucune option disponible',
                    child: Icon(Icons.info_outline, size: 18, color: AppCouleurs.gris),
                  )
                : null,
          ),
          items: options
              .map(
                (o) => DropdownMenuItem<T>(
                  value: o.valeur,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (o.icone != null) ...[
                        Icon(o.icone, size: 18, color: AppCouleurs.bleu),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(o.libelle, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
          validator: (valeur) {
            if (!requis) return null;
            if (valeur == null) return 'Sélectionnez une valeur.';
            return null;
          },
          selectedItemBuilder: (context) => options
              .map(
                (o) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    o.libelle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        if (courante == null && options.isNotEmpty && valeur == null)
          const SizedBox(height: 4),
      ],
    );
  }
}
