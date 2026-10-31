import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/bouton.dart';
import '../../components/champ_texte.dart';
import '../../components/selecteur.dart';
import '../../providers/auth_provider.dart';
import '../../theme/couleurs.dart';
import '../../utils/messages.dart';
import '../../utils/validations.dart';
import '../shell_view.dart';

/// Inscription citoyenne (rôle `citoyen` imposé côté serveur).
class VueInscription extends StatefulWidget {
  const VueInscription({super.key});

  @override
  State<VueInscription> createState() => _VueInscriptionState();
}

class _VueInscriptionState extends State<VueInscription> {
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _postnom = TextEditingController();
  final _prenom = TextEditingController();
  final _email = TextEditingController();
  final _telephone = TextEditingController();
  final _motDePasse = TextEditingController();
  final _confirmation = TextEditingController();
  final _adresse = TextEditingController();

  String? _genre;
  DateTime? _naissance;
  bool _soumettre = false;
  bool _visible = false;

  @override
  void dispose() {
    for (final c in [
      _nom,
      _postnom,
      _prenom,
      _email,
      _telephone,
      _motDePasse,
      _confirmation,
      _adresse,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _choisirNaissance() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _naissance ?? DateTime(2005),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      locale: const Locale('fr'),
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );
    if (date != null) setState(() => _naissance = date);
  }

  Future<void> _inscrire() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_motDePasse.text != _confirmation.text) {
      notifier(context, message: 'Les deux mots de passe ne correspondent pas.', succes: false);
      return;
    }
    setState(() => _soumettre = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.inscrire({
      'nom': _nom.text.trim(),
      'postnom': _postnom.text.trim(),
      'prenom': _prenom.text.trim(),
      'email': _email.text.trim(),
      'telephone': _telephone.text.trim(),
      'password': _motDePasse.text,
      'genre': _genre,
      'adresse': _adresse.text.trim(),
      'date_naissance': _naissance,
    });
    if (!mounted) return;
    setState(() => _soumettre = false);
    if (ok) {
      montrerSucces(context, 'Compte créé, bienvenue !');
      Navigator.of(context).pushNamedAndRemoveUntil(ShellView.chemin, (_) => false);
    } else {
      montrerErreur(context, auth.erreur ?? "Inscription impossible.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Identité',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              ChampTexte(
                libelle: 'Nom',
                controller: _nom,
                icone: Icons.badge_outlined,
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
                      validator: (v) =>
                          v == null || v.trim().length <= 50 ? null : '50 caractères max.',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChampTexte(
                      libelle: 'Prénom',
                      controller: _prenom,
                      capitale: TextCapitalization.words,
                      validator: (v) =>
                          v == null || v.trim().length <= 50 ? null : '50 caractères max.',
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
                        OptionSelecteur(valeur: 'M', libelle: 'Masculin', icone: Icons.male),
                        OptionSelecteur(valeur: 'F', libelle: 'Féminin', icone: Icons.female),
                        OptionSelecteur(valeur: 'Autre', libelle: 'Autre'),
                      ],
                      onChanged: (v) => setState(() => _genre = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ChampDateNaissance(
                      valeur: _naissance,
                      onTap: _choisirNaissance,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),

              const Text(
                'Coordonnées',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              ChampTexte(
                libelle: 'Adresse e-mail',
                controller: _email,
                icone: Icons.mail_outline,
                clavier: TextInputType.emailAddress,
                requis: true,
                validator: (v) => Validations.email(v),
              ),
              const SizedBox(height: 16),
              ChampTexte(
                libelle: 'Téléphone',
                controller: _telephone,
                icone: Icons.phone_iphone,
                clavier: TextInputType.phone,
                hint: '+243810000000',
                requis: true,
                validator: (v) => Validations.telephone(v),
              ),
              const SizedBox(height: 16),
              ChampTexte(
                libelle: 'Adresse',
                controller: _adresse,
                icone: Icons.home_outlined,
                hint: 'Av., quartier, ville',
                maxLignes: 2,
              ),
              const SizedBox(height: 26),

              const Text(
                'Sécurité',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              ChampMotDePasse(
                libelle: 'Mot de passe',
                controller: _motDePasse,
                hint: '8 caractères minimum, lettre + chiffre',
                afficherIndicateur: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              ChampTexte(
                libelle: 'Confirmer le mot de Passe',
                controller: _confirmation,
                icone: Icons.lock_outline,
                obscure: !_visible,
                requis: true,
                suffixe: IconButton(
                  icon: Icon(
                    _visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _visible = !_visible),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirmation requise.';
                  if (v != _motDePasse.text) return 'Les mots de passe ne correspondent pas.';
                  return null;
                },
              ),
              const SizedBox(height: 28),
              BoutonPrincipal(
                texte: 'Créer mon compte',
                icone: Icons.person_add_alt_1_outlined,
                enCharge: auth.chargement || _soumettre,
                onPressed: _soumettre ? null : _inscrire,
              ),
              const SizedBox(height: 14),
              Text(
                'En créant un compte, vous devenez un utilisateur « citoyen ». '
                'Les comptes policier sont créés par l’administration.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppCouleurs.texteSecondaire.withValues(alpha: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChampDateNaissance extends StatelessWidget {
  const _ChampDateNaissance({required this.valeur, required this.onTap});

  final DateTime? valeur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Naissance',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: InputDecorator(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.cake_outlined, size: 20, color: AppCouleurs.grisBleu),
              suffixIcon: Icon(Icons.arrow_drop_down, color: AppCouleurs.grisBleu),
            ),
            child: Text(
              valeur == null
                  ? 'JJ/MM/AAAA'
                  : '${valeur!.day.toString().padLeft(2, '0')}/'
                      '${valeur!.month.toString().padLeft(2, '0')}/${valeur!.year}',
              style: TextStyle(
                fontSize: 15,
                color: valeur == null ? AppCouleurs.gris : AppCouleurs.textePrimaire,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
