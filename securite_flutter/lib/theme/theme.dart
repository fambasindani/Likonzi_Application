import 'package:flutter/material.dart';

import 'couleurs.dart';

/// Espacements, rayons et ombres — utilisés partout pour un rendu homogène.
class AppEspacements {
  AppEspacements._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: md, vertical: md);
  static const EdgeInsets carte = EdgeInsets.all(md);
  static const EdgeInsets compact = EdgeInsets.all(sm);

  static const BorderRadius rayonPetit = BorderRadius.all(Radius.circular(10));
  static const BorderRadius rayon = BorderRadius.all(Radius.circular(16));
  static const BorderRadius rayonGrand = BorderRadius.all(Radius.circular(24));
  static const BorderRadius pilule = BorderRadius.all(Radius.circular(999));

  static List<BoxShadow> ombreDouce = const [
    BoxShadow(color: AppCouleurs.ombre, blurRadius: 12, offset: Offset(0, 4)),
  ];
  static List<BoxShadow> ombreForte = const [
    BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 10)),
  ];
}

/// Thème global de l'application — primaire `#505FEE` (identique à l'app RN).
ThemeData construireTheme() {
  const primaire = AppCouleurs.bleu;

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaire,
      primary: primaire,
      secondary: AppCouleurs.vert,
      error: AppCouleurs.rouge,
      surface: AppCouleurs.blanc,
      onPrimary: AppCouleurs.blanc,
      onSurface: AppCouleurs.textePrimaire,
      outline: AppCouleurs.bordure,
    ),
    scaffoldBackgroundColor: AppCouleurs.fond,
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppCouleurs.blanc,
      foregroundColor: AppCouleurs.textePrimaire,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppCouleurs.textePrimaire,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(color: AppCouleurs.textePrimaire),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppCouleurs.textePrimaire,
      displayColor: AppCouleurs.textePrimaire,
    ).copyWith(
      headlineMedium: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: AppCouleurs.textePrimaire,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppCouleurs.textePrimaire,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppCouleurs.textePrimaire,
      ),
      bodyMedium: const TextStyle(fontSize: 15, height: 1.45, color: AppCouleurs.textePrimaire),
      bodySmall: const TextStyle(fontSize: 13, color: AppCouleurs.texteSecondaire),
      labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      color: AppCouleurs.blanc,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppEspacements.rayon,
        side: const BorderSide(color: AppCouleurs.bordure),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaire,
        foregroundColor: AppCouleurs.blanc,
        minimumSize: const Size.fromHeight(54),
        shape: const RoundedRectangleBorder(borderRadius: AppEspacements.rayon),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaire,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: primaire, width: 1.4),
        shape: const RoundedRectangleBorder(borderRadius: AppEspacements.rayon),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaire,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppCouleurs.blanc,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      hintStyle: const TextStyle(color: AppCouleurs.gris, fontSize: 15),
      labelStyle: const TextStyle(color: AppCouleurs.texteSecondaire, fontSize: 15),
      border: OutlineInputBorder(
        borderRadius: AppEspacements.rayon,
        borderSide: const BorderSide(color: AppCouleurs.bordure),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppEspacements.rayon,
        borderSide: const BorderSide(color: AppCouleurs.bordure),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppEspacements.rayon,
        borderSide: const BorderSide(color: primaire, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppEspacements.rayon,
        borderSide: const BorderSide(color: AppCouleurs.rouge),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppEspacements.rayon,
        borderSide: const BorderSide(color: AppCouleurs.rouge, width: 1.8),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppCouleurs.blancCasse,
      selectedColor: AppCouleurs.bleu,
      side: const BorderSide(color: AppCouleurs.bordure, width: 1.2),
      shape: const RoundedRectangleBorder(borderRadius: AppEspacements.pilule),
      // Couleur IMPOSEE : sans elle, le libellé devenait illisible sur fond clair.
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppCouleurs.textePrimaire,
      ),
      secondaryLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppCouleurs.blanc,
      ),
      checkmarkColor: AppCouleurs.blanc,
    ),
    dividerTheme: const DividerThemeData(color: AppCouleurs.bordure, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppCouleurs.textePrimaire,
      contentTextStyle: const TextStyle(color: AppCouleurs.blanc, fontSize: 14),
      shape: const RoundedRectangleBorder(borderRadius: AppEspacements.rayon),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppCouleurs.blanc,
      selectedItemColor: AppCouleurs.bleu,
      unselectedItemColor: AppCouleurs.grisBleu,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppCouleurs.bleu,
      foregroundColor: AppCouleurs.blanc,
      elevation: 6,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      iconColor: AppCouleurs.grisBleu,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppCouleurs.bleu,
      unselectedLabelColor: AppCouleurs.grisBleu,
      indicatorColor: AppCouleurs.bleu,
      dividerColor: AppCouleurs.bordure,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppCouleurs.bleu),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppCouleurs.blanc
            : AppCouleurs.gris,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppCouleurs.bleu
            : AppCouleurs.grisClaire,
      ),
    ),
  );
}
