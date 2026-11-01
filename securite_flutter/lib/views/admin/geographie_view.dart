import 'package:flutter/material.dart';

import '../../components/bouton.dart';
import '../../components/carte_conteneur.dart';
import '../../components/champ_texte.dart';
import '../../components/liste.dart';
import '../../components/selecteur.dart';
import '../../services/api_client.dart';
import '../../services/meta_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/messages.dart';

/// Référentiel géographique (admin) : **province → ville → commune →
/// commissariat**.
///
/// Quatre onglets, chacun avec ses listes, son bouton « Ajouter » et ses
/// formulaires de création / modification. Une permission `geo.gerer` est
/// exigée côté serveur : les écritures sont refusées (403) aux autres rôles.
class VueGeographie extends StatefulWidget {
  const VueGeographie({super.key});

  @override
  State<VueGeographie> createState() => _VueGeographieState();
}

class _VueGeographieState extends State<VueGeographie> {
  final MetaService _meta = MetaService.instance;

  static const _libelles = [
    'Provinces',
    'Villes',
    'Communes',
    'Commissariats',
  ];

  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _villes = [];
  List<Map<String, dynamic>> _communes = [];
  List<Map<String, dynamic>> _commissariats = [];

  bool _chargement = true;
  String? _erreur;
  int _onglet = 0;

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
      final r = await Future.wait<List<Map<String, dynamic>>>([
        _meta.provinces(),
        _meta.villes(),
        _meta.communes(),
        _meta.commissariats(),
      ]);
      _provinces = r[0];
      _villes = r[1];
      _communes = r[2];
      _commissariats = r[3];
    } on ExceptionApi catch (e) {
      _erreur = e.message;
    } catch (_) {
      _erreur = 'Impossible de charger le référentiel géographique.';
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  // ------------------------------------------------------------------- actions

  Future<void> _ouvrirForm(Widget formulaire) async {
    final enregistre = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: const BoxDecoration(
          color: AppCouleurs.blanc,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          28 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(child: formulaire),
      ),
    );
    if (enregistre == true && mounted) _charger();
  }

  void _ajouter() {
    switch (_onglet) {
      case 0:
        _ouvrirForm(_FormProvince(meta: _meta));
      case 1:
        _ouvrirForm(_FormVille(meta: _meta, provinces: _provinces));
      case 2:
        _ouvrirForm(
          _FormCommune(meta: _meta, provinces: _provinces, villes: _villes),
        );
      default:
        _ouvrirForm(
          _FormCommissariat(
            meta: _meta,
            provinces: _provinces,
            villes: _villes,
            communes: _communes,
          ),
        );
    }
  }

  void _modifier(int onglet, Map<String, dynamic> e) {
    switch (onglet) {
      case 0:
        _ouvrirForm(_FormProvince(meta: _meta, existant: e));
      case 1:
        _ouvrirForm(_FormVille(meta: _meta, provinces: _provinces, existant: e));
      case 2:
        _ouvrirForm(
          _FormCommune(
            meta: _meta,
            provinces: _provinces,
            villes: _villes,
            existant: e,
          ),
        );
      default:
        _ouvrirForm(
          _FormCommissariat(
            meta: _meta,
            provinces: _provinces,
            villes: _villes,
            communes: _communes,
            existant: e,
          ),
        );
    }
  }

  Future<void> _supprimer(
    String intitule,
    Map<String, dynamic> e,
    Future<void> Function(int) action,
  ) async {
    final libelle = '${e['nom'] ?? ''}';
    final confirme = await confirmer(
      context,
      titre: 'Supprimer « $libelle » ?',
      message: intitule == 'Commissariat'
          ? 'Le commissariat est archivé (purge douce) : il disparaît des '
              'listings mais reste tracé dans le journal d’audit.'
          : 'Les éléments rattachés à cet élément doivent d’abord être '
              'supprimés, sinon le serveur refusera la suppression.',
      libelleValider: 'Supprimer',
      destructif: true,
      icone: Icons.delete_outline,
    );
    if (!confirme || !mounted) return;
    try {
      await action(e['id'] as int);
      if (!mounted) return;
      montrerSucces(context, '$intitule supprimé(e).');
      _charger();
    } catch (err) {
      if (mounted) montrerErreur(context, err);
    }
  }

  // -------------------------------------------------------------------- rendu

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Géographie & commissariats'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _charger,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _chargement || _erreur != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _ajouter,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
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
                        libelles: _libelles,
                        selection: _onglet,
                        onChanged: (i) => setState(() => _onglet = i),
                      ),
                    ),
                    Expanded(child: _vueOnglet()),
                  ],
                ),
    );
  }

  Widget _vueOnglet() => switch (_onglet) {
        0 => _listeProvinces(),
        1 => _listeVilles(),
        2 => _listeCommunes(),
        _ => _listeCommissariats(),
      };

  Widget _conteneur({
    required String titre,
    required String sousTitre,
    required String meta,
    required int onglet,
    required Map<String, dynamic> element,
    required Future<void> Function(int) suppression,
    required String intitule,
  }) {
    return CarteConteneur(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enfant: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (sousTitre.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    sousTitre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppCouleurs.texteSecondaire,
                    ),
                  ),
                ],
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      color: AppCouleurs.grisBleu,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Modifier',
            onPressed: () => _modifier(onglet, element),
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: AppCouleurs.bleu,
          ),
          IconButton(
            tooltip: 'Supprimer',
            onPressed: () => _supprimer(intitule, element, suppression),
            icon: const Icon(Icons.delete_outline, size: 20),
            color: AppCouleurs.rouge,
          ),
        ],
      ),
    );
  }

  Widget _deroulante(List<Map<String, dynamic>> elements, Widget Function(Map<String, dynamic>) carte) {
    return RefreshIndicator(
      onRefresh: _charger,
      color: AppCouleurs.bleu,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: elements.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => carte(elements[i]),
      ),
    );
  }

  static String _nomDe(dynamic valeur) {
    if (valeur is Map) return '${valeur['nom'] ?? ''}';
    return valeur?.toString() ?? '';
  }

  static String _coordonnees(Map<String, dynamic> e) {
    final lat = e['latitude'];
    final lon = e['longitude'];
    if (lat == null || lon == null) return '';
    return '$lat, $lon';
  }

  Widget _listeProvinces() {
    if (_provinces.isEmpty) {
      return const EtatVide(
        icone: Icons.public,
        titre: 'Aucune province',
        message: 'Ajoutez une province pour démarrer le référentiel.',
      );
    }
    return _deroulante(_provinces, (e) {
      final chef = e['chef_lieu'] as String?;
      return _conteneur(
        onglet: 0,
        intitule: 'Province',
        element: e,
        suppression: _meta.supprimerProvince,
        titre: '${e['nom'] ?? ''}',
        sousTitre: chef == null || chef.isEmpty ? '' : 'Chef-lieu : $chef',
        meta: '${e['code'] ?? ''}',
      );
    });
  }

  Widget _listeVilles() {
    if (_villes.isEmpty) {
      return const EtatVide(
        icone: Icons.location_city_outlined,
        titre: 'Aucune ville',
      );
    }
    return _deroulante(_villes, (e) {
      final geo = _coordonnees(e);
      return _conteneur(
        onglet: 1,
        intitule: 'Ville',
        element: e,
        suppression: _meta.supprimerVille,
        titre: '${e['nom'] ?? ''}',
        sousTitre: _nomDe(e['province']),
        meta: geo,
      );
    });
  }

  Widget _listeCommunes() {
    if (_communes.isEmpty) {
      return const EtatVide(
        icone: Icons.map_outlined,
        titre: 'Aucune commune',
        message: 'Ajoutez les communes de vos villes (ex. Limete, Masina).',
      );
    }
    return _deroulante(_communes, (e) {
      final parents = [
        if (e['ville'] != null && '${e['ville']}'.isNotEmpty) '${e['ville']}',
        if (e['province'] != null && '${e['province']}'.isNotEmpty)
          '${e['province']}',
      ].join(' — ');
      final code = e['code'] as String?;
      return _conteneur(
        onglet: 2,
        intitule: 'Commune',
        element: e,
        suppression: _meta.supprimerCommune,
        titre: '${e['nom'] ?? ''}',
        sousTitre: parents,
        meta: code == null || code.isEmpty ? '' : code,
      );
    });
  }

  Widget _listeCommissariats() {
    if (_commissariats.isEmpty) {
      return const EtatVide(
        icone: Icons.local_police_outlined,
        titre: 'Aucun commissariat',
      );
    }
    return _deroulante(_commissariats, (e) {
      final rattachement = [
        if (e['commune'] != null && '${e['commune']}'.isNotEmpty)
          '${e['commune']}',
        if (e['ville'] != null && '${e['ville']}'.isNotEmpty) '${e['ville']}',
        if (e['province'] != null && '${e['province']}'.isNotEmpty)
          '${e['province']}',
      ].join(' — ');
      final actif = e['statut'] == true || e['statut'] == 1;
      final geo = _coordonnees(e);
      final detail = [
        if (rattachement.isNotEmpty) rattachement,
        if (e['adresse'] != null && '${e['adresse']}'.isNotEmpty)
          '${e['adresse']}',
        if (geo.isNotEmpty) geo,
      ].join(' · ');
      return _conteneur(
        onglet: 3,
        intitule: 'Commissariat',
        element: e,
        suppression: _meta.supprimerCommissariat,
        titre: '${e['nom'] ?? ''}',
        sousTitre: detail,
        meta: '${e['code'] ?? ''}${actif ? '' : '  ·  inactif'}',
      );
    });
  }
}

