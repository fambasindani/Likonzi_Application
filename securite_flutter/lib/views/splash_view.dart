import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/config_service.dart';
import '../theme/couleurs.dart';
import '../theme/theme.dart';
import 'auth/login_view.dart';
import 'shell_view.dart';

/// Écran de démarrage : restaure la session puis redirige.
class VueDemarrage extends StatefulWidget {
  const VueDemarrage({super.key});

  @override
  State<VueDemarrage> createState() => _VueDemarrageState();
}

class _VueDemarrageState extends State<VueDemarrage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controleur;
  late final Animation<double> _echelle;

  @override
  void initState() {
    super.initState();
    _controleur = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _echelle = CurvedAnimation(parent: _controleur, curve: Curves.elasticOut);
    _controleur.forward();
    _demarrer();
  }

  Future<void> _demarrer() async {
    final auth = context.read<AuthProvider>();
    final debut = DateTime.now();
    await auth.initialiser();
    final ecart = DateTime.now().difference(debut);
    if (ecart.inMilliseconds < 1400) {
      await Future<void>.delayed(Duration(milliseconds: 1400 - ecart.inMilliseconds));
    }
    if (!mounted) return;
    // Transition SANS glissement : avec MaterialPageRoute, le splash bleu
    // restait visible en haut pendant la transition (écran « divisé en deux »).
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) =>
            auth.connecte ? const ShellView() : const VueConnexion(),
      ),
    );
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fond identique a celui de la connexion (`AppCouleurs.fond`) : le
    // SafeArea global laisse decouvrir le fond de fenetre en bas de l'ecran
    // (barre de navigation Android 15+). Un fond bleu plein ecran y laissait
    // une bande blanche : l'ecran semblait coupe en deux au demarrage.
    return Scaffold(
      backgroundColor: AppCouleurs.fond,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.fromLTRB(24, 44, 24, 36),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppCouleurs.bleu, AppCouleurs.bleuNuit],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: AppEspacements.ombreForte,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _echelle,
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 96,
                      height: 96,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.shield_moon_outlined,
                        size: 78,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  ConfigService.nomApp,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ConfigService.slogan,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: 28),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
