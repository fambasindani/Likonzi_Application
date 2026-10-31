import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/avatar.dart';
import '../../components/bouton.dart';
import '../../components/carte_conteneur.dart';
import '../../components/champ_texte.dart';
import '../../components/apercu_roles.dart';
import '../../components/liste.dart';
import '../../models/utilisateur.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/meta_service.dart';
import '../../services/utilisateur_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/formatage.dart';
import '../../utils/messages.dart';
import 'utilisateurs_view.dart';
import '../../components/badge.dart';

/// Fiche d'un compte : `GET/PATCH/DELETE /users/<id>`,
/// `PUT /users/<id>/roles`, `POST /users/<id>/statut`.
class VueDetailUtilisateur extends StatefulWidget {
  const VueDetailUtilisateur({super.key, required this.utilisateur});

  final Utilisateur utilisateur;

  @override
  State<VueDetailUtilisateur> createState() => _VueDetailUtilisateurState();
}

class _VueDetailUtilisateurState extends State<VueDetailUtilisateur> {
  final UtilisateurService _service = UtilisateurService.instance;
  late Utilisateur _u;
  List<Map<String, dynamic>> _rolesDisponibles = [];
  final Set<String> _rolesChoisis = {};

  /// L'édition des rôles est réservée au super administrateur (cf. backend).
  bool get _peutEditerRoles => _acteur?.aRole('super_admin') ?? false;
  Utilisateur? _acteur;
  bool _enCours = false;
  bool _modifications = false;

  @override
  void initState() {
    super.initState();
    _u = widget.utilisateur;
    _rolesChoisis.addAll(_u.roles);
    _acteur = context.read<AuthProvider>().utilisateur;
    _chargerRoles();
    _rafraichir();
  }

  Future<void> _chargerRoles() async {
    try {
      final roles = await MetaService.instance.roles();
      if (mounted) setState(() => _rolesDisponibles = roles);
    } catch (_) {
      // Référentiel indisponible : on garde les rôles courants.
    }
  }

  Future<void> _rafraichir() async {
    try {
      final maj = await _service.detail(_u.id);
      if (mounted) {
        setState(() {
          _u = maj;
          _rolesChoisis
            ..clear()
            ..addAll(maj.roles);
        });
      }
    } catch (_) {
      // Conserve l'affichage courant.
    }
  }

