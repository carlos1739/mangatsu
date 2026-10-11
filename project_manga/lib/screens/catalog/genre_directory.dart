import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project_manga/models/manga.dart';
import 'package:project_manga/services/api_service.dart';
import 'package:project_manga/services/appearance_controller.dart';

class GenreDirectory extends StatefulWidget {
  const GenreDirectory({super.key});

  @override
  State<GenreDirectory> createState() => _GenreDirectoryState();
}

class _GenreDirectoryState extends State<GenreDirectory> {
  late final Future<List<Manga>> _mangaFuture;
  final _searchController = TextEditingController();
  static const _knownGenres = <String>[
    'Action',
    'Adventure',
    'Award Winning',
    'Drama',
    'Comedy',
    'Fantasy',
    'Horror',
    'Mystery',
    'Suspense',
    'Supernatural',
    'Boys Love',
    'Slice of Life',
    'Sports',
    'Romance',
    'Gore',
    'Military',
    'Psychological',
    'Historical',
    'Isekai',
    'Urban Fantasy',
    'Adult Cast',
    'Reincarnation',
    'School',
    'Team Sports',
    'Anthropomorphic',
    'Gag Humor',
    'Mythology',
    'Combat Sports',
    'Vampire',
    'Childcare',
    'Iyashikei',
    'Seinen',
    'Shounen',
    'Adult',
    'Ecchi',
    'Hentai',
  ];
  int get _appearance => appearanceController.value;
  bool get _isDark => _appearance == 1;
  bool get _isSepia => _appearance == 2;
  Color get _background =>
      _isDark
          ? const Color(0xff101014)
          : _isSepia
          ? const Color(0xfff4ead5)
          : const Color(0xfff7f7f8);
  Color get _surface =>
      _isDark
          ? const Color(0xff1c1c23)
          : _isSepia
          ? const Color(0xfffff8e8)
          : Colors.white;
  Color get _textColor => _isDark ? Colors.white : const Color(0xff24242b);
  Color get _mutedColor => _isDark ? Colors.white60 : const Color(0xff74747d);

  @override
  void initState() {
    super.initState();
    appearanceController.addListener(_onAppearanceChanged);
    _mangaFuture = _loadDirectoryManga();
  }

  void _onAppearanceChanged() {
    if (mounted) setState(() {});
  }

  Future<List<Manga>> _loadDirectoryManga() => ApiService.getAllManga();

