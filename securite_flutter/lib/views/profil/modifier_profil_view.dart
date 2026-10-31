import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/bouton.dart';
import '../../components/champ_texte.dart';
import '../../components/selecteur.dart';
import '../../components/selecteur_date.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/utilisateur_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/messages.dart';
import '../../utils/validations.dart';

/// Modification du propre profil (champs réservés : e-mail/téléphone si admin).
class VueModifierProfil extends StatefulWidget {
  const VueModifierProfil({super.key});

  @override
  State<VueModifierProfil> createState() => _VueModifierProfilState();
}

class _VueModifierProfilState extends State<VueModifierProfil> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nom;
  late final TextEditingController _postnom;
  late final TextEditingController _prenom;
  late final TextEditingController _email;
  late final TextEditingController _telephone;
  late final TextEditingController _adresse;
  late final TextEditingController _matricule;
  late final TextEditingController _grade;

  String? _genre;
  DateTime? _naissance;
  bool _enCours = false;
  bool _modifie = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthProvider>().utilisateur;
    _nom = TextEditingController(text: u?.nom ?? '');
    _postnom = TextEditingController(text: u?.postnom ?? '');
    _prenom = TextEditingController(text: u?.prenom ?? '');
    _email = TextEditingController(text: u?.email ?? '');
    _telephone = TextEditingController(text: u?.telephone ?? '');
    _adresse = TextEditingController(text: u?.adresse ?? '');
    _matricule = TextEditingController(text: u?.matriculePolice ?? '');
    _grade = TextEditingController(text: u?.gradePolice ?? '');
    _genre = u?.genre;
    _naissance = u?.dateNaissance;
  }

  @override
  void dispose() {
    for (final c in [
      _nom,
      _postnom,
      _prenom,
      _email,
      _telephone,
      _adresse,
      _matricule,
      _grade,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _marquerModifie() {
    if (!_modifie) setState(() => _modifie = true);
  }

  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthProvider>();
    final u = auth.utilisateur;
    if (u == null) return;
    setState(() => _enCours = true);

    try {
      // Profil de base → /auth/me ; champs avancés → /users/<id>
      await UtilisateurService.instance.modifier(u.id, {
        'nom': _nom.text.trim(),
        'postnom': _postnom.text.trim(),
        'prenom': _prenom.text.trim(),
        'adresse': _adresse.text.trim(),
        if (_genre != null) 'genre': _genre,
        if (_naissance != null)
          'date_naissance': _naissance!.toIso8601String().split('T').first,
      });
      if (auth.estAdmin) {
        await UtilisateurService.instance.modifier(u.id, {
          'email': _email.text.trim(),
          'telephone': _telephone.text.trim(),
          'matricule_police': _matricule.text.trim(),
          'grade_police': _grade.text.trim(),
        });
      }
      await auth.rafraichirProfil();
      if (!mounted) return;
      montrerSucces(context, 'Profil mis à jour.');
      Navigator.of(context).pop(true);
    } on ExceptionApi catch (e) {
      if (mounted) montrerErreur(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final estAdmin = auth.estAdmin;
    final estPolice = auth.estPolice;

    return PopScope(
      canPop: !_modifie,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_modifie) return;
        final confirme = await confirmerSimple(
          context,
          titre: 'Abandonner les modifications ?',
          message: 'Vos changements ne seront pas enregistrés.',
          libelleValider: 'Abandonner',
          destructif: true,
        );
        if (confirme && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Modifier le profil'),
          actions: [
            TextButton(
              onPressed: _enCours ? null : _enregistrer,
              child: _enCours
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer'),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onChanged: _marquerModifie,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Identité',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                ChampTexte(
                  libelle: 'Nom',
                  controller: _nom,
                  requis: true,
                  capitale: TextCapitalization.words,
                  validator: (v) => Validations.requis(v, champ: 'Le nom', longueurMax: 50),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ChampTexte(
                        libelle: 'Postnom',
                        controller: _postnom,
                        capitale: TextCapitalization.words,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChampTexte(
                        libelle: 'Prénom',
                        controller: _prenom,
                        capitale: TextCapitalization.words,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Selecteur<String>(
                        libelle: 'Genre',
                        valeur: _genre,
                        hint: 'Non renseigné',
                        options: const [
                          OptionSelecteur(valeur: 'M', libelle: 'Masculin'),
                          OptionSelecteur(valeur: 'F', libelle: 'Féminin'),
                          OptionSelecteur(valeur: 'Autre', libelle: 'Autre'),
                        ],
                        onChanged: (v) {
                          _marquerModifie();
                          setState(() => _genre = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SelecteurDate(
                        libelle: 'Naissance',
                        valeur: _naissance,
                        onChanged: (v) {
                          _marquerModifie();
                          setState(() => _naissance = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ChampTexte(
                  libelle: 'Adresse',
                  controller: _adresse,
                  icone: Icons.home_outlined,
                  maxLignes: 2,
                  hint: 'Av., quartier, ville',
                ),

                const SizedBox(height: 26),
                const Text('Coordonnées',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (!estAdmin)
                  const BandeauInfoRef(
                    message:
                        'L’adresse e-mail et le téléphone ne sont modifiables que par '
                        'l’administration.',
                  ),
                const SizedBox(height: 12),
                ChampTexte(
                  libelle: 'Adresse e-mail',
                  controller: _email,
                  icone: Icons.mail_outline,
                  clavier: TextInputType.emailAddress,
                  actif: estAdmin,
                  requis: estAdmin,
                  validator: estAdmin ? (v) => Validations.email(v) : null,
                ),
                const SizedBox(height: 16),
                ChampTexte(
                  libelle: 'Téléphone',
                  controller: _telephone,
                  icone: Icons.phone_iphone,
                  clavier: TextInputType.phone,
                  actif: estAdmin,
                  requis: estAdmin,
                  validator: estAdmin ? (v) => Validations.telephone(v) : null,
                ),

                if (estPolice) ...[
                  const SizedBox(height: 26),
                  const Text('Service',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  ChampTexte(
                    libelle: 'Matricule',
                    controller: _matricule,
                    icone: Icons.pin_outlined,
                    actif: estAdmin,
                  ),
                  const SizedBox(height: 16),
                  ChampTexte(
                    libelle: 'Grade',
                    controller: _grade,
                    icone: Icons.military_tech_outlined,
                    actif: estAdmin,
                  ),
                ],

                const SizedBox(height: 28),
                BoutonPrincipal(
                  texte: 'Enregistrer les modifications',
                  icone: Icons.save_outlined,
                  enCharge: _enCours,
                  onPressed: _enCours ? null : _enregistrer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Variante compacte de `confirmer` (import circulaire évité).
Future<bool> confirmerSimple(
  BuildContext context, {
  required String titre,
  required String message,
  String libelleValider = 'Confirmer',
  bool destructif = false,
}) async {
  final resultat = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(titre),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructif
              ? FilledButton.styleFrom(backgroundColor: AppCouleurs.rouge)
              : null,
          child: Text(libelleValider),
        ),
      ],
    ),
  );
  return resultat ?? false;
}

/// Bandeau d'information (évite un import lourd dans ce fichier).
class BandeauInfoRef extends StatelessWidget {
  const BandeauInfoRef({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppCouleurs.bleuPastel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 17, color: AppCouleurs.bleu),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }
}