// ======================================================================== formulaires

/// Barre commune des formulaires : titre + bouton d'enregistrement.
class _Feuille extends StatelessWidget {
  const _Feuille({
    required this.titre,
    required this.soumettre,
    required this.enCharge,
    required this.enfant,
  });

  final String titre;
  final VoidCallback soumettre;
  final bool enCharge;
  final List<Widget> enfant;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppCouleurs.grisClaire,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          titre,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        ...enfant,
        const SizedBox(height: 20),
        BoutonPrincipal(
          texte: 'Enregistrer',
          icone: Icons.check_rounded,
          enCharge: enCharge,
          onPressed: enCharge ? null : soumettre,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Coordonnées GPS facultatives (les deux ensemble).
class _ChampsGps extends StatelessWidget {
  const _ChampsGps({required this.latitude, required this.longitude});

  final TextEditingController latitude;
  final TextEditingController longitude;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ChampTexte(
            libelle: 'Latitude',
            controller: latitude,
            hint: '-4.325',
            clavier: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ChampTexte(
            libelle: 'Longitude',
            controller: longitude,
            hint: '15.310',
            clavier: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
      ],
    );
  }
}

double? _decimal(String brut) {
  final texte = brut.trim().replaceAll(',', '.');
  if (texte.isEmpty) return null;
  return double.tryParse(texte);
}

// --------------------------------------------------------------------- province

class _FormProvince extends StatefulWidget {
  const _FormProvince({required this.meta, this.existant});

