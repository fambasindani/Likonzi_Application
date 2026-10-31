import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../components/badge.dart';
import '../../models/alerte.dart';
import '../../providers/carte_provider.dart';
import '../../services/config_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/formatage.dart';
import '../alertes/alerte_detail_view.dart';
import '../commissariats/commissariats_view.dart';
import '../../components/carte_conteneur.dart';
import '../../services/alerte_service.dart';
import '../../models/geographie.dart';
import '../../services/geo_service.dart';
import 'positions_view.dart';
import '../../services/api_client.dart';
import '../../utils/messages.dart';

/// Carte des alertes et commissariats autour de moi.
class VueCarte extends StatefulWidget {
  const VueCarte({super.key});

  @override
  State<VueCarte> createState() => _VueCarteState();
}

class _VueCarteState extends State<VueCarte> {
  final MapController _controleurCarte = MapController();
  /// Hauteur du bandeau d'alertes : contenu (≈104 px) + marge.
  static const double _hauteurBandeAlertes = 130;

  double _rayon = 15;
  bool _afficherAlertes = true;
  bool _afficherCommissariats = true;
  bool _afficherAgents = false;
  List<Localisation> _agents = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialiser());
  }

  Future<void> _initialiser() async {
    final carte = context.read<CarteProvider>();
    await carte.localiserAppareil();
    if (!mounted) return;

    // GET /positions/moi : dernière position connue côté serveur, à défaut de GPS.
    try {
      final enregistree = await GeoService.instance.maPosition();
      if (mounted && carte.position == null && enregistree != null) {
        carte.deplacerCentre(LatLng(enregistree.latitude, enregistree.longitude));
      }
    } catch (_) {
      // Non bloquant : la carte s'ouvre sur le centre par défaut.
    }

    if (!mounted) return;
    await carte.chargerAutour(rayonKm: _rayon);
    if (_afficherAgents) await _chargerAgents();
  }

  /// GET /positions?vue=derniere : dernière position de chaque agent.
  Future<void> _chargerAgents() async {
    try {
      final agents = await GeoService.instance.cartographie(jours: 7);
      if (mounted) setState(() => _agents = agents);
    } on ExceptionApi catch (e) {
      if (mounted) setState(() => _agents = []);
      if (mounted) notifier(context, message: e.message, succes: false);
    } catch (_) {
      if (mounted) setState(() => _agents = []);
    }
  }

  Future<void> _changerRayon(double valeur) async {
    setState(() => _rayon = valeur);
    await context.read<CarteProvider>().chargerAutour(rayonKm: valeur);
  }

  void _recentrer() {
    final centre = context.read<CarteProvider>().pointCentral;
    _controleurCarte.move(centre, 14.5);
  }

  @override
  void dispose() {
    _controleurCarte.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final carte = context.watch<CarteProvider>();
    final centre = carte.pointCentral;

    final marqueurs = <Marker>[
      if (carte.position != null)
        Marker(
          point: LatLng(carte.position!.latitude, carte.position!.longitude),
          width: 52,
          height: 52,
          child: const _MarqueurMoi(),
        ),
      if (_afficherCommissariats)
        for (final c in carte.commissariats.where((c) => c.aCoordonnees))
          Marker(
            point: LatLng(c.latitude!, c.longitude!),
            width: 44,
            height: 44,
            child: Tooltip(
              message: '${c.nom}\n${Formatage.distance(c.distanceKm ?? 0)}',
              child: const Icon(Icons.local_police, color: AppCouleurs.bleu, size: 34),
            ),
          ),
      if (_afficherAgents)
        for (final ag in _agents)
          Marker(
            point: LatLng(ag.latitude, ag.longitude),
            width: 44,
            height: 44,
            child: Tooltip(
              message: [ag.nom, ag.prenom].where((e) => e != null).join(' '),
              child: Container(
                decoration: BoxDecoration(
                  color: AppCouleurs.bleu,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppCouleurs.blanc, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppCouleurs.bleu.withValues(alpha: 0.45),
                      blurRadius: 8,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  Formatage.initiales(ag.nom, ag.prenom),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppCouleurs.blanc,
                  ),
                ),
              ),
            ),
          ),
      if (_afficherAlertes)
        for (final a in carte.alertesProches)
          Marker(
            point: LatLng(
              a.alerte.latitude ?? centre.latitude,
              a.alerte.longitude ?? centre.longitude,
            ),
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: () => _detailsAlerte(a),
              child: Icon(
                Icons.location_pin,
                color: AppCouleurs.urgence(a.alerte.niveauUrgence),
                size: 40,
              ),
            ),
          ),
    ];

    return Scaffold(
      body: Stack(
      children: [
        FlutterMap(
          mapController: _controleurCarte,
          options: MapOptions(
            initialCenter: centre,
            initialZoom: carte.position != null ? 14.5 : 11,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, __) {},
          ),
          children: [
            TileLayer(
              urlTemplate: ConfigService.tuileUrl,
              userAgentPackageName: 'cd.securite.securite',
              subdomains: const ['a', 'b', 'c'],
            ),
            MarkerLayer(markers: marqueurs),
            if (carte.alertesProches.isNotEmpty || carte.commissariats.isNotEmpty)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: centre,
                    radius: _rayon * 1000,
                    useRadiusInMeter: true,
                    color: AppCouleurs.bleu.withValues(alpha: 0.08),
                    borderColor: AppCouleurs.bleu.withValues(alpha: 0.35),
                    borderStrokeWidth: 1.4,
                  ),
                ],
              ),
          ],
        ),

        // --------------------------------------------------- panneau supérieur
        Positioned(
          top: 8,
          left: 12,
          right: 12,
          child: Column(
            children: [
              CarteConteneur(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ombre: true,
                enfant: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Row(
                      children: [
                        const Icon(Icons.tune, size: 17, color: AppCouleurs.bleu),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Rayon de recherche',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          Formatage.distance(_rayon),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppCouleurs.bleu,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _rayon,
                      min: 1,
                      max: 60,
                      divisions: 59,
                      label: Formatage.distance(_rayon),
                      onChanged: (v) => setState(() => _rayon = v),
                      onChangeEnd: _changerRayon,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _FiltreCarte(
                                  libelle: 'Alertes',
                                  icone: Icons.warning_amber_outlined,
                                  actif: _afficherAlertes,
                                  valeur: carte.alertesProches.length,
                                  onChanged: (v) => setState(() => _afficherAlertes = v),
                                ),
                                const SizedBox(width: 8),
                                _FiltreCarte(
                                  libelle: 'Agents',
                                  icone: Icons.badge_outlined,
                                  actif: _afficherAgents,
                                  valeur: _agents.length,
                                  onChanged: (v) {
                                    setState(() => _afficherAgents = v);
                                    if (v) _chargerAgents();
                                  },
                                ),
                                const SizedBox(width: 8),
                                _FiltreCarte(
                                  libelle: 'Commissariats',
                                  icone: Icons.local_police_outlined,
                                  actif: _afficherCommissariats,
                                  valeur: carte.commissariats.length,
                                  onChanged: (v) => setState(() => _afficherCommissariats = v),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Historique des positions',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const VuePositions()),
                          ),
                          icon: const Icon(Icons.history, size: 20),
                        ),
                        IconButton(
                          tooltip: 'Ma position',
                          onPressed: carte.positionEnCours
                              ? null
                              : () async {
                                  final provider = context.read<CarteProvider>();
                                  await provider.localiserAppareil(forcer: true);
                                  if (!mounted) return;
                                  _recentrer();
                                  await provider.chargerAutour(rayonKm: _rayon);
                                },
                          icon: const Icon(Icons.my_location, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ------------------------------------------------- états & actions
        if (carte.chargement)
          const Positioned(
            top: 170,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
            ),
          ),

        if (carte.erreur != null)
          Positioned(
            top: 160,
            left: 24,
            right: 24,
            child: BandeauInfo(type: 'attention', message: carte.erreur!),
          ),

        // ------------------------------------------- bandeau d'alertes (bas)
        if (carte.alertesProches.isNotEmpty)
          Positioned(
            left: 12,
            right: 12,
            bottom: 24,
            child: SizedBox(
              height: _hauteurBandeAlertes,
              child: ScrollConfiguration(
                behavior: const _SansBarreDefilement(),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: carte.alertesProches.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final proche = carte.alertesProches[index];
                    return SizedBox(
                      width: 268,
                      child: _CarteAlerteProche(
                        alerte: proche.alerte,
                        distance: proche.distanceKm,
                        onTap: () => _detailsAlerte(proche),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

        Positioned(
          right: 14,
          bottom: 24,
          child: Column(
            children: [
              _BoutonCarte(icone: Icons.add, onPressed: () => _zoomer(1)),
              const SizedBox(height: 10),
              _BoutonCarte(icone: Icons.remove, onPressed: () => _zoomer(-1)),
              const SizedBox(height: 10),
              _BoutonCarte(
                icone: Icons.local_police_outlined,
                couleur: AppCouleurs.bleu,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VueCommissariats()),
                ),
              ),
            ],
          ),
        ),

      ],
    ),
    );
  }

  void _zoomer(double delta) {
    final camera = _controleurCarte.camera;
    _controleurCarte.move(camera.center, (camera.zoom + delta).clamp(1.0, 19.0));
  }

  void _detailsAlerte(AlerteProche proche) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VueDetailAlerte(alerte: proche.alerte)),
    );
  }
}

class _BoutonCarte extends StatelessWidget {
  const _BoutonCarte({
    required this.icone,
    required this.onPressed,
    this.couleur = AppCouleurs.blanc,
  });

  final IconData icone;
  final VoidCallback onPressed;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: couleur,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            icone,
            size: 22,
            color: couleur == AppCouleurs.bleu ? AppCouleurs.blanc : AppCouleurs.bleu,
          ),
        ),
      ),
    );
  }
}

