import 'package:flutter/material.dart';

import '../../components/carte_conteneur.dart';
import '../../components/liste.dart';
import '../../services/api_client.dart';
import '../../services/meta_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/formatage.dart';
import '../../components/badge.dart';

/// Journal d'audit (permission `audit.lire`) — `GET /audit`.
class VueAudit extends StatefulWidget {
  const VueAudit({super.key});

  @override
  State<VueAudit> createState() => _VueAuditState();
}

class _VueAuditState extends State<VueAudit> {
  final MetaService _meta = MetaService.instance;
  final _filtre = TextEditingController();

  List<Map<String, dynamic>> _entrees = [];
  int _page = 1;
  int _pages = 0;
  int _total = 0;
  bool _chargement = true;
  bool _chargePlus = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _filtre.dispose();
    super.dispose();
  }

  Future<void> _charger({int page = 1}) async {
    setState(() {
      if (page == 1) _chargement = true;
      _erreur = null;
    });
    try {
      final resultat = await _meta.audit(
        page: page,
        action: _filtre.text.trim(),
      );
      setState(() {
        _entrees = page == 1 ? resultat.elements : [..._entrees, ...resultat.elements];
        _page = resultat.page;
        _pages = resultat.pages;
        _total = resultat.total;
      });
    } on ExceptionApi catch (e) {
      setState(() => _erreur = e.message);
    } catch (_) {
      setState(() => _erreur = 'Impossible de charger le journal.');
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _pageSuivante() async {
    if (_chargePlus || _page >= _pages) return;
    setState(() => _chargePlus = true);
    await _charger(page: _page + 1);
    if (mounted) setState(() => _chargePlus = false);
  }

  IconData _icone(String action) => switch (action) {
        'connexion' || 'connexion_echec' => Icons.login_outlined,
        'inscription' => Icons.person_add_alt_outlined,
        'alerte_creee' || 'alerte_prise_en_charge' => Icons.notifications_active_outlined,
        'cas_cree' || 'cas_maj' => Icons.folder_special_outlined,
        'preuve_televersee' => Icons.attach_file,
        'objet_declare' || 'objet_statut' => Icons.search,
        'suppression_compte' => Icons.person_off_outlined,
        'changement_mdp' || 'reset_mdp' => Icons.lock_reset_outlined,
        _ => Icons.history_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journal d’audit')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _filtre,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _charger(),
              decoration: InputDecoration(
                hintText: 'Filtrer par action (ex. alerte_creee)…',
                prefixIcon: const Icon(Icons.filter_alt_outlined, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, size: 20),
                  onPressed: () => _charger(),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Flexible(
                  child: BadgeSimple(texte: '$_total entrée(s)', icone: Icons.list_alt),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _charger(),
                  child: const Text('Actualiser'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _chargement && _entrees.isEmpty
                ? const EtatChargement()
                : _erreur != null && _entrees.isEmpty
                    ? EtatErreur(message: _erreur!, onReessayer: () => _charger())
                    : _entrees.isEmpty
                        ? const EtatVide(
                            icone: Icons.receipt_long_outlined,
                            titre: 'Journal vide',
                            message: 'Aucune action enregistrée pour ce filtre.',
                          )
                        : RefreshIndicator(
                            onRefresh: () => _charger(),
                            color: AppCouleurs.bleu,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: _entrees.length + (_page < _pages ? 1 : 0),
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                if (index >= _entrees.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    child: _chargePlus
                                        ? const Center(
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(strokeWidth: 2.5),
                                            ),
                                          )
                                        : TextButton(
                                            onPressed: _pageSuivante,
                                            child: const Text('Charger plus'),
                                          ),
                                  );
                                }
                                final e = _entrees[index];
                                final action = '${e['action'] ?? ''}';
                                return CarteConteneur(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  enfant: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        _icone(action),
                                        size: 19,
                                        color: action.contains('echec')
                                            ? AppCouleurs.rouge
                                            : AppCouleurs.bleu,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              action,
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${e['entite'] ?? ''}'
                                              '${e['entite_id'] != null ? ' #${e['entite_id']}' : ''}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppCouleurs.grisBleu,
                                              ),
                                            ),
                                            if (e['description'] != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                '${e['description']}',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 12.5),
                                              ),
                                            ],
                                            const SizedBox(height: 6),
                                            Text(
                                              [
                                                if (e['user_id'] != null)
                                                  'utilisateur #${e['user_id']}',
                                                if (e['ip_address'] != null) '${e['ip_address']}',
                                                Formatage.dateTime(
                                                    DateTime.tryParse('${e['created_at'] ?? ''}')),
                                              ].join(' · '),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppCouleurs.gris,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