  final MetaService meta;
  final Map<String, dynamic>? existant;

  @override
  State<_FormProvince> createState() => _FormProvinceState();
}

class _FormProvinceState extends State<_FormProvince> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _nom;
  late final TextEditingController _chefLieu;
  bool _enCharge = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existant;
    _code = TextEditingController(text: '${e?['code'] ?? ''}');
    _nom = TextEditingController(text: '${e?['nom'] ?? ''}');
    _chefLieu = TextEditingController(text: '${e?['chef_lieu'] ?? ''}');
  }

  @override
  void dispose() {
    _code.dispose();
    _nom.dispose();
    _chefLieu.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _enCharge = true);
    final corps = {
      'code': _code.text.trim(),
      'nom': _nom.text.trim(),
      'chef_lieu': _chefLieu.text.trim(),
    };
    try {
      if (widget.existant == null) {
        await widget.meta.creerProvince(corps);
      } else {
        await widget.meta.majProvince(widget.existant!['id'] as int, corps);
      }
      if (!mounted) return;
      montrerSucces(context, 'Province enregistrée.');
      Navigator.of(context).pop(true);
    } catch (err) {
      if (mounted) {
        setState(() => _enCharge = false);
        montrerErreur(context, err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: _Feuille(
        titre: widget.existant == null ? 'Nouvelle province' : 'Modifier la province',
        enCharge: _enCharge,
        soumettre: _enregistrer,
        enfant: [
          ChampTexte(
            libelle: 'Code',
            controller: _code,
            hint: 'KIN',
            requis: true,
            capitale: TextCapitalization.characters,
          ),
          const SizedBox(height: 14),
          ChampTexte(
            libelle: 'Nom',
            controller: _nom,
            hint: 'Kinshasa',
            requis: true,
          ),
          const SizedBox(height: 14),
          ChampTexte(
            libelle: 'Chef-lieu (facultatif)',
            controller: _chefLieu,
            hint: 'Kinshasa',
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------- ville

class _FormVille extends StatefulWidget {
  const _FormVille({required this.meta, required this.provinces, this.existant});

  final MetaService meta;
  final List<Map<String, dynamic>> provinces;
  final Map<String, dynamic>? existant;

  @override
  State<_FormVille> createState() => _FormVilleState();
}

class _FormVilleState extends State<_FormVille> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nom;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  int? _idProvince;
  bool _enCharge = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existant;
    _nom = TextEditingController(text: '${e?['nom'] ?? ''}');
    _latitude = TextEditingController(text: '${e?['latitude'] ?? ''}');
    _longitude = TextEditingController(text: '${e?['longitude'] ?? ''}');
    if (e != null) {
      final p = e['province'];
      _idProvince = p is Map ? p['id'] as int? : e['id_province'] as int?;
    }
  }

  @override
  void dispose() {
    _nom.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _enCharge = true);
    final lat = _decimal(_latitude.text);
    final lon = _decimal(_longitude.text);
    final corps = <String, dynamic>{
      'id_province': _idProvince,
      'nom': _nom.text.trim(),
      if (lat != null) 'latitude': lat,
      if (lon != null) 'longitude': lon,
    };
    try {
      if (widget.existant == null) {
        await widget.meta.creerVille(corps);
      } else {
        await widget.meta.majVille(widget.existant!['id'] as int, corps);
      }
      if (!mounted) return;
      montrerSucces(context, 'Ville enregistrée.');
      Navigator.of(context).pop(true);
    } catch (err) {
      if (mounted) {
        setState(() => _enCharge = false);
        montrerErreur(context, err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: _Feuille(
        titre: widget.existant == null ? 'Nouvelle ville' : 'Modifier la ville',
        enCharge: _enCharge,
        soumettre: _enregistrer,
        enfant: [
          Selecteur<int>(
            libelle: 'Province',
            requis: true,
            icone: Icons.public,
            valeur: _idProvince,
            options: [
              for (final p in widget.provinces)
                OptionSelecteur(
                  valeur: p['id'] as int,
                  libelle: '${p['nom'] ?? ''}',
                ),
            ],
            onChanged: (v) => setState(() => _idProvince = v),
          ),
          const SizedBox(height: 14),
          ChampTexte(
            libelle: 'Nom de la ville',
            controller: _nom,
            hint: 'Kinshasa',
            requis: true,
          ),
          const SizedBox(height: 14),
          _ChampsGps(latitude: _latitude, longitude: _longitude),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------- commune

class _FormCommune extends StatefulWidget {
  const _FormCommune({
    required this.meta,
    required this.provinces,
    required this.villes,
    this.existant,
  });

  final MetaService meta;
  final List<Map<String, dynamic>> provinces;
  final List<Map<String, dynamic>> villes;
  final Map<String, dynamic>? existant;

  @override
  State<_FormCommune> createState() => _FormCommuneState();
}

class _FormCommuneState extends State<_FormCommune> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nom;
  late final TextEditingController _code;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  int? _idProvince;
  int? _idVille;
  bool _enCharge = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existant;
    _nom = TextEditingController(text: '${e?['nom'] ?? ''}');
    _code = TextEditingController(text: '${e?['code'] ?? ''}');
    _latitude = TextEditingController(text: '${e?['latitude'] ?? ''}');
    _longitude = TextEditingController(text: '${e?['longitude'] ?? ''}');
    _idVille = e?['id_ville'] as int?;
    if (_idVille != null) {
      final ville = widget.villes.firstWhere(
        (v) => v['id'] == _idVille,
        orElse: () => const {},
      );
      _idProvince = ville['id_province'] as int?;
    }
  }

  @override
  void dispose() {
    _nom.dispose();
    _code.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _enCharge = true);
    final lat = _decimal(_latitude.text);
    final lon = _decimal(_longitude.text);
    final corps = <String, dynamic>{
      'id_ville': _idVille,
      'nom': _nom.text.trim(),
      if (_code.text.trim().isNotEmpty) 'code': _code.text.trim(),
      if (lat != null) 'latitude': lat,
      if (lon != null) 'longitude': lon,
    };
    try {
      if (widget.existant == null) {
        await widget.meta.creerCommune(corps);
      } else {
        await widget.meta.majCommune(widget.existant!['id'] as int, corps);
      }
      if (!mounted) return;
      montrerSucces(context, 'Commune enregistrée.');
      Navigator.of(context).pop(true);
    } catch (err) {
      if (mounted) {
        setState(() => _enCharge = false);
        montrerErreur(context, err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final villesFiltrees = _idProvince == null
        ? <Map<String, dynamic>>[]
        : widget.villes
            .where((v) => v['id_province'] == _idProvince)
            .toList(growable: false);
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: _Feuille(
        titre:
            widget.existant == null ? 'Nouvelle commune' : 'Modifier la commune',
        enCharge: _enCharge,
        soumettre: _enregistrer,
        enfant: [
          Selecteur<int>(
            libelle: 'Province',
            requis: true,
            icone: Icons.public,
            valeur: _idProvince,
            options: [
              for (final p in widget.provinces)
                OptionSelecteur(
                  valeur: p['id'] as int,
                  libelle: '${p['nom'] ?? ''}',
                ),
            ],
            onChanged: (v) => setState(() {
              _idProvince = v;
              _idVille = null;
            }),
          ),
          const SizedBox(height: 14),
          Selecteur<int>(
            libelle: 'Ville',
            requis: true,
            icone: Icons.location_city_outlined,
            valeur: _idVille,
            hint: _idProvince == null ? 'Choisissez d’abord une province' : 'Sélectionnez…',
            options: [
              for (final v in villesFiltrees)
                OptionSelecteur(
                  valeur: v['id'] as int,
                  libelle: '${v['nom'] ?? ''}',
                ),
            ],
            onChanged: (v) => setState(() => _idVille = v),
          ),
          const SizedBox(height: 14),
          ChampTexte(
            libelle: 'Nom de la commune',
            controller: _nom,
            hint: 'Limete',
            requis: true,
          ),
          const SizedBox(height: 14),
          ChampTexte(
            libelle: 'Code (facultatif)',
            controller: _code,
            hint: 'LIM',
            capitale: TextCapitalization.characters,
          ),
          const SizedBox(height: 14),
          _ChampsGps(latitude: _latitude, longitude: _longitude),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ commissariat

class _FormCommissariat extends StatefulWidget {
  const _FormCommissariat({
    required this.meta,
    required this.provinces,
    required this.villes,
    required this.communes,
    this.existant,
  });

  final MetaService meta;
  final List<Map<String, dynamic>> provinces;
  final List<Map<String, dynamic>> villes;
  final List<Map<String, dynamic>> communes;
  final Map<String, dynamic>? existant;

  @override
  State<_FormCommissariat> createState() => _FormCommissariatState();
}

class _FormCommissariatState extends State<_FormCommissariat> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _nom;
  late final TextEditingController _adresse;
  late final TextEditingController _telephone;
  late final TextEditingController _email;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  int? _idProvince;
  int? _idVille;
  int? _idCommune;
  bool _statut = true;
  bool _enCharge = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existant;
    _code = TextEditingController(text: '${e?['code'] ?? ''}');
    _nom = TextEditingController(text: '${e?['nom'] ?? ''}');
    _adresse = TextEditingController(text: '${e?['adresse'] ?? ''}');
    _telephone = TextEditingController(text: '${e?['telephone'] ?? ''}');
    _email = TextEditingController(text: '${e?['email'] ?? ''}');
    _latitude = TextEditingController(text: '${e?['latitude'] ?? ''}');
    _longitude = TextEditingController(text: '${e?['longitude'] ?? ''}');
    _idProvince = e?['id_province'] as int?;
    _idVille = e?['id_ville'] as int?;
    _idCommune = e?['id_commune'] as int?;
    if (e != null) _statut = e['statut'] == true || e['statut'] == 1;
  }

  @override
  void dispose() {
    _code.dispose();
    _nom.dispose();
    _adresse.dispose();
    _telephone.dispose();
    _email.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _enCharge = true);
    final lat = _decimal(_latitude.text);
    final lon = _decimal(_longitude.text);
    final corps = <String, dynamic>{
      'code': _code.text.trim(),
      'nom': _nom.text.trim(),
      if (_idProvince != null) 'id_province': _idProvince,
      if (_idVille != null) 'id_ville': _idVille,
      if (_idCommune != null) 'id_commune': _idCommune,
      if (_adresse.text.trim().isNotEmpty) 'adresse': _adresse.text.trim(),
      if (_telephone.text.trim().isNotEmpty)
        'telephone': _telephone.text.trim(),
      if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
      if (lat != null) 'latitude': lat,
      if (lon != null) 'longitude': lon,
      'statut': _statut,
    };
    try {
      if (widget.existant == null) {
        await widget.meta.creerCommissariat(corps);
      } else {
        await widget.meta.majCommissariat(widget.existant!['id'] as int, corps);
      }
      if (!mounted) return;
      montrerSucces(context, 'Commissariat enregistré.');
      Navigator.of(context).pop(true);
    } catch (err) {
      if (mounted) {
        setState(() => _enCharge = false);
        montrerErreur(context, err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final villesFiltrees = _idProvince == null
        ? <Map<String, dynamic>>[]
        : widget.villes
            .where((v) => v['id_province'] == _idProvince)
            .toList(growable: false);
    final communesFiltrees = _idVille == null
        ? <Map<String, dynamic>>[]
        : widget.communes
            .where((c) => c['id_ville'] == _idVille)
            .toList(growable: false);

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: _Feuille(
        titre: widget.existant == null
            ? 'Nouveau commissariat'
            : 'Modifier le commissariat',
        enCharge: _enCharge,
        soumettre: _enregistrer,
        enfant: [
          ChampTexte(
            libelle: 'Code',
            controller: _code,
            hint: 'COM-KIN-005',
            requis: true,
            capitale: TextCapitalization.characters,
          ),
          const SizedBox(height: 14),
          ChampTexte(
            libelle: 'Nom',
            controller: _nom,
            hint: 'Commissariat de Limete',
            requis: true,
          ),
          const SizedBox(height: 14),
          Selecteur<int>(
            libelle: 'Province',
            requis: true,
            icone: Icons.public,
            valeur: _idProvince,
            options: [
              for (final p in widget.provinces)
                OptionSelecteur(
                  valeur: p['id'] as int,
                  libelle: '${p['nom'] ?? ''}',
                ),
            ],
            onChanged: (v) => setState(() {
              _idProvince = v;
              _idVille = null;
              _idCommune = null;
            }),
          ),
          const SizedBox(height: 14),
          Selecteur<int>(
            libelle: 'Ville',
            requis: true,
            icone: Icons.location_city_outlined,
            valeur: _idVille,
            hint: _idProvince == null
                ? 'Choisissez d’abord une province'
                : 'Sélectionnez…',
            options: [
              for (final v in villesFiltrees)
                OptionSelecteur(
                  valeur: v['id'] as int,
                  libelle: '${v['nom'] ?? ''}',
                ),
            ],
            onChanged: (v) => setState(() {
              _idVille = v;
              _idCommune = null;
            }),
          ),
          const SizedBox(height: 14),
          Selecteur<int>(
            libelle: 'Commune',
            icone: Icons.map_outlined,
            valeur: _idCommune,
            hint: _idVille == null
                ? 'Choisissez d’abord une ville'
                : 'Sélectionnez…',
            options: [
              for (final c in communesFiltrees)
                OptionSelecteur(
                  valeur: c['id'] as int,
                  libelle: '${c['nom'] ?? ''}',
                ),
            ],
            onChanged: (v) => setState(() => _idCommune = v),
          ),
          const SizedBox(height: 14),
          ChampTexte(
            libelle: 'Adresse',
            controller: _adresse,
            hint: 'Av. Général Mobutu, Limete',
            maxLignes: 2,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ChampTexte(
                  libelle: 'Téléphone',
                  controller: _telephone,
                  hint: '+243810000004',
                  clavier: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChampTexte(
                  libelle: 'E-mail',
                  controller: _email,
                  hint: 'com@police.cd',
                  clavier: TextInputType.emailAddress,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ChampsGps(latitude: _latitude, longitude: _longitude),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Commissariat actif',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Un commissariat inactif n’apparaît plus dans les listings.',
              style: TextStyle(fontSize: 12),
            ),
            value: _statut,
            onChanged: (v) => setState(() => _statut = v),
          ),
        ],
      ),
    );
  }
}
