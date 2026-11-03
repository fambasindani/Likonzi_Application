import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/avatar.dart';
import '../../components/fiche_identite.dart';
import '../../components/liste.dart';
import '../../models/social.dart';
import '../../models/utilisateur.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/social_service.dart';
import '../../theme/couleurs.dart';
import '../../utils/formatage.dart';
import '../../utils/messages.dart';
import '../carte/itineraire_view.dart';

/// Conversation privée avec un contact.
class VueConversation extends StatefulWidget {
  const VueConversation({super.key, required this.destinataire});

  final Utilisateur destinataire;

  @override
  State<VueConversation> createState() => _VueConversationState();
}

class _VueConversationState extends State<VueConversation> {
  final SocialService _service = SocialService.instance;
  final _controleur = TextEditingController();
  final _scroll = ScrollController();

  List<Message> _messages = [];
  bool _chargement = true;
  bool _envoi = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _controleur.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final page = await _service.conversation(widget.destinataire.id, perPage: 200);
      _messages = page.elements;
      // Les messages reçus passent en « lu ».
      for (final m in _messages.where((m) => !m.lu && m.idDestinataire != widget.destinataire.id)) {
        await _service.marquerLu(m.id);
      }
    } on ExceptionApi catch (e) {
      _erreur = e.message;
    } catch (_) {
      _erreur = 'Impossible de charger la conversation.';
    } finally {
      if (mounted) {
        setState(() => _chargement = false);
        _versLeBas();
      }
    }
  }

  void _versLeBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Un SOS du contact figure parmi les derniers échanges : on affiche alors
  /// son identité détaillée (grande photo + appel) en haut de la conversation.
  bool get _sosRecu {
    final derniers = _messages.length > 5
        ? _messages.sublist(_messages.length - 5)
        : _messages;
    return derniers.any(
      (m) =>
          m.idExpediteur == widget.destinataire.id &&
          (m.contenu.contains('SOS') ||
              m.contenu.startsWith('🚨') ||
              m.contenu.startsWith('⚠️')),
    );
  }

  Future<void> _envoyer() async {
    final texte = _controleur.text.trim();
    if (texte.isEmpty || _envoi) return;
    setState(() {
      _envoi = true;
      _controleur.clear();
    });
    try {
      final message = await _service.envoyerMessage(widget.destinataire.id, texte);
      setState(() => _messages = [..._messages, message]);
      _versLeBas();
    } on ExceptionApi catch (e) {
      if (mounted) {
        _controleur.text = texte;
        montrerErreur(context, e);
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moiId = context.watch<AuthProvider>().utilisateur?.id ?? -1;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        actions: [
          // Depuis un message reçu : itinéraire vers le commissariat le plus proche.
          IconButton(
            tooltip: 'Itinéraire vers la police',
            icon: const Icon(Icons.directions_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VueItineraire()),
            ),
          ),
        ],
        title: Row(
          children: [
            AvatarUtilisateur.noms(
              nom: widget.destinataire.nom,
              prenom: widget.destinataire.prenom,
              url: widget.destinataire.urlAvatar,
              taille: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.destinataire.nomComplet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    widget.destinataire.fonction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppCouleurs.texteSecondaire),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // SOS reçu : identité complète de l'émetteur (photo, nom, appel).
          if (_sosRecu)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: FicheIdentite(
                libelle: 'SOS reçu',
                nom: widget.destinataire.nom,
                postnom: widget.destinataire.postnom,
                prenom: widget.destinataire.prenom,
                fonction: widget.destinataire.fonction,
                telephone: widget.destinataire.telephone,
                avatar: widget.destinataire.urlAvatar,
                accent: AppCouleurs.rouge,
              ),
            ),
          Expanded(
            child: _chargement
                ? const EtatChargement()
                : _erreur != null
                    ? EtatErreur(message: _erreur!, onReessayer: _charger)
                    : _messages.isEmpty
                        ? const EtatVide(
                            icone: Icons.chat_bubble_outline,
                            titre: 'Aucun message',
                            message: 'Démarrez la conversation en envoyant un message.',
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) =>
                                _BulleMessage(message: _messages[index], moiId: moiId),
                          ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: const BoxDecoration(
                color: AppCouleurs.blanc,
                border: Border(top: BorderSide(color: AppCouleurs.bordure)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controleur,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _envoyer(),
                      decoration: const InputDecoration(
                        hintText: 'Écrivez un message…',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _envoi
                        ? const SizedBox(
                            key: ValueKey('envoi'),
                            width: 42,
                            height: 42,
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            ),
                          )
                        : IconButton(
                            key: const ValueKey('bouton'),
                            onPressed: _envoyer,
                            style: IconButton.styleFrom(
                              backgroundColor: AppCouleurs.bleu,
                              foregroundColor: AppCouleurs.blanc,
                            ),
                            icon: const Icon(Icons.send_rounded, size: 20),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulleMessage extends StatelessWidget {
  const _BulleMessage({required this.message, required this.moiId});

  final Message message;
  final int moiId;

  @override
  Widget build(BuildContext context) {
    final mien = message.idExpediteur == moiId;
    return Align(
      alignment: mien ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: mien ? AppCouleurs.bleu : AppCouleurs.blancCasse,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mien ? 18 : 4),
            bottomRight: Radius.circular(mien ? 4 : 18),
          ),
          border: mien ? null : Border.all(color: AppCouleurs.bordure),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.contenu,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: mien ? AppCouleurs.blanc : AppCouleurs.textePrimaire,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Formatage.heure(message.dateEnvoi),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: mien
                        ? AppCouleurs.blanc.withValues(alpha: 0.8)
                        : AppCouleurs.gris,
                  ),
                ),
                if (mien) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.lu ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.lu
                        ? AppCouleurs.vert
                        : AppCouleurs.blanc.withValues(alpha: 0.8),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
