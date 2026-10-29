import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:project_manga/models/manga.dart';
import 'package:project_manga/screens/auth/user/user_session.dart';
import 'package:project_manga/services/api_service.dart';

class FavoriteService {
  static String get _base => ApiService.baseUrl;
  static const Duration _timeout = ApiService.timeout;

  static int _requireUserId() {
    final userId = UserSession.id;
    if (userId == null) throw Exception('Login dulu untuk memakai favorit');
    return userId;
  }

  static Future<bool> isFavorite(String mangaId) async {
    final userId = UserSession.id;
    if (userId == null) return false;
    try {
      final response = await http
          .get(Uri.parse('$_base/favorites/$mangaId?user_id=$userId'))
          .timeout(_timeout);
      if (response.statusCode != 200) return false;
      return jsonDecode(response.body)['isFavorite'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> addFavorite(Manga manga) async {
    final userId = _requireUserId();
    final response = await http
        .post(
          Uri.parse('$_base/favorites'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'manga_id': manga.id,
            'title': manga.title,
            'image_url': manga.linkGambar,
          }),
        )
        .timeout(_timeout);
    if (response.statusCode != 201) {
      throw Exception('Gagal menambah favorit');
    }
  }

  static Future<void> removeFavorite(String mangaId) async {
    final userId = _requireUserId();
    final response = await http
        .delete(Uri.parse('$_base/favorites/$mangaId?user_id=$userId'))
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('Gagal menghapus favorit');
    }
  }

  static Future<List<Manga>> getFavorites() async {
    final userId = _requireUserId();
    final response = await http
        .get(Uri.parse('$_base/favorites?user_id=$userId'))
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat favorit');
    }
    final data = (jsonDecode(response.body)['data'] as List<dynamic>? ?? []);
    return data.map((item) => Manga.fromApiJson(item)).toList();
  }
}