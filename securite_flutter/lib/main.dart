import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/alerte_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/carte_provider.dart';
import 'providers/social_provider.dart';
import 'services/config_service.dart';
import 'theme/theme.dart';
import 'views/shell_view.dart';
import 'views/splash_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuration 100 % pilotée par `.env` (aucun secret embarqué).
  await ConfigService.charger();
  await initializeDateFormatting('fr_FR');

  runApp(const AppSecurite());
}

class AppSecurite extends StatelessWidget {
  const AppSecurite({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AlerteProvider()),
        ChangeNotifierProvider(create: (_) => SocialProvider()),
        ChangeNotifierProvider(create: (_) => CarteProvider()),
      ],
      child: MaterialApp(
        title: ConfigService.nomApp,
        debugShowCheckedModeBanner: false,
        theme: construireTheme(),
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Android 15+ impose le mode « edge-to-edge » : la barre de
        // navigation système recouvre le bas de l'écran. Ce SafeArea global
        // écarte TOUT le contenu (boutons, cartes, FAB) de cet espace.
        // SafeArea retire le padding pour ses descendants : les écrans qui ont
        // déjà leur propre SafeArea ne sont pas doublés.
        // Le ColoredBox peint la bande ainsi découverte avec la couleur de
        // fond de l'application : sans elle, cette bande montrait le blanc
        // du système et l'écran semblait coupé en deux au démarrage.
        builder: (context, child) => ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            top: false,
            bottom: true,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: const VueDemarrage(),
        routes: {ShellView.chemin: (_) => const ShellView()},
      ),
    );
  }
}