  Future<void> _agir(Future<void> Function() action, {String succes = 'Mis à jour.'}) async {
    setState(() => _enCours = true);
    try {
      await action();
      await _rafraichir();
      if (mounted) montrerSucces(context, succes);
    } on ExceptionApi catch (e) {
      if (mounted) montrerErreur(context, e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _enregistrerRoles() async {
    await _agir(
      () => _service.attribuerRoles(_u.id, _rolesChoisis.toList()),
      succes: 'Rôles mis à jour.',
    );
  }

  Future<void> _changerStatut() async {
    final choix = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppCouleurs.blanc,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text('Changer le statut',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            for (final s in ['actif', 'suspendu', 'bloque', 'inactif'])
              ListTile(
                leading: BadgeStatutRef(statut: s),
                title: Text(s),
                trailing: s == _u.statut ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(s),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choix == null || choix == _u.statut || !mounted) return;
    await _agir(
      () => _service.changerStatut(_u.id, choix),
      succes: 'Statut : $choix.',
    );
  }

  Future<void> _supprimer() async {
    final confirme = await confirmer(
      context,
      titre: 'Supprimer ce compte ?',
      message:
          'Suppression douce : les alertes, dossiers et preuves rattachés sont conservés.',
      libelleValider: 'Supprimer',
      destructif: true,
      icone: Icons.person_off_outlined,
    );
    if (!confirme || !mounted) return;
    await _agir(() => _service.supprimer(_u.id), succes: 'Compte supprimé.');
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _modifierCoordonnees() async {
    final email = TextEditingController(text: _u.email);
    final tel = TextEditingController(text: _u.telephone);
    final matricule = TextEditingController(text: _u.matriculePolice ?? '');
    final grade = TextEditingController(text: _u.gradePolice ?? '');

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Modifier les coordonnées'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChampTexte(
                libelle: 'Adresse e-mail',
                controller: email,
                clavier: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              ChampTexte(
                libelle: 'Téléphone',
                controller: tel,
                clavier: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              ChampTexte(libelle: 'Matricule', controller: matricule),
              const SizedBox(height: 14),
              ChampTexte(libelle: 'Grade', controller: grade),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    await _agir(
      () => _service.modifier(_u.id, {
        'email': email.text.trim(),
        'telephone': tel.text.trim(),
        'matricule_police': matricule.text.trim(),
        'grade_police': grade.text.trim(),
      }),
      succes: 'Coordonnées mises à jour.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_modifications,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_modifications);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_u.nomComplet),
          actions: [
            IconButton(
              tooltip: 'Coordonnées',
              onPressed: _enCours ? null : _modifierCoordonnees,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Rafraîchir',
              onPressed: _rafraichir,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            CarteConteneur(
              enfant: Column(
                children: [
                  AvatarUtilisateur.noms(
                    nom: _u.nom,
                    prenom: _u.prenom,
                    url: _u.urlAvatar,
                    taille: 76,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _u.nomComplet,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _u.email,
                    style: const TextStyle(fontSize: 13.5, color: AppCouleurs.texteSecondaire),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatage.telephone(_u.telephone),
                    style: const TextStyle(fontSize: 13.5, color: AppCouleurs.texteSecondaire),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      BadgeStatutRef(statut: _u.statut),
                      if (_u.matriculePolice != null)
                        BadgeSimple(texte: _u.matriculePolice!, icone: Icons.pin_outlined),
                      if (_u.gradePolice != null) BadgeSimple(texte: _u.gradePolice!),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            TitreSection(
              titre: 'Rôles',
              icone: Icons.verified_user_outlined,
              padding: const EdgeInsets.only(bottom: 8),
            ),
            CarteConteneur(
              enfant: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_rolesDisponibles.isEmpty)
                    Text(
                      _rolesChoisis.isEmpty ? 'Aucun rôle attribué.' : _rolesChoisis.join(', '),
                      style: const TextStyle(fontSize: 14),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final r in _rolesDisponibles)
                          FilterChip(
                            label: Text('${r['nom'] ?? ''}'),
                            selected: _rolesChoisis.contains('${r['nom'] ?? ''}'),
                            onSelected: !_peutEditerRoles
                                ? null
                                : (ok) => setState(() {
                                      final nom = '${r['nom'] ?? ''}';
                                      ok
                                          ? _rolesChoisis.add(nom)
                                          : _rolesChoisis.remove(nom);
                                      _modifications = true;
                                    }),
                          ),
                      ],
                    ),
                  const SizedBox(height: 14),
                  // Permissions obtenues : le rôle choisi, et ce qu'il ouvre.
                  ApercuRoles(
                    rolesChoisis: _rolesChoisis.toList()..sort(),
                    rolesDisponibles: _rolesDisponibles,
                  ),
                  if (!_peutEditerRoles) ...[
                    const SizedBox(height: 10),
                    const BandeauInfoLectureSeule(
                      message:
                          'La modification des rôles est réservée au super administrateur.',
                    ),
                  ] else ...[
                    const SizedBox(height: 14),
                    BoutonPrincipal(
                      texte: 'Enregistrer les rôles',
                      icone: Icons.save_outlined,
                      enCharge: _enCours,
                      onPressed: _enCours
                          ? null
                          : () {
                              setState(() => _modifications = false);
                              _enregistrerRoles();
                            },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            CarteConteneur(
              enfant: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LigneInfo(cle: 'Identifiant', valeur: '#${_u.id}', premiere: true),
                  LigneInfo(
                    cle: 'Commissariat',
                    valeur: _u.commissariatNom ?? 'Non rattaché',
                    icone: Icons.local_police_outlined,
                  ),
                  LigneInfo(
                    cle: 'Dernière connexion',
                    valeur: Formatage.relative(_u.derniereConnexion),
                    icone: Icons.schedule,
                  ),
                  LigneInfo(
                    cle: 'Inscrit le',
                    valeur: Formatage.date(
                        DateTime.tryParse(_u.toJson()['created_at']?.toString() ?? '')),
                    icone: Icons.calendar_today_outlined,
                  ),
                  LigneInfo(
                    cle: 'E-mail vérifié',
                    valeur: _u.emailVerifie ? 'Oui' : 'Non',
                    icone: Icons.verified_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            BoutonSecondaire(
              texte: _u.statut == 'actif' ? 'Suspendre le compte' : 'Réactiver le compte',
              icone: _u.statut == 'actif' ? Icons.block_outlined : Icons.check_circle_outline,
              onPressed: _enCours ? null : _changerStatut,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _enCours ? null : _supprimer,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Supprimer le compte'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppCouleurs.rouge,
                side: const BorderSide(color: AppCouleurs.rouge),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
