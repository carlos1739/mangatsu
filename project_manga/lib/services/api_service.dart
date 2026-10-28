import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:project_manga/models/manga.dart';
import 'package:project_manga/screens/auth/user/user_session.dart';

class ApiService {
  static String get baseUrl =>
      kIsWeb
          ? Uri.base.resolve('/api').toString()
          : 'http://127.0.0.1:5000/api';
  static const Duration timeout = Duration(seconds: 30);
  static List<Manga>? _mangaCache;
  static final Map<String, String> bookmarkStatus = {};

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

  static Future<Manga> getMangaDetail(String id) async {
    final response = await http
        .get(Uri.parse('$baseUrl/manga/$id'))
        .timeout(timeout);
    if (response.statusCode != 200) throw Exception('Manga not found');
    return Manga.fromApiJson(jsonDecode(response.body)['data']);
  }

  static Future<MangaChapterPage> getMangaChapters(
    String mangaId, {
    int page = 1,
  }) async {
    final uri = Uri.parse('$baseUrl/manga/$mangaId/chapters').replace(
      queryParameters: {
        'page': '$page',
        'language': ['id', 'en'],
      },
    );
    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat chapter: ${response.statusCode}');
    }
    return MangaChapterPage.fromApiJson(jsonDecode(response.body));
  }

  static Future<List<String>> getChapterPages(String chapterId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/chapter/$chapterId/pages'))
        .timeout(timeout);
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(
        body['message']?.toString() ??
            'Gagal memuat halaman chapter: ${response.statusCode}',
      );
    }
    final pages =
        (jsonDecode(response.body)['data']['pages'] as List<dynamic>? ?? []);
    return pages.map((page) => page.toString()).toList();
  }

  static Future<List<Manga>> getMangaByGenre(List<String> genres) async {
    final results = <Manga>[];
    for (final genre in genres) {
      final uri = Uri.parse(
        '$baseUrl/manga/genre/${Uri.encodeComponent(genre)}',
      );
      final response = await http.get(uri).timeout(timeout);
      if (response.statusCode != 200) {
        throw Exception('Gagal memuat genre: ${response.statusCode}');
      }
      final data = (jsonDecode(response.body)['data'] as List<dynamic>? ?? []);
      results.addAll(data.map((item) => Manga.fromApiJson(item)));
    }
    return {
      for (final manga in results) _mangaKey(manga): manga,
    }.values.toList();
  }

  static String _mangaKey(Manga manga) =>
      manga.id.isNotEmpty ? manga.id : manga.title.toLowerCase();

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
      final id = item['id']?.toString();
      if (id != null && id.isNotEmpty) {
        bookmarkStatus[id] = item['read_status']?.toString() ?? 'plan';
      }
    }
    return data.map((item) => Manga.fromApiJson(item)).toList();
  }

  static Future<bool> isBookmarked(String mangaId) async {
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

  static Future<String?> getBookmarkStatus(String mangaId) async {
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

  static Future<void> removeBookmark(String mangaId) async {
    final userId = _requireUserId();
    final response = await http
        .delete(Uri.parse('$baseUrl/bookmark/$mangaId?user_id=$userId'))
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception('Failed to remove bookmark');
    }
  }

  static Future<void> updateBookmarkStatus(
    String mangaId,
    String status,
  ) async {
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

  // Review API methods
  static Future<List<Map<String, dynamic>>> getReviews(String mangaId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/manga/$mangaId/reviews'))
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat ulasan');
    }
    final data = (jsonDecode(response.body)['data'] as List<dynamic>? ?? []);
    return data.map((item) => item as Map<String, dynamic>).toList();
  }

  static Future<void> addReview(String mangaId, int rating, String comment) async {
    final userId = _requireUserId();
    final response = await http
        .post(
          Uri.parse('$baseUrl/manga/$mangaId/reviews'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'rating': rating,
            'comment': comment,
          }),
        )
        .timeout(timeout);
    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Gagal mengirim ulasan');
    }
  }
}
