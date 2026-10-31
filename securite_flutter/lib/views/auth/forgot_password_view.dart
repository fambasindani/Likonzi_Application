import 'package:flutter/material.dart';

import '../../components/bouton.dart';
import '../../components/carte_conteneur.dart';
import '../../components/champ_texte.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import '../../theme/couleurs.dart';
import '../../utils/messages.dart';
import '../../utils/validations.dart';

/// Réinitialisation du mot de passe en deux temps :
/// 1. demande de code (e-mail) — 2. code + nouveau mot de passe.
class VueMotDePasseOublie extends StatefulWidget {
  const VueMotDePasseOublie({super.key});

  @override
  State<VueMotDePasseOublie> createState() => _VueMotDePasseOublieState();
}

class _VueMotDePasseOublieState extends State<VueMotDePasseOublie> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _nouveau = TextEditingController();
  int _etape = 1;
  bool _enCours = false;
  String? _codeDemo;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _nouveau.dispose();
    super.dispose();
  }

  Future<void> _demanderCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _enCours = true);
    try {
      final reponse = await AuthService.instance.motDePasseOublie(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _codeDemo = reponse['code_demo'] as String?;
        _etape = 2;
      });
      notifier(
        context,
        message: 'Si ce compte existe, un code a été envoyé à ${_email.text.trim()}.',
      );
    } on ExceptionApi catch (e) {
      if (mounted) montrerErreur(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _reinitialiser() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _enCours = true);
    try {
      await AuthService.instance.reinitialiserMotDePasse(
        email: _email.text.trim(),
        code: _code.text.trim(),
        nouveau: _nouveau.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ExceptionApi catch (e) {
      if (mounted) montrerErreur(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progression des étapes
              Row(
                children: [
                  for (var i = 1; i <= 2; i++) ...[
                    Expanded(
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: i <= _etape ? AppCouleurs.bleu : AppCouleurs.bordure,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    if (i < 2) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 24),

              if (_etape == 1) ...[
                const BandeauInfo(
                  message:
                      'Indiquez l’adresse e-mail de votre compte. Un code de vérification '
                      'vous sera envoyé.',
                ),
                const SizedBox(height: 20),
                ChampTexte(
                  libelle: 'Adresse e-mail',
                  controller: _email,
                  icone: Icons.mail_outline,
                  clavier: TextInputType.emailAddress,
                  requis: true,
                  validator: (v) => Validations.email(v),
                ),
                const SizedBox(height: 24),
                BoutonPrincipal(
                  texte: 'Recevoir un code',
                  icone: Icons.mark_email_read_outlined,
                  enCharge: _enCours,
                  onPressed: _enCours ? null : _demanderCode,
                ),
              ] else ...[
                if (_codeDemo != null) ...[
                  BandeauInfo(
                    type: 'attention',
                    message: 'Mode développement : votre code est $_codeDemo',
                  ),
                  const SizedBox(height: 16),
                ],
                ChampTexte(
                  libelle: 'Adresse e-mail',
                  controller: _email,
                  icone: Icons.mail_outline,
                  clavier: TextInputType.emailAddress,
                  actif: false,
                  requis: true,
                ),
                const SizedBox(height: 16),
                ChampTexte(
                  libelle: 'Code reçu',
                  controller: _code,
                  icone: Icons.pin_outlined,
                  clavier: TextInputType.number,
                  hint: '000000',
                  requis: true,
                  validator: (v) => Validations.requis(
                    v,
                    champ: 'Le code',
                    longueurMin: 4,
                    longueurMax: 10,
                  ),
                ),
                const SizedBox(height: 16),
                ChampMotDePasse(
                  libelle: 'Nouveau mot de passe',
                  controller: _nouveau,
                  hint: '8 caractères minimum, lettre + chiffre',
                  afficherIndicateur: true,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 24),
                BoutonPrincipal(
                  texte: 'Réinitialiser',
                  icone: Icons.lock_reset_outlined,
                  enCharge: _enCours,
                  onPressed: _enCours ? null : _reinitialiser,
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _etape = 1),
                    child: const Text('Renvoyer un code'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
