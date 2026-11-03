import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../components/bouton.dart';
import '../../components/entete.dart';
import '../../components/liste.dart';
import '../../models/geographie.dart';
import '../../providers/carte_provider.dart';
import '../../services/api_client.dart';
import '../../services/config_service.dart';
import '../../services/geo_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/messages.dart';

/// Itinéraire « moi → commissariat le plus proche » affiché dans l'application :
/// ligne sur la carte, distance, appel et ouverture dans Google Maps.
class VueItineraire extends StatefulWidget {
  const VueItineraire({super.key, this.titre = 'Itinéraire police'});

  final String titre;

  @override
  State<VueItineraire> createState() => _VueItineraireState();
}

class _VueItineraireState extends State<VueItineraire> {
  Commissariat? _station;
  LatLng? _moi;
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _preparer());
  }

  Future<void> _preparer() async {
    final carte = context.read<CarteProvider>();
    if (carte.position == null) await carte.localiserAppareil();
    final position = carte.position;
    if (position == null) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = 'Position introuvable : activez la localisation.';
      });
      return;
    }
    _moi = LatLng(position.latitude, position.longitude);

    try {
      final proches = await GeoService.instance.commissariatsProches(
        latitude: position.latitude,
        longitude: position.longitude,
        rayonKm: 80,
        limite: 1,
      );
      if (!mounted) return;
      setState(() {
        _station = proches.isEmpty ? null : proches.first;
        _chargement = false;
        if (proches.isEmpty) _erreur = 'Aucun commissariat trouvé à proximité.';
      });
    } on ExceptionApi catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = 'Impossible de trouver le commissariat le plus proche.';
      });
    }
  }

  LatLng? get _pointStation {
    final s = _station;
    if (s == null || s.latitude == null || s.longitude == null) return null;
    return LatLng(s.latitude!, s.longitude!);
  }

  double get _distanceKm {
    final s = _station;
    final moi = _moi;
    final station = _pointStation;
    if (s == null || moi == null || station == null) return 0;
    if (s.distanceKm != null) return s.distanceKm!;
    return const Distance().as(LengthUnit.Kilometer, moi, station);
  }

  double get _zoom {
    final d = _distanceKm;
    if (d < 2) return 14.5;
    if (d < 8) return 13;
    if (d < 25) return 11.5;
    return 10;
  }

  LatLng get _centreCarte {
    final moi = _moi!;
    final station = _pointStation!;
    return LatLng((moi.latitude + station.latitude) / 2, (moi.longitude + station.longitude) / 2);
  }

  Future<void> _appeler() async {
    final numero = (_station?.telephone ?? '').replaceAll(RegExp(r'[^\d+]'), '');
    if (numero.isEmpty) return;
    try {
      await launchUrl(Uri(scheme: 'tel', path: numero));
    } catch (_) {
      if (mounted) montrerErreur(context, "Aucune application d'appel sur l'appareil.");
    }
  }

  Future<void> _ouvrirItineraireExterne() async {
    final moi = _moi;
    final station = _pointStation;
    if (moi == null || station == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${moi.latitude},${moi.longitude}'
      '&destination=${station.latitude},${station.longitude}'
      '&travelmode=driving',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) montrerErreur(context, "Impossible d'ouvrir Google Maps.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EntetePage(titre: widget.titre, icone: Icons.directions_outlined),
      body: SafeArea(
        child: _chargement
            ? const EtatChargement()
            : (_erreur != null || _moi == null || _pointStation == null)
                ? EtatErreur(message: _erreur ?? 'Itinéraire indisponible.', onReessayer: _preparer)
                : _carte(),
      ),
    );
  }

  Widget _carte() {
    final moi = _moi!;
    final station = _pointStation!;
    final s = _station!;

    return Column(
      children: [
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: _centreCarte,
              initialZoom: _zoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: ConfigService.tuileUrl,
                userAgentPackageName: 'cd.securite.securite',
                subdomains: const ['a', 'b', 'c'],
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [moi, station],
                    strokeWidth: 4.5,
                    color: AppCouleurs.bleu.withValues(alpha: 0.85),
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: moi,
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.person_pin_circle, color: AppCouleurs.bleu, size: 40),
                  ),
                  Marker(
                    point: station,
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.local_police, color: AppCouleurs.rouge, size: 36),
                  ),
                ],
              ),
            ],
          ),
        ),
        _panneau(s),
      ],
    );
  }

  Widget _panneau(Commissariat s) {
    final tel = (s.telephone ?? '').replaceAll(RegExp(r'[^\d+]'), '');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: const BoxDecoration(
        color: AppCouleurs.blanc,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: AppCouleurs.ombre, blurRadius: 12, offset: Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppCouleurs.rougePastel,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_police, color: AppCouleurs.rouge, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.nom,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                    ),
                    if (s.adresse != null && s.adresse!.isNotEmpty)
                      Text(
                        s.adresse!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: AppCouleurs.texteSecondaire),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppCouleurs.bleuPastel,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_distanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppCouleurs.bleu,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: BoutonPrincipal(
                  texte: "Ouvrir l'itinéraire",
                  icone: Icons.directions_outlined,
                  onPressed: _ouvrirItineraireExterne,
                ),
              ),
              if (tel.isNotEmpty) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 54,
                  child: BoutonSecondaire(
                    texte: '',
                    icone: Icons.call_outlined,
                    onPressed: _appeler,
                  ),
                ),
              ],
            ],
          ),
          if (tel.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                "Le trajet s'ouvre dans Google Maps (le commissariat n'a pas de numéro enregistré).",
                style: TextStyle(fontSize: 12, color: AppCouleurs.texteSecondaire),
              ),
            ),
        ],
      ),
    );
  }
}
