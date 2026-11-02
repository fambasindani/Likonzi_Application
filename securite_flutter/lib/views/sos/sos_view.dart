import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/bouton.dart';
import '../../components/carte_conteneur.dart';
import '../../components/entete.dart';
import '../../providers/carte_provider.dart';
import '../../providers/sos_provider.dart';
import '../../theme/couleurs.dart';
import '../../utils/messages.dart';

/// Écran SOS : déclenchement, compte à rebours serveur, envoi, levée.
class VueSos extends StatefulWidget {
  const VueSos({super.key});

  @override
  State<VueSos> createState() => _VueSosState();
}

class _VueSosState extends State<VueSos> {
  static const _durees = [5, 10, 15, 30];

  int _duree = 15;
  bool _enAction = false;

  Future<void> _lancer(Future<void> Function() action, {String? succes}) async {
    setState(() => _enAction = true);
    try {
      await action();
      if (mounted && succes != null) montrerSucces(context, succes);
    } catch (e) {
      if (mounted) montrerErreur(context, e);
    } finally {
      if (mounted) setState(() => _enAction = false);
    }
  }

  Future<void> _declencher() async {
    final valide = await confirmer(
      context,
      titre: 'Déclencher le SOS ?',
      message:
          'Un compte à rebours de $_duree minute(s) démarre. Passé ce délai, '
          'vos amis reçoivent un message d’urgence et une alerte part vers le '
          'commissariat le plus proche. Vous pourrez annuler entre-temps.',
      libelleValider: 'Déclencher',
      destructif: true,
      icone: Icons.warning_amber_outlined,
    );
    if (!valide || !mounted) return;

    final carte = context.read<CarteProvider>();
    if (carte.position == null) {
      await carte.localiserAppareil();
    }
    if (!mounted) return;

    await _lancer(
      () => context.read<SosProvider>().programmer(
            latitude: carte.position?.latitude,
            longitude: carte.position?.longitude,
            dureeMinutes: _duree,
          ),
      succes: 'SOS programmé : envoi dans $_duree min si vous n’annulez pas.',
    );
  }

  Future<void> _envoyerMaintenant() async {
    final valide = await confirmer(
      context,
      titre: 'Envoyer le SOS maintenant ?',
      message: 'Vos amis et la police sont prévenus immédiatement, sans attendre la fin du décompte.',
      libelleValider: 'Envoyer',
      destructif: true,
      icone: Icons.campaign_outlined,
    );
    if (!valide || !mounted) return;
    await _lancer(
      () => context.read<SosProvider>().envoyer(),
      succes: 'SOS envoyé à vos proches.',
    );
  }

  Future<void> _annuler() async {
    final valide = await confirmer(
      context,
      titre: 'Annuler le SOS ?',
      message: 'Personne n’est prévenu : c’est une fausse alerte, le décompte s’arrête.',
      libelleValider: 'Annuler le SOS',
      destructif: true,
      icone: Icons.block,
    );
    if (!valide || !mounted) return;
    await _lancer(
      () => context.read<SosProvider>().annuler(),
      succes: 'SOS annulé, personne n’a été prévenu.',
    );
  }

