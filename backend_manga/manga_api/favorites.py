import uuid

from flask import Blueprint, jsonify, request

from database.db import execute_query, execute_write

favorites_bp = Blueprint("favorites", __name__)


def _get_user_id():
    data = request.get_json(silent=True) or {}
    raw = request.args.get("user_id") or data.get("user_id")
    try:
        return int(raw)
    except (TypeError, ValueError):
        return None


def _valid_manga_id(raw):
    try:
        return str(uuid.UUID(str(raw or "")))
    except ValueError:
        return None


@favorites_bp.route("/api/favorites", methods=["GET"])
def get_favorites():
    user_id = _get_user_id()
    if not user_id:
        return jsonify({"status": "error", "message": "Login dulu"}), 401

    rows = execute_query(
        "SELECT manga_id AS id, title, image_url AS link_gambar "
        "FROM favorit WHERE user_id = %s ORDER BY created_at DESC",
        (user_id,),
    )
    for row in rows:
        row["mangadex_url"] = f"https://mangadex.org/title/{row['id']}"
    return jsonify({"status": "success", "data": rows}), 200


@favorites_bp.route("/api/favorites", methods=["POST"])
def add_favorite():
    data = request.get_json(silent=True) or {}
    user_id = _get_user_id()
    manga_id = _valid_manga_id(data.get("manga_id"))
    if not user_id or not manga_id:
        return jsonify({
            "status": "error",
            "message": "user_id dan manga_id yang valid wajib",
        }), 400

    execute_write(
        "INSERT INTO favorit (user_id, manga_id, title, image_url) "
        "VALUES (%s, %s, %s, %s) "
        "ON DUPLICATE KEY UPDATE title = VALUES(title), "
        "image_url = VALUES(image_url)",
        (
            user_id,
            manga_id,
            (data.get("title") or "")[:255],
            (data.get("image_url") or "")[:500],
        ),
    )
    return jsonify({"status": "success", "message": "Favorit disimpan"}), 201


@favorites_bp.route("/api/favorites/<uuid:manga_id>", methods=["GET"])
def is_favorite(manga_id):
    user_id = _get_user_id()
    if not user_id:
        return jsonify({"status": "success", "isFavorite": False}), 200

    rows = execute_query(
        "SELECT id FROM favorit WHERE user_id = %s AND manga_id = %s LIMIT 1",
        (user_id, str(manga_id)),
    )
    return jsonify({"status": "success", "isFavorite": bool(rows)}), 200


@favorites_bp.route("/api/favorites/<uuid:manga_id>", methods=["DELETE"])
def remove_favorite(manga_id):
    user_id = _get_user_id()
    if not user_id:
        return jsonify({"status": "error", "message": "Login dulu"}), 401

    execute_write(
        "DELETE FROM favorit WHERE user_id = %s AND manga_id = %s",
        (user_id, str(manga_id)),
    )
    return jsonify({"status": "success", "message": "Favorit dihapus"}), 200