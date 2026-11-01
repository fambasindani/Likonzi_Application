import 'package:flutter_test/flutter_test.dart';
import 'package:likonzi/models/alerte.dart';
import 'package:likonzi/models/dossier.dart';
import 'package:likonzi/models/reponse_api.dart';
import 'package:likonzi/models/social.dart';
import 'package:likonzi/models/utilisateur.dart';

void main() {
  group('Parsing JSON du backend', () {
    test('Utilisateur : champs obligatoires + relations', () {
      final u = Utilisateur.brut({
        'id': 7,
        'nom': 'KABILA',
        'postnom': 'MWAMBA',
        'prenom': 'Pierre',
        'email': 'pierre@test.cd',
        'telephone': '+243810000001',
        'statut': 'actif',
        'commissariat': {'id': 1, 'nom': 'Commissariat de Gombe'},
        'matricule_police': 'POL-0042',
        'email_verifie': 1,
        'roles': ['policier'],
        'permissions': ['alertes.lire', 'cas.lire'],
      });

      expect(u.id, 7);
      expect(u.nomComplet, 'KABILA MWAMBA Pierre');
      expect(u.initiales, 'KP');
      expect(u.commissariatNom, 'Commissariat de Gombe');
      expect(u.estPolice, isTrue);
      expect(u.aPermission('alertes.lire'), isTrue);
      expect(u.aPermission('cas.supprimer'), isFalse);
      expect(u.emailVerifie, isTrue);
      expect(u.fonction, 'POL-0042');
    });

    test('permissions acceptées en liste de CHAÎNES (format /roles)', () {
      final u = Utilisateur.brut({
        'id': 1,
        'nom': 'X',
        'email': 'x@y.cd',
        'telephone': '+243810',
        'roles': ['citoyen'],
        'permissions': ['alertes.lire', 'objets.lire'],
      });
      expect(u.permissions, ['alertes.lire', 'objets.lire']);
      expect(u.aPermission('alertes.lire'), isTrue);
      expect(u.aPermission('cas.supprimer'), isFalse);
    });

    test('permissions acceptées en liste de MAPS (format /roles complet)', () {
      final u = Utilisateur.brut({
        'id': 1,
        'nom': 'X',
        'email': 'x@y.cd',
        'telephone': '+243810',
        'permissions': [
          {'code': 'alertes.lire'},
          {'code': 'users.maj'},
        ],
      });
      expect(u.permissions, ['alertes.lire', 'users.maj']);
    });

    test('Utilisateur : JSON minimal sans planter', () {
      final u = Utilisateur.brut({'id': 1});
      expect(u.id, 1);
      expect(u.roles, isEmpty);
      expect(u.estCitoyen, isTrue);
      expect(u.initiales, '?');
    });

    test('Alerte : relations type / emetteur / policier', () {
      final a = Alerte.brut({
        'id': 12,
        'reference': 'ALT-20261030-ABC123',
        'id_user': 3,
        'id_type_alerte': 1,
        'contenu': 'Deux motards me suivent.',
        'niveau_urgence': 'critique',
        'statut': 'nouvelle',
        'latitude': -4.325,
        'longitude': 15.31,
        'date_alerte': '2026-10-30T19:04:00',
        'type': {'code': 'DANGER', 'contenu': 'Je suis en danger'},
        'emetteur': {'id': 3, 'nom': 'NGOY', 'prenom': 'Jean'},
        'commissariat_nom': 'Gombe',
        'policier': {'id': 9, 'nom': 'POLICE', 'prenom': 'Agent'},
      });

      expect(a.reference, 'ALT-20261030-ABC123');
      expect(a.typeCode, 'DANGER');
      expect(a.emetteur, 'NGOY Jean');
      expect(a.aCoordonnees, isTrue);
      expect(a.estNouvelle, isTrue);
      expect(a.statutsPossibles, contains('prise_en_compte'));
      expect(a.statutsPossibles, contains('en_cours'));
      expect(a.statutsPossibles, contains('fausse_alerte'));
    });

    test('Alerte finalisée : plus aucune transition', () {
      final a = Alerte.brut({'id': 1, 'reference': 'X', 'statut': 'resolue'});
      expect(a.estTerminee, isTrue);
      expect(a.statutsPossibles, isEmpty);
    });

    test('Dossier : acteurs et transitions', () {
      final d = Dossier.brut({
        'id': 4,
        'numero_dossier': 'DOS-20261030-001',
        'type_cas': 'vol_vehicule',
        'description': 'Vol au parking.',
        'date_faits': '2026-10-29T18:00:00',
        'statut': 'ouvert',
        'priorite': 'haute',
        'id_commissariat': 1,
        'victime': {'id': 3, 'nom': 'NGOY', 'prenom': 'Jean', 'telephone': '+243810'},
        'enqueteur': {'id': 8, 'nom': 'KALONJI'},
        'interventions': [
          {'id': 1, 'type_intervention': 'patrouille', 'description': 'Ronde'},
        ],
      });

      expect(d.numeroDossier, 'DOS-20261030-001');
      expect(Dossier.libelleType(d.typeCas), 'Vol de véhicule');
      expect(d.victime, 'NGOY Jean');
      expect(d.enqueteur, 'KALONJI');
      expect(d.interventions, hasLength(1));
      expect(d.interventions.first.typeIntervention, 'patrouille');
      expect(Dossier.libelleIntervention('patrouille'), 'Patrouille');
      expect(d.statutsPossibles, contains('clos'));
      expect(d.estTermine, isFalse);
    });

    test('Notification : type et icône', () {
      final n = NotificationApp.brut({
        'id': 2,
        'id_user': 5,
        'type': 'alerte_assignee',
        'titre': 'Alerte assignée',
        'message': 'ALT-1',
        'lu': 0,
        'date_envoi': '2026-10-30T19:00:00',
      });
      expect(n.lu, isFalse);
      expect(n.cleIcone, 'notifications_active');
      final copie = n.copierAvecLu(true);
      expect(copie.lu, isTrue);
      expect(copie.titre, n.titre);
    });
  });

  group('Enveloppe de réponse', () {
    test('Page : pagination lue depuis meta', () {
      final page = Page.brut({
        'success': true,
        'data': [
          {'id': 1, 'nom': 'A'},
          {'id': 2, 'nom': 'B'},
        ],
        'meta': {'page': 2, 'per_page': 2, 'total': 5, 'pages': 3},
      }, (j) => Utilisateur.brut(j));

      expect(page.elements, hasLength(2));
      expect(page.page, 2);
      expect(page.total, 5);
      expect(page.pages, 3);
      expect(page.pageSuivante, isTrue);
    });

    test('ReponseApi : erreurs par champ (422)', () {
      final r = ReponseApi.brut({
        'success': false,
        'message': 'Données invalides.',
        'code': 'validation_failed',
        'errors': {
          'email': ['Cette adresse e-mail est déjà utilisée.'],
          'telephone': ['Ce numéro est déjà utilisé.'],
        },
      });
      expect(r.succes, isFalse);
      expect(r.erreurs['email'], isNotEmpty);
      expect(r.erreurs.keys, containsAll(['email', 'telephone']));
    });
  });
}
