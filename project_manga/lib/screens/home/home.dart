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
  Future<Map<String, dynamic>>? _readingSummaryFuture;
  List<Manga> _releasedManga = [];
  List<Manga> _trendingManga = [];
  bool _trendingLoading = true;
  String? _trendingError;
  int _trendingRequestId = 0;
  final ValueNotifier<int> _heroIndex = ValueNotifier(0);
  bool isLoading = true;
  String? errorMessage;
  String? _selectedSortOption;
  int _visibleUpdates = 8;
  int _trendingTab = 0;
  final Set<String> _removedHistory = {};
  final Set<String> _deletingProgressMangaIds = {};
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
    if (UserSession.isLoggedIn) {
      _readingSummaryFuture = ApiService.getReadingSummary();
    }
    _loadManga();
    _loadTrending(_trendingTab);
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

  Future<void> _loadTrending(int tab) async {
    final requestId = ++_trendingRequestId;
    if (mounted) {
      setState(() {
        _trendingTab = tab;
        _trendingLoading = true;
        _trendingError = null;
        _trendingManga = [];
      });
    }

    const periods = ['daily', 'weekly', 'monthly'];
    try {
      final manga = await ApiService.getTrendingManga(periods[tab]);
      if (!mounted || requestId != _trendingRequestId) return;
      setState(() {
        _trendingManga = manga;
        _trendingLoading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _trendingRequestId) return;
      setState(() {
        _trendingError = error.toString();
        _trendingLoading = false;
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

  Future<void> _openMangaDetail(Manga manga) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder:
            (_) => MangaDetail(manga: manga, recommendations: _releasedManga),
      ),
    );
    if (mounted) {
      setState(() {
        if (UserSession.isLoggedIn) {
          _readingSummaryFuture = ApiService.getReadingSummary();
          if (_showLibrary) _bookmarksFuture = ApiService.getBookmarks();
        }
      });
    }
  }

  bool _hasReleasedChapter(Manga manga) {
    final chapter = manga.chapter.trim().toLowerCase();
    final chapterNumber = double.tryParse(chapter);
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
      _bookmarksFuture = ApiService.getBookmarks();
      _readingSummaryFuture = ApiService.getReadingSummary();
    });
  }

  void _reloadLibrary() {
    setState(() {
      _bookmarksFuture = ApiService.getBookmarks();
      _readingSummaryFuture = ApiService.getReadingSummary();
    });
  }

  void _reloadReadingSummary() {
    setState(() {
      _readingSummaryFuture =
          UserSession.isLoggedIn ? ApiService.getReadingSummary() : null;
    });
  }

  Widget _buildReadingSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _surface,
            _isDark ? const Color(0xff252035) : const Color(0xfff3edff),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xff9b5de5).withValues(alpha: .2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xff9b5de5).withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Color(0xff9b5de5),
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progres Membaca',
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Perjalanan baca manga kamu',
                      style: TextStyle(
                        color: _textColor.withValues(alpha: .58),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Muat ulang progres',
                onPressed: _reloadReadingSummary,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!UserSession.isLoggedIn)
            _readingProgressEmptyState(
              'Belum ada progres',
              'Login untuk menyimpan progres bacaan.',
            )
          else
            FutureBuilder<Map<String, dynamic>>(
              future: _readingSummaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Progres membaca gagal dimuat.',
                          style: TextStyle(color: _textColor),
                        ),
                      ),
                      TextButton(
                        onPressed: _reloadReadingSummary,
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  );
                }

                final summary = snapshot.data;
                final recentProgress =
                    (summary?['recent_progress'] as List<dynamic>? ?? [])
                        .whereType<Map<String, dynamic>>()
                        .map(Manga.fromApiJson)
                        .toList();
                if (recentProgress.isEmpty) {
                  return _readingProgressEmptyState(
                    'Belum ada progres',
                    'Manga yang mulai dibaca akan muncul di sini.',
                  );
                }

                final totalChapters =
                    summary?['total_chapters_read'] as int? ?? 0;
                final seriesCount = summary?['series_count'] as int? ?? 0;
                final statusCounts =
                    summary?['status_counts'] as Map<String, dynamic>? ??
                    const {};
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _readingStat('$seriesCount', 'Manga'),
                        const SizedBox(width: 8),
                        _readingStat('$totalChapters', 'Chapter selesai'),
                        const SizedBox(width: 8),
                        _readingStat(
                          '${statusCounts['reading'] ?? 0}',
                          'Dibaca',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...recentProgress.take(4).map(_readingProgressTile),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _readingStat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: _surface.withValues(alpha: .8),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: _textColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _textColor.withValues(alpha: .6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readingProgressTile(Manga manga) {
    final percent = manga.progressPercent.clamp(0, 100);
    final chapter = manga.lastChapterNumber;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _surface.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _openMangaDetail(manga),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _progressCover(manga),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    manga.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _textColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$percent%',
                                  style: const TextStyle(
                                    color: Color(0xff8a4dd0),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: LinearProgressIndicator(
                                value: percent / 100,
                                minHeight: 5,
                                backgroundColor: _textColor.withValues(
                                  alpha: .1,
                                ),
                                color: const Color(0xff9b5de5),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              chapter == null
                                  ? 'Belum ada chapter'
                                  : 'Lanjut: Chapter $chapter',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textColor.withValues(alpha: .58),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: _textColor.withValues(alpha: .42),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Hapus progres',
                visualDensity: VisualDensity.compact,
                onPressed:
                    _deletingProgressMangaIds.contains(manga.id)
                        ? null
                        : () => _confirmDeleteReadingProgress(manga),
                icon:
                    _deletingProgressMangaIds.contains(manga.id)
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent.withValues(alpha: .85),
                          size: 20,
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressCover(Manga manga) {
    if (manga.cardImageUrl.isEmpty) {
      return Container(
        width: 42,
        height: 54,
        color: _background,
        child: Icon(
          Icons.menu_book_rounded,
          color: _textColor.withValues(alpha: .5),
        ),
      );
    }
    return Image.network(
      manga.cardImageUrl,
      width: 42,
      height: 54,
      fit: BoxFit.cover,
      errorBuilder:
          (_, __, ___) => Container(
            width: 42,
            height: 54,
            color: _background,
            child: Icon(
              Icons.menu_book_rounded,
              color: _textColor.withValues(alpha: .5),
            ),
          ),
    );
  }

  Future<void> _confirmDeleteReadingProgress(Manga manga) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Hapus progres membaca?'),
            content: Text(
              'Progres dan riwayat baca "${manga.title}" akan dihapus. '
              'Manga di Rak Buku tetap tersimpan.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text('Hapus'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingProgressMangaIds.add(manga.id));
    try {
      await ApiService.deleteReadingProgress(manga.id);
      if (!mounted) return;
      setState(() {
        _deletingProgressMangaIds.remove(manga.id);
        _readingSummaryFuture = ApiService.getReadingSummary();
      });
      _showMessage('Progres "${manga.title}" berhasil dihapus.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _deletingProgressMangaIds.remove(manga.id));
      _showMessage('Gagal menghapus progres: $error');
    }
  }

  Widget _readingProgressEmptyState(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.menu_book_outlined,
            color: _textColor.withValues(alpha: .5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: _textColor.withValues(alpha: .65)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<List<Manga>>(
                    future: _bookmarksFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const SizedBox(
                          height: 80,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rak buku belum dapat dimuat.',
                              style: TextStyle(color: _textColor),
                            ),
                            TextButton.icon(
                              onPressed: _reloadLibrary,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Coba lagi'),
                            ),
                          ],
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
                              IconButton(
                                tooltip: 'Muat ulang rak buku',
                                onPressed: _reloadLibrary,
                                icon: const Icon(Icons.refresh),
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
                              height: 210,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: bookmarks.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(width: 12),
                                itemBuilder: (context, index) {
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
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Image.network(
                                                manga.cardImageUrl,
                                                width: 130,
                                                fit: BoxFit.cover,
                                                filterQuality:
                                                    FilterQuality.low,
                                                cacheWidth: 260,
                                                cacheHeight: 320,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => Container(
                                                      width: 130,
                                                      color: _background,
                                                      alignment:
                                                          Alignment.center,
                                                      child: Icon(
                                                        Icons.menu_book,
                                                        color: _textColor
                                                            .withValues(
                                                              alpha: .55,
                                                            ),
                                                      ),
                                                    ),
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
                                          Text(
                                            manga.lastChapterNumber == null
                                                ? ApiService.statusLabel(
                                                  manga.readStatus,
                                                )
                                                : 'Chapter ${manga.lastChapterNumber}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: _textColor.withValues(
                                                alpha: .65,
                                              ),
                                              fontSize: 11,
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
                ],
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
