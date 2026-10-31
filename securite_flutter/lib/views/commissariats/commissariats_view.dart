import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../components/liste.dart';
import '../../components/selecteur.dart';
import '../../models/geographie.dart';
import '../../providers/carte_provider.dart';
import '../../services/api_client.dart';
import '../../services/dossier_service.dart';
import '../../services/geo_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/messages.dart';
import '../../components/carte_commissariat.dart';

/// Commissariats : autour de moi, ou filtrés par province / ville.
///
/// Consomme `GET /proximite/commissariats`, `GET /commissariats`,
/// `GET /provinces` et `GET /villes`.
class VueCommissariats extends StatefulWidget {
  const VueCommissariats({super.key});

  @override
  State<VueCommissariats> createState() => _VueCommissariatsState();
}

class _VueCommissariatsState extends State<VueCommissariats> {
  List<Commissariat> _elements = [];
  List<Province> _provinces = [];
  List<Ville> _villes = [];
  int? _idProvince;
  int? _idVille;
  bool _chargement = true;
  String? _erreur;
  bool _autourDeMoi = true;

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  Future<void> _demarrer() async {
    await _chargerProvinces();
    await _charger();
  }

  Future<void> _chargerProvinces() async {
    try {
      final provinces = await CommissariatService.instance.provinces();
      if (!mounted) return;
      setState(() => _provinces = provinces);
    } catch (_) {
      // Référentiel indisponible : les filtres resteront masqués.
    }
  }

  Future<void> _chargerVilles(int? idProvince) async {
    if (!mounted) return;
    if (idProvince == null) {
      setState(() => _villes = []);
      return;
    }
    try {
      final villes = await CommissariatService.instance.villes(idProvince: idProvince);
      if (!mounted) return;
      setState(() => _villes = villes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _villes = []);
    }
  }

  Future<void> _charger() async {
    if (!mounted) return;
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      if (_autourDeMoi && _idProvince == null) {
        final carte = context.read<CarteProvider>();
        await carte.localiserAppareil();
        final position = carte.position;
        if (position != null) {
          _elements = await GeoService.instance.commissariatsProches(
            latitude: position.latitude,
            longitude: position.longitude,
            rayonKm: 60,
            limite: 50,
          );
        } else {
          _autourDeMoi = false;
          _elements = await CommissariatService.instance.commissariats();
        }
      } else {
        final liste = await CommissariatService.instance.commissariats(
          idProvince: _idProvince,
        );
        _elements = _idVille == null
            ? liste
            : liste.where((c) => c.idVille == _idVille).toList(growable: false);
      }
    } on ExceptionApi catch (e) {
      _erreur = e.message;
    } catch (_) {
      _erreur = 'Impossible de charger les commissariats.';
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _appeler(Commissariat c) async {
    final numero = (c.telephone ?? '').replaceAll(RegExp(r'[^\d+]'), '');
    if (numero.isEmpty) {
      notifier(context, message: 'Aucun numéro renseigné pour ce commissariat.', succes: false);
      return;
    }
    final uri = Uri(scheme: 'tel', path: numero);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      montrerErreur(context, 'Impossible de passer l’appel.');
    }
  }

  Future<void> _itineraire(Commissariat c) async {
    if (!c.aCoordonnees) {
      _repliItineraire(c, 'Aucune position GPS pour ce commissariat.');
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${c.latitude},${c.longitude}',
    );
    try {
      // `canLaunchUrl` refuse parfois sur Android 11+ (visibilité des paquets) :
      // on tente directement l'ouverture et on se replie en cas d'échec.
      final ouvert = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ouvert && mounted) _repliItineraire(c, null);
    } catch (_) {
      if (mounted) _repliItineraire(c, null);
    }
  }

  /// Repli quand aucun navigateur/carte n'est disponible sur l'appareil.
  void _repliItineraire(Commissariat c, String? raison) {
    if (!mounted) return;
    final coord = c.aCoordonnees
        ? '${c.latitude}, ${c.longitude}'
        : 'coordonnées non disponibles';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ouvrir l’itinéraire'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (raison != null) ...[
              Text(raison,
                  style: const TextStyle(
                      fontSize: 13, color: AppCouleurs.texteSecondaire)),
              const SizedBox(height: 12),
            ],
            Text(c.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (c.adresse != null) ...[
              const SizedBox(height: 4),
              Text(c.adresse!,
                  style: const TextStyle(
                      fontSize: 13, color: AppCouleurs.texteSecondaire)),
            ],
            const SizedBox(height: 10),
            Text('Destination : $coord',
                style: const TextStyle(
                    fontSize: 13, fontFamily: 'monospace')),
            const SizedBox(height: 6),
            const Text(
              'Copiez ces informations dans votre application de cartes.',
              style: TextStyle(fontSize: 12.5, color: AppCouleurs.texteSecondaire),
            ),
          ],
        ),
        actions: [
          if (c.aCoordonnees)
            TextButton(
              onPressed: () async {
                final geo = Uri.parse('geo:${c.latitude},${c.longitude}');
                try {
                  await launchUrl(geo);
                } catch (_) {
                  // Aucune application de cartes : on laisse l'utilisateur copier.
                }
              },
              child: const Text('App cartes'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commissariats'),
        actions: [
          IconButton(
            tooltip: _autourDeMoi ? 'Filtrer par province' : 'Autour de moi',
            onPressed: () {
              setState(() {
                _autourDeMoi = !_autourDeMoi;
                if (_autourDeMoi) {
                  _idProvince = null;
                  _idVille = null;
                }
              });
              _charger();
            },
            icon: Icon(_autourDeMoi ? Icons.public : Icons.my_location),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_provinces.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Selecteur<int>(
                      libelle: 'Province',
                      valeur: _idProvince,
                      hint: 'Toutes',
                      icone: Icons.map_outlined,
                      options: [
                        for (final p in _provinces)
                          OptionSelecteur(valeur: p.id, libelle: p.nom),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _idProvince = v;
                          _idVille = null;
                          _autourDeMoi = false;
                        });
                        _chargerVilles(v);
                        _charger();
                      },
                    ),
                  ),
                  if (_villes.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Selecteur<int>(
                        libelle: 'Ville',
                        valeur: _idVille,
                        hint: 'Toutes',
                        icone: Icons.location_city_outlined,
                        options: [
                          for (final v in _villes)
                            OptionSelecteur(valeur: v.id, libelle: v.nom),
                        ],
                        onChanged: (v) {
                          setState(() => _idVille = v);
                          _charger();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(child: _corps()),
        ],
      ),
    );
  }

  Widget _corps() {
    if (_chargement) return const EtatChargement();
    if (_erreur != null) {
      return EtatErreur(message: _erreur!, onReessayer: _charger);
    }
    if (_elements.isEmpty) {
      return const EtatVide(
        icone: Icons.local_police_outlined,
        titre: 'Aucun commissariat',
        message: 'Aucun commissariat trouvé pour ce filtre.',
      );
    }
    return RefreshIndicator(
      onRefresh: _charger,
      color: AppCouleurs.bleu,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: _elements.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final c = _elements[index];
          return CarteCommissariat(
            commissariat: c,
            onAppeler: () => _appeler(c),
            onItineraire: () => _itineraire(c),
          );
        },
      ),
    );
  }
}
