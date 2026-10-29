import os
from threading import local
from datetime import datetime, timedelta
from typing import Any
from urllib.parse import quote

import requests


MANGADEX_API = os.getenv('MANGADEX_API', 'https://api.mangadex.org').rstrip('/')
CACHE_HOURS = 24
MANGADEX_TIMEOUT = (5, 15)
LIST_CACHE: dict[str, Any] = {}
TAG_CACHE: tuple[datetime, dict[str, str]] | None = None
GENRE_COUNT_CACHE: dict[str, tuple[datetime, int]] = {}


def create_http_session():
    session = requests.Session()
    session.headers.update({'User-Agent': 'Mangatsu/1.0'})
    return session


HTTP_SESSIONS = local()


def _http_session():
    session = getattr(HTTP_SESSIONS, 'session', None)
    if session is None:
        session = create_http_session()
        HTTP_SESSIONS.session = session
    return session


def fetch_mangadex(path: str, params: dict[str, Any] | None = None):
    try:
        response = _http_session().get(
            f'{MANGADEX_API}{path}',
            params=params,
            timeout=MANGADEX_TIMEOUT,
        )
        if response.status_code == 200:
            return response.json(), None
        if response.status_code == 404:
            return None, ('Data tidak ditemukan di MangaDex', 404)
        if response.status_code == 429:
            return None, ('Rate limit MangaDex, coba lagi sebentar', 429)
        return None, (f'MangaDex error {response.status_code}', 502)
    except requests.exceptions.Timeout:
        return None, ('MangaDex timeout', 504)
    except requests.exceptions.RequestException as error:
        return None, (f'Tidak bisa terhubung ke MangaDex: {error}', 503)
    except ValueError:
        return None, ('Respons MangaDex bukan JSON yang valid', 502)


def _localized_value(values: dict[str, Any], languages: tuple[str, ...]) -> str:
    for language in languages:
        value = values.get(language)
        if value:
            return str(value)
    return str(next(iter(values.values()), ''))


def parse_mangadex_response(item: dict[str, Any]) -> dict[str, Any] | None:
    manga_id = item.get('id')
    attributes = item.get('attributes') or {}
    if not manga_id or not attributes:
        return None

    relationships = item.get('relationships') or []
    author_names = [
        relationship.get('attributes', {}).get('name')
        for relationship in relationships
        if relationship.get('type') in ('author', 'artist')
        and relationship.get('attributes', {}).get('name')
    ]
    cover_filename = next(
        (
            relationship.get('attributes', {}).get('fileName')
            for relationship in relationships
            if relationship.get('type') == 'cover_art'
            and relationship.get('attributes', {}).get('fileName')
        ),
        None,
    )
    tags = [
        _localized_value(
            (tag.get('attributes') or {}).get('name') or {},
            ('en', 'id', 'ja-ro'),
        )
        for tag in attributes.get('tags') or []
    ]
    tags = [tag for tag in tags if tag]
    cover_url = (
        f'https://uploads.mangadex.org/covers/{manga_id}/'
        f'{quote(cover_filename, safe="")}'
        if cover_filename
        else ''
    )
    year = attributes.get('year')

    return {
        'id': str(manga_id),
        'title': _localized_value(
            attributes.get('title') or {},
            ('en', 'id', 'ja-ro'),
        )[:255] or 'Unknown',
        'author': ', '.join(dict.fromkeys(author_names))[:255] or 'Unknown',
        'chapter': str(attributes.get('lastChapter') or 'N/A'),
        'status': (attributes.get('status') or 'Unknown')[:50],
        'synopsis': _localized_value(
            attributes.get('description') or {},
            ('id', 'en', 'ja-ro'),
        ),
        'release': str(year) if year else 'Unknown',
        'genre': tags[:],
        'rating': 0.0,
        'link_gambar': cover_url,
        'mangadex_url': f'https://mangadex.org/title/{manga_id}',
    }


def save_many(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    seen: set[str] = set()
    for item in items:
        parsed = parse_mangadex_response(item)
        if parsed and parsed['id'] not in seen:
            seen.add(parsed['id'])
            result.append(parsed)
    return result


def parse_mangadex_chapter(item: dict[str, Any]) -> dict[str, Any] | None:
    chapter_id = item.get('id')
    attributes = item.get('attributes') or {}
    if not chapter_id:
        return None
    return {
        'id': str(chapter_id),
        'chapter': str(attributes.get('chapter') or '?'),
        'title': attributes.get('title') or '',
        'language': attributes.get('translatedLanguage') or '',
        'pages': attributes.get('pages') or 0,
    }


def get_mangadex_tags() -> tuple[dict[str, str] | None, tuple[str, int] | None]:
    global TAG_CACHE
    if TAG_CACHE and is_fresh(TAG_CACHE[0]):
        return TAG_CACHE[1], None

    response, error = fetch_mangadex('/manga/tag')
    if error:
        return None, error

    tags: dict[str, str] = {}
    for item in response.get('data') or []:
        attributes = item.get('attributes') or {}
        name = _localized_value(attributes.get('name') or {}, ('en', 'id'))
        if name and item.get('id'):
            tags[name.casefold()] = str(item['id'])
    TAG_CACHE = (datetime.utcnow(), tags)
    return tags, None


def is_fresh(timestamp: datetime) -> bool:
    return datetime.utcnow() - timestamp < timedelta(hours=CACHE_HOURS)
