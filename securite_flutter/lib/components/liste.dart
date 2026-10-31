import 'package:flutter/material.dart';

import '../theme/couleurs.dart';

/// État de chargement centré.
class EtatChargement extends StatelessWidget {
  const EtatChargement({super.key, this.message = 'Chargement…', this.compact = false});

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AppCouleurs.texteSecondaire)),
        ],
      ),
    );
  }
}

/// État vide (aucun résultat).
class EtatVide extends StatelessWidget {
  const EtatVide({
    super.key,
    this.icone = Icons.inbox_outlined,
    required this.titre,
    this.message,
    this.libelleAction,
    this.onAction,
  });

  final IconData icone;
  final String titre;
  final String? message;
  final String? libelleAction;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppCouleurs.bleuPastel,
                shape: BoxShape.circle,
              ),
              child: Icon(icone, size: 40, color: AppCouleurs.bleu),
            ),
            const SizedBox(height: 20),
            Text(
              titre,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppCouleurs.textePrimaire,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppCouleurs.texteSecondaire,
                ),
              ),
            ],
            if (libelleAction != null && onAction != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(libelleAction!),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// État d'erreur avec bouton « réessayer ».
class EtatErreur extends StatelessWidget {
  const EtatErreur({
    super.key,
    required this.message,
    this.onReessayer,
    this.icone = Icons.wifi_off_rounded,
  });

  final String message;
  final VoidCallback? onReessayer;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: AppCouleurs.rougePastel,
                shape: BoxShape.circle,
              ),
              child: Icon(icone, size: 40, color: AppCouleurs.rouge),
            ),
            const SizedBox(height: 20),
            Text(
              'Oups…',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppCouleurs.textePrimaire,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppCouleurs.texteSecondaire,
              ),
            ),
            if (onReessayer != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onReessayer,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Réessayer'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Liste paginée : pull-to-refresh + chargement à l'arrivée en bas.
class ListePaginee<T> extends StatefulWidget {
  const ListePaginee({
    super.key,
    required this.elements,
    required this.construire,
    required this.onRafraichir,
    this.onPageSuivante,
    this.enCharge = false,
    this.pageSuivanteEnCharge = false,
    this.aPlus = false,
    this.erreur,
    this.videTitre = 'Aucun résultat',
    this.videMessage,
    this.videIcone = Icons.inbox_outlined,
    this.videAction,
    this.libelleVideAction,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
    this.espacement = 10,
  });

  final List<T> elements;
  final Widget Function(BuildContext, int) construire;
  final Future<void> Function() onRafraichir;
  final Future<void> Function()? onPageSuivante;
  final bool enCharge;
  final bool pageSuivanteEnCharge;
  final bool aPlus;
  final String? erreur;
  final String videTitre;
  final String? videMessage;
  final IconData videIcone;
  final VoidCallback? videAction;
  final String? libelleVideAction;
  final EdgeInsetsGeometry padding;
  final double espacement;

  @override
  State<ListePaginee<T>> createState() => _ListePagineeState<T>();
}

class _ListePagineeState<T> extends State<ListePaginee<T>> {
  final ScrollController _controleur = ScrollController();

  @override
  void initState() {
    super.initState();
    _controleur.addListener(_surDefilement);
  }

  @override
  void dispose() {
    _controleur.removeListener(_surDefilement);
    _controleur.dispose();
    super.dispose();
  }

  void _surDefilement() {
    if (!widget.aPlus || widget.pageSuivanteEnCharge || widget.onPageSuivante == null) return;
    if (_controleur.position.pixels >=
        _controleur.position.maxScrollExtent - 320) {
      widget.onPageSuivante!();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.enCharge && widget.elements.isEmpty) {
      return const EtatChargement();
    }
    if (widget.erreur != null && widget.elements.isEmpty) {
      return EtatErreur(message: widget.erreur!, onReessayer: widget.onRafraichir);
    }
    if (widget.elements.isEmpty) {
      return EtatVide(
        icone: widget.videIcone,
        titre: widget.videTitre,
        message: widget.videMessage,
        libelleAction: widget.libelleVideAction,
        onAction: widget.videAction,
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRafraichir,
      color: AppCouleurs.bleu,
      child: ListView.separated(
        controller: _controleur,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: widget.elements.length + (widget.aPlus || widget.pageSuivanteEnCharge ? 1 : 0),
        separatorBuilder: (_, __) => SizedBox(height: widget.espacement),
        itemBuilder: (context, index) {
          if (index >= widget.elements.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: widget.pageSuivanteEnCharge
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : TextButton(
                        onPressed: widget.onPageSuivante,
                        child: const Text('Charger plus'),
                      ),
              ),
            );
          }
          return widget.construire(context, index);
        },
      ),
    );
  }
}

/// Titre de section avec libellé facultatif à droite.
class TitreSection extends StatelessWidget {
  const TitreSection({
    super.key,
    required this.titre,
    this.action,
    this.libelleAction,
    this.icone,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 8, 8),
  });

  final String titre;
  final VoidCallback? action;
  final String? libelleAction;
  final IconData? icone;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (icone != null) ...[
            Icon(icone, size: 18, color: AppCouleurs.bleu),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              titre,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: AppCouleurs.textePrimaire,
              ),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: action,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: Text(libelleAction ?? 'Voir tout'),
            ),
        ],
      ),
    );
  }
}
