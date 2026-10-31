import 'package:flutter/material.dart';

import '../../components/bouton.dart';
import '../../components/carte_conteneur.dart';
import '../../components/champ_texte.dart';
import '../../components/selecteur.dart';
import '../../components/selecteur_date.dart';
import '../../models/dossier.dart';
import '../../services/api_client.dart';
import '../../services/dossier_service.dart';
import '../../utils/messages.dart';
import '../../utils/validations.dart';
import 'dossier_detail_view.dart';

/// Ouverture d'un nouveau dossier d'enquête.
class VueCreationDossier extends StatefulWidget {
  const VueCreationDossier({super.key});

  @override
  State<VueCreationDossier> createState() => _VueCreationDossierState();
}

class _VueCreationDossierState extends State<VueCreationDossier> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _lieu = TextEditingController();

  String? _typeCas;
  String _priorite = 'normale';
  DateTime _dateFaits = DateTime.now();
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _typeCas = ConstantesDossier.types.first;
  }

  @override
  void dispose() {
    _description.dispose();
    _lieu.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dateFaits.isAfter(DateTime.now())) {
      notifier(context, message: 'La date des faits ne peut pas être dans le futur.', succes: false);
      return;
    }
    setState(() => _enCours = true);
    try {
      final dossier = await DossierService.instance.creer(
        typeCas: _typeCas!,
        description: _description.text.trim(),
        dateFaits: _dateFaits,
        lieu: _lieu.text.trim(),
        priorite: _priorite,
      );
      if (!mounted) return;
      montrerSucces(context, 'Dossier ${dossier.numeroDossier} ouvert.');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => VueDetailDossier(dossier: dossier)),
      );
    } on ExceptionApi catch (e) {
      if (mounted) montrerErreur(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ouvrir un dossier')),
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
                    'Le dossier est rattaché à votre commissariat. La victime sera notifiée '
                    'si elle est identifiée.',
              ),
              const SizedBox(height: 20),
              Selecteur<String>(
                libelle: 'Type de dossier',
                requis: true,
                valeur: _typeCas,
                icone: Icons.folder_special_outlined,
                options: [
                  for (final t in ConstantesDossier.types)
                    OptionSelecteur(valeur: t, libelle: Dossier.libelleType(t)),
                ],
                onChanged: (v) => setState(() => _typeCas = v),
              ),
              const SizedBox(height: 18),
              ChampTexte(
                libelle: 'Description des faits',
                controller: _description,
                hint: 'Reconstituez les faits de manière précise et factuelle…',
                maxLignes: 6,
                requis: true,
                capitale: TextCapitalization.sentences,
                validator: (v) => Validations.requis(
                  v,
                  champ: 'La description',
                  longueurMin: 5,
                  longueurMax: 10000,
                ),
              ),
              const SizedBox(height: 18),
              SelecteurDateHeure(
                libelle: 'Date et heure des faits',
                valeur: _dateFaits,
                requis: true,
                onChanged: (v) => setState(() => _dateFaits = v ?? DateTime.now()),
              ),
              const SizedBox(height: 18),
              ChampTexte(
                libelle: 'Lieu des faits',
                controller: _lieu,
                icone: Icons.place_outlined,
                hint: 'Av., quartier, ville',
                maxLignes: 2,
              ),
              const SizedBox(height: 18),
              const Text(
                'Priorité',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Segment(
                libelles: const ['Basse', 'Normale', 'Haute', 'Critique'],
                selection: ['basse', 'normale', 'haute', 'critique'].indexOf(_priorite),
                onChanged: (i) => setState(
                  () => _priorite = ['basse', 'normale', 'haute', 'critique'][i],
                ),
              ),
              const SizedBox(height: 28),
              BoutonPrincipal(
                texte: 'Ouvrir le dossier',
                icone: Icons.create_new_folder_outlined,
                enCharge: _enCours,
                onPressed: _enCours ? null : _envoyer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