class _MarqueurMoi extends StatelessWidget {
  const _MarqueurMoi();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: AppCouleurs.bleu,
          shape: BoxShape.circle,
          border: Border.all(color: AppCouleurs.blanc, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppCouleurs.bleu.withValues(alpha: 0.5),
              blurRadius: 10,
              spreadRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltreCarte extends StatelessWidget {
  const _FiltreCarte({
    required this.libelle,
    required this.icone,
    required this.actif,
    required this.valeur,
    required this.onChanged,
  });

  final String libelle;
  final IconData icone;
  final bool actif;
  final int valeur;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!actif),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: actif ? AppCouleurs.bleuPastel : AppCouleurs.blancCasse,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 15, color: actif ? AppCouleurs.bleu : AppCouleurs.grisBleu),
            const SizedBox(width: 5),
            Text(
              '$libelle ($valeur)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: actif ? AppCouleurs.bleu : AppCouleurs.grisBleu,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarteAlerteProche extends StatelessWidget {
  const _CarteAlerteProche({
    required this.alerte,
    required this.distance,
    required this.onTap,
  });

  final Alerte alerte;
  final double distance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CarteConteneur(
      onTap: onTap,
      ombre: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      bordure: AppCouleurs.urgence(alerte.niveauUrgence).withValues(alpha: 0.5),
      // Contenu cadré : sans `Spacer` et avec la date portée par l'en-tête,
      // la carte reste sous la hauteur de la liste (sinon Flutter dessine la
      // barre striée de débordement — « la ligne » visible sous la carte).
      enfant: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BadgeUrgence(niveau: alerte.niveauUrgence, compact: true),
              const Spacer(),
              Text(
                Formatage.distance(distance),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppCouleurs.bleu,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Formatage.relative(alerte.dateAlerte),
                style: const TextStyle(fontSize: 11, color: AppCouleurs.gris),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            alerte.typeLibelle ?? 'Alerte',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            alerte.contenu,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, height: 1.3, color: AppCouleurs.texteSecondaire),
          ),
        ],
      ),
    );
  }
}

/// Supprime la barre de défilement du bandeau horizontal (une fine ligne
/// apparaissait sous les cartes dès le défilement).
class _SansBarreDefilement extends ScrollBehavior {
  const _SansBarreDefilement();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
