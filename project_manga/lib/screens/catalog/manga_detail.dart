import 'package:flutter/material.dart';
import 'package:project_manga/models/manga.dart';
import 'package:project_manga/services/api_service.dart';
import 'package:project_manga/widgets/anime_card.dart';
import 'package:project_manga/services/appearance_controller.dart';
import 'package:project_manga/screens/catalog/chapter_reader.dart';
import 'package:project_manga/screens/auth/user/user_session.dart';
import 'package:project_manga/screens/profile/profile.dart';

import 'package:url_launcher/url_launcher.dart';

class MangaDetail extends StatefulWidget {
  final Manga manga;
  final List<Manga> recommendations;

  const MangaDetail({
    super.key,
    required this.manga,
    this.recommendations = const [],
  });

  @override
  State<MangaDetail> createState() => _MangaDetailState();
}

class _MangaDetailState extends State<MangaDetail> {
  static const _maxWidth = 1180.0;
  final _chapterSearch = TextEditingController();
  final _chapterScrollController = ScrollController();
  bool _sortNewest = false;
  bool _showFullSynopsis = false;
  bool _bookmarked = false;
  bool _bookmarkLoading = false;

  List<Map<String, dynamic>> _reviews = [];
  bool _reviewsLoading = true;
  String? _reviewsError;
  int _selectedRating = 5;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmittingReview = false;
  bool _progressLoading = true;
  String _readStatus = 'plan';
  bool _hasReadingProgress = false;
  MangaChapter? _lastReadChapter;
  final Set<String> _completedChapterIds = {};
  int _progressPercent = 0;
  int _totalChaptersAvailable = 0;
  int _visibleComments = 3;
  int get _appearance => appearanceController.value;
  Manga? _loadedManga;
  List<MangaChapter> _chapters = const [];
  List<MangaChapter> _visibleChapters = const [];
  bool _chaptersLoading = true;
  bool _loadingMoreChapters = false;
  bool _hasMoreChapters = false;
  int _chaptersPage = 1;
  String? _chaptersError;

  Manga get _currentManga => _loadedManga ?? widget.manga;
  bool get _isDark => _appearance == 1;
  bool get _isSepia => _appearance == 2;
  Color get _background =>
      _isDark
          ? const Color(0xff121212)
          : _isSepia
          ? const Color(0xfff4ead5)
          : const Color(0xfff7f7f8);
  Color get _surface =>
      _isDark
          ? const Color(0xff1d1d1f)
          : _isSepia
          ? const Color(0xfffff8e8)
          : Colors.white;
  Color get _textColor => _isDark ? Colors.white : const Color(0xff24242b);

  @override
  void initState() {
    super.initState();
    appearanceController.addListener(_onAppearanceChanged);
    _bookmarked = _currentManga.bookmark;
    _rebuildChapters();
    _checkBookmark();
    _loadMangaDetail();
    _loadMangaChapters();
    _loadReviews();
    _chapterSearch.addListener(_onChapterSearchChanged);
  }

  void _onAppearanceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMangaDetail() async {
    try {
      final detail = await ApiService.getMangaDetail(widget.manga.id);
      if (!mounted) return;
      setState(() {
        _loadedManga = detail;
      });
    } catch (error) {
      debugPrint('Gagal memuat detail manga ${widget.manga.id}: $error');
    }
  }

