// ignore_for_file: unused_element

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:project_manga/services/appearance_controller.dart';
import 'package:project_manga/screens/catalog/by_title.dart';
import 'package:project_manga/screens/catalog/manga_detail.dart';
import 'package:project_manga/models/manga.dart';
import 'package:project_manga/screens/profile/profile.dart';
import 'package:project_manga/services/api_service.dart';
import 'package:project_manga/screens/auth/user/user_session.dart';
import 'package:project_manga/screens/auth/login.dart';

part 'home_view.dart';
part 'home_hero.dart';
part 'home_sections.dart';

class Beranda extends StatefulWidget {
  const Beranda({super.key});

  @override
  State<Beranda> createState() => _BerandaState();
}

abstract class _HomeStateBase extends State<Beranda> {
  List<Manga> allManga = [];
  List<Manga> displayedManga = [];
  final TextEditingController _searchController = TextEditingController();
  Timer? _carouselTimer;
  final ScrollController _collectionsScrollController = ScrollController();
  Future<List<Manga>>? _bookmarksFuture;
  List<Manga> _releasedManga = [];
  List<Manga> _trendingManga = [];
  final ValueNotifier<int> _heroIndex = ValueNotifier(0);
  bool isLoading = true;
  String? errorMessage;
  String? _selectedSortOption;
  int _visibleUpdates = 8;
  int _trendingTab = 0;
  final Set<int> _removedHistory = {};
  bool _showLibrary = false;

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

  @override
  void initState() {
    super.initState();
    _loadManga();
  }

  Future<void> _loadManga() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
      final manga = await ApiService.getAllManga();
      if (!mounted) return;
      setState(() {
        allManga = manga;
        displayedManga = manga;
        _releasedManga = manga.where(_hasReleasedChapter).toList();
        _trendingManga = List<Manga>.of(manga)
          ..sort((a, b) => b.view.compareTo(a.view));
        isLoading = false;
      });
      _startCarousel();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _startCarousel() {
    _carouselTimer?.cancel();
    if (_releasedManga.length < 2) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) {
        _heroIndex.value = (_heroIndex.value + 1) % _releasedManga.length;
      }
    });
  }

  List<Manga> get _searchResults {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return [];
    return allManga
        .where((manga) => manga.title.toLowerCase().contains(query))
        .take(5)
        .toList();
  }

  Future<void> _search(String title) async {
    if (title.trim().isEmpty) return;
    try {
      final result = await ApiService.searchManga(title.trim());
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MangaByTitle(title: title.trim(), komikS: result),
        ),
      );
    } catch (e) {
      _showMessage('Pencarian gagal: $e');
    }
  }

  void _filterAndSort(String? value) {
    if (value == null) return;
    setState(() {
      _selectedSortOption = value;
      displayedManga = List.of(allManga);
      if (value == 'a-z') {
        displayedManga.sort((a, b) => a.title.compareTo(b.title));
      } else if (value == 'z-a') {
        displayedManga.sort((a, b) => b.title.compareTo(a.title));
      } else {
        displayedManga =
            allManga
                .where((manga) => manga.status.toLowerCase() == value)
                .toList();
      }
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openMangaDetail(Manga manga) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => MangaDetail(manga: manga, recommendations: _releasedManga),
      ),
    );
  }

  bool _hasReleasedChapter(Manga manga) {
    final chapter = manga.chapter.trim().toLowerCase();
    final chapterNumber = int.tryParse(chapter);
    return chapter.isNotEmpty &&
        chapter != 'n/a' &&
        chapterNumber != null &&
        chapterNumber > 0;
  }

  void _cycleAppearance() {
    appearanceController.cycle();
  }

  void _openLibrary() {
    if (!UserSession.isLoggedIn) {
      showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              backgroundColor: _surface,
              title: Text('Rak Buku', style: TextStyle(color: _textColor)),
              content: Text(
                'Login terlebih dahulu untuk membuka rak buku dan manga yang kamu simpan.',
                style: TextStyle(color: _textColor),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Nanti'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignIn()),
                    );
                  },
                  child: const Text('Login'),
                ),
              ],
            ),
      );
      return;
    }
    setState(() {
      _showLibrary = true;
      _bookmarksFuture ??= ApiService.getBookmarks();
    });
  }

  Widget _buildLibrarySection() {
    return SliverToBoxAdapter(
      child: Align(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _textColor.withValues(alpha: .08)),
              ),
              child: FutureBuilder<List<Manga>>(
                future: _bookmarksFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Text(
                      'Rak buku belum dapat dimuat.',
                      style: TextStyle(color: _textColor),
                    );
                  }
                  final bookmarks = snapshot.data ?? <Manga>[];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Rak Buku',
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed:
                                () => setState(() => _showLibrary = false),
                            child: const Text('Tutup'),
                          ),
                        ],
                      ),
                      if (bookmarks.isEmpty)
                        Text(
                          'Belum ada manga yang ditandai.',
                          style: TextStyle(color: _textColor),
                        )
                      else
                        SizedBox(
                          height: 190,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: bookmarks.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(width: 12),
                            itemBuilder: (_, index) {
                              final manga = bookmarks[index];
                              return SizedBox(
                                width: 130,
                                child: InkWell(
                                  onTap: () => _openMangaDetail(manga),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: Image.network(
                                            manga.cardImageUrl,
                                            width: 130,
                                            fit: BoxFit.cover,
                                            filterQuality: FilterQuality.low,
                                            cacheWidth: 260,
                                            cacheHeight: 320,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        manga.title,
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
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BerandaState extends _HomeStateBase
    with HomeView, HomeHero, HomeSections {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: appearanceController,
      builder: (context, _, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            scaffoldBackgroundColor: _background,
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xff8d4de8),
              surface: _surface,
            ),
            textTheme: Theme.of(context).textTheme.apply(bodyColor: _textColor),
          ),
          child: Scaffold(
            backgroundColor: _background,
            body:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : errorMessage != null
                    ? _errorState()
                    : RepaintBoundary(
                      child: CustomScrollView(
                        slivers: [
                          _buildHeader(),
                          _buildSearchDropdown(),
                          _buildCategoryMenu(),
                          if (_showLibrary) _buildLibrarySection(),
                          _buildHero(),
                          _buildFilterBar(),
                          _buildContinueReading(),
                          _buildLatestAndTrending(),
                          _buildCuratedCollections(),
                          _buildCommunitySnippets(),
                          _buildFooter(),
                        ],
                      ),
                    ),
          ),
        );
      },
    );
  }

  // UI is split into home_view.dart, home_hero.dart, and home_sections.dart.
  @override
  void dispose() {
    _carouselTimer?.cancel();
    _heroIndex.dispose();
    _collectionsScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
