import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:likonzi/components/bouton.dart';
import 'package:likonzi/components/carte_alerte.dart';
import 'package:likonzi/components/carte_commissariat.dart';
import 'package:likonzi/components/carte_dossier.dart';
import 'package:likonzi/components/carte_notification.dart';
import 'package:likonzi/components/carte_objet.dart';
import 'package:likonzi/models/alerte.dart';
import 'package:likonzi/models/dossier.dart';
import 'package:likonzi/models/geographie.dart';
import 'package:likonzi/models/objet.dart';
import 'package:likonzi/models/social.dart';
import 'package:likonzi/models/utilisateur.dart';
import 'package:likonzi/providers/alerte_provider.dart';
import 'package:likonzi/providers/auth_provider.dart';
import 'package:likonzi/providers/carte_provider.dart';
import 'package:likonzi/providers/social_provider.dart';
import 'package:likonzi/providers/sos_provider.dart';
import 'package:likonzi/theme/theme.dart';
import 'package:likonzi/components/liste.dart';
import 'package:likonzi/views/accueil/accueil_view.dart';
import 'package:likonzi/views/dossiers/dossiers_view.dart';
import 'package:likonzi/views/alertes/alertes_view.dart';
import 'package:likonzi/views/objets/mes_biens_view.dart';
import 'package:likonzi/views/objets/objet_create_view.dart';
import 'package:likonzi/views/objets/objet_detail_view.dart';

