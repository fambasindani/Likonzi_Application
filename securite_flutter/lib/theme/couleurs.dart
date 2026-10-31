import 'package:flutter/material.dart';

/// Palette reprise à l'identique de `securite/Couleurs/COLORS.js`
/// afin de conserver l'identité visuelle de l'application d'origine.
class AppCouleurs {
  AppCouleurs._();

  // ------------------------------------------------------------------ d'origine
  static const Color blanc = Color(0xFFFFFFFF);
  static const Color noir = Color(0xFF000000);
  static const Color bleu = Color(0xFF505FEE); // couleur primaire
  static const Color clair = Color(0xFFF3F4FB);
  static const Color gris = Color(0xFFBABBC2);
  static const Color grisBleu = Color(0xFF797885); // « darblue »
  static const Color rouge = Color(0xFFFF0000); // « red »
  static const Color vert = Color(0xFF47D9AF);
  static const Color jaune = Color(0xFFFFDB58);
  static const Color blancCasse = Color(0xFFF0F2F5);
  static const Color grisClaire = Color(0xFFCCCCCC);
  static const Color beige = Color(0xFFF5F5DC);

  // ------------------------------------------------- dérivées (garde-fou UI)
  static const Color bleuFonce = Color(0xFF3A47C4);
  static const Color bleuNuit = Color(0xFF2B348C);
  static const Color bleuPastel = Color(0xFFE4E7FC);
  static const Color fond = Color(0xFFF7F8FC);

  /// Orange : indispensable pour les niveaux d'urgence intermédiaires.
  static const Color orange = Color(0xFFFF8A3D);
  static const Color orangePastel = Color(0xFFFFF0E4);

  static const Color rougePastel = Color(0xFFFFE6E6);
  static const Color vertPastel = Color(0xFFDFF7EF);
  static const Color jaunePastel = Color(0xFFFFF8DC);

  static const Color textePrimaire = Color(0xFF1B1D28);
  static const Color texteSecondaire = Color(0xFF6B6E7E);
  static const Color texteInverse = Color(0xFFFFFFFF);

  static const Color bordure = Color(0xFFE6E8F0);
  static const Color ombre = Color(0x14000000);

  // --------------------------------------------------- niveaux d'urgence
  static Color urgence(String niveau) {
    switch (niveau.toLowerCase()) {
      case 'critique':
        return rouge;
      case 'eleve':
        return orange;
      case 'moyen':
        return jaune;
      case 'faible':
        return vert;
      default:
        return gris;
    }
  }

  static Color urgenceFond(String niveau) {
    switch (niveau.toLowerCase()) {
      case 'critique':
        return rougePastel;
      case 'eleve':
        return orangePastel;
      case 'moyen':
        return jaunePastel;
      case 'faible':
        return vertPastel;
      default:
        return clair;
    }
  }

  // --------------------------------------------------- statuts métier
  static Color statut(String statut) {
    switch (statut.toLowerCase()) {
      case 'nouvelle':
        return rouge;
      case 'prise_en_compte':
      case 'en_cours':
        return orange;
      case 'ouvert':
      case 'en_attente':
        return jaune;
      case 'resolue':
      case 'clos':
      case 'retrouve':
      case 'restitue':
        return vert;
      case 'classe':
      case 'fausse_alerte':
        return gris;
      case 'declare_vol':
      case 'recherche':
        return orange;
      default:
        return gris;
    }
  }

  static Color statutFond(String valeur) {
    final couleur = statut(valeur);
    if (couleur == rouge) return rougePastel;
    if (couleur == orange) return orangePastel;
    if (couleur == jaune) return jaunePastel;
    if (couleur == vert) return vertPastel;
    return clair;
  }

  /// Libellé français d'un statut brut renvoyé par l'API.
  static String libelle(String brut) {
    switch (brut.toLowerCase()) {
      case 'nouvelle':
        return 'Nouvelle';
      case 'prise_en_compte':
        return 'Prise en charge';
      case 'en_cours':
        return 'En cours';
      case 'resolue':
        return 'Résolue';
      case 'classe':
        return 'Classée';
      case 'fausse_alerte':
        return 'Fausse alerte';
      case 'ouvert':
        return 'Ouvert';
      case 'en_attente':
        return 'En attente';
      case 'clos':
        return 'Clos';
      case 'declare_vol':
        return 'Déclaré volé';
      case 'recherche':
        return 'Recherché';
      case 'retrouve':
        return 'Retrouvé';
      case 'restitue':
        return 'Restitué';
      case 'en_fourriere':
        return 'En fourrière';
      case 'critique':
        return 'Critique';
      case 'eleve':
        return 'Élevé';
      case 'moyen':
        return 'Moyen';
      case 'faible':
        return 'Faible';
      case 'acceptee':
        return 'Acceptée';
      case 'refusee':
        return 'Refusée';
      case 'annulee':
        return 'Annulée';
      case 'en_attente_demande':
        return 'En attente';
      default:
        return brut;
    }
  }
}
