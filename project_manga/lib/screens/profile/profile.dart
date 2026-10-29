import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:project_manga/models/manga.dart';
import 'package:project_manga/screens/catalog/manga_detail.dart';
import 'package:project_manga/screens/auth/login.dart';
import 'package:project_manga/screens/auth/user/user_session.dart';
import 'package:project_manga/screens/home/home.dart';
import 'package:project_manga/services/appearance_controller.dart';
import 'package:project_manga/services/favorite_service.dart';

class Profil extends StatefulWidget {
  const Profil({super.key});

  @override
  State<Profil> createState() => _ProfilState();
}

class _ProfilState extends State<Profil> {
  static String get baseUrl =>
      kIsWeb ? Uri.base.origin : 'http://10.0.2.2:5000';

  bool _favoritesLoading = false;
  String? _favoritesError;
  List<Manga> _favorites = [];

  @override
  void initState() {
    super.initState();
    if (UserSession.isLoggedIn) _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    if (!UserSession.isLoggedIn) return;
    setState(() {
      _favoritesLoading = true;
      _favoritesError = null;
    });
    try {
      final favorites = await FavoriteService.getFavorites();
      if (!mounted) return;
      setState(() {
        _favorites = favorites;
        _favoritesLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _favoritesError = error.toString();
        _favoritesLoading = false;
      });
    }
  }

