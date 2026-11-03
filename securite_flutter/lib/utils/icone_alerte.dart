import 'package:flutter/material.dart';

/// Icône Material correspondant à un type d'alerte.
///
/// Miroir des codes `typealertes` du backend (DANGER, KULUNA, AGRESSION…).
IconData iconeTypeAlerte(String? code) {
  switch (code) {
    case 'DANGER':
      return Icons.dangerous_outlined;
    case 'KULUNA':
      return Icons.mood_bad_outlined;
    case 'AGRESSION':
      return Icons.g_mobiledata;
    case 'ENLEVEMENT':
      return Icons.person_off_outlined;
    case 'VOL':
      return Icons.inventory_2_outlined;
    case 'INCENDIE':
      return Icons.local_fire_department_outlined;
    case 'ACCIDENT':
      return Icons.car_crash_outlined;
    case 'HOSPITALISATION':
      return Icons.local_hospital_outlined;
    case 'VIOLENCE_FEMME':
      return Icons.female_outlined;
    case 'AUTRE':
      return Icons.help_outline;
    default:
      return Icons.notifications_active_outlined;
  }
}
