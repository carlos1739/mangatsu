import uuid
from datetime import datetime
from urllib.parse import quote

from flask import Blueprint, jsonify, request

from database.db import execute_query, execute_write

from .services import (
    LIST_CACHE,
    fetch_mangadex,
    get_mangadex_tags,
    is_fresh,
    parse_mangadex_chapter,
    parse_mangadex_response,
    save_many,
)

api = Blueprint("api", __name__)
MANGA_INCLUDES = ['cover_art', 'author', 'artist']
SAFE_CONTENT_RATING = ['safe']


def _error_response(error):
    return jsonify({'status': 'error', 'message': error[0]}), error[1]


def ok_list(data, source, **extra):
    return jsonify({
        'status': 'success',
        'source': source,
        'data': data,
        **extra,
    }), 200


def _manga_params(limit, offset, **extra):
    return {
        'limit': limit,
        'offset': offset,
        'includes[]': MANGA_INCLUDES,
        'contentRating[]': SAFE_CONTENT_RATING,
        **extra,
    }


def serve_list(cache_key, params):
    entry = LIST_CACHE.get(cache_key)
    if entry and is_fresh(entry[0]):
        return ok_list(
            entry[1],
            'cache',
            total=entry[2],
            page=entry[3],
        )

    response, error = fetch_mangadex('/manga', params)
    if error:
        return _error_response(error)

    mangas = save_many(response.get('data') or [])
    page = params['offset'] // params['limit'] + 1
    total = (response.get('total') or 0)
    LIST_CACHE[cache_key] = (datetime.utcnow(), mangas, total, page)
    return ok_list(mangas, 'mangadex', total=total, page=page)


@api.route('/api/manga', methods=['GET'])
def get_all_manga():
    page = max(request.args.get('page', 1, type=int), 1)
    limit = 25
    params = _manga_params(
        limit,
        (page - 1) * limit,
        **{'order[followedCount]': 'desc'},
    )
    return serve_list(f'top:{page}', params)


@api.route('/api/manga/search', methods=['GET'])
def search_manga():
    query = request.args.get('q', '').strip()
    page = max(request.args.get('page', 1, type=int), 1)
    if not query:
        return jsonify({'status': 'success', 'data': [], 'total': 0}), 200

    limit = 25
    params = _manga_params(
        limit,
        (page - 1) * limit,
        title=query,
        **{'order[relevance]': 'desc'},
    )
    return serve_list(f'search:{query.casefold()}:{page}', params)


@api.route('/api/manga/genre/<string:genre_name>', methods=['GET'])
def get_by_genre(genre_name):
    page = max(request.args.get('page', 1, type=int), 1)
    tags, error = get_mangadex_tags()
    if error:
        return _error_response(error)

    tag_id = tags.get(genre_name.replace('-', ' ').casefold())
    if not tag_id:
        return ok_list([], 'mangadex', total=0, page=page)

    limit = 25
    params = _manga_params(
        limit,
        (page - 1) * limit,
        **{
            'includedTags[]': [tag_id],
            'order[followedCount]': 'desc',
        },
    )
    return serve_list(f'genre:{tag_id}:{page}', params)


@api.route('/api/manga/<uuid:manga_id>', methods=['GET'])
def get_manga_detail(manga_id):
    manga_id = str(manga_id)
    detail_cache = LIST_CACHE.setdefault('manga-detail', {})
    cached = detail_cache.get(manga_id)
    if cached and is_fresh(cached['cached_at']):
        return jsonify({
            'status': 'success',
            'source': 'cache',
            'data': cached['data'],
        }), 200

    response, error = fetch_mangadex(
        f'/manga/{manga_id}',
        {'includes[]': MANGA_INCLUDES},
    )
    if error:
        return _error_response(error)

    parsed = parse_mangadex_response(response.get('data') or {})
    if not parsed:
        return jsonify({'status': 'error', 'message': 'Manga tidak ditemukan'}), 404

    detail_cache[manga_id] = {
        'cached_at': datetime.utcnow(),
        'data': parsed,
    }
    return jsonify({
        'status': 'success',
        'source': 'mangadex',
        'data': parsed,
    }), 200