  Future<void> _checkBookmark() async {
    try {
      final progress = await ApiService.getReadingProgress(widget.manga.id);
      if (!mounted) return;
      setState(() {
        _hasReadingProgress = progress?['has_progress'] == true;
        _bookmarked =
            progress?['is_bookmarked'] as bool? ?? _currentManga.bookmark;
        _readStatus = progress?['read_status']?.toString() ?? 'plan';
        _progressPercent = progress?['progress_percent'] as int? ?? 0;
        final completedChapterIds = progress?['completed_chapter_ids'];
        _completedChapterIds
          ..clear()
          ..addAll(
            completedChapterIds is List
                ? completedChapterIds.map((id) => id.toString())
                : const <String>[],
          );
        _progressLoading = false;
        final chapterId = progress?['last_chapter_id']?.toString();
        if (chapterId != null && chapterId.isNotEmpty) {
          _lastReadChapter = MangaChapter(
            id: chapterId,
            chapter: progress?['last_chapter_number']?.toString() ?? '?',
            title: progress?['last_chapter_title']?.toString() ?? '',
            language: progress?['last_chapter_language']?.toString() ?? '',
            pages: 0,
          );
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _progressLoading = false);
        _showMessage('Gagal memuat progres membaca: $error');
      }
    }
  }

  Future<void> _toggleBookmark() async {
    setState(() => _bookmarkLoading = true);
    try {
      if (_bookmarked) {
        await ApiService.removeBookmark(widget.manga.id);
      } else {
        await ApiService.addBookmark(_currentManga);
      }
      if (mounted) {
        setState(() {
          _bookmarked = !_bookmarked;
          if (_bookmarked && !_hasReadingProgress) _readStatus = 'plan';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _bookmarked ? 'Ditambahkan ke koleksi' : 'Dihapus dari koleksi',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui bookmark: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _bookmarkLoading = false);
    }
  }

  Future<void> _changeStatus(String value) async {
    final old = _readStatus;
    setState(() => _readStatus = value);
    try {
      await ApiService.updateReadingStatus(_currentManga, value);
      if (mounted) setState(() => _hasReadingProgress = true);
      _showMessage('Status diperbarui: ${ApiService.statusLabel(value)}');
    } catch (error) {
      if (mounted) setState(() => _readStatus = old);
      _showMessage('Gagal memperbarui status: $error');
    }
  }

  Future<void> _loadReviews() async {
    if (!mounted) return;
    setState(() {
      _reviewsLoading = true;
      _reviewsError = null;
    });
    try {
      final reviews = await ApiService.getReviews(widget.manga.id);
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _reviewsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _reviewsLoading = false;
        _reviewsError = 'Gagal memuat ulasan: $error';
      });
    }
  }

  Future<void> _submitReview() async {
    if (!UserSession.isLoggedIn) {
      _showMessage('Silakan login terlebih dahulu untuk memberi ulasan.');
      return;
    }
    final text = _reviewController.text.trim();
    if (text.isEmpty) {
      _showMessage('Tulis ulasan terlebih dahulu.');
      return;
    }

    setState(() => _isSubmittingReview = true);
    try {
      await ApiService.addReview(widget.manga.id, _selectedRating, text);
      _reviewController.clear();
      await _loadReviews();
      _showMessage('Ulasan berhasil dikirim!');
    } catch (e) {
      _showMessage('Gagal mengirim ulasan: $e');
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  Future<void> _loadMangaChapters() async {
    setState(() {
      _chaptersLoading = true;
      _chaptersError = null;
    });
    try {
      final result = await ApiService.getMangaChapters(
        widget.manga.id,
        page: _chaptersPage,
      );
      if (!mounted) return;
      setState(() {
        _chapters = result.chapters;
        _chaptersPage = result.page;
        _totalChaptersAvailable = result.total;
        _hasMoreChapters = result.page * 100 < result.total;
        _chaptersLoading = false;
        _rebuildChapters();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _chaptersError = error.toString();
        _chaptersLoading = false;
      });
    }
  }

  Future<void> _loadMoreChapters() async {
    if (_loadingMoreChapters || !_hasMoreChapters) return;
    setState(() => _loadingMoreChapters = true);
    try {
      final result = await ApiService.getMangaChapters(
        widget.manga.id,
        page: _chaptersPage + 1,
      );
      if (!mounted) return;
      setState(() {
        _chapters = [..._chapters, ...result.chapters];
        _chaptersPage = result.page;
        _totalChaptersAvailable = result.total;
        _hasMoreChapters = result.page * 100 < result.total;
        _loadingMoreChapters = false;
        _rebuildChapters();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingMoreChapters = false);
      _showMessage('Gagal memuat chapter berikutnya: $error');
    }
  }

  void _onChapterSearchChanged() {
    if (!mounted) return;
    setState(_rebuildChapters);
  }

  void _rebuildChapters() {
    final query = _chapterSearch.text.trim().toLowerCase().replaceFirst(
      RegExp(r'^chapter\s*'),
      '',
    );
    final chapters = List<MangaChapter>.of(_chapters);
    final filtered =
        query.isEmpty
            ? chapters
            : chapters
                .where(
                  (chapter) =>
                      chapter.chapter.toLowerCase().contains(query) ||
                      chapter.title.toLowerCase().contains(query),
                )
                .toList();
    filtered.sort((a, b) {
      final aNumber = double.tryParse(a.chapter);
      final bNumber = double.tryParse(b.chapter);
      final comparison =
          aNumber != null && bNumber != null
              ? aNumber.compareTo(bNumber)
              : a.chapter.compareTo(b.chapter);
      return _sortNewest ? -comparison : comparison;
    });
    _visibleChapters = filtered;
  }

  List<MangaChapter> _orderedReadingChapters() {
    final chapters = List<MangaChapter>.of(_chapters);
    chapters.sort((a, b) {
      final aNumber = double.tryParse(a.chapter);
      final bNumber = double.tryParse(b.chapter);
      final comparison =
          aNumber != null && bNumber != null
              ? aNumber.compareTo(bNumber)
              : a.chapter.compareTo(b.chapter);
      return comparison != 0 ? comparison : a.language.compareTo(b.language);
    });
    return chapters;
  }

  int _compareChapterNumbers(MangaChapter first, MangaChapter second) {
    final firstNumber = double.tryParse(first.chapter);
    final secondNumber = double.tryParse(second.chapter);
    if (firstNumber != null && secondNumber != null) {
      return firstNumber.compareTo(secondNumber);
    }
    return first.chapter.compareTo(second.chapter);
  }

  bool _hasAdjacentChapter(MangaChapter chapter, {required bool next}) {
    final chapters = _orderedReadingChapters();
    final hasLoadedAdjacent = chapters.any((item) {
      final comparison = _compareChapterNumbers(item, chapter);
      if (next) {
        return comparison > 0 && !_completedChapterIds.contains(item.id);
      }
      return comparison < 0;
    });
    if (hasLoadedAdjacent) return true;
    return next && _hasMoreChapters;
  }

  Future<MangaChapter?> _getNextUnreadChapter(MangaChapter? chapter) async {
    while (true) {
      final unread =
          _orderedReadingChapters()
              .where(
                (item) =>
                    (chapter == null ||
                        _compareChapterNumbers(item, chapter) > 0) &&
                    !_completedChapterIds.contains(item.id),
              )
              .toList();
      if (unread.isNotEmpty) {
        final next = unread.first;
        if (chapter == null) return next;
        return unread.firstWhere(
          (item) =>
              item.chapter == next.chapter && item.language == chapter.language,
          orElse: () => next,
        );
      }
      if (!_hasMoreChapters) return null;

      final result = await ApiService.getMangaChapters(
        widget.manga.id,
        page: _chaptersPage + 1,
      );
      if (!mounted) return null;
      if (result.page <= _chaptersPage && result.chapters.isEmpty) return null;
      setState(() {
        _chapters = [..._chapters, ...result.chapters];
        _chaptersPage = result.page;
        _totalChaptersAvailable = result.total;
        _hasMoreChapters = result.page * 100 < result.total;
        _rebuildChapters();
      });
    }
  }

  Future<MangaChapter?> _getAdjacentChapter(
    MangaChapter chapter, {
    required bool next,
  }) async {
    if (next) return _getNextUnreadChapter(chapter);

    while (true) {
      final chapters = _orderedReadingChapters();
      final adjacent =
          chapters.where((item) {
            final comparison = _compareChapterNumbers(item, chapter);
            return next ? comparison > 0 : comparison < 0;
          }).toList();
      if (adjacent.isNotEmpty) {
        final target = next ? adjacent.first : adjacent.last;
        return adjacent.firstWhere(
          (item) =>
              item.chapter == target.chapter &&
              item.language == chapter.language,
          orElse: () => target,
        );
      }
      if (!next || !_hasMoreChapters) return null;

      final result = await ApiService.getMangaChapters(
        widget.manga.id,
        page: _chaptersPage + 1,
      );
      if (!mounted) return null;
      setState(() {
        _chapters = [..._chapters, ...result.chapters];
        _chaptersPage = result.page;
        _totalChaptersAvailable = result.total;
        _hasMoreChapters = result.page * 100 < result.total;
        _rebuildChapters();
      });
    }
  }

  ChapterReader _buildChapterReader(MangaChapter chapter) {
    return ChapterReader(
      mangaTitle: _currentManga.title,
      chapter: chapter,
      hasPreviousChapter: _hasAdjacentChapter(chapter, next: false),
      hasNextChapter: _hasAdjacentChapter(chapter, next: true),
      onNavigateChapter: (next) => _getAdjacentChapter(chapter, next: next),
      readerBuilder: _buildChapterReader,
      onPageProgress:
          UserSession.isLoggedIn
              ? (currentPage, totalPages) async {
                final percent = await ApiService.recordChapterRead(
                  _currentManga,
                  chapter,
                  totalChapters: _totalChaptersAvailable,
                  currentPage: currentPage,
                  totalPages: totalPages,
                );
                if (mounted) {
                  setState(() {
                    _progressPercent = percent;
                    _hasReadingProgress = true;
                    _lastReadChapter = chapter;
                    _readStatus = 'reading';
                    if (currentPage >= totalPages) {
                      _completedChapterIds.add(chapter.id);
                    }
                  });
                }
                return percent;
              }
              : null,
    );
  }

  void _cycleAppearance() {
    appearanceController.cycle();
  }

  Future<void> _openMangaSource() async {
    final manga = _currentManga;
    final uri = Uri.tryParse(manga.mangaDexUrl ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'mangadex.org' ||
        uri.pathSegments.length < 2 ||
        uri.pathSegments[0] != 'title' ||
        uri.pathSegments[1] != manga.id.toString()) {
      _showMessage('Tautan MangaDex tidak tersedia.');
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showMessage('Tidak dapat membuka halaman MangaDex.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Gagal membuka MangaDex: $error');
      }
    }
  }

  Future<void> _startReading([MangaChapter? chapter]) async {
    if (_chaptersLoading) return;
    if (_chaptersError != null) {
      _showMessage('Chapter gagal dimuat. Coba muat ulang daftar chapter.');
      return;
    }
    if (_chapters.isEmpty) {
      _showMessage('Belum ada chapter bahasa Indonesia atau Inggris.');
      return;
    }
    if (_totalChaptersAvailable < 1) {
      _showMessage('Jumlah chapter tersedia belum dapat dimuat.');
      return;
    }

    MangaChapter? firstChapter;
    try {
      firstChapter =
          chapter ??
          (_lastReadChapter != null &&
                  !_completedChapterIds.contains(_lastReadChapter!.id)
              ? _lastReadChapter
              : await _getNextUnreadChapter(_lastReadChapter));
    } catch (error) {
      _showMessage('Gagal mencari chapter yang belum dibaca: $error');
      return;
    }
    final selectedChapter = firstChapter;
    if (selectedChapter == null) {
      _showMessage('Semua chapter yang tersedia sudah selesai dibaca.');
      return;
    }
    if (double.tryParse(selectedChapter.chapter) != 1 && chapter == null) {
      if (_lastReadChapter == null) {
        _showMessage(
          'Chapter 1 belum tersedia; membuka chapter paling awal yang tersedia.',
        );
      }
    }
    if (UserSession.isLoggedIn) {
      try {
        final percent = await ApiService.recordChapterRead(
          _currentManga,
          selectedChapter,
          totalChapters: _totalChaptersAvailable,
        );
        if (mounted) {
          setState(() {
            _hasReadingProgress = true;
            _readStatus = 'reading';
            _lastReadChapter = selectedChapter;
            _progressPercent = percent;
          });
        }
      } catch (error) {
        if (mounted) {
          _showMessage('Progres tidak tersimpan: $error');
        }
      }
    } else {
      _showMessage('Login untuk menyimpan progres membaca.');
    }
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => _buildChapterReader(selectedChapter)),
    );
    if (mounted && UserSession.isLoggedIn) _checkBookmark();
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _background,
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: const Color(0xff9b5de5),
          surface: _surface,
        ),
      ),
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor:
              _isDark ? const Color(0xff171719) : const Color(0xff24212a),
          foregroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 68,
          titleSpacing: 18,
          title: InkWell(
            onTap: _goHome,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logo/LogoM1.png', width: 38, height: 38),
                const SizedBox(width: 8),
                const Text(
                  'MangaTsu',
                  style: TextStyle(
                    fontFamily: 'Tilt',
                    fontSize: 23,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Ganti mode tampilan',
              onPressed: _cycleAppearance,
              icon: Icon(
                _isDark
                    ? Icons.dark_mode
                    : _isSepia
                    ? Icons.auto_awesome
                    : Icons.light_mode,
                color: Colors.white,
              ),
            ),
            IconButton(
              tooltip: 'Profil',
              onPressed:
                  () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const Profil()),
                  ),
              icon: const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xffd3a7ff),
                child: Icon(Icons.person, color: Color(0xff30203e), size: 20),
              ),
            ),
            const SizedBox(width: 18),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(42),
            child: SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _menuItem('For You', true, _goHome),
                  _menuItem('Latest Updates', false),
                  _menuItem('Trending This Week', false),
                  _menuItem('Genres', false),
                  _menuItem('Surprise Me!', false),
                ],
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroSection(),
                    const SizedBox(height: 36),
                    _communitySection(),
                    const SizedBox(height: 36),
                    _chapterSection(),
                    const SizedBox(height: 36),
                    _recommendationSection(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroSection() {
    final manga = _currentManga;
    final synopsis =
        manga.sinopsis.isEmpty
            ? 'Belum ada sinopsis untuk manga ini.'
            : manga.sinopsis;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xff18181b),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Opacity(
                opacity: .12,
                child: Image.network(
                  manga.linkGambar,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.low,
                  cacheWidth: 960,
                  cacheHeight: 640,
                ),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 650;
              return Flex(
                direction: compact ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _coverAndActions(compact),
                  SizedBox(width: compact ? 0 : 28, height: compact ? 24 : 0),
                  Expanded(flex: compact ? 0 : 1, child: _detailInfo(synopsis)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _menuItem(String label, bool active, [VoidCallback? onTap]) {
    return Padding(
      padding: const EdgeInsets.only(right: 26),
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color:
                  active
                      ? const Color(0xffd3a7ff)
                      : Colors.white.withValues(alpha: .7),
              fontSize: 12,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _coverAndActions(bool compact) {
    final cover = SizedBox(
      width: compact ? 190 : 210,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            _currentManga.linkGambar,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
            cacheWidth: 420,
            cacheHeight: 630,
          ),
        ),
      ),
    );
    final actions = Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
                _chaptersLoading || _progressLoading
                    ? null
                    : () => _startReading(),
            icon: Icon(
              _progressLoading
                  ? Icons.hourglass_empty
                  : _lastReadChapter == null
                  ? Icons.play_arrow_rounded
                  : Icons.play_circle_outline,
            ),
            label: Text(
              _progressLoading
                  ? 'Memuat progres baca...'
                  : _lastReadChapter == null
                  ? 'Mulai Baca Chapter 1'
                  : _completedChapterIds.contains(_lastReadChapter!.id)
                  ? 'Baca chapter selanjutnya'
                  : 'Lanjutkan ${_lastReadChapter!.displayTitle}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openMangaSource,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Lihat di MangaDex'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _bookmarkLoading ? null : _toggleBookmark,
            icon: Icon(_bookmarked ? Icons.bookmark : Icons.bookmark_border),
            label: Text(_bookmarked ? 'Tersimpan' : 'Bookmark'),
          ),
        ),
        if (_bookmarked || _hasReadingProgress) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _readStatus,
                isExpanded: true,
                dropdownColor: const Color(0xff24242b),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                items: const [
                  DropdownMenuItem(value: 'reading', child: Text('Reading')),
                  DropdownMenuItem(value: 'plan', child: Text('Plan')),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Text('Completed'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) _changeStatus(value);
                },
              ),
            ),
          ),
        ],
      ],
    );
    return compact
        ? Column(children: [cover, const SizedBox(height: 12), actions])
        : SizedBox(
          width: 210,
          child: Column(children: [cover, const SizedBox(height: 12), actions]),
        );
  }

  Widget _detailInfo(String synopsis) {
    final manga = _currentManga;
    final statusColor =
        manga.status.toLowerCase() == 'ongoing'
            ? Colors.greenAccent
            : Colors.redAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          manga.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Author: ${manga.author}',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _pill(manga.status, statusColor),
            ...manga.genre.map((genre) => _pill(genre, Colors.white54)),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          manga.rating > 0
              ? 'Rating MangaDex: ${manga.rating.toStringAsFixed(1)}'
              : 'Rating tidak tersedia dari MangaDex.',
          style: const TextStyle(color: Colors.white60),
        ),
        if (_hasReadingProgress) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Progres baca',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              Text(
                '$_progressPercent%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (_progressPercent.clamp(0, 100)) / 100,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: .14),
              color: const Color(0xffb77cff),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          synopsis,
          maxLines: _showFullSynopsis ? null : 4,
          overflow: _showFullSynopsis ? null : TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white70,
            height: 1.55,
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed:
              () => setState(() => _showFullSynopsis = !_showFullSynopsis),
          child: Text(
            _showFullSynopsis
                ? 'Tampilkan lebih sedikit'
                : 'Baca selengkapnya...',
          ),
        ),
      ],
    );
  }

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .3)),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 11)),
  );

  Widget _chapterSection() {
    return _sectionShell(
      title: 'Daftar Chapter',
      child: Column(
        children: [
          if (!_chaptersLoading &&
              _chaptersError == null &&
              _chapters.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chapterSearch,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      'Cari nomor atau judul chapter',
                      Icons.search,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Urutkan',
                  onPressed: () {
                    setState(() {
                      _sortNewest = !_sortNewest;
                      _rebuildChapters();
                    });
                  },
                  icon: Icon(
                    _sortNewest ? Icons.south : Icons.north,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (_chaptersLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: Color(0xffb77cff)),
            )
          else if (_chaptersError != null)
            _chapterMessage(
              'Gagal memuat chapter: $_chaptersError',
              action: TextButton.icon(
                onPressed: _loadMangaChapters,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            )
          else if (_chapters.isEmpty)
            _chapterMessage(
              'Belum ada chapter bahasa Indonesia atau Inggris untuk manga ini.',
            )
          else if (_visibleChapters.isEmpty)
            _chapterMessage('Tidak ada chapter yang cocok dengan pencarian.')
          else
            Column(
              children: [
                RepaintBoundary(
                  child: Container(
                    height: 400,
                    padding: const EdgeInsets.all(12),
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: const Color(0xff171719),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .07),
                      ),
                    ),
                    child: ScrollbarTheme(
                      data: ScrollbarThemeData(
                        thumbColor: WidgetStateProperty.all(
                          Colors.white.withValues(alpha: .28),
                        ),
                        trackColor: WidgetStateProperty.all(
                          Colors.white.withValues(alpha: .04),
                        ),
                        trackBorderColor: WidgetStateProperty.all(
                          Colors.transparent,
                        ),
                        thickness: WidgetStateProperty.all(5),
                        radius: const Radius.circular(10),
                        minThumbLength: 36,
                      ),
                      child: Scrollbar(
                        controller: _chapterScrollController,
                        thumbVisibility: true,
                        interactive: true,
                        child: GridView.builder(
                          controller: _chapterScrollController,
                          padding: const EdgeInsets.only(right: 10),
                          physics: const AlwaysScrollableScrollPhysics(),
                          clipBehavior: Clip.hardEdge,
                          itemCount: _visibleChapters.length,
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 260,
                                mainAxisExtent: 62,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                          itemBuilder: (_, index) {
                            final chapter = _visibleChapters[index];
                            return Material(
                              color: const Color(0xff242426),
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _startReading(chapter),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    9,
                                    8,
                                    7,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              chapter.displayTitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${chapter.language.toUpperCase()} · ${chapter.pages} halaman',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.menu_book_outlined,
                                        size: 18,
                                        color: Color(0xffd3a7ff),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                if (_hasMoreChapters)
                  TextButton.icon(
                    onPressed: _loadingMoreChapters ? null : _loadMoreChapters,
                    icon:
                        _loadingMoreChapters
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.expand_more),
                    label: Text(
                      _loadingMoreChapters
                          ? 'Memuat chapter...'
                          : 'Muat chapter berikutnya',
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _chapterMessage(String message, {Widget? action}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff171719),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
          if (action != null) ...[const SizedBox(height: 8), action],
        ],
      ),
    );
  }

  Widget _communitySection() {
    return _sectionShell(
      title: 'Rating & Ulasan Komunitas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xff1d1d1f),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tulis Ulasan & Beri Rating',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      'Rating: ',
                      style: TextStyle(color: Colors.white70),
                    ),
                    for (int i = 1; i <= 5; i++)
                      InkWell(
                        onTap: () => setState(() => _selectedRating = i),
                        child: Icon(
                          i <= _selectedRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 26,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reviewController,
                  minLines: 2,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(
                    'Bagikan pendapatmu tentang manga ini...',
                    Icons.chat_bubble_outline,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmittingReview ? null : _submitReview,
                    child:
                        _isSubmittingReview
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text('Kirim Ulasan'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xff1d1d1f),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _reviewsLoading || _reviewsError != null
                            ? 'Ulasan'
                            : 'Ulasan (${_reviews.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Muat ulang ulasan',
                      onPressed: _reviewsLoading ? null : _loadReviews,
                      color: const Color(0xffc28aff),
                      icon:
                          _reviewsLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.refresh),
                    ),
                  ],
                ),
                if (_reviewsLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Memuat ulasan...',
                      style: TextStyle(color: Colors.white60),
                    ),
                  )
                else if (_reviewsError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      'Ulasan gagal dimuat. Tekan ikon muat ulang untuk mencoba lagi.\n$_reviewsError',
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  )
                else if (_reviews.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Belum ada ulasan untuk manga ini. Jadilah yang pertama!',
                      style: TextStyle(color: Colors.white60),
                    ),
                  )
                else ...[
                  const SizedBox(height: 8),
                  ..._reviews.take(_visibleComments).map(_reviewTile),
                  if (_visibleComments < _reviews.length)
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() => _visibleComments += 3),
                        child: const Text('Muat Ulasan Lainnya'),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewTile(Map<String, dynamic> review) {
    final rating = review['rating'] as int? ?? 5;
    final userName = review['user_name']?.toString() ?? 'Anonim';
    final comment = review['comment']?.toString() ?? '';
    final createdAt = review['created_at']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff1d1d1f),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xff9b5de5),
            child: Icon(Icons.person, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      createdAt,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    for (int i = 1; i <= 5; i++)
                      Icon(
                        i <= rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 14,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  comment,
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recommendationSection() {
    final recommendations =
        widget.recommendations
            .where(
              (manga) =>
                  manga.id != _currentManga.id && _hasReleasedChapter(manga),
            )
            .take(6)
            .toList();
    if (recommendations.isEmpty) return const SizedBox.shrink();
    return _sectionShell(
      title: 'Manga Serupa',
      child: SizedBox(
        height: 310,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: recommendations.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder:
              (_, index) => SizedBox(
                width: 170,
                child: AnimeCard(
                  anime: recommendations[index],
                  checkBookmark: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => MangaDetail(
                              manga: recommendations[index],
                              recommendations: widget.recommendations,
                            ),
                      ),
                    );
                  },
                ),
              ),
        ),
      ),
    );
  }

  Widget _sectionShell({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ).copyWith(color: _textColor),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: const Color(0xff1d1d1f),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );

  bool _hasReleasedChapter(Manga manga) {
    final chapter = manga.chapter.trim().toLowerCase();
    final chapterNumber = double.tryParse(chapter);
    return chapter.isNotEmpty &&
        chapter != 'n/a' &&
        chapterNumber != null &&
        chapterNumber > 0;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    appearanceController.removeListener(_onAppearanceChanged);
    _chapterSearch.removeListener(_onChapterSearchChanged);
    _chapterSearch.dispose();
    _chapterScrollController.dispose();

    _reviewController.dispose();

    super.dispose();
  }
}
