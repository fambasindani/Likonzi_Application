import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/bouton.dart';
import '../../components/champ_texte.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../theme/couleurs.dart';
import '../../utils/messages.dart';

/// Changement du mot de passe (nécessite le mot de passe actuel).
class VueChangerMotDePasse extends StatefulWidget {
  const VueChangerMotDePasse({super.key});

  @override
  State<VueChangerMotDePasse> createState() => _VueChangerMotDePasseState();
}

class _VueChangerMotDePasseState extends State<VueChangerMotDePasse> {
  final _formKey = GlobalKey<FormState>();
  final _actuel = TextEditingController();
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();
  bool _enCours = false;

  @override
  void dispose() {
    _actuel.dispose();
    _nouveau.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_nouveau.text != _confirmation.text) {
      notifier(
        context,
        message: 'La confirmation ne correspond pas au nouveau mot de passe.',
        succes: false,
      );
      return;
    }
    setState(() => _enCours = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.changerMotDePasse(
      actuel: _actuel.text,
      nouveau: _nouveau.text,
    );
    if (!mounted) return;
    setState(() => _enCours = false);
    if (ok) {
      montrerSucces(context, 'Mot de passe modifié.');
      Navigator.of(context).pop(true);
    } else {
      montrerErreur(
        context,
        auth.erreur is ExceptionApi
            ? auth.erreur!
            : ExceptionApi(message: auth.erreur ?? 'Échec du changement.'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Changer le mot de passe')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BandeauInfoLocal(
                message:
                    'Votre nouveau mot de passe doit contenir au moins 8 caractères, '
                    'une lettre et un chiffre.',
              ),
              const SizedBox(height: 20),
              ChampMotDePasse(
                libelle: 'Mot de passe actuel',
                controller: _actuel,
                hint: '••••••••',
              ),
              const SizedBox(height: 18),
              ChampMotDePasse(
                libelle: 'Nouveau mot de passe',
                controller: _nouveau,
                hint: '8 caractères minimum',
                afficherIndicateur: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              ChampTexte(
                libelle: 'Confirmer le nouveau mot de passe',
                controller: _confirmation,
                icone: Icons.lock_outline,
                obscure: true,
                requis: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirmation requise.';
                  if (v != _nouveau.text) return 'Les mots de passe ne correspondent pas.';
                  return null;
                },
              ),
              const SizedBox(height: 28),
              BoutonPrincipal(
                texte: 'Mettre à jour',
                icone: Icons.save_outlined,
                enCharge: _enCours,
                onPressed: _enCours ? null : _enregistrer,
              ),
              const SizedBox(height: 14),
              const Text(
                'Un changement de mot de passe invalide les sessions des autres appareils.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppCouleurs.texteSecondaire),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BandeauInfoLocal extends StatelessWidget {
  const BandeauInfoLocal({super.key, required this.message});

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
          const Icon(Icons.shield_outlined, size: 17, color: AppCouleurs.bleu),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }
}
