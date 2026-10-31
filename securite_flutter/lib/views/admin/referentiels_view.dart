import 'package:flutter/material.dart';

import '../../components/carte_conteneur.dart';
import '../../components/liste.dart';
import '../../services/api_client.dart';
import '../../services/meta_service.dart';
import '../../services/utilisateur_service.dart';
import '../../theme/couleurs.dart';
import '../../components/avatar.dart';
import '../../components/badge.dart';
import '../../components/bouton.dart';

/// Référentiels métier (admin) :
/// `GET /type-alertes`, `GET /type-objets`, `GET /roles`, `GET /permissions`.
class VueReferentiels extends StatefulWidget {
  const VueReferentiels({super.key, this.ongletInitial = 0});

  /// Onglet ouvert au démarrage (0 alertes, 1 objets, 2 rôles, 3 permissions).
  final int ongletInitial;

  @override
  State<VueReferentiels> createState() => _VueReferentielsState();
}

class _VueReferentielsState extends State<VueReferentiels> {
  final MetaService _meta = MetaService.instance;

  List<Map<String, dynamic>> _typeAlertes = [];
  List<Map<String, dynamic>> _typeObjets = [];
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _permissions = [];

  bool _chargement = true;
  String? _erreur;
  late int _onglet = widget.ongletInitial;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final r = await Future.wait([
        _meta.typeAlertes(),
        _meta.typeObjets(),
        _meta.roles(),
        UtilisateurService.instance.permissions(),
      ]);
      _typeAlertes = r[0].cast<Map<String, dynamic>>();
      _typeObjets = r[1].cast<Map<String, dynamic>>();
      _roles = r[2].cast<Map<String, dynamic>>();
      _permissions = r[3].cast<Map<String, dynamic>>();
    } on ExceptionApi catch (e) {
      _erreur = e.message;
    } catch (_) {
      _erreur = 'Impossible de charger les référentiels.';
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Référentiels'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _charger,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _chargement
          ? const EtatChargement()
          : _erreur != null
              ? EtatErreur(message: _erreur!, onReessayer: _charger)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: Segment(
                        libelles: const ['Alertes', 'Objets', 'Rôles', 'Permissions'],
                        selection: _onglet,
                        onChanged: (i) => setState(() => _onglet = i),
                      ),
                    ),
                    Expanded(
                      child: switch (_onglet) {
                        0 => _listeGeneree(
                            _typeAlertes,
                            (e) => '${e['code'] ?? ''}',
                            (e) => '${e['contenu'] ?? ''}',
                            (e) => '${e['niveau_urgence_defaut'] ?? ''}',
                            Icons.notifications_active_outlined,
                          ),
                        1 => _listeGeneree(
                            _typeObjets,
                            (e) => '${e['code'] ?? ''}',
                            (e) => '${e['description'] ?? ''}',
                            (e) => (e['statut'] == true || e['statut'] == 1)
                                ? 'actif'
                                : 'inactif',
                            Icons.inventory_2_outlined,
                          ),
                        2 => _listeRoles(),
                        _ => _listePermissions(),
                      },
                    ),
                  ],
                ),
    );
  }

  Widget _listeGeneree(
    List<Map<String, dynamic>> elements,
    String Function(Map<String, dynamic>) code,
    String Function(Map<String, dynamic>) libelle,
    String Function(Map<String, dynamic>) info,
    IconData icone,
  ) {
    if (elements.isEmpty) {
      return const EtatVide(
        icone: Icons.folder_copy_outlined,
        titre: 'Référentiel vide',
      );
    }
    return RefreshIndicator(
      onRefresh: _charger,
      color: AppCouleurs.bleu,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: elements.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final e = elements[index];
          return CarteConteneur(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enfant: Row(
              children: [
                IconeDomaine(icone: icone, taille: 38, tailleIcone: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        libelle(e),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        code(e),
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: AppCouleurs.grisBleu,
                        ),
                      ),
                    ],
                  ),
                ),
                BadgeSimple(texte: info(e), compact: true),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _listeRoles() {
    if (_roles.isEmpty) {
      return const EtatVide(icone: Icons.security_outlined, titre: 'Aucun rôle');
    }
    return RefreshIndicator(
      onRefresh: _charger,
      color: AppCouleurs.bleu,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _roles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final r = _roles[index];
          // `GET /roles` renvoie les permissions comme une liste de CHAÎNES
          // (codes) : un cast vers Map plantait l'écran (page rouge).
          final perms = (r['permissions'] as List? ?? const [])
              .map((p) => (p is Map ? '${p['code'] ?? ''}' : '$p').trim())
              .where((p) => p.isNotEmpty)
              .toList();
          return CarteConteneur(
            enfant: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconeDomaine(
                      icone: Icons.verified_user_outlined,
                      couleur: AppCouleurs.bleu,
                      taille: 38,
                      tailleIcone: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r['nom'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (r['description'] != null)
                            Text(
                              '${r['description']}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppCouleurs.texteSecondaire,
                              ),
                            ),
                        ],
                      ),
                    ),
                    BadgeSimple(texte: '${perms.length} perm.', compact: true),
                  ],
                ),
                if (perms.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in perms.take(8))
                        BadgeSimple(texte: p, compact: true, couleur: AppCouleurs.bleu),
                      if (perms.length > 8)
                        BadgeSimple(
                          texte: '+${perms.length - 8}',
                          compact: true,
                          couleur: AppCouleurs.grisBleu,
                          fond: AppCouleurs.clair,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _listePermissions() {
    if (_permissions.isEmpty) {
      return const EtatVide(icone: Icons.lock_outlined, titre: 'Aucune permission');
    }
    final parModule = <String, List<Map<String, dynamic>>>{};
    for (final p in _permissions) {
      final module = '${p['module'] ?? 'autre'}';
      parModule.putIfAbsent(module, () => []).add(p);
    }
    final modules = parModule.keys.toList()..sort();
    return RefreshIndicator(
      onRefresh: _charger,
      color: AppCouleurs.bleu,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (final module in modules) ...[
            TitreSection(
              titre: module.toUpperCase(),
              icone: Icons.folder_outlined,
              padding: const EdgeInsets.only(bottom: 6),
            ),
            CarteConteneur(
              padding: const EdgeInsets.all(12),
              enfant: Column(
                children: [
                  for (final p in parModule[module]!)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              size: 16, color: AppCouleurs.vert),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${p['code'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}