  @override
  void dispose() {
    appearanceController.removeListener(_onAppearanceChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor:
            _isDark ? const Color(0xff15151b) : const Color(0xff17131d),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 18,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo/LogoM1.png', width: 38, height: 38),
            const SizedBox(width: 8),
            const Text(
              'angaTsu',
              style: TextStyle(
                fontFamily: 'Tilt',
                fontSize: 23,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 18),
            const Text(
              'Eksplorasi',
              style: TextStyle(
                color: Color(0xffd3a7ff),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/'),
            icon: const Icon(Icons.home_outlined, size: 18),
            label: const Text('Beranda'),
          ),
          IconButton(
            tooltip: 'Ganti mode tampilan',
            onPressed: appearanceController.cycle,
            icon: Icon(
              _isDark
                  ? Icons.dark_mode
                  : _isSepia
                  ? Icons.auto_awesome
                  : Icons.light_mode,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: FutureBuilder<List<Manga>>(
        future: _mangaFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xff9a5bea)),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Data eksplorasi gagal dimuat: ${snapshot.error}',
                style: TextStyle(color: _mutedColor),
                textAlign: TextAlign.center,
              ),
            );
          }

          final manga = snapshot.data ?? const <Manga>[];
          final counts = _genreCounts(manga);
          return ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, child) {
              final query = value.text.trim().toLowerCase();
              final genres =
                  _allGenres(counts)
                      .where((item) => item.toLowerCase().contains(query))
                      .toList();
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _intro(manga, counts)),
                  SliverToBoxAdapter(child: _searchField()),
                  SliverToBoxAdapter(
                    child: _sectionTitle(
                      'Semua genre',
                      'Genre, tema, dan demografi dalam satu koleksi',
                    ),
                  ),
                  _genreGrid(genres, counts),
                  SliverToBoxAdapter(child: _featuredManga(manga)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Map<String, int> _genreCounts(List<Manga> manga) {
    final counts = <String, int>{};
    final knownNames = {
      for (final name in _knownGenres) name.toLowerCase(): name,
    };
    for (final item in manga) {
      for (final value in item.genre) {
        final normalized = value.trim().toLowerCase();
        final name = knownNames[normalized] ?? value.trim();
        if (name.isNotEmpty) counts[name] = (counts[name] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<String> _allGenres(Map<String, int> counts) {
    final names = <String>{..._knownGenres, ...counts.keys};
    final genres =
        names.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return genres;
  }

  Widget _intro(List<Manga> manga, Map<String, int> counts) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    _isDark
                        ? const [Color(0xff241a35), Color(0xff17151e)]
                        : const [Color(0xfff0e5ff), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Color(0xffa66be8).withValues(alpha: .24),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.explore_outlined,
                  color: Color(0xffd3a7ff),
                  size: 42,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cari dunia cerita baru',
                        style: TextStyle(
                          color:
                              _isDark ? Colors.white : const Color(0xff292234),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${manga.length} manga · ${counts.length} genre untuk dijelajahi',
                        style: TextStyle(
                          color:
                              _isDark
                                  ? Colors.white60
                                  : const Color(0xff70677b),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: _textColor),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search, color: _mutedColor),
              hintText: 'Cari genre...',
              hintStyle: TextStyle(color: _mutedColor),
              filled: true,
              fillColor: _surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: _mutedColor.withValues(alpha: .16),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xff9a5bea)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(
    String title,
    String subtitle, {
    double horizontalPadding = 20,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: _mutedColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _genreGrid(List<String> genres, Map<String, int> counts) {
    if (genres.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Center(
            child: Text(
              'Genre tidak ditemukan',
              style: TextStyle(color: _mutedColor),
            ),
          ),
        ),
      );
    }
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final sidePadding = math.max(
          20.0,
          (constraints.crossAxisExtent - 1320.0) / 2,
        );
        final contentWidth = math.max(
          0.0,
          constraints.crossAxisExtent - (sidePadding * 2),
        );
        final columns =
            contentWidth >= 760
                ? 4
                : contentWidth >= 540
                ? 3
                : contentWidth >= 320
                ? 2
                : 1;
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(sidePadding, 0, sidePadding, 20),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  _genreTile(genres[index], counts[genres[index]] ?? 0),
              childCount: genres.length,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: 82,
              crossAxisSpacing: 15,
              mainAxisSpacing: 16,
            ),
          ),
        );
      },
    );
  }

  Widget _genreTile(String name, int count) {
    return InkWell(
      onTap: () => _openGenre(name),
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _mutedColor.withValues(alpha: .16)),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_library_outlined, color: Color(0xffbd8cff)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                color:
                    _isDark ? const Color(0xffbda4d8) : const Color(0xff765b91),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featuredManga(List<Manga> manga) {
    final featured = manga.take(6).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                'Rekomendasi untuk kamu',
                'Manga pilihan untuk memulai eksplorasi',
                horizontalPadding: 0,
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 190,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: featured.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = featured[index];
                    return SizedBox(
                      width: 130,
                      child: InkWell(
                        onTap: () {
                          if (item.genre.isNotEmpty) {
                            _openGenre(item.genre.first);
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  item.cardImageUrl,
                                  width: 130,
                                  fit: BoxFit.cover,
                                  cacheWidth: 260,
                                  cacheHeight: 360,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openGenre(String name) {
    Navigator.pushNamed(context, '/genre/${Uri.encodeComponent(name)}');
  }
}
