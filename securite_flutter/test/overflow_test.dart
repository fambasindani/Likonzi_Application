import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:likonzi/models/alerte.dart';
import 'package:likonzi/models/dossier.dart';
import 'package:likonzi/models/utilisateur.dart';
import 'package:likonzi/providers/alerte_provider.dart';
import 'package:likonzi/providers/auth_provider.dart';
import 'package:likonzi/providers/carte_provider.dart';
import 'package:likonzi/providers/social_provider.dart';
import 'package:likonzi/providers/sos_provider.dart';
import 'package:likonzi/theme/theme.dart';
import 'package:likonzi/views/accueil/accueil_view.dart';
import 'package:likonzi/views/admin/audit_view.dart';
import 'package:likonzi/views/admin/geographie_view.dart';
import 'package:likonzi/views/admin/referentiels_view.dart';
import 'package:likonzi/views/admin/utilisateurs_view.dart';
import 'package:likonzi/views/alertes/alerte_create_view.dart';
import 'package:likonzi/views/alertes/alerte_detail_view.dart';
import 'package:likonzi/views/alertes/alertes_view.dart';
import 'package:likonzi/views/auth/forgot_password_view.dart';
import 'package:likonzi/views/auth/login_view.dart';
import 'package:likonzi/views/auth/register_view.dart';
import 'package:likonzi/views/boite/boite_view.dart';
import 'package:likonzi/views/boite/conversation_view.dart';
import 'package:likonzi/views/carte/carte_view.dart';
import 'package:likonzi/views/carte/positions_view.dart';
import 'package:likonzi/views/commissariats/commissariats_view.dart';
import 'package:likonzi/views/dossiers/dossier_create_view.dart';
import 'package:likonzi/views/dossiers/dossier_detail_view.dart';
import 'package:likonzi/views/dossiers/dossiers_view.dart';
import 'package:likonzi/views/dossiers/mes_interventions_view.dart';
import 'package:likonzi/views/objets/objet_create_view.dart';
import 'package:likonzi/views/objets/objets_view.dart';
import 'package:likonzi/views/profil/apropos_view.dart';
import 'package:likonzi/views/profil/changer_mdp_view.dart';
import 'package:likonzi/views/profil/modifier_profil_view.dart';
import 'package:likonzi/views/profil/profil_view.dart';
import 'package:likonzi/views/profil/verification_view.dart';
import 'package:likonzi/views/admin/administration_view.dart';
import 'package:likonzi/views/objets/mes_biens_view.dart';
import 'package:likonzi/views/objets/partages_view.dart';

