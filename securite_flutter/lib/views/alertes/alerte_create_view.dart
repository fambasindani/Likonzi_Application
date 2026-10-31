import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/bouton.dart';
import '../../components/carte_conteneur.dart';
import '../../components/champ_texte.dart';
import '../../components/selecteur.dart';
import '../../providers/alerte_provider.dart';
import '../../providers/carte_provider.dart';
import '../../services/api_client.dart';
import '../../theme/couleurs.dart';
import '../../utils/messages.dart';
import '../../utils/validations.dart';
import 'alerte_detail_view.dart';

/// Déclenchement d'une alerte par un citoyen.
class VueCreationAlerte extends StatefulWidget {
  const VueCreationAlerte({super.key});

  @override
  State<VueCreationAlerte> createState() => _VueCreationAlerteState();
}

class _VueCreationAlerteState extends State<VueCreationAlerte> {
  final _formKey = GlobalKey<FormState>();
  final _contenu = TextEditingController();
  final _adresse = TextEditingController();

  int? _idType;
  String? _urgence;
  bool _utiliserPosition = true;
  bool _enCours = false;
  bool _positionPubliee = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final types = await context.read<AlerteProvider>().chargerTypes();
      if (mounted && types.isNotEmpty && _idType == null) {
        setState(() => _idType = types.first.id);
      }
    });
  }

  @override
  void dispose() {
    _contenu.dispose();
    _adresse.dispose();
    super.dispose();
  }

  Future<void> _localiser() async {
    final carte = context.read<CarteProvider>();
    final ok = await carte.localiserAppareil();
    if (ok && mounted) {
      setState(() => _positionPubliee = true);
      notifier(context, message: 'Position GPS récupérée.');
    } else if (mounted && carte.erreur != null) {
      montrerErreur(context, carte.erreur!);
    }
  }

  Future<void> _envoyer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_idType == null) {
      notifier(context, message: 'Choisissez un type d’alerte.', succes: false);
      return;
    }
    setState(() => _enCours = true);

    final carte = context.read<CarteProvider>();
    double? latitude;
    double? longitude;
    if (_utiliserPosition) {
      if (carte.position == null) {
        final ok = await carte.localiserAppareil();
        if (!mounted) return;
        if (!ok) {
          setState(() => _enCours = false);
          montrerErreur(
            context,
            carte.erreur ?? 'Position introuvable : désactivez le mode position.',
          );
          return;
        }
      }
      latitude = carte.position?.latitude;
      longitude = carte.position?.longitude;
    }

    try {
      final alerte = await context.read<AlerteProvider>().creer(
            idTypeAlerte: _idType!,
            contenu: _contenu.text.trim(),
            niveauUrgence: _urgence,
            latitude: latitude,
            longitude: longitude,
            adressePrecise: _adresse.text.trim(),
          );
      if (!mounted) return;
      montrerSucces(context, 'Alerte ${alerte.reference} envoyée.');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => VueDetailAlerte(alerte: alerte)),
      );
    } on ExceptionApi catch (e) {
      if (mounted) montrerErreur(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlerteProvider>();
    final carte = context.watch<CarteProvider>();
    final types = provider.types;

    return Scaffold(
      appBar: AppBar(title: const Text('Déclarer une alerte')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BandeauInfo(
                message:
                    'Votre alerte est transmise immédiatement au commissariat le plus proche.',
              ),
              const SizedBox(height: 20),

              Selecteur<int>(
                libelle: 'Type d’alerte',
                requis: true,
                valeur: _idType,
                icone: Icons.category_outlined,
                hint: types.isEmpty ? 'Chargement…' : 'Choisissez un type',
                options: [
                  for (final t in types)
                    OptionSelecteur(
                      valeur: t.id,
                      libelle: t.contenu,
                      icone: t.necessitePolice ? Icons.local_police_outlined : Icons.health_and_safety,
                    ),
                ],
                onChanged: (v) {
                  setState(() => _idType = v);
                  final type = types.where((t) => t.id == v).firstOrNull;
                  if (type != null) _urgence ??= type.niveauDefaut;
                },
              ),
              const SizedBox(height: 18),

              ChampTexte(
                libelle: 'Description de la situation',
                controller: _contenu,
                hint: 'Décrivez précisément ce qui se passe, le nombre de personnes…',
                maxLignes: 5,
                requis: true,
                capitale: TextCapitalization.sentences,
                validator: (v) => Validations.requis(
                  v,
                  champ: 'La description',
                  longueurMin: 3,
                  longueurMax: 5000,
                ),
              ),
              const SizedBox(height: 18),

              const Text(
                'Niveau d’urgence',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Segment(
                libelles: const ['Faible', 'Moyen', 'Élevé', 'Critique'],
                selection: switch (_urgence ?? 'moyen') {
                  'faible' => 0,
                  'moyen' => 1,
                  'eleve' => 2,
                  _ => 3,
                },
                onChanged: (i) => setState(
                  () => _urgence = ['faible', 'moyen', 'eleve', 'critique'][i],
                ),
              ),
              const SizedBox(height: 22),

              CarteConteneur(
                padding: const EdgeInsets.all(14),
                enfant: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.my_location, size: 18, color: AppCouleurs.bleu),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Ma position GPS',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Switch(
                          value: _utiliserPosition,
                          onChanged: (v) {
                            setState(() => _utiliserPosition = v);
                            if (v && carte.position == null) _localiser();
                          },
                        ),
                      ],
                    ),
                    if (_utiliserPosition) ...[
                      const SizedBox(height: 6),
                      Text(
                        carte.position == null
                            ? 'Position non encore obtenue.'
                            : 'Position : ${carte.position!.latitude.toStringAsFixed(5)}, '
                                '${carte.position!.longitude.toStringAsFixed(5)}'
                                '${_positionPubliee ? ' — prête' : ''}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: carte.position == null
                              ? AppCouleurs.orange
                              : AppCouleurs.texteSecondaire,
                        ),
                      ),
                      if (carte.position == null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: carte.positionEnCours ? null : _localiser,
                            child: Text(
                              carte.positionEnCours
                                  ? 'Localisation en cours…'
                                  : 'Obtenir ma position',
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              ChampTexte(
                libelle: 'Adresse précise',
                controller: _adresse,
                icone: Icons.place_outlined,
                hint: 'Av., avenue, quartier, ville',
                maxLignes: 2,
              ),
              const SizedBox(height: 26),

              BoutonPrincipal(
                texte: 'Envoyer l’alerte',
                icone: Icons.send_rounded,
                enCharge: _enCours,
                onPressed: _enCours ? null : _envoyer,
              ),
              const SizedBox(height: 10),
              const Text(
                'En cas de danger immédiat, composez également le numéro d’urgence.',
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