@api.route('/api/manga/<uuid:manga_id>/chapters', methods=['GET'])
def get_manga_chapters(manga_id):
    page = max(request.args.get('page', 1, type=int), 1)
    requested_languages = request.args.getlist('language')
    languages = [
        language
        for language in requested_languages or ['id', 'en']
        if language in ('id', 'en')
    ]
    if not languages:
        return jsonify({
            'status': 'error',
            'message': 'Bahasa chapter harus id atau en',
        }), 400

    limit = 100
    params = {
        'limit': limit,
        'offset': (page - 1) * limit,
        'translatedLanguage[]': languages,
        'order[chapter]': 'asc',
        'contentRating[]': SAFE_CONTENT_RATING,
    }
    response, error = fetch_mangadex(f'/manga/{manga_id}/feed', params)
    if error:
        return _error_response(error)

    chapters = [
        chapter
        for item in response.get('data') or []
        if (chapter := parse_mangadex_chapter(item))
    ]
    return ok_list(
        chapters,
        'mangadex',
        total=response.get('total') or 0,
        page=page,
        languages=languages,
    )


@api.route('/api/chapter/<uuid:chapter_id>/pages', methods=['GET'])
def get_chapter_pages(chapter_id):
    response, error = fetch_mangadex(f'/at-home/server/{chapter_id}')
    if error:
        return _error_response(error)

    chapter = response.get('chapter') or {}
    base_url = response.get('baseUrl')
    content_hash = chapter.get('hash')
    filenames = chapter.get('data') or []
    if not base_url or not content_hash or not filenames:
        return jsonify({
            'status': 'error',
            'message': 'Halaman chapter tidak tersedia di MangaDex',
        }), 404

    pages = [
        f'{base_url}/data/{quote(content_hash, safe="")}/{quote(filename, safe="")}'
        for filename in filenames
    ]
    return jsonify({
        'status': 'success',
        'source': 'mangadex',
        'data': {'pages': pages},
    }), 200


VALID_READ_STATUS = ('reading', 'plan', 'completed')


def get_user_id():
    data = request.get_json(silent=True) or {}
    raw = request.args.get('user_id') or data.get('user_id')
    try:
        return int(raw)
    except (TypeError, ValueError):
        return None


def _get_manga_id(data):
    try:
        return str(uuid.UUID(str(data.get('manga_id') or '')))
    except (ValueError, AttributeError):
        return None


@api.route('/api/bookmark', methods=['GET'])
def get_bookmarks():
    user_id = get_user_id()
    if not user_id:
        return jsonify({'status': 'error', 'message': 'Login dulu'}), 401

    rows = execute_query(
        'SELECT manga_id AS id, title, image_url AS link_gambar, read_status '
        'FROM bookmarks WHERE user_id = %s ORDER BY created_at DESC',
        (user_id,),
    )
    for row in rows:
        row['bookmark'] = True
        row['mangadex_url'] = f'https://mangadex.org/title/{row["id"]}'
    return jsonify({'status': 'success', 'data': rows}), 200


@api.route('/api/bookmark', methods=['POST'])
def add_bookmark():
    data = request.get_json(silent=True) or {}
    user_id = get_user_id()
    manga_id = _get_manga_id(data)
    if not user_id or not manga_id:
        return jsonify({
            'status': 'error',
            'message': 'user_id dan manga_id MangaDex yang valid wajib',
        }), 400

    execute_write(
        'INSERT INTO bookmarks (user_id, manga_id, title, image_url) '
        'VALUES (%s, %s, %s, %s) '
        'ON DUPLICATE KEY UPDATE title = VALUES(title), image_url = VALUES(image_url)',
        (
            user_id,
            manga_id,
            (data.get('title') or '')[:255],
            (data.get('image_url') or '')[:500],
        ),
    )
    return jsonify({'status': 'success', 'message': 'Bookmark disimpan'}), 201


