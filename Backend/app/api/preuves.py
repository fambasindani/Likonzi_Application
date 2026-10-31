"""Preuves : téléversement, intégrité SHA-256, téléchargement — `/api/v1/preuves`."""
from __future__ import annotations

from flask import Blueprint, current_app, request, send_file

from ..services import preuve_service
from ..utils.decorators import current_user, login_required, require_permission
from ..utils.payload import payload, query_int
from ..utils.responses import created, no_content, ok, paginated

preuves_bp = Blueprint("preuves", __name__)


@preuves_bp.get("/types-autorises")
@login_required
def extensions():
    """Liste blanche des extensions acceptées (affichée par le client mobile)."""
    return ok(
        data={
            "extensions": sorted(preuve_service.EXTENSIONS_AUTORISEES),
            "taille_max_octets": current_app.config["MAX_CONTENT_LENGTH"],
            "image_max_octets": current_app.config.get("IMAGE_MAX_OCTETS", 200 * 1024),
            "entites": ["alerte", "cas", "objet", "intervention"],
            "types_preuve": ["photo", "video", "audio", "document", "autre"],
        }
    )


@preuves_bp.post("")
@login_required
@require_permission("preuves.creer")
def televerser():
    fichier = request.files.get("fichier") or request.files.get("image")
    preuve = preuve_service.creer(payload(), fichier, current_user())
    return created(data=preuve.to_dict(), message="Preuve enregistrée et empreinte calculée.")


@preuves_bp.get("")
@login_required
@require_permission("preuves.lire")
def lister():
    page, per_page = query_int("page", 1) or 1, query_int("per_page", 20) or 20
    items, total = preuve_service.lister(
        current_user(),
        page=page,
        per_page=per_page,
        entite_type=request.args.get("entite_type"),
        entite_id=query_int("entite_id"),
    )
    return paginated([p.to_dict() for p in items], page, per_page, total)


@preuves_bp.get("/<int:preuve_id>")
@login_required
@require_permission("preuves.lire")
def detail(preuve_id: int):
    preuve = preuve_service.recuperer(preuve_id, current_user())
    return ok(data=preuve.to_dict())


@preuves_bp.get("/<int:preuve_id>/verifier")
@login_required
@require_permission("preuves.lire")
def verifier(preuve_id: int):
    """Recalcule le SHA-256 du fichier stocké et le compare à l'empreinte en base."""
    preuve = preuve_service.recuperer(preuve_id, current_user())
    return ok(data=preuve_service.verifier_integrite(preuve))


@preuves_bp.get("/<int:preuve_id>/telecharger")
@login_required
@require_permission("preuves.telecharger")
def telecharger(preuve_id: int):
    preuve = preuve_service.recuperer(preuve_id, current_user())
    chemin, nom, mime = preuve_service.export_fichier(preuve)
    return send_file(
        chemin,
        mimetype=mime,
        as_attachment=True,
        download_name=nom,
    )


@preuves_bp.delete("/<int:preuve_id>")
@login_required
@require_permission("preuves.supprimer")
def supprimer(preuve_id: int):
    preuve = preuve_service.recuperer(preuve_id, current_user())
    preuve_service.supprimer(preuve, current_user())
    return no_content("Preuve supprimée (suppression douce, fichier conservé pour l'audit).")
