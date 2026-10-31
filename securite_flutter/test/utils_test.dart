import 'package:flutter_test/flutter_test.dart';
import 'package:securite/theme/couleurs.dart';
import 'package:securite/utils/formatage.dart';
import 'package:securite/utils/validations.dart';

void main() {
  group('Validations', () {
    test('e-mail valide / invalide', () {
      expect(Validations.email('a@b.cd'), isNull);
      expect(Validations.email('pas-un-mail'), isNotNull);
      expect(Validations.email(''), isNotNull);
      expect(Validations.email('', requis: false), isNull);
    });

    test('téléphone congolais', () {
      expect(Validations.telephone('+243810000000'), isNull);
      expect(Validations.telephone('0810000000'), isNull);
      expect(Validations.telephone('abc'), isNotNull);
    });

    test('politique de mot de passe identique au backend', () {
      expect(Validations.motDePasse('court'), isNotNull);
      expect(Validations.motDePasse('abcdefgh'), isNotNull); // sans chiffre
      expect(Validations.motDePasse('12345678'), isNull); // mot de passe de reference
      expect(Validations.motDePasse('Citoyen2026'), isNull);
    });

    test('confirmation de mot de passe', () {
      expect(Validations.motDePasseIdentique('abc12345', 'abc12345'), isNotNull);
      expect(Validations.motDePasseIdentique('abc12345', 'autre1234'), isNull);
    });

    test('bornes numériques', () {
      expect(Validations.decimal('999', min: -90, max: 90), isNotNull);
      expect(Validations.decimal('-4.325', min: -90, max: 90), isNull); // valide
      expect(Validations.entier('pas-un-nombre'), isNotNull);
      expect(Validations.entier('20', min: 1, max: 100), isNull); // valide
    });
  });

  group('Formatage', () {
    test('distance en mètres puis en kilomètres', () {
      expect(Formatage.distance(0.4), '400 m');
      expect(Formatage.distance(12.34), '12,3 km');
    });

    test('taille de fichier', () {
      expect(Formatage.taille(512), '512 o');
      expect(Formatage.taille(2048), '2 Ko');
      expect(Formatage.taille(5 * 1024 * 1024), '5,0 Mo');
    });

    test('initiales', () {
      expect(Formatage.initiales('Kabila', 'Pierre'), 'KP');
      expect(Formatage.initiales(null, null), '?');
    });

    test('date relative', () {
      expect(Formatage.relative(DateTime.now().subtract(const Duration(seconds: 10))),
          "à l'instant");
      expect(Formatage.relative(DateTime.now().subtract(const Duration(minutes: 5))),
          'il y a 5 min');
      expect(Formatage.relative(DateTime.now().subtract(const Duration(days: 1))), 'hier');
      expect(Formatage.relative(null), '—');
    });
  });

  group('Palette (reprise de Couleurs/COLORS.js)', () {
    test('couleurs d\'origine conservées', () {
      expect(AppCouleurs.bleu.toARGB32(), 0xFF505FEE);
      expect(AppCouleurs.vert.toARGB32(), 0xFF47D9AF);
      expect(AppCouleurs.jaune.toARGB32(), 0xFFFFDB58);
      expect(AppCouleurs.gris.toARGB32(), 0xFFBABBC2);
      expect(AppCouleurs.clair.toARGB32(), 0xFFF3F4FB);
    });

    test('niveaux d\'urgence', () {
      expect(AppCouleurs.urgence('critique'), AppCouleurs.rouge);
      expect(AppCouleurs.urgence('eleve'), AppCouleurs.orange);
      expect(AppCouleurs.urgence('moyen'), AppCouleurs.jaune);
      expect(AppCouleurs.urgence('faible'), AppCouleurs.vert);
    });

    test('libellés français des statuts', () {
      expect(AppCouleurs.libelle('prise_en_compte'), 'Prise en charge');
      expect(AppCouleurs.libelle('fausse_alerte'), 'Fausse alerte');
      expect(AppCouleurs.libelle('declare_vol'), 'Déclaré volé');
      expect(AppCouleurs.libelle('eleve'), 'Élevé');
    });
  });
}