  Future<void> _lever() async {
    final valide = await confirmer(
      context,
      titre: 'Vous êtes en sécurité ?',
      message: 'Le SOS est levé et vos amis reçoivent un message de rétablissement.',
      libelleValider: 'Je vais bien',
      icone: Icons.check_circle_outline,
    );
    if (!valide || !mounted) return;
    await _lancer(
      () => context.read<SosProvider>().cloturer(),
      succes: 'SOS levé, vos amis ont été prévenus.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final sos = context.watch<SosProvider>();

    return Scaffold(
      appBar: const EntetePage(
        titre: 'SOS d’urgence',
        sousTitre: 'Minute de grâce — vos proches sont prévenus',
        icone: Icons.sos_outlined,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppCouleurs.rouge,
          onRefresh: sos.rafraichir,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              if (sos.chargement && sos.sos == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 70),
                  child: Center(child: CircularProgressIndicator(color: AppCouleurs.rouge)),
                )
              else if (sos.enCours)
                _panneauDecompte(sos)
              else if (sos.envoye)
                _panneauEnvoye(sos)
              else
                _panneauRepos(sos),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ au repos

  Widget _panneauRepos(SosProvider sos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CarteInfoSos(
          titre: 'Une situation de danger ?',
          message:
              'Déclenchez un SOS : si vous n’annulez pas dans les temps, un message '
              'd’urgence part vers vos amis et une alerte est transmise au '
              'commissariat le plus proche.',
        ),
        const SizedBox(height: 18),
        const Text(
          'Délai avant l’envoi',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Segment(
          libelles: [for (final d in _durees) '$d min'],
          selection: _durees.indexOf(_duree),
          onChanged: (i) => setState(() => _duree = _durees[i]),
        ),
        const SizedBox(height: 22),
        BoutonPrincipal(
          texte: 'Déclencher le SOS',
          icone: Icons.sos,
          couleur: AppCouleurs.rouge,
          enCharge: _enAction || sos.enAction,
          onPressed: _declencher,
        ),
        const SizedBox(height: 12),
        const Text(
          'Vous disposez du délai choisi pour annuler. Passé ce délai, le '
          'message est envoyé même si l’application est fermée.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: AppCouleurs.texteSecondaire, height: 1.5),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- décompte

  Widget _panneauDecompte(SosProvider sos) {
    final alerte = sos.sos?.intermediaireEnvoye ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CarteConteneur(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
          enfant: Column(
            children: [
              const Text(
                'Envoi automatique dans',
                style: TextStyle(fontSize: 14, color: AppCouleurs.texteSecondaire),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 190,
                height: 190,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 190,
                      height: 190,
                      child: CircularProgressIndicator(
                        value: sos.progression,
                        strokeWidth: 12,
                        strokeCap: StrokeCap.round,
                        color: AppCouleurs.rouge,
                        backgroundColor: AppCouleurs.rougePastel,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sos.minuteur,
                          style: const TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.5,
                            color: AppCouleurs.rouge,
                          ),
                        ),
                        Text(
                          sos.sos?.libelleStatut ?? '',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppCouleurs.texteSecondaire,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (alerte)
                const Text(
                  'Vos amis ont déjà reçu une première alerte.\n'
                  'Le SOS complet part à la fin du décompte.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.5, color: AppCouleurs.texteSecondaire),
                )
              else
                const Text(
                  'Annulez si tout va bien : personne n’aura été prévenu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.5, color: AppCouleurs.texteSecondaire),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        BoutonPrincipal(
          texte: 'Envoyer maintenant',
          icone: Icons.campaign_outlined,
          couleur: AppCouleurs.rouge,
          enCharge: _enAction || sos.enAction,
          onPressed: _envoyerMaintenant,
        ),
        const SizedBox(height: 10),
        BoutonSecondaire(
          texte: 'Annuler (fausse alerte)',
          icone: Icons.close,
          onPressed: (_enAction || sos.enAction) ? null : _annuler,
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ envoyé

  Widget _panneauEnvoye(SosProvider sos) {
    final police = sos.sos?.idAlerte != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CarteInfoSos(
          titre: 'SOS envoyé',
          couleur: AppCouleurs.vert,
          fond: AppCouleurs.vertPastel,
          icone: Icons.check_circle_outline,
          message: police
              ? 'Vos amis ont reçu votre message d’urgence et une alerte a été '
                  'transmise au commissariat le plus proche. Appelez si nécessaire.'
              : 'Vos amis ont reçu votre message d’urgence. Appelez-les si nécessaire.',
        ),
        const SizedBox(height: 18),
        BoutonPrincipal(
          texte: 'Je vais bien — lever le SOS',
          icone: Icons.check_circle_outline,
          couleur: AppCouleurs.vert,
          couleurTexte: AppCouleurs.textePrimaire,
          enCharge: _enAction || sos.enAction,
          onPressed: _lever,
        ),
        const SizedBox(height: 10),
        const Text(
          'Prévenez vos proches du rétablissement en levant le SOS.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: AppCouleurs.texteSecondaire, height: 1.5),
        ),
      ],
    );
  }
}

/// Carte d'information colorée (rouge par défaut, vert après envoi).
class CarteInfoSos extends StatelessWidget {
  const CarteInfoSos({
    super.key,
    required this.titre,
    required this.message,
    this.icone = Icons.shield_outlined,
    this.couleur = AppCouleurs.rouge,
    this.fond = AppCouleurs.rougePastel,
  });

  final String titre;
  final String message;
  final IconData icone;
  final Color couleur;
  final Color fond;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: couleur.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Icon(icone, color: couleur, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: couleur),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.55,
                    color: AppCouleurs.textePrimaire,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
