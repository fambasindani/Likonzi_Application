import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/bouton.dart';
import '../../components/champ_texte.dart';
import '../../providers/auth_provider.dart';
import '../../services/config_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/messages.dart';
import '../../utils/validations.dart';
import '../shell_view.dart';
import 'forgot_password_view.dart';
import 'register_view.dart';
import '../../theme/theme.dart';

/// Connexion : e-mail + mot de passe.
class VueConnexion extends StatefulWidget {
  const VueConnexion({super.key});

  @override
  State<VueConnexion> createState() => _VueConnexionState();
}

class _VueConnexionState extends State<VueConnexion> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _motDePasse = TextEditingController();
  bool _soumettre = false;

  @override
  void dispose() {
    _email.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _connecter() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() => _soumettre = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.connecter(
      email: _email.text.trim(),
      password: _motDePasse.text,
    );
    if (!mounted) return;
    setState(() => _soumettre = false);
    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil(ShellView.chemin, (_) => false);
    } else {
      montrerErreur(context, auth.erreur ?? 'Connexion impossible.');
    }
  }

  Future<void> _motDePasseOublie() async {
    final reussi = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const VueMotDePasseOublie()),
    );
    if (reussi == true && mounted) {
      notifier(context, message: 'Mot de passe réinitialisé, connectez-vous.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppCouleurs.fond,
      body: SafeArea(
        child: Center(
          // Largeur bornée : en paysage ou sur tablette, le formulaire reste
          // une colonne centrée au lieu d'étirer le contenu sur toute la largeur.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --------------------------------------------------- identité
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppCouleurs.bleuPastel,
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 66,
                      height: 66,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.shield_moon_outlined,
                        size: 54,
                        color: AppCouleurs.bleu,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  ConfigService.nomApp,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                    color: AppCouleurs.textePrimaire,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Connectez-vous pour signaler et suivre les alertes',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppCouleurs.texteSecondaire.withValues(alpha: 1),
                  ),
                ),
                const SizedBox(height: 30),

                // ---------------------------------------------------- formulaire
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppCouleurs.blanc,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppCouleurs.bordure),
                    boxShadow: AppEspacements.ombreDouce,
                  ),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ChampTexte(
                          libelle: 'Adresse e-mail',
                          controller: _email,
                          hint: 'exemple@domaine.cd',
                          icone: Icons.mail_outline,
                          clavier: TextInputType.emailAddress,
                          requis: true,
                          validator: (v) => Validations.email(v),
                        ),
                        const SizedBox(height: 18),
                        ChampMotDePasse(
                          libelle: 'Mot de passe',
                          controller: _motDePasse,
                          hint: 'Votre mot de passe',
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _motDePasseOublie,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              minimumSize: const Size(0, 32),
                            ),
                            child: const Text(
                              'Mot de passe oublié ?',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        BoutonPrincipal(
                          texte: 'Se connecter',
                          icone: Icons.login_rounded,
                          enCharge: auth.chargement || _soumettre,
                          onPressed: _soumettre ? null : _connecter,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    const Text(
                      'Pas encore de compte ?',
                      style: TextStyle(color: AppCouleurs.texteSecondaire),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const VueInscription()),
                      ),
                      child: const Text('Créer un compte'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Serveur : ${ConfigService.apiBaseUrl}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: AppCouleurs.gris),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

