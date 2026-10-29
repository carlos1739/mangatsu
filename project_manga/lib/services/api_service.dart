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

  static Future<List<Manga>> getTrendingManga(String period) async {
    final uri = Uri.parse(
      '$baseUrl/manga/trending',
    ).replace(queryParameters: {'period': period});
    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception(
        _apiErrorMessage(
          response.body,
          statusCode: response.statusCode,
          fallback: 'Gagal memuat manga trending',
        ),
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final manga = data['data'] as List<dynamic>? ?? const [];
    return manga.map((item) => Manga.fromApiJson(item)).toList();
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

  static Future<MangaGenrePage> getMangaByGenre(
    String genre, {
    int page = 1,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/manga/genre/${Uri.encodeComponent(genre)}',
    ).replace(queryParameters: {'page': '$page'});
    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception(
        _apiErrorMessage(
          response.body,
          statusCode: response.statusCode,
          fallback: 'Gagal memuat genre',
        ),
      );
    }
    return MangaGenrePage.fromApiJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<Map<String, int>> getMangaGenreCounts(
    List<String> genres,
  ) async {
    final uri = Uri.parse(
      '$baseUrl/manga/genre-counts',
    ).replace(queryParameters: {'genres': genres.join('|')});
    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception(
        _apiErrorMessage(
          response.body,
          statusCode: response.statusCode,
          fallback: 'Gagal memuat jumlah manga per genre',
        ),
      );
    }
    final data =
        (jsonDecode(response.body)['data'] as Map<String, dynamic>? ?? {});
    return data.map((genre, count) => MapEntry(genre, (count as num).toInt()));
  }

  static int _requireUserId() {
    final userId = UserSession.id;
    if (userId == null) throw Exception('Login dulu untuk memakai bookmark');
    return userId;
  }

  static String _apiErrorMessage(
    String body, {
    required int statusCode,
    required String fallback,
  }) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } on FormatException {
      // Non-JSON server errors are reported by status code below.
    }
    return '$fallback (HTTP $statusCode)';
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

  static Future<Map<String, dynamic>?> getReadingProgress(
    String mangaId,
  ) async {
    final userId = UserSession.id;
    if (userId == null) return null;
    final response = await http
        .get(Uri.parse('$baseUrl/reading/progress/$mangaId?user_id=$userId'))
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception(
        _apiErrorMessage(
          response.body,
          statusCode: response.statusCode,
          fallback: 'Gagal memuat progres membaca',
        ),
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is! Map<String, dynamic>) return null;
    return {
      ...data,
      'is_bookmarked': body['is_bookmarked'] == true,
      'has_progress': body['has_progress'] == true,
    };
  }

  static Future<int> recordChapterRead(
    Manga manga,
    MangaChapter chapter, {
    required int totalChapters,
    int currentPage = 0,
    int totalPages = 0,
  }) async {
    final userId = _requireUserId();
    final response = await http
        .post(
          Uri.parse('$baseUrl/reading/progress'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'manga_id': manga.id,
            'manga_title': manga.title,
            'image_url': manga.linkGambar,
            'chapter_id': chapter.id,
            'chapter_number': chapter.chapter,
            'chapter_title': chapter.title,
            'chapter_language': chapter.language,
            'total_chapters': totalChapters,
            'current_page': currentPage,
            'total_pages': totalPages,
          }),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception(
        _apiErrorMessage(
          response.body,
          statusCode: response.statusCode,
          fallback: 'Gagal menyimpan progres membaca',
        ),
      );
    }
    final data = jsonDecode(response.body)['data'] as Map<String, dynamic>;
    return data['progress_percent'] as int? ?? 0;
  }

  static Future<Map<String, dynamic>> getReadingSummary() async {
    final userId = _requireUserId();
    final response = await http
        .get(Uri.parse('$baseUrl/reading/summary?user_id=$userId'))
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception(
        _apiErrorMessage(
          response.body,
          statusCode: response.statusCode,
          fallback: 'Gagal memuat statistik membaca',
        ),
      );
    }
    return jsonDecode(response.body)['data'] as Map<String, dynamic>;
  }

  static Future<void> deleteReadingProgress(String mangaId) async {
    final userId = _requireUserId();
    final response = await http
        .delete(Uri.parse('$baseUrl/reading/progress/$mangaId?user_id=$userId'))
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception(
        _apiErrorMessage(
          response.body,
          statusCode: response.statusCode,
          fallback: 'Gagal menghapus progres membaca',
        ),
      );
    }
  }

  static Future<void> updateReadingStatus(Manga manga, String status) async {
    final userId = _requireUserId();
    final response = await http
        .put(
          Uri.parse('$baseUrl/reading/status'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'manga_id': manga.id,
            'manga_title': manga.title,
            'image_url': manga.linkGambar,
            'read_status': status,
          }),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception(
        _apiErrorMessage(
          response.body,
          statusCode: response.statusCode,
          fallback: 'Gagal memperbarui status baca',
        ),
      );
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

  // Review API methods
  static Future<List<Map<String, dynamic>>> getReviews(String mangaId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/manga/$mangaId/reviews'))
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception(
        _apiErrorMessage(
          response.body,
          statusCode: response.statusCode,
          fallback: 'Gagal memuat ulasan',
        ),
      );
    }
    final data = (jsonDecode(response.body)['data'] as List<dynamic>? ?? []);
    return data.map((item) => item as Map<String, dynamic>).toList();
  }

  static Future<void> addReview(
    String mangaId,
    int rating,
    String comment,
  ) async {
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
      throw Exception(
        _apiErrorMessage(
          response.body,
          statusCode: response.statusCode,
          fallback: 'Gagal mengirim ulasan',
        ),
      );
    }
  }
}
