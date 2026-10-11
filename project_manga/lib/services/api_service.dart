import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:project_manga/models/manga.dart';
import 'package:project_manga/screens/auth/user/user_session.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:5000/api';
  static const Duration timeout = Duration(seconds: 30);
  static List<Manga>? _mangaCache;
  static final Map<int, String> bookmarkStatus = {};

  static Future<List<Manga>> getAllManga() async {
    if (_mangaCache != null) return List<Manga>.of(_mangaCache!);
    final response = await http
        .get(Uri.parse('$baseUrl/manga'))
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception('Failed to load manga: ${response.statusCode}');
    }
    final data = (jsonDecode(response.body)['data'] as List<dynamic>? ?? []);
    final manga = data.map((item) => Manga.fromApiJson(item)).toList();
    _mangaCache = manga;
    return List<Manga>.of(manga);
  }

  static Future<List<Manga>> searchManga(String query) async {
    final uri = Uri.parse(
      '$baseUrl/manga/search?q=${Uri.encodeQueryComponent(query)}',
    );
    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode != 200) throw Exception('Search failed');
    final data = (jsonDecode(response.body)['data'] as List<dynamic>? ?? []);
    return data.map((item) => Manga.fromApiJson(item)).toList();
  }

  static Future<Manga> getMangaDetail(int id) async {
    final response = await http
        .get(Uri.parse('$baseUrl/manga/$id'))
        .timeout(timeout);
    if (response.statusCode != 200) throw Exception('Manga not found');
    return Manga.fromApiJson(jsonDecode(response.body)['data']);
  }

  static Future<List<Manga>> getMangaByGenre(List<String> genres) async {
    final manga = await getAllManga();
    final matches = _filterByGenres(manga, genres);
    if (matches.isNotEmpty) return matches;

    final searchResults = <Manga>[];
    for (final genre in genres) {
      searchResults.addAll(await searchManga(genre));
    }
    final unique = <String, Manga>{
      for (final item in searchResults) _mangaKey(item): item,
    };
    return _filterByGenres(unique.values.toList(), genres);
  }

  static List<Manga> _filterByGenres(List<Manga> manga, List<String> genres) {
    return manga
        .where(
          (item) => genres.every(
            (genre) => item.genre.any(
              (value) =>
                  value.trim().toLowerCase() == genre.trim().toLowerCase(),
            ),
          ),
        )
        .toList();
  }

  static String _mangaKey(Manga manga) =>
      manga.id > 0 ? 'id:${manga.id}' : 'title:${manga.title.toLowerCase()}';

  static int _requireUserId() {
    final userId = UserSession.id;
    if (userId == null) throw Exception('Login dulu untuk memakai bookmark');
    return userId;
  }

  static String statusLabel(String? status) {
    switch (status) {
      case 'reading':
        return 'Sedang dibaca';
      case 'completed':
        return 'Selesai';
      default:
        return 'Ingin dibaca';
    }
  }

  static Future<void> addBookmark(Manga manga) async {
    final userId = _requireUserId();
    final response = await http
        .post(
          Uri.parse('$baseUrl/bookmark'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'manga_id': manga.id,
            'title': manga.title,
            'image_url': manga.linkGambar,
          }),
        )
        .timeout(timeout);
    if (response.statusCode != 201) throw Exception('Failed to bookmark');
  }

  static Future<List<Manga>> getBookmarks() async {
    final userId = _requireUserId();
    final response = await http
        .get(Uri.parse('$baseUrl/bookmark?user_id=$userId'))
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception('Failed to load bookmarks');
    }
    final data = (jsonDecode(response.body)['data'] as List<dynamic>? ?? []);
    bookmarkStatus.clear();
    for (final item in data) {
      final id = item['mal_id'];
      if (id is int) {
        bookmarkStatus[id] = item['read_status']?.toString() ?? 'plan';
      }
    }
    return data.map((item) => Manga.fromApiJson(item)).toList();
  }

  static Future<bool> isBookmarked(int mangaId) async {
    final userId = UserSession.id;
    if (userId == null) return false;
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/bookmark/$mangaId?user_id=$userId'))
          .timeout(timeout);
      if (response.statusCode != 200) return false;
      return jsonDecode(response.body)['isBookmarked'] ?? false;
    } catch (error) {
      developer.log('Error checking bookmark: $error', name: 'ApiService');
      return false;
    }
  }

  static Future<String?> getBookmarkStatus(int mangaId) async {
    final userId = UserSession.id;
    if (userId == null) return null;
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/bookmark/$mangaId?user_id=$userId'))
          .timeout(timeout);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      return data['isBookmarked'] == true
          ? data['readStatus']?.toString() ?? 'plan'
          : null;
    } catch (error) {
      developer.log(
        'Error checking bookmark status: $error',
        name: 'ApiService',
      );
      return null;
    }
  }

  static Future<void> removeBookmark(int mangaId) async {
    final userId = _requireUserId();
    final response = await http
        .delete(Uri.parse('$baseUrl/bookmark/$mangaId?user_id=$userId'))
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception('Failed to remove bookmark');
    }
  }

  static Future<void> updateBookmarkStatus(int mangaId, String status) async {
    final userId = _requireUserId();
    final response = await http
        .put(
          Uri.parse('$baseUrl/bookmark/$mangaId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': userId, 'read_status': status}),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception('Failed to update bookmark');
    }
  }
}