/// Passe les écrans aux deux tailles de téléphone limites et remonte
/// **tous** les débordements de taille (RenderFlex overflow) d'un coup.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tailles = <String, Size>{
    'petit (320x568)': Size(320, 568),
    'moyen (360x640)': Size(360, 640),
  };

  final debordements = <String>[];
  String ecranCourant = '?';

  setUpAll(() async {
    // Environnement de test : le binding Flutter bloque tout HTTP (400).
    // On éteint surtout DEBUG_RESEAU pour que l'intercepteur Dio ne vienne
    // pas polluer la sortie avec les dumps d'exceptions réseau.
    // Environnement de test autonome : le binding Flutter bloque tout HTTP
    // (400) et DEBUG_RESEAU=false évite les dumps Dio en sortie.
    dotenv.loadFromString(
      envString: 'API_BASE_URL=http://localhost:1/api/v1\n'
          'SOCKET_URL=http://localhost:1\n'
          'MAP_PROVIDER=osm\n'
          'APP_NOM=LIKONZI\n'
          'APP_SLOGAN=Protéger, alerter, intervenir\n'
          'DEBUG_RESEAU=false\n'
          'PAR_PAGE=20\n',
    );
    await initializeDateFormatting('fr_FR');
  });

  Utilisateur profilTest() => Utilisateur.brut({
        'id': 7,
        'nom': 'KABILA',
        'postnom': 'MWAMBA',
        'prenom': 'Pierre Émile',
        'email': 'pierre.emile.kabila@test.cd',
        'telephone': '+243810000001',
        'statut': 'actif',
        'adresse': 'Avenue de la Justice, Gombe, Kinshasa',
        'matricule_police': 'POL-0042',
        'grade_police': 'Inspecteur général de police',
        'commissariat': {'id': 1, 'nom': 'Commissariat Central de Kinshasa / Gombe'},
        'email_verifie': 0,
        'roles': ['super_admin', 'policier'],
        'permissions': [
          'alertes.lire',
          'cas.lire',
          'users.lire',
          'users.maj',
          'audit.lire',
          'rbac.gerer',
          'objets.lire',
        ],
      });

  Alerte alerteTest() => Alerte.brut({
        'id': 12,
        'reference': 'ALT-20261030-ABC123',
        'id_user': 7,
        'id_type_alerte': 1,
        'contenu':
            'Deux motards armés me suivent depuis la station-service, direction '
            'l\'avenue Kasa-Vubu, veuillez intervenir au plus vite.',
        'niveau_urgence': 'critique',
        'statut': 'prise_en_compte',
        'latitude': -4.325,
        'longitude': 15.31,
        'adresse_precise': 'Av. Kasa-Vubu, Gombe, Kinshasa',
        'date_alerte': '2026-10-30T19:04:00',
        'type': {'code': 'DANGER', 'contenu': 'Je suis en danger'},
        'emetteur': {'id': 7, 'nom': 'KABILA', 'prenom': 'Pierre'},
        'commissariat_nom': 'Commissariat Central de Kinshasa / Gombe',
        'policier': {'id': 9, 'nom': 'NGOY', 'prenom': 'Agent'},
      });

  Dossier dossierTest() => Dossier.brut({
        'id': 4,
        'numero_dossier': 'DOS-20261030-001',
        'type_cas': 'vol_vehicule',
        'description':
            'Vol d\'un véhicule au parking de la Gombe. Deux individus à moto '
            'se sont approchés et ont pris le volant sous la menace.',
        'date_faits': '2026-10-29T18:00:00',
        'date_ouverture': '2026-10-29T19:00:00',
        'statut': 'en_cours',
        'priorite': 'haute',
        'lieu': 'Parking de la Gombe, Kinshasa',
        'id_commissariat': 1,
        'victime': {'id': 7, 'nom': 'KABILA', 'prenom': 'Pierre', 'telephone': '+243810'},
        'enqueteur': {'id': 8, 'nom': 'KALONJI', 'prenom': 'Marc'},
        'commissariat_nom': 'Commissariat Central de Kinshasa / Gombe',
        'interventions': [
          {
            'id': 1,
            'type_intervention': 'patrouille',
            'description': 'Ronde de contrôle sur l\'avenue et vérification des véhicules.',
            'date_intervention': '2026-10-30T08:00:00',
            'duree_minutes': 45,
            'lieu': 'Av. Kasa-Vubu',
          },
        ],
      });

  Future<void> pumpEcran(
    WidgetTester tester,
    Size taille,
    String nom,
    Widget Function() fabriquer,
  ) async {
    ecranCourant = nom;
    tester.view.physicalSize = taille * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()..appliquerProfil(profilTest())),
          ChangeNotifierProvider(create: (_) => AlerteProvider()),
          ChangeNotifierProvider(create: (_) => SocialProvider()),
          ChangeNotifierProvider(create: (_) => CarteProvider()),
          ChangeNotifierProvider(create: (_) => SosProvider()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: construireTheme(),
          locale: const Locale('fr'),
          // Les écrans sont pensés pour le corps d'un Scaffold (ShellView) :
          // on les héberge pareil pour avoir des contraintes réalistes.
          home: Scaffold(body: Builder(builder: (_) => fabriquer())),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 1200));
  }

  testWidgets('aucun débordement de taille sur les écrans', (tester) async {
    // Hors-ligne assumé : le test bloque tout HTTP (400) et les plugins
    // natifs sont absents. On n'avale QUE les débordements de taille, qui
    // sont l'objet de ce test ; tout le reste est ignoré pour ne pas
    // masquer le résultat recherché.
    var avalees = 0;
    final precedent = FlutterError.onError;
    FlutterError.onError = (details) {
      final texte = details.exception.toString();
      if (texte.toLowerCase().contains('overflow')) {
        debordements.add('« $ecranCourant » → ${details.toString()}');
      } else {
        avalees++;
      }
    };
    addTearDown(() {
      FlutterError.onError = precedent;
      debugPrint('erreurs hors-ligne ignorées : $avalees');
    });

    final ecrans = <String, Widget Function()>{
      'Connexion': () => const VueConnexion(),
      'Inscription': () => const VueInscription(),
      'Mot de passe oublié': () => const VueMotDePasseOublie(),
      'Accueil': () => const VueAccueil(),
      'Alertes': () => const VueAlertes(),
      'Détail alerte': () => VueDetailAlerte(alerte: alerteTest()),
      'Création alerte': () => const VueCreationAlerte(),
      'Dossiers': () => const VueDossiers(),
      'Détail dossier': () => VueDetailDossier(dossier: dossierTest()),
      'Création dossier': () => const VueCreationDossier(),
      'Objets': () => const VueObjets(),
      'Création objet': () => const VueCreationObjet(),
      'Boîte': () => const VueBoite(),
      'Conversation': () => VueConversation(destinataire: profilTest()),
      'Carte': () => const VueCarte(),
      'Commissariats': () => const VueCommissariats(),
      'Positions': () => const VuePositions(),
      'Mes interventions': () => const VueMesInterventions(),
      'Profil': () => const VueProfil(),
      'Modifier profil': () => const VueModifierProfil(),
      'Changer mot de passe': () => const VueChangerMotDePasse(),
      'Vérification': () => const VueVerification(),
      'À propos': () => const VueAPropos(),
      'Utilisateurs': () => const VueUtilisateurs(),
      'Référentiels': () => const VueReferentiels(),
      'Géographie': () => const VueGeographie(),
      'Audit': () => const VueAudit(),
      'Administration': () => const VueAdministration(),
      'Mes biens': () => const VueMesBiens(),
      'Partages reçus': () => const VuePartages(),
    };

    for (final taille in tailles.entries) {
      for (final ecran in ecrans.entries) {
        ecranCourant = '${ecran.key} @ ${taille.key}';
        await pumpEcran(tester, taille.value, ecranCourant, ecran.value);
      }
    }

    // Obligatoire : FlutterTest exige que FlutterError.onError soit rétabli
    // AVANT tout expect().
    FlutterError.onError = precedent;
    addTearDown(() => FlutterError.onError = precedent);

    final uniques = debordements.toSet().toList()..sort();
    expect(
      uniques,
      isEmpty,
      reason: '${uniques.length} débordement(s) de taille détecté(s) :\n'
          '${uniques.map((e) => ' - $e').join('\n')}',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}
