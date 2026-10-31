import 'package:flutter/material.dart';

import '../theme/couleurs.dart';
import '../utils/formatage.dart';

/// Champ de date en lecture seule ouvrant le sélecteur Material.
class SelecteurDate extends StatelessWidget {
  const SelecteurDate({
    super.key,
    required this.libelle,
    required this.valeur,
    required this.onChanged,
    this.icone = Icons.calendar_today_outlined,
    this.requis = false,
    this.erreur,
    this.minimum,
    this.maximum,
    this.hint = 'Sélectionnez une date',
    this.formatCourt = true,
  });

  final String libelle;
  final DateTime? valeur;
  final ValueChanged<DateTime?> onChanged;
  final IconData icone;
  final bool requis;
  final String? erreur;
  final DateTime? minimum;
  final DateTime? maximum;
  final String hint;
  final bool formatCourt;

  Future<void> _ouvrir(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: valeur ?? (maximum ?? DateTime.now()),
      firstDate: minimum ?? DateTime(1900),
      lastDate: maximum ?? DateTime(2100),
      helpText: libelle.toUpperCase(),
      cancelText: 'Annuler',
      confirmText: 'Valider',
      locale: const Locale('fr'),
    );
    if (date != null) onChanged(date);
  }

  @override
  Widget build(BuildContext context) {
    final texte = valeur == null
        ? hint
        : (formatCourt ? Formatage.date(valeur) : Formatage.dateLongue(valeur));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                libelle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppCouleurs.textePrimaire,
                ),
              ),
            ),
            if (requis)
              const Text(' *', style: TextStyle(color: AppCouleurs.rouge, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _ouvrir(context),
          borderRadius: BorderRadius.circular(16),
          child: InputDecorator(
            decoration: InputDecoration(
              hintText: hint,
              errorText: erreur,
              prefixIcon: Icon(icone, size: 20, color: AppCouleurs.grisBleu),
              suffixIcon: const Icon(Icons.arrow_drop_down, color: AppCouleurs.grisBleu),
            ),
            child: Text(
              texte,
              style: TextStyle(
                fontSize: 15,
                color: valeur == null ? AppCouleurs.gris : AppCouleurs.textePrimaire,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Champ date + heure (interventions, faits).
class SelecteurDateHeure extends StatelessWidget {
  const SelecteurDateHeure({
    super.key,
    required this.libelle,
    required this.valeur,
    required this.onChanged,
    this.requis = false,
    this.erreur,
    this.icone = Icons.event_outlined,
  });

  final String libelle;
  final DateTime? valeur;
  final ValueChanged<DateTime?> onChanged;
  final bool requis;
  final String? erreur;
  final IconData icone;

  Future<void> _ouvrir(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: valeur ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      cancelText: 'Annuler',
      confirmText: 'Suivant',
    );
    if (date == null || !context.mounted) return;
    final heure = await showTimePicker(
      context: context,
      initialTime: valeur != null
          ? TimeOfDay.fromDateTime(valeur!)
          : TimeOfDay.now(),
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );
    if (heure == null) return;
    onChanged(DateTime(date.year, date.month, date.day, heure.hour, heure.minute));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                libelle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppCouleurs.textePrimaire,
                ),
              ),
            ),
            if (requis)
              const Text(' *', style: TextStyle(color: AppCouleurs.rouge, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _ouvrir(context),
          borderRadius: BorderRadius.circular(16),
          child: InputDecorator(
            decoration: InputDecoration(
              hintText: 'Sélectionnez date et heure',
              errorText: erreur,
              prefixIcon: Icon(icone, size: 20, color: AppCouleurs.grisBleu),
            ),
            child: Text(
              valeur == null
                  ? 'Sélectionnez date et heure'
                  : Formatage.dateTime(valeur),
              style: TextStyle(
                fontSize: 15,
                color: valeur == null ? AppCouleurs.gris : AppCouleurs.textePrimaire,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
