import 'package:flutter/material.dart';

/// Icône Material correspondant à un type d'objet déclaré.
///
/// Miroir des codes `type_objets` du backend (MOTO, VOITURE, TELEPHONE…).
/// Utilisée partout où un objet apparaît : liste, détail, création, partages.
IconData iconeTypeObjet(String? code) {
  switch (code) {
    case 'MOTO':
      return Icons.motorcycle_outlined;
    case 'VOITURE':
      return Icons.directions_car_outlined;
    case 'ORDINATEUR':
      return Icons.laptop_mac_outlined;
    case 'TELEPHONE':
      return Icons.phone_iphone_outlined;
    case 'VELO':
      return Icons.pedal_bike_outlined;
    case 'BIJOUX':
      return Icons.diamond_outlined;
    case 'DOCUMENT':
      return Icons.description_outlined;
    case 'ELECTROMENAGER':
      return Icons.kitchen_outlined;
    default: // AUTRE et types futurs
      return Icons.inventory_2_outlined;
  }
}
