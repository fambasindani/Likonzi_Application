import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/couleurs.dart';

/// Champ de texte aligné sur le thème (label, erreur, préfixe/suffixe).
class ChampTexte extends StatefulWidget {
  const ChampTexte({
    super.key,
    required this.libelle,
    this.controller,
    this.hint,
    this.erreur,
    this.onChanged,
    this.onChangedTexte,
    this.validator,
    this.icone,
    this.suffixe,
    this.requis = false,
    this.obscure = false,
    this.clavier = TextInputType.text,
    this.formatteur,
    this.initial,
    this.maxLignes = 1,
    this.actif = true,
    this.capitale = TextCapitalization.none,
  });

  final String libelle;
  final TextEditingController? controller;
  final String? hint;
  final String? erreur;
  final ValueChanged<String>? onChanged;
  final void Function(String)? onChangedTexte;
  final FormFieldValidator<String>? validator;
  final IconData? icone;
  final Widget? suffixe;
  final bool requis;
  final bool obscure;
  final TextInputType clavier;
  final TextInputFormatter? formatteur;
  final String? initial;
  final int maxLignes;
  final bool actif;
  final TextCapitalization capitale;

  @override
  State<ChampTexte> createState() => _ChampTexteState();
}

class _ChampTexteState extends State<ChampTexte> {
  late final TextEditingController _controleur;
  late bool _cache;

  @override
  void initState() {
    super.initState();
    _controleur = widget.controller ?? TextEditingController(text: widget.initial);
    _cache = widget.obscure;
  }

  @override
  void dispose() {
    if (widget.controller == null) _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 2,
          children: [
            Text(
              widget.libelle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppCouleurs.textePrimaire,
              ),
            ),
            if (widget.requis)
              const Text(' *', style: TextStyle(color: AppCouleurs.rouge, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _controleur,
          enabled: widget.actif,
          obscureText: _cache,
          keyboardType: widget.clavier,
          textInputAction: TextInputAction.next,
          textCapitalization: widget.capitale,
          inputFormatters: widget.formatteur != null ? [widget.formatteur!] : null,
          maxLines: widget.obscure ? 1 : widget.maxLignes,
          onChanged: widget.onChanged ?? widget.onChangedTexte,
          validator: widget.validator,
          style: const TextStyle(fontSize: 15, color: AppCouleurs.textePrimaire),
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.erreur,
            prefixIcon: widget.icone != null
                ? Icon(widget.icone, size: 20, color: AppCouleurs.grisBleu)
                : null,
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: _cache ? 'Afficher' : 'Masquer',
                    icon: Icon(
                      _cache ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppCouleurs.grisBleu,
                    ),
                    onPressed: () => setState(() => _cache = !_cache),
                  )
                : widget.suffixe,
          ),
        ),
      ],
    );
  }
}

/// Champ « mot de passe » avec indicateur de robustesse.
class ChampMotDePasse extends StatelessWidget {
  const ChampMotDePasse({
    super.key,
    required this.libelle,
    this.controller,
    this.erreur,
    this.hint,
    this.onChanged,
    this.requis = true,
    this.afficherIndicateur = false,
  });

  final String libelle;
  final TextEditingController? controller;
  final String? erreur;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final bool requis;
  final bool afficherIndicateur;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChampTexte(
          libelle: libelle,
          controller: controller,
          hint: hint ?? '••••••••',
          erreur: erreur,
          icone: Icons.lock_outline,
          obscure: true,
          requis: requis,
          clavier: TextInputType.visiblePassword,
          onChanged: onChanged,
        ),
        if (afficherIndicateur && controller != null)
          _IndicateurForce(motDePasse: controller!.text),
      ],
    );
  }
}

class _IndicateurForce extends StatelessWidget {
  const _IndicateurForce({required this.motDePasse});

  final String motDePasse;

  int get _score {
    var s = 0;
    if (motDePasse.length >= 8) s++;
    if (motDePasse.contains(RegExp(r'[A-Za-z]'))) s++;
    if (motDePasse.contains(RegExp(r'[0-9]'))) s++;
    if (motDePasse.contains(RegExp(r'[^A-Za-z0-9]'))) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    if (motDePasse.isEmpty) return const SizedBox.shrink();
    final (libelle, couleur) = switch (_score) {
      0 || 1 => ('Faible', AppCouleurs.rouge),
      2 => ('Moyen', AppCouleurs.jaune),
      3 => ('Bon', AppCouleurs.orange),
      _ => ('Excellent', AppCouleurs.vert),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          for (var i = 0; i < 4; i++)
            Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: i < _score ? couleur : AppCouleurs.bordure,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          const SizedBox(width: 8),
          Text(
            libelle,
            style: TextStyle(fontSize: 12, color: couleur, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Barre de recherche réutilisable.
class ChampRecherche extends StatelessWidget {
  const ChampRecherche({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onSoumis,
    this.action,
    this.focusNode,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSoumis;
  final Widget? action;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSoumis,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 20, color: AppCouleurs.grisBleu),
        suffixIcon: action,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }
}