@api.route('/api/bookmark/<uuid:manga_id>', methods=['GET'])
def is_bookmarked(manga_id):
    user_id = get_user_id()
    if not user_id:
        return jsonify({'status': 'success', 'isBookmarked': False}), 200

    rows = execute_query(
        'SELECT read_status FROM bookmarks '
        'WHERE user_id = %s AND manga_id = %s LIMIT 1',
        (user_id, str(manga_id)),
    )
    return jsonify({
        'status': 'success',
        'isBookmarked': bool(rows),
        'readStatus': rows[0]['read_status'] if rows else None,
    }), 200


@api.route('/api/bookmark/<uuid:manga_id>', methods=['PUT'])
def update_bookmark(manga_id):
    data = request.get_json(silent=True) or {}
    user_id = get_user_id()
    read_status = data.get('read_status')
    if not user_id:
        return jsonify({'status': 'error', 'message': 'Login dulu'}), 401
    if read_status not in VALID_READ_STATUS:
        return jsonify({'status': 'error', 'message': 'Status tidak valid'}), 400

    exists = execute_query(
        'SELECT id FROM bookmarks WHERE user_id = %s AND manga_id = %s LIMIT 1',
        (user_id, str(manga_id)),
    )
    if not exists:
        return jsonify({
            'status': 'error',
            'message': 'Bookmark tidak ditemukan',
        }), 404

    execute_write(
        'UPDATE bookmarks SET read_status = %s '
        'WHERE user_id = %s AND manga_id = %s',
        (read_status, user_id, str(manga_id)),
    )
    return jsonify({'status': 'success', 'message': 'Status diperbarui'}), 200


@api.route('/api/bookmark/<uuid:manga_id>', methods=['DELETE'])
def remove_bookmark(manga_id):
    user_id = get_user_id()
    if not user_id:
        return jsonify({'status': 'error', 'message': 'Login dulu'}), 401

    execute_write(
        'DELETE FROM bookmarks WHERE user_id = %s AND manga_id = %s',
        (user_id, str(manga_id)),
    )
    return jsonify({'status': 'success', 'message': 'Bookmark dihapus'}), 200

# Review API routes
@api.route('/api/manga/<uuid:manga_id>/reviews', methods=['GET'])
def get_manga_reviews(manga_id):
    manga_id = str(manga_id)
    reviews = execute_query(
        'SELECT r.id, r.user_id, u.nama AS user_name, r.rating, r.comment, r.created_at '
        'FROM reviews r JOIN users u ON r.user_id = u.id '
        'WHERE r.manga_id = %s ORDER BY r.created_at DESC',
        (manga_id,),
    )
    for rev in reviews:
        if isinstance(rev.get('created_at'), datetime):
            rev['created_at'] = rev['created_at'].strftime('%Y-%m-%d %H:%M')
    return jsonify({'status': 'success', 'data': reviews}), 200


@api.route('/api/manga/<uuid:manga_id>/reviews', methods=['POST'])
def add_manga_review(manga_id):
    manga_id = str(manga_id)
    data = request.get_json(silent=True) or {}
    user_id = data.get('user_id')
    rating = data.get('rating')
    comment = (data.get('comment') or '').strip()

    if not user_id:
        return jsonify({'status': 'error', 'message': 'Login dulu untuk memberi ulasan'}), 401
    
    try:
        user_id = int(user_id)
    except (TypeError, ValueError):
        return jsonify({'status': 'error', 'message': 'user_id tidak valid'}), 400

    if not rating or not isinstance(rating, int) or rating < 1 or rating > 5:
        return jsonify({'status': 'error', 'message': 'Rating harus antara 1 sampai 5 bintang'}), 400
    
    if not comment:
        return jsonify({'status': 'error', 'message': 'Ulasan tidak boleh kosong'}), 400

    execute_write(
        'INSERT INTO reviews (user_id, manga_id, rating, comment) VALUES (%s, %s, %s, %s)',
        (user_id, manga_id, rating, comment),
    )
    return jsonify({'status': 'success', 'message': 'Ulasan berhasil ditambahkan'}), 201


@api.route('/api', methods=['GET'])
@api.route('/api/health', methods=['GET'])
def health():
    return jsonify({'status': 'API running'}), 200