/// Régressions d'interface relevées sur l'appareil :
///  1. « Voir tout » depuis l'accueil affichait une page rouge ;
///  2. les cartes avec de vraies données débordaient ;
///  3. les boutons du bas d'écran étaient coupés (barre système Android 15+).
///
/// Le réseau étant bloqué en test (400), les erreurs « hors ligne » sont
/// enregistrées puis ignorées : on n'échoue que sur les débordements et sur
/// les constats explicites de présence.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL=http://localhost:1/api/v1\n'
          'SOCKET_URL=http://localhost:1\n'
          'MAP_PROVIDER=osm\n'
          'APP_NOM=LIKONZI\n'
          'DEBUG_RESEAU=false\n'
          'PAR_PAGE=20\n',
    );
    initializeDateFormatting('fr_FR');
  });

  // ------------------------------------------------------------- données réelles

  Utilisateur profil() => Utilisateur.brut({
        'id': 7,
        'nom': 'KABILA',
        'postnom': 'MWAMBA',
        'prenom': 'Pierre Émile',
        'email': 'pierre.emile.kabila@test.cd',
        'telephone': '+243810000001',
        'statut': 'actif',
        'adresse': 'Avenue de la Justice, Gombe, Kinshasa',
        'commissariat': {'id': 1, 'nom': 'Commissariat Central de Kinshasa / Gombe'},
        'roles': ['super_admin', 'policier'],
        'permissions': [
          'alertes.creer',
          'alertes.lire',
          'objets.creer',
          'objets.lire',
          'objets.maj',
          'cas.lire',
          'users.lire',
        ],
      });

  const texteLong =
      'Deux motards armés me suivent depuis la station-service de la Gombe, '
      'direction l’avenue Kasa-Vubu. Ils portent des casques intégraux et l’un '
      'd’eux tient un objet métallique. Je suis à pied avec mon enfant, '
      'veuillez intervenir au plus vite, je continue vers le marché.';

  Alerte alerte([String? contenu]) => Alerte.brut({
        'id': 42,
        'reference': 'ALT-20261030-9XYZ89',
        'id_user': 7,
        'id_type_alerte': 1,
        'contenu': contenu ?? texteLong,
        'niveau_urgence': 'critique',
        'statut': 'nouvelle',
        'latitude': -4.325,
        'longitude': 15.31,
        'adresse_precise': 'Avenue Kasa-Vubu, quartier Gombe, commune de Gombe, Kinshasa',
        'date_alerte': '2026-10-30T19:04:00',
        'type': {'code': 'DANGER', 'contenu': 'Je suis en danger'},
        'emetteur': {'id': 7, 'nom': 'KABILA', 'prenom': 'Pierre'},
        'commissariat_nom': 'Commissariat Central de Kinshasa / Gombe',
      });

  Objet objet() => Objet.brut({
        'id': 5,
        'id_type': 2,
        'id_user_proprietaire': 7,
        'marque': 'Toyota',
        'model': 'Land Cruiser VX80 longue portée',
        'numero_chassis': 'JT8HJ1234567890123',
        'immatriculation': 'CD 4521 AB',
        'couleur': 'Blanc nacré',
        'date_vol': '2026-10-29T18:00:00',
        'lieu_vol': 'Parking souterrain de la Gombe, avenue de la Justice',
        'statut': 'recherche',
        'type': {'code': 'VOITURE', 'description': 'Voiture'},
        'proprietaire': {'id': 7, 'nom': 'KABILA', 'prenom': 'Pierre'},
      });

  Dossier dossier() => Dossier.brut({
        'id': 4,
        'numero_dossier': 'DOS-20261030-001',
        'type_cas': 'vol_vehicule',
        'description': texteLong,
        'date_faits': '2026-10-29T18:00:00',
        'date_ouverture': '2026-10-29T19:00:00',
        'statut': 'en_cours',
        'priorite': 'critique',
        'lieu': 'Parking souterrain de la Gombe, avenue de la Justice, Kinshasa',
        'id_commissariat': 1,
        'victime': {'id': 7, 'nom': 'KABILA', 'prenom': 'Pierre'},
        'enqueteur': {'id': 8, 'nom': 'KALONJI', 'prenom': 'Marc'},
        'commissariat_nom': 'Commissariat Central de Kinshasa / Gombe',
        'interventions': [
          {
            'id': 1,
            'type_intervention': 'patrouille',
            'description': texteLong,
            'date_intervention': '2026-10-30T08:00:00',
            'duree_minutes': 120,
            'lieu': 'Avenue Kasa-Vubu',
          },
        ],
      });

  Commissariat commissariat() => Commissariat.brut({
        'id': 1,
        'code': 'COM-KIN-001',
        'nom': 'Commissariat Central de Kinshasa / Gombe',
        'adresse':
            'Avenue de la Justice, face au Palais du Peuple, Quartier Gombe, Commune de Gombe, Kinshasa',
        'telephone': '+243810000001',
        'latitude': -4.325,
        'longitude': 15.31,
        'ville': 'Kinshasa',
        'province': 'Kinshasa',
        'distance_km': 0.42,
        'statut': true,
      });

  // ----------------------------------------------------------------- utilitaires

  void dimensionner(WidgetTester tester, Size taille) {
    tester.view.physicalSize = taille * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Widget heberger(Widget ecran) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..appliquerProfil(profil()),
        ),
        ChangeNotifierProvider(create: (_) => AlerteProvider()),
        ChangeNotifierProvider(create: (_) => SocialProvider()),
        ChangeNotifierProvider(create: (_) => CarteProvider()),
        ChangeNotifierProvider(create: (_) => SosProvider()),
      ],
      child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: construireTheme(),
      locale: const Locale('fr'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Même builder que l'application : SafeArea bas global.
      builder: (context, child) => SafeArea(
        top: false,
        bottom: true,
        child: child ?? const SizedBox.shrink(),
      ),
        home: Scaffold(body: ecran),
      ),
    );
  }

  // ==================================================== 1. Accueil -> Voir tout
  testWidgets('Accueil : « Voir tout » ouvre la liste sans page rouge', (tester) async {
    dimensionner(tester, const Size(360, 640));

    // Hors ligne : le test bloque tout HTTP (400) et les plugins sont absents.
    final erreurs = <String>[];
    final precedent = FlutterError.onError;
    FlutterError.onError = (d) => erreurs.add(d.toString());

    final provider = AlerteProvider()
      ..ensemencerPourTest(
        alertes: [alerte(), alerte('Je suis en danger, deux individus devant chez moi.')],
      );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider()..appliquerProfil(profil()),
          ),
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider(create: (_) => SocialProvider()),
          ChangeNotifierProvider(create: (_) => CarteProvider()),
          ChangeNotifierProvider(create: (_) => SosProvider()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: construireTheme(),
          locale: const Locale('fr'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Même assemblage que main.dart : providers -> MaterialApp.
          builder: (context, child) => SafeArea(
            top: false,
            bottom: true,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(body: VueAccueil()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // La liste de l'accueil est paresseuse : on défile jusqu'à la section.
    final voirTout = find.text('Voir tout');
    final scroll = find.byType(Scrollable);
    for (var i = 0; i < 12 && voirTout.evaluate().isEmpty; i++) {
      if (scroll.evaluate().isEmpty) break;
      await tester.drag(scroll.first, const Offset(0, -260));
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(voirTout, findsWidgets,
        reason: 'le bouton « Voir tout » est absent de l’accueil après défilement');

    await tester.ensureVisible(voirTout.first);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(voirTout.first);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 700));

    // ignore: avoid_print
    // Rétablir AVANT tout expect (exigence du framework de test).
    FlutterError.onError = precedent;
    addTearDown(() => FlutterError.onError = precedent);
    final debordements =
        erreurs.where((e) => e.toLowerCase().contains('overflow')).toList();

    expect(find.byType(VueAlertes), findsOneWidget,
        reason: '« Voir tout » n’a pas ouvert la liste des alertes');
    expect(find.textContaining('Deux motards armés'), findsWidgets,
        reason: 'l’alerte réelle ne s’affiche pas dans la liste');
    expect(debordements, isEmpty,
        reason: 'débordement(s) sur le parcours Accueil -> Voir tout : $debordements');
  });

  // ==================================================== 2. cartes avec données réelles
  testWidgets('Les cartes supportent des contenus longs sans débordement', (tester) async {
    final details = <String>[];
    final precedent = FlutterError.onError;
    void capter(FlutterErrorDetails d) {
      final texte = d.toString();
      if (texte.toLowerCase().contains('overflow')) {
        details.add(texte);
      }
    }

    for (final taille in const [Size(320, 568), Size(360, 640)]) {
      dimensionner(tester, taille);
      final cartes = <String, Widget>{
        'CarteAlerte': CarteAlerte(alerte: alerte(), afficherEmetteur: true),
        'CarteObjet': CarteObjet(objet: objet()),
        'CarteDossier': CarteDossier(dossier: dossier()),
        'CarteCommissariat': CarteCommissariat(
          commissariat: commissariat(),
          onAppeler: () {},
          onItineraire: () {},
        ),
        'CarteNotification': CarteNotification(
          notification: NotificationApp.brut({
            'id': 1,
            'id_user': 7,
            'type': 'alerte_assignee',
            'titre': 'Alerte assignée à un collègue du commissariat central',
            'message': texteLong,
            'lu': 0,
            'date_envoi': '2026-10-30T19:04:00',
          }),
        ),
        'CarteConversation': CarteConversation(
          nom: 'MWAMBA KABILA Pierre Émile Joseph',
          sousTitre: 'Inspecteur général de police — Commissariat Central de Kinshasa',
          initiales: 'MP',
          nonLus: 24,
          heure: '19:04',
          onTap: () {},
        ),
      };

      for (final carte in cartes.entries) {
        details.clear();
        FlutterError.onError = capter;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              // CarteAlerte affiche le badge « Ami » : elle a besoin d'AuthProvider.
              ChangeNotifierProvider(
                create: (_) => AuthProvider()..appliquerProfil(profil()),
              ),
            ],
            child: MaterialApp(
              theme: construireTheme(),
              locale: const Locale('fr'),
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: Scaffold(
                body: ListView(padding: const EdgeInsets.all(16), children: [carte.value]),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Rétablir AVANT tout expect (exigence du framework de test).
        FlutterError.onError = precedent;
        final constat = List<String>.from(details);
        expect(constat, isEmpty,
            reason: '${carte.key} à ${taille.width.toInt()}px -> $constat');
      }
    }
    FlutterError.onError = precedent;
    addTearDown(() => FlutterError.onError = precedent);
  });

  // ==================================================== 3. boutons du bas d'écran
  testWidgets('Les boutons du bas restent entiers avec la barre système', (tester) async {
    dimensionner(tester, const Size(360, 640));
    // Simule la barre de navigation Android (edge-to-edge).
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    tester.view.padding = const FakeViewPadding(bottom: 48);
    addTearDown(() {
      tester.view.viewPadding = FakeViewPadding.zero;
      tester.view.padding = FakeViewPadding.zero;
    });

    Future<void> verifierBouton(String nom, Finder cible) async {
      // Les listes/formulaires sont paresseuses : on défile jusqu'à la cible.
      // On cible explicitement le conteneur principal (un Scrollable interne
      // comme un menu déroulant ferait glisser sans effet).
      final candidats = <Finder>[
        find.byType(SingleChildScrollView),
        find.byType(ListView),
        find.byType(Scrollable),
      ];
      Finder? scroll;
      for (final c in candidats) {
        if (c.evaluate().isNotEmpty) {
          scroll = c;
          break;
        }
      }
      if (scroll != null && cible.evaluate().isEmpty) {
        try {
          await tester.scrollUntilVisible(cible, 300, scrollable: scroll);
          await tester.pump(const Duration(milliseconds: 120));
        } catch (_) {
          // repli : défilement manuel
          for (var i = 0; i < 25 && cible.evaluate().isEmpty; i++) {
            if (scroll.evaluate().isEmpty) break;
            await tester.drag(scroll.first, const Offset(0, -300));
            await tester.pump(const Duration(milliseconds: 80));
          }
        }
      }
      expect(cible.evaluate(), isNotEmpty,
          reason: '$nom est introuvable après défilement '
              '(scroll=${scroll?.evaluate().length ?? 0})');
      await tester.ensureVisible(cible);
      await tester.pump(const Duration(milliseconds: 300));
      final vue = Offset.zero & tester.getSize(find.byType(MaterialApp));
      final rect = tester.getRect(cible);
      final entier = vue.contains(rect.topLeft) && vue.contains(rect.bottomRight);
      expect(entier, isTrue,
          reason: '$nom est coupé : bouton=$rect écran=$vue (barre système 48px)');
    }

    Future<void> relancer(Widget ecran) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(heberger(ecran));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }

    // a) formulaire « déclarer un objet »
    await relancer(const VueCreationObjet());
    await verifierBouton(
      'Enregistrer la déclaration',
      find
          .ancestor(
            of: find.text('Enregistrer la déclaration'),
            matching: find.byType(BoutonPrincipal),
          ),
    );

    // b) fiche d'objet : partage
    await relancer(VueDetailObjet(objet: objet()));
    await verifierBouton(
      'Partager cette fiche',
      find
          .ancestor(
            of: find.text('Partager cette fiche et ses images'),
            matching: find.byType(BoutonPrincipal),
          ),
    );

    // c) inventaire : bouton flottant « Ajouter »
    await relancer(const VueMesBiens());
    await verifierBouton('Ajouter (FAB)', find.byType(FloatingActionButton));

    // d) commissariat : boutons Appeler / Itinéraire en bas de carte
    await relancer(
      ListView(
        children: [
          CarteCommissariat(
            commissariat: commissariat(),
            onAppeler: () {},
            onItineraire: () {},
          ),
        ],
      ),
    );
    await verifierBouton(
      'Itinéraire (carte commissariat)',
      find.ancestor(
        of: find.text('Itinéraire'),
        matching: find.byType(BoutonSecondaire),
      ),
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  // ==================================================== 4. premier chargement des dossiers
  // Régression constatée sur l'appareil : l'onglet « Tous » restait bloqué sur
  // le chargement, alors qu'un clic sur un filtre (forcer: true) fonctionnait.
  testWidgets('Dossiers : le premier chargement ne reste pas bloqué', (tester) async {
    dimensionner(tester, const Size(360, 640));
    final erreurs = <String>[];
    final precedent = FlutterError.onError;
    FlutterError.onError = (d) => erreurs.add(d.toString());

    await tester.pumpWidget(heberger(const VueDossiers()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 1200));

    FlutterError.onError = precedent;
    addTearDown(() => FlutterError.onError = precedent);

    // Hors ligne, la requête échoue : on doit aboutir à un ÉTAT FINAL
    // (erreur ou liste vide) et jamais rester sur le spinner.
    final spinner = find.byType(CircularProgressIndicator);
    final etatFinal = find.byType(EtatErreur).evaluate().isNotEmpty ||
        find.byType(EtatVide).evaluate().isNotEmpty ||
        find.byType(CarteDossier).evaluate().isNotEmpty;

    expect(spinner.evaluate(), isEmpty,
        reason: 'l\u2019onglet Dossiers reste bloqué sur le chargement '
            '(drapeau _chargement jamais libéré) — erreurs: $erreurs');
    expect(etatFinal, isTrue,
        reason: 'aucun état final affiché après le premier chargement — erreurs: $erreurs');
  });
}