  Future<void> _removeFavorite(Manga manga) async {
    try {
      await FavoriteService.removeFavorite(manga.id);
      if (!mounted) return;
      setState(() => _favorites.removeWhere((item) => item.id == manga.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manga dihapus dari Favorit')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus Favorit: $error')),
      );
    }
  }

  Future<void> _openFavorite(Manga manga) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => MangaDetail(manga: manga)),
    );
    if (mounted) _loadFavorites();
  }

  void _logout(BuildContext context) {
    UserSession.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SignIn()),
      (route) => false,
    );
  }

  void _goHome(BuildContext context) {
    UserSession.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const Beranda()),
      (route) => false,
    );
  }

  /// Return null kalau berhasil, atau pesan error kalau gagal.
  Future<String?> _deleteAccount(String password) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/delete-account'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': UserSession.email ?? '',
          'password': password,
        }),
      );

      if (response.statusCode == 200) return null;

      try {
        final body = jsonDecode(response.body);
        return body['message']?.toString() ??
            'Gagal (kode ${response.statusCode})';
      } catch (_) {
        return 'Gagal (kode ${response.statusCode})';
      }
    } catch (e) {
      return 'Tidak bisa terhubung ke server: $e';
    }
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    final passwordController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Hapus Akun'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Apakah kamu yakin ingin menghapus akun ini? '
                    'Semua data akan hilang dan tidak bisa dikembalikan.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Masukkan password untuk konfirmasi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Tidak'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Ya', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    final error = await _deleteAccount(passwordController.text);

    if (!context.mounted) return;
    if (error == null) {
      _goHome(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: appearanceController,
      builder: (context, appearance, _) {
        final dark = appearance == 1;
        final background =
            dark
                ? const Color(0xff121212)
                : appearance == 2
                ? const Color(0xfff4ead5)
                : const Color(0xfff6f5f8);
        final surface =
            dark
                ? const Color(0xff1d1d1f)
                : appearance == 2
                ? const Color(0xfffff8e8)
                : Colors.white;
        final foreground = dark ? Colors.white : const Color(0xff24212a);

        return Scaffold(
          backgroundColor: background,
          appBar: AppBar(
            backgroundColor: dark ? const Color(0xff171719) : surface,
            foregroundColor: foreground,
            elevation: 0,
            title: const Text(
              'Profil',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            leading: IconButton(
              tooltip: 'Kembali',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                children: [
                  if (UserSession.isLoggedIn) ...[
                    _AccountCard(
                      name: UserSession.nama ?? 'Pengguna Mangatsu',
                      email: UserSession.email ?? '-',
                      surface: surface,
                      foreground: foreground,
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Icon(Icons.favorite_rounded, color: Colors.redAccent),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Favorit Saya',
                            style: TextStyle(
                              color: foreground,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Muat ulang',
                          onPressed: _favoritesLoading ? null : _loadFavorites,
                          icon: const Icon(Icons.refresh),
                        ),
                        Text(
                          '${_favorites.length}',
                          style: TextStyle(
                            color: foreground.withValues(alpha: .65),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildFavorites(surface, foreground),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () => _logout(context),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Keluar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: foreground,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: foreground.withValues(alpha: .18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => _showDeleteDialog(context),
                      icon: const Icon(Icons.delete_outline, size: 19),
                      label: const Text('Hapus akun'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                    ),
                  ] else ...[
                    _LoginPrompt(
                      surface: surface,
                      foreground: foreground,
                      onLogin: () => _logout(context),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFavorites(Color surface, Color foreground) {
    if (_favoritesLoading && _favorites.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_favoritesError != null && _favorites.isEmpty) {
      return _FavoritesMessage(
        surface: surface,
        icon: Icons.cloud_off_outlined,
        title: 'Favorit belum bisa dimuat',
        subtitle: _favoritesError!,
        actionLabel: 'Coba lagi',
        onAction: _loadFavorites,
      );
    }
    if (_favorites.isEmpty) {
      return _FavoritesMessage(
        surface: surface,
        icon: Icons.favorite_border_rounded,
        title: 'Belum ada manga favorit',
        subtitle:
            'Tekan tombol Favorit di halaman detail manga untuk menyimpan.',
      );
    }

    return Column(
      children: [
        for (final manga in _favorites)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _FavoriteTile(
              manga: manga,
              surface: surface,
              foreground: foreground,
              onTap: () => _openFavorite(manga),
              onRemove: () => _removeFavorite(manga),
            ),
          ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  final String name;
  final String email;
  final Color surface;
  final Color foreground;

  const _AccountCard({
    required this.name,
    required this.email,
    required this.surface,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: foreground.withValues(alpha: .08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xffd3a7ff),
            child: Text(
              name.isEmpty ? 'M' : name.characters.first.toUpperCase(),
              style: const TextStyle(
                color: Color(0xff30203e),
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground.withValues(alpha: .62),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  final Manga manga;
  final Color surface;
  final Color foreground;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FavoriteTile({
    required this.manga,
    required this.surface,
    required this.foreground,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: foreground.withValues(alpha: .08)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 58,
                  height: 78,
                  child:
                      manga.linkGambar.isEmpty
                          ? const ColoredBox(
                            color: Color(0xffe6e1ea),
                            child: Icon(Icons.menu_book_rounded),
                          )
                          : Image.network(
                            manga.linkGambar,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, _, _) => const ColoredBox(
                                  color: Color(0xffe6e1ea),
                                  child: Icon(Icons.menu_book_rounded),
                                ),
                          ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manga.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      manga.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground.withValues(alpha: .6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Hapus dari Favorit',
                onPressed: onRemove,
                icon: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.redAccent,
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: foreground.withValues(alpha: .5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoritesMessage extends StatelessWidget {
  final Color surface;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _FavoritesMessage({
    required this.surface,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: const Color(0xff9b78c7)),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  final Color surface;
  final Color foreground;
  final VoidCallback onLogin;

  const _LoginPrompt({
    required this.surface,
    required this.foreground,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xffeee5f8),
            child: Icon(Icons.person_outline, color: Color(0xff76549d)),
          ),
          const SizedBox(height: 14),
          Text(
            'Masuk ke Mangatsu',
            style: TextStyle(
              color: foreground,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Login untuk melihat profil dan menyimpan manga favorit.',
            textAlign: TextAlign.center,
            style: TextStyle(color: foreground.withValues(alpha: .65)),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onLogin,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Login'),
          ),
        ],
      ),
    );
  }
}
