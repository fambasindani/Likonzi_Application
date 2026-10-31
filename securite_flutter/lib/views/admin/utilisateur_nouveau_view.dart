import 'package:flutter/material.dart';

import '../../components/bouton.dart';
import '../../components/champ_texte.dart';
import '../../components/apercu_roles.dart';
import '../../components/selecteur.dart';
import '../../components/selecteur_date.dart';
import '../../models/geographie.dart';
import '../../services/api_client.dart';
import '../../services/dossier_service.dart';
import '../../services/meta_service.dart';
import '../../services/utilisateur_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/messages.dart';
import '../../utils/validations.dart';

/// Création d'un compte par un administrateur — `POST /users`.
///
/// Les rôles sont chargés depuis `GET /roles`, les commissariats depuis
/// `GET /commissariats`.
class VueNouveauUtilisateur extends StatefulWidget {
  const VueNouveauUtilisateur({super.key});

  @override
  State<VueNouveauUtilisateur> createState() => _VueNouveauUtilisateurState();
}

class _VueNouveauUtilisateurState extends State<VueNouveauUtilisateur> {
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _postnom = TextEditingController();
  final _prenom = TextEditingController();
  final _email = TextEditingController();
  final _telephone = TextEditingController();
  final _password = TextEditingController();
  final _matricule = TextEditingController();
  final _grade = TextEditingController();

  List<Map<String, dynamic>> _rolesDisponibles = [];
  List<Commissariat> _commissariats = [];
  final Set<String> _rolesChoisis = {'policier'};
  int? _idCommissariat;
  String? _genre;
  DateTime? _naissance;
  bool _chargement = true;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _chargerReferentiels();
  }

  Future<void> _chargerReferentiels() async {
    try {
      final r = await Future.wait([
        MetaService.instance.roles(),
        CommissariatService.instance.commissariats(),
      ]);
      _rolesDisponibles = r[0].cast<Map<String, dynamic>>();
      _commissariats = r[1].cast<Commissariat>();
    } catch (_) {
      // Les listes resteront vides : le formulaire reste utilisable partiellement.
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nom,
      _postnom,
      _prenom,
      _email,
      _telephone,
      _password,
      _matricule,
      _grade,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_rolesChoisis.isEmpty) {
      notifier(context, message: 'Sélectionnez au moins un rôle.', succes: false);
      return;
    }
    setState(() => _enCours = true);
    try {
      await UtilisateurService.instance.creer(
        nom: _nom.text.trim(),
        postnom: _postnom.text.trim(),
        prenom: _prenom.text.trim(),
        email: _email.text.trim(),
        telephone: _telephone.text.trim(),
        password: _password.text,
        roles: _rolesChoisis.toList(),
        idCommissariat: _idCommissariat,
        matriculePolice: _matricule.text.trim(),
        gradePolice: _grade.text.trim(),
        genre: _genre,
        dateNaissance: _naissance,
      );
      if (!mounted) return;
      montrerSucces(context, 'Compte créé.');
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
      appBar: AppBar(title: const Text('Créer un compte')),
      body: _chargement
          ? const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
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
                            hint: '—',
                            options: const [
                              OptionSelecteur(valeur: 'M', libelle: 'Masculin'),
                              OptionSelecteur(valeur: 'F', libelle: 'Féminin'),
                              OptionSelecteur(valeur: 'Autre', libelle: 'Autre'),
                            ],
                            onChanged: (v) => setState(() => _genre = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SelecteurDate(
                            libelle: 'Naissance',
                            valeur: _naissance,
                            onChanged: (v) => setState(() => _naissance = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),

                    const Text('Coordonnées',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
                    ChampMotDePasse(
                      libelle: 'Mot de passe provisoire',
                      controller: _password,
                      hint: '8 caractères, lettre + chiffre',
                      afficherIndicateur: true,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 26),

                    const Text('Rattachement',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text(
                      'Rôles attribués',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final r in _rolesDisponibles)
                          FilterChip(
                            label: Text('${r['nom'] ?? ''}'),
                            selected: _rolesChoisis.contains('${r['nom'] ?? ''}'),
                            onSelected: (ok) => setState(() {
                              final nom = '${r['nom'] ?? ''}';
                              ok ? _rolesChoisis.add(nom) : _rolesChoisis.remove(nom);
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // L'administrateur voit les permissions correspondantes.
                    ApercuRoles(
                      rolesChoisis: _rolesChoisis.toList()..sort(),
                      rolesDisponibles: _rolesDisponibles,
                    ),
                    if (_rolesDisponibles.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Référentiel des rôles indisponible.',
                          style: TextStyle(fontSize: 12, color: AppCouleurs.texteSecondaire),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Selecteur<int>(
                      libelle: 'Commissariat',
                      valeur: _idCommissariat,
                      hint: 'Aucun (facultatif)',
                      icone: Icons.local_police_outlined,
                      options: [
                        for (final c in _commissariats)
                          OptionSelecteur(valeur: c.id, libelle: c.nom),
                      ],
                      onChanged: (v) => setState(() => _idCommissariat = v),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ChampTexte(
                            libelle: 'Matricule',
                            controller: _matricule,
                            icone: Icons.pin_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChampTexte(
                            libelle: 'Grade',
                            controller: _grade,
                            icone: Icons.military_tech_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    BoutonPrincipal(
                      texte: 'Créer le compte',
                      icone: Icons.person_add_alt_1_outlined,
                      enCharge: _enCours,
                      onPressed: _enCours ? null : _enregistrer,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
