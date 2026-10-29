import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from urllib.parse import quote

from flask import Blueprint, jsonify, request

from database.db import execute_query, execute_write

from .services import (
    LIST_CACHE,
    GENRE_COUNT_CACHE,
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


@api.route('/api/manga/trending', methods=['GET'])
def get_trending_manga():
    period_days = {
        'daily': 1,
        'weekly': 7,
        'monthly': 30,
    }.get(request.args.get('period', 'daily'))
    if period_days is None:
        return jsonify({
            'status': 'error',
            'message': 'Periode harus daily, weekly, atau monthly',
        }), 400

    manga = execute_query(
        'SELECT h.manga_id AS id, MAX(p.manga_title) AS title, '
        'MAX(p.image_url) AS link_gambar, '
        'COUNT(DISTINCT h.user_id) AS view '
        'FROM reading_history h '
        'JOIN reading_progress p '
        'ON p.user_id = h.user_id AND p.manga_id = h.manga_id '
        f'WHERE h.last_read_at >= DATE_SUB(CURRENT_TIMESTAMP, INTERVAL {period_days} DAY) '
        'GROUP BY h.manga_id '
        'ORDER BY view DESC, MAX(h.last_read_at) DESC '
        'LIMIT 25',
    )
    for item in manga:
        item['mangadex_url'] = f'https://mangadex.org/title/{item["id"]}'

    return jsonify({
        'status': 'success',
        'period': request.args.get('period', 'daily'),
        'data': manga,
    }), 200


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


@api.route('/api/manga/genre-counts', methods=['GET'])
def get_genre_counts():
    requested_genres = list(dict.fromkeys(
        genre.strip()
        for genre in request.args.get('genres', '').split('|')
        if genre.strip()
    ))
    if not requested_genres:
        return jsonify({
            'status': 'success',
            'data': {},
        }), 200
    if len(requested_genres) > 100:
        return jsonify({
            'status': 'error',
            'message': 'Maksimal 100 genre per permintaan',
        }), 400

    tags, error = get_mangadex_tags()
    if error:
        return _error_response(error)

    genre_tags = {
        genre: tags.get(genre.replace('-', ' ').casefold())
        for genre in requested_genres
    }

    def fetch_count(item):
        genre, tag_id = item
        if not tag_id:
            return genre, 0, None
        cached = GENRE_COUNT_CACHE.get(tag_id)
        if cached and is_fresh(cached[0]):
            return genre, cached[1], None

        response, fetch_error = fetch_mangadex(
            '/manga',
            _manga_params(
                1,
                0,
                **{
                    'includedTags[]': [tag_id],
                    'order[followedCount]': 'desc',
                },
            ),
        )
        if fetch_error:
            return genre, None, fetch_error

        total = int(response.get('total') or 0)
        GENRE_COUNT_CACHE[tag_id] = (datetime.utcnow(), total)
        return genre, total, None

    with ThreadPoolExecutor(max_workers=4) as executor:
        results = list(executor.map(fetch_count, genre_tags.items()))

    errors = [error for _, _, error in results if error]
    if errors:
        return _error_response(errors[0])

    return jsonify({
        'status': 'success',
        'data': {genre: count for genre, count, _ in results},
    }), 200


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


def _get_chapter_id(data):
    try:
        return str(uuid.UUID(str(data.get('chapter_id') or '')))
    except (ValueError, AttributeError):
        return None


@api.route('/api/bookmark', methods=['GET'])
def get_bookmarks():
    user_id = get_user_id()
    if not user_id:
        return jsonify({'status': 'error', 'message': 'Login dulu'}), 401

    rows = execute_query(
        'SELECT b.manga_id AS id, b.title, b.image_url AS link_gambar, '
        'COALESCE(p.read_status, b.read_status) AS read_status, '
        'p.last_chapter_id, p.last_chapter_number, p.last_chapter_title, '
        'p.last_chapter_language, p.last_read_at, p.total_chapters, '
        'p.completed_chapters, p.progress_percent '
        'FROM bookmarks b LEFT JOIN reading_progress p '
        'ON p.user_id = b.user_id AND p.manga_id = b.manga_id '
        'WHERE b.user_id = %s ORDER BY b.created_at DESC',
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

    progress = execute_query(
        'SELECT read_status, last_chapter_id, last_chapter_number, '
        'last_chapter_title, last_chapter_language, last_read_at '
        'FROM reading_progress '
        'WHERE user_id = %s AND manga_id = %s LIMIT 1',
        (user_id, str(manga_id)),
    )
    bookmark = execute_query(
        'SELECT id, read_status FROM bookmarks '
        'WHERE user_id = %s AND manga_id = %s LIMIT 1',
        (user_id, str(manga_id)),
    )
    progress_data = progress[0] if progress else {}
    return jsonify({
        'status': 'success',
        'isBookmarked': bool(bookmark),
        'readStatus': (
            progress[0]['read_status']
            if progress
            else bookmark[0]['read_status'] if bookmark else None
        ),
        **{
            'lastChapterId': progress_data.get('last_chapter_id'),
            'lastChapterNumber': progress_data.get('last_chapter_number'),
            'lastChapterTitle': progress_data.get('last_chapter_title'),
            'lastChapterLanguage': progress_data.get('last_chapter_language'),
        },
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
        'SELECT id, title, image_url FROM bookmarks '
        'WHERE user_id = %s AND manga_id = %s LIMIT 1',
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
    execute_write(
        'INSERT INTO reading_progress '
        '(user_id, manga_id, manga_title, image_url, read_status) '
        'VALUES (%s, %s, %s, %s, %s) '
        'ON DUPLICATE KEY UPDATE read_status = VALUES(read_status), '
        'manga_title = VALUES(manga_title), image_url = VALUES(image_url)',
        (
            user_id,
            str(manga_id),
            exists[0]['title'],
            exists[0]['image_url'],
            read_status,
        ),
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


@api.route('/api/reading/progress/<uuid:manga_id>', methods=['GET'])
def get_reading_progress(manga_id):
    user_id = get_user_id()
    if not user_id:
        return jsonify({'status': 'error', 'message': 'Login dulu'}), 401

    manga_id = str(manga_id)
    bookmark = execute_query(
        'SELECT id, read_status FROM bookmarks '
        'WHERE user_id = %s AND manga_id = %s LIMIT 1',
        (user_id, manga_id),
    )
    rows = execute_query(
        'SELECT manga_id AS id, manga_title AS title, image_url AS link_gambar, '
        'read_status, last_chapter_id, last_chapter_number, '
        'last_chapter_title, last_chapter_language, last_read_at, '
        'total_chapters, completed_chapters, progress_percent '
        'FROM reading_progress WHERE user_id = %s AND manga_id = %s LIMIT 1',
        (user_id, manga_id),
    )
    if rows:
        completed_chapters = execute_query(
            'SELECT chapter_id FROM reading_history '
            'WHERE user_id = %s AND manga_id = %s '
            'AND total_pages > 0 AND current_page >= total_pages',
            (user_id, manga_id),
        )
        rows[0]['completed_chapter_ids'] = [
            row['chapter_id'] for row in completed_chapters
        ]
        if isinstance(rows[0].get('last_read_at'), datetime):
            rows[0]['last_read_at'] = rows[0]['last_read_at'].strftime(
                '%Y-%m-%d %H:%M'
            )
        return jsonify({
            'status': 'success',
            'is_bookmarked': bool(bookmark),
            'has_progress': True,
            'data': rows[0],
        }), 200

    bookmark_data = None
    if bookmark:
        bookmark_data = execute_query(
            'SELECT manga_id AS id, title, image_url AS link_gambar, read_status '
            'FROM bookmarks WHERE user_id = %s AND manga_id = %s LIMIT 1',
            (user_id, manga_id),
        )[0]
    return jsonify({
        'status': 'success',
        'is_bookmarked': bool(bookmark),
        'has_progress': False,
        'data': bookmark_data,
    }), 200


@api.route('/api/reading/progress/<uuid:manga_id>', methods=['DELETE'])
def delete_reading_progress(manga_id):
    user_id = get_user_id()
    if not user_id:
        return jsonify({'status': 'error', 'message': 'Login dulu'}), 401

    manga_id = str(manga_id)
    execute_write(
        'DELETE FROM reading_history WHERE user_id = %s AND manga_id = %s',
        (user_id, manga_id),
    )
    execute_write(
        'DELETE FROM reading_progress WHERE user_id = %s AND manga_id = %s',
        (user_id, manga_id),
    )
    execute_write(
        'UPDATE bookmarks SET read_status = %s '
        'WHERE user_id = %s AND manga_id = %s',
        ('plan', user_id, manga_id),
    )
    return jsonify({
        'status': 'success',
        'message': 'Progres membaca dihapus',
    }), 200


@api.route('/api/reading/progress', methods=['POST'])
def record_reading_progress():
    data = request.get_json(silent=True) or {}
    user_id = get_user_id()
    manga_id = _get_manga_id(data)
    chapter_id = _get_chapter_id(data)
    manga_title = (data.get('manga_title') or '').strip()
    chapter_number = (data.get('chapter_number') or '').strip()
    total_chapters = data.get('total_chapters')
    current_page = data.get('current_page', 0)
    total_pages = data.get('total_pages', 0)

    if not user_id:
        return jsonify({'status': 'error', 'message': 'Login dulu'}), 401
    if not manga_id or not chapter_id:
        return jsonify({
            'status': 'error',
            'message': 'ID manga dan chapter harus valid',
        }), 400
    if not manga_title or not chapter_number:
        return jsonify({
            'status': 'error',
            'message': 'Judul manga dan nomor chapter wajib diisi',
        }), 400
    if (
        not isinstance(total_chapters, int)
        or isinstance(total_chapters, bool)
        or total_chapters < 1
        or total_chapters > 4294967295
    ):
        return jsonify({
            'status': 'error',
            'message': 'Jumlah chapter tersedia tidak valid',
        }), 400
    if (
        not isinstance(current_page, int)
        or isinstance(current_page, bool)
        or not isinstance(total_pages, int)
        or isinstance(total_pages, bool)
        or current_page < 0
        or total_pages < 0
        or current_page > 65535
        or total_pages > 65535
        or current_page > total_pages
        or (total_pages == 0 and current_page != 0)
    ):
        return jsonify({
            'status': 'error',
            'message': 'Posisi halaman tidak valid',
        }), 400

    chapter_title = (data.get('chapter_title') or '').strip()[:255]
    chapter_language = (data.get('chapter_language') or '').strip()[:10]
    image_url = (data.get('image_url') or '').strip()[:500]
    execute_write(
        'INSERT INTO reading_progress '
        '(user_id, manga_id, manga_title, image_url, read_status, '
        'last_chapter_id, last_chapter_number, last_chapter_title, '
        'last_chapter_language, last_read_at, total_chapters) '
        'VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP, %s) '
        'ON DUPLICATE KEY UPDATE manga_title = VALUES(manga_title), '
        'image_url = VALUES(image_url), read_status = VALUES(read_status), '
        'last_chapter_id = VALUES(last_chapter_id), '
        'last_chapter_number = VALUES(last_chapter_number), '
        'last_chapter_title = VALUES(last_chapter_title), '
        'last_chapter_language = VALUES(last_chapter_language), '
        'last_read_at = CURRENT_TIMESTAMP, '
        'total_chapters = VALUES(total_chapters)',
        (
            user_id,
            manga_id,
            manga_title[:255],
            image_url or None,
            'reading',
            chapter_id,
            chapter_number[:50],
            chapter_title or None,
            chapter_language or None,
            total_chapters,
        ),
    )
    execute_write(
        'UPDATE bookmarks SET read_status = %s '
        'WHERE user_id = %s AND manga_id = %s',
        ('reading', user_id, manga_id),
    )
    if total_pages > 0 and current_page > 0:
        execute_write(
            'INSERT INTO reading_history '
            '(user_id, manga_id, chapter_id, chapter_number, chapter_title, '
            'current_page, total_pages) '
            'VALUES (%s, %s, %s, %s, %s, %s, %s) '
            'ON DUPLICATE KEY UPDATE chapter_number = VALUES(chapter_number), '
            'chapter_title = VALUES(chapter_title), '
            'current_page = GREATEST(current_page, VALUES(current_page)), '
            'total_pages = VALUES(total_pages), '
            'last_read_at = CURRENT_TIMESTAMP',
            (
                user_id,
                manga_id,
                chapter_id,
                chapter_number[:50],
                chapter_title or None,
                current_page,
                total_pages,
            ),
        )

        reading_counts = execute_query(
            'SELECT COALESCE(SUM('
            'CASE WHEN total_pages > 0 AND current_page >= total_pages '
            'THEN 1 ELSE 0 END'
            '), 0) AS completed_chapters, '
            'COALESCE(SUM('
            'CASE WHEN current_page < total_pages AND total_pages > 0 '
            'THEN current_page / total_pages ELSE 0 END'
            '), 0) AS partial_chapters FROM reading_history '
            'WHERE user_id = %s AND manga_id = %s',
            (user_id, manga_id),
        )[0]
        completed_chapters = int(reading_counts['completed_chapters'])
        progress_units = min(
            total_chapters,
            completed_chapters + float(reading_counts['partial_chapters']),
        )
        progress_percent = min(
            100,
            int(progress_units * 100 / total_chapters),
        )
        execute_write(
            'UPDATE reading_progress SET completed_chapters = %s, '
            'progress_percent = %s WHERE user_id = %s AND manga_id = %s',
            (completed_chapters, progress_percent, user_id, manga_id),
        )

    progress = execute_query(
        'SELECT completed_chapters, total_chapters, progress_percent '
        'FROM reading_progress WHERE user_id = %s AND manga_id = %s LIMIT 1',
        (user_id, manga_id),
    )[0]
    return jsonify({
        'status': 'success',
        'message': 'Progres chapter tersimpan',
        'data': progress,
    }), 200


@api.route('/api/reading/summary', methods=['GET'])
def get_reading_summary():
    user_id = get_user_id()
    if not user_id:
        return jsonify({'status': 'error', 'message': 'Login dulu'}), 401

    total_count = execute_query(
        'SELECT COUNT(*) AS total FROM reading_history '
        'WHERE user_id = %s AND current_page >= total_pages AND total_pages > 0',
        (user_id,),
    )[0]['total']
    total_series = execute_query(
        'SELECT COUNT(*) AS total FROM reading_progress WHERE user_id = %s',
        (user_id,),
    )[0]['total']
    status_counts = execute_query(
        'SELECT read_status, COUNT(*) AS total FROM ('
        'SELECT p.read_status FROM reading_progress p WHERE p.user_id = %s '
        'UNION ALL '
        'SELECT b.read_status FROM bookmarks b '
        'WHERE b.user_id = %s AND NOT EXISTS ('
        'SELECT 1 FROM reading_progress p '
        'WHERE p.user_id = b.user_id AND p.manga_id = b.manga_id'
        ')) AS user_statuses GROUP BY read_status',
        (user_id, user_id),
    )
    recent = execute_query(
        'SELECT manga_id AS id, manga_title AS title, '
        'image_url AS link_gambar, read_status, last_chapter_id, '
        'last_chapter_number, last_chapter_title, last_chapter_language, '
        'last_read_at, total_chapters, completed_chapters, progress_percent '
        'FROM reading_progress WHERE user_id = %s '
        'ORDER BY last_read_at DESC LIMIT 10',
        (user_id,),
    )
    for row in recent:
        row['mangadex_url'] = f'https://mangadex.org/title/{row["id"]}'
        row['progress_percent'] = int(row['progress_percent'])
        if isinstance(row.get('last_read_at'), datetime):
            row['last_read_at'] = row['last_read_at'].strftime('%Y-%m-%d %H:%M')

    return jsonify({
        'status': 'success',
        'data': {
            'total_chapters_read': total_count,
            'series_count': total_series,
            'status_counts': {
                row['read_status']: row['total'] for row in status_counts
            },
            'recent_progress': recent,
        },
    }), 200


@api.route('/api/reading/status', methods=['PUT'])
def update_reading_status():
    data = request.get_json(silent=True) or {}
    user_id = get_user_id()
    manga_id = _get_manga_id(data)
    read_status = data.get('read_status')
    manga_title = (data.get('manga_title') or '').strip()
    image_url = (data.get('image_url') or '').strip()[:500]

    if not user_id:
        return jsonify({'status': 'error', 'message': 'Login dulu'}), 401
    if not manga_id:
        return jsonify({'status': 'error', 'message': 'ID manga tidak valid'}), 400
    if read_status not in VALID_READ_STATUS:
        return jsonify({'status': 'error', 'message': 'Status tidak valid'}), 400

    bookmark = execute_query(
        'SELECT title, image_url FROM bookmarks '
        'WHERE user_id = %s AND manga_id = %s LIMIT 1',
        (user_id, manga_id),
    )
    if not manga_title and not bookmark:
        return jsonify({
            'status': 'error',
            'message': 'Judul manga wajib diisi',
        }), 400
    if bookmark:
        manga_title = manga_title or bookmark[0]['title']
        image_url = image_url or bookmark[0]['image_url'] or ''

    execute_write(
        'INSERT INTO reading_progress '
        '(user_id, manga_id, manga_title, image_url, read_status) '
        'VALUES (%s, %s, %s, %s, %s) '
        'ON DUPLICATE KEY UPDATE read_status = VALUES(read_status), '
        'manga_title = VALUES(manga_title), image_url = VALUES(image_url)',
        (user_id, manga_id, manga_title[:255], image_url or None, read_status),
    )
    execute_write(
        'UPDATE bookmarks SET read_status = %s '
        'WHERE user_id = %s AND manga_id = %s',
        (read_status, user_id, manga_id),
    )
    return jsonify({
        'status': 'success',
        'message': 'Status baca diperbarui',
    }), 200


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
