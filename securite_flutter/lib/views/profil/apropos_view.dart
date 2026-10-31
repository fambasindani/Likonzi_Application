import 'package:flutter/material.dart';

import '../../components/carte_conteneur.dart';
import '../../components/liste.dart';
import '../../services/api_client.dart';
import '../../services/config_service.dart';
import '../../services/meta_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/formatage.dart';

/// « À propos » : santé du service, configuration serveur, routes d'auth.
///
/// Consomme `GET /health`, `GET /config-public` et `GET /auth/_schema`.
class VueAPropos extends StatefulWidget {
  const VueAPropos({super.key});

  @override
  State<VueAPropos> createState() => _VueAProposState();
}

class _VueAProposState extends State<VueAPropos> {
  final MetaService _meta = MetaService.instance;

  Map<String, dynamic> _sante = {};
  Map<String, dynamic> _configServeur = {};
  List<Map<String, dynamic>> _routes = [];
  bool _chargement = true;
  String? _erreur;

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
      final resultats = await Future.wait([
        _meta.health(),
        _meta.configPublic(),
        _meta.schemaAuth(),
      ]);
      _sante = resultats[0] as Map<String, dynamic>;
      _configServeur = resultats[1] as Map<String, dynamic>;
      _routes = (resultats[2] as List).cast<Map<String, dynamic>>();
    } on ExceptionApi catch (e) {
      _erreur = e.message;
    } catch (_) {
      _erreur = 'Impossible de contacter le serveur.';
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseOk = _sante['base_de_donnees'] == 'up';

    return Scaffold(
      appBar: AppBar(
        title: const Text('À propos'),
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
              : RefreshIndicator(
                  onRefresh: _charger,
                  color: AppCouleurs.bleu,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      // ------------------------------------------------- identité
                      CarteConteneur(
                        enfant: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: AppCouleurs.bleuPastel,
                                shape: BoxShape.circle,
                              ),
                              child: Image.asset(
                                'assets/logo.png',
                                width: 56,
                                height: 56,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.shield_moon_outlined,
                                  size: 46,
                                  color: AppCouleurs.bleu,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              ConfigService.nomApp,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              ConfigService.slogan,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppCouleurs.texteSecondaire,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // -------------------------------------------------- santé
                      CarteConteneur(
                        enfant: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  baseOk ? Icons.check_circle : Icons.error,
                                  color: baseOk ? AppCouleurs.vert : AppCouleurs.rouge,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  baseOk ? 'Service opérationnel' : 'Service dégradé',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: baseOk ? AppCouleurs.vert : AppCouleurs.rouge,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'v2.1.0',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppCouleurs.grisBleu,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _LigneCleValeur(
                              cle: 'Base de données',
                              valeur: _sante['base_de_donnees']?.toString() ?? '—',
                            ),
                            _LigneCleValeur(
                              cle: 'Utilisateurs enregistrés',
                              valeur: _sante['utilisateurs']?.toString() ?? '—',
                            ),
                            _LigneCleValeur(
                              cle: 'Uptime',
                              valeur: Formatage.duree(
                                ((_sante['uptime_secondes'] as num?) ?? 0).toInt() ~/ 60,
                              ),
                            ),
                            _LigneCleValeur(
                              cle: 'Python',
                              valeur: _sante['python']?.toString() ?? '—',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ------------------------------------------------- config
                      CarteConteneur(
                        enfant: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CONFIGURATION',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 0.7,
                                fontWeight: FontWeight.w800,
                                color: AppCouleurs.grisBleu,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Côté application (.env)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            for (final e in ConfigService.resume().entries)
                              _LigneCleValeur(cle: e.key, valeur: e.value),
                            const SizedBox(height: 12),
                            const Text(
                              'Côté serveur (/config-public)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            for (final e in _configServeur.entries)
                              _LigneCleValeur(cle: e.key, valeur: '${e.value}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // --------------------------------------------- routes auth
                      CarteConteneur(
                        enfant: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.route, size: 17, color: AppCouleurs.bleu),
                                const SizedBox(width: 8),
                                Text(
                                  'ROUTES D’AUTHENTIFICATION (${_routes.length})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 0.7,
                                    fontWeight: FontWeight.w800,
                                    color: AppCouleurs.grisBleu,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            for (final r in _routes)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 54,
                                      padding: const EdgeInsets.symmetric(vertical: 3),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _couleurMethode('${r['methode']}'),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${r['methode']}',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppCouleurs.blanc,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${r['chemin']}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
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
                    ],
                  ),
                ),
    );
  }

  Color _couleurMethode(String methode) => switch (methode) {
        'POST' => AppCouleurs.vert,
        'GET' => AppCouleurs.bleu,
        'PATCH' || 'PUT' => AppCouleurs.orange,
        'DELETE' => AppCouleurs.rouge,
        _ => AppCouleurs.grisBleu,
      };
}

class _LigneCleValeur extends StatelessWidget {
  const _LigneCleValeur({required this.cle, required this.valeur});

  final String cle;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              cle,
              style: const TextStyle(fontSize: 13, color: AppCouleurs.texteSecondaire),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              valeur,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
