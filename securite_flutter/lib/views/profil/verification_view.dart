import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/bouton.dart';
import '../../components/carte_conteneur.dart';
import '../../components/champ_texte.dart';
import '../../components/selecteur.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/messages.dart';
import '../../utils/validations.dart';

/// Vérification de l'adresse e-mail ou du numéro de téléphone (OTP).
///
/// Consomme `POST /auth/send-verification` puis `POST /auth/verify`.
class VueVerification extends StatefulWidget {
  const VueVerification({super.key, this.typeInitial});

  /// `email` ou `telephone`.
  final String? typeInitial;

  @override
  State<VueVerification> createState() => _VueVerificationState();
}

class _VueVerificationState extends State<VueVerification> {
  final _code = TextEditingController();
  late String _type;
  int _etape = 1;
  bool _enCours = false;
  String? _codeDemo;
  DateTime? _expire;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthProvider>().utilisateur;
    _type = widget.typeInitial ??
        ((u?.emailVerifie ?? true) ? 'telephone' : 'email');
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String get _destination {
    final u = context.read<AuthProvider>().utilisateur;
    if (u == null) return '';
    return _type == 'email' ? u.email : u.telephone;
  }

  Future<void> _envoyerCode() async {
    setState(() {
      _enCours = true;
      _codeDemo = null;
    });
    try {
      final reponse = await AuthService.instance.demanderVerification(_type);
      if (!mounted) return;
      setState(() {
        _etape = 2;
        _codeDemo = reponse['code_demo'] as String?;
        final brut = reponse['expire_at'] as String?;
        _expire = brut != null ? DateTime.tryParse(brut) : null;
      });
      notifier(context, message: 'Code envoyé vers $_destination.');
    } on ExceptionApi catch (e) {
      if (mounted) montrerErreur(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _confirmer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _enCours = true);
    try {
      await AuthService.instance.confirmerVerification(
        type: _type,
        code: _code.text.trim(),
      );
      if (!mounted) return;
      await context.read<AuthProvider>().rafraichirProfil();
      if (!mounted) return;
      montrerSucces(
        context,
        _type == 'email' ? 'Adresse e-mail vérifiée.' : 'Téléphone vérifié.',
      );
      Navigator.of(context).pop(true);
    } on ExceptionApi catch (e) {
      if (mounted) montrerErreur(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final u = auth.utilisateur;
    final dejaVerifie = _type == 'email' ? (u?.emailVerifie ?? false) : (u?.telephoneVerifie ?? false);

    return Scaffold(
      appBar: AppBar(title: const Text('Vérification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Selecteur<String>(
              libelle: 'Canal à vérifier',
              valeur: _type,
              icone: Icons.alternate_email,
              options: [
                const OptionSelecteur(valeur: 'email', libelle: 'Adresse e-mail', icone: Icons.mail_outline),
                const OptionSelecteur(valeur: 'telephone', libelle: 'Numéro de téléphone', icone: Icons.phone_iphone),
              ],
              onChanged: (v) => setState(() {
                _type = v ?? 'email';
                _etape = 1;
                _codeDemo = null;
                _code.clear();
              }),
            ),
            const SizedBox(height: 16),
            CarteConteneur(
              enfant: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        dejaVerifie ? Icons.verified_outlined : Icons.hourglass_top_outlined,
                        color: dejaVerifie ? AppCouleurs.vert : AppCouleurs.orange,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          dejaVerifie ? 'Déjà vérifié' : 'Non vérifié',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: dejaVerifie ? AppCouleurs.vert : AppCouleurs.orange,
                          ),
                        ),
                      ),
                      if (dejaVerifie)
                        const BadgeOk(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _destination,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  if (_expire != null && _etape == 2) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Code valable jusqu’à '
                      '${_expire!.hour.toString().padLeft(2, '0')}:'
                      '${_expire!.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 12.5, color: AppCouleurs.texteSecondaire),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_etape == 1) ...[
              BoutonPrincipal(
                texte: dejaVerifie ? 'Renvoyer un code' : 'Envoyer le code',
                icone: Icons.send_rounded,
                enCharge: _enCours,
                onPressed: _enCours ? null : _envoyerCode,
              ),
            ] else ...[
              if (_codeDemo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: BandeauInfoRef(message: 'Mode développement : votre code est $_codeDemo'),
                ),
              Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: ChampTexte(
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
              ),
              const SizedBox(height: 20),
              BoutonPrincipal(
                texte: 'Valider le code',
                icone: Icons.check_circle_outline,
                enCharge: _enCours,
                onPressed: _enCours ? null : _confirmer,
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _enCours ? null : _envoyerCode,
                  child: const Text('Renvoyer le code'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BadgeOk extends StatelessWidget {
  const BadgeOk({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppCouleurs.vertPastel,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Vérifié',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppCouleurs.vert),
      ),
    );
  }
}

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
