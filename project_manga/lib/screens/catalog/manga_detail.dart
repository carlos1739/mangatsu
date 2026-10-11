import 'package:flutter/material.dart';
import 'package:project_manga/models/manga.dart';
import 'package:project_manga/services/api_service.dart';
import 'package:project_manga/widgets/anime_card.dart';
import 'package:project_manga/services/appearance_controller.dart';

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
  bool _sortNewest = true;
  bool _showFullSynopsis = false;
  bool _bookmarked = false;
  bool _bookmarkLoading = false;
  String _readStatus = 'plan'; // <-- baru
  int _visibleComments = 3;
  int get _appearance => appearanceController.value;
  Manga? _loadedManga;
  List<int> _visibleChapters = const [];

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
        // _bookmarked = detail.bookmark;  // dihapus
      });
    } catch (error) {
      debugPrint('Gagal memuat detail manga ${widget.manga.id}: $error');
    }
  }

  // [UBAH] _checkBookmark diganti: sekarang mengambil status baca
  Future<void> _checkBookmark() async {
    final status = await ApiService.getBookmarkStatus(widget.manga.id);
    if (!mounted) return;
    setState(() {
      _bookmarked = status != null;
      if (status != null) _readStatus = status;
    });
  }
  // [AKHIR]

  Future<void> _toggleBookmark() async {
    setState(() => _bookmarkLoading = true);
    try {
      if (_bookmarked) {
        await ApiService.removeBookmark(widget.manga.id);
      } else {
        await ApiService.addBookmark(_currentManga);
      }
      if (mounted) {
        // [UBAH] sebelumnya: setState(() => _bookmarked = !_bookmarked);
        setState(() {
          _bookmarked = !_bookmarked;
          if (_bookmarked) _readStatus = 'plan';
        });
        // [AKHIR]
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

  // [BARU] fungsi untuk mengubah status baca
  Future<void> _changeStatus(String value) async {
    final old = _readStatus;
    setState(() => _readStatus = value);
    try {
      await ApiService.updateBookmarkStatus(widget.manga.id, value);
      _showMessage('Status diperbarui: ${ApiService.statusLabel(value)}');
    } catch (error) {
      if (mounted) setState(() => _readStatus = old);
      _showMessage('Gagal memperbarui status: $error');
    }
  }
  // [AKHIR]

  int get _chapterCount => int.tryParse(_currentManga.chapter) ?? 0;

  void _onChapterSearchChanged() {
    if (!mounted) return;
    setState(_rebuildChapters);
  }

  void _rebuildChapters() {
    final query = _chapterSearch.text.trim().toLowerCase().replaceFirst(
      RegExp(r'^chapter\s*'),
      '',
    );
    final chapters = List<int>.generate(_chapterCount, (index) => index + 1);
    final filtered =
        query.isEmpty
            ? chapters
            : chapters
                .where((chapter) => chapter.toString().contains(query))
                .toList();
    _visibleChapters = _sortNewest ? filtered.reversed.toList() : filtered;
  }

  void _cycleAppearance() {
    appearanceController.cycle();
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
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xffd3a7ff),
              child: Icon(Icons.person, color: Color(0xff30203e), size: 20),
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
                    _chapterSection(),
                    const SizedBox(height: 36),
                    _communitySection(),
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
                () => _showMessage(
                  _chapterCount > 0
                      ? 'Membuka Chapter 1...'
                      : 'Chapter belum tersedia',
                ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(_chapterCount > 0 ? 'Mulai Baca Ch. 1' : 'Mulai Baca'),
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
        // [BARU] dropdown status baca, hanya muncul jika sudah di-bookmark
        if (_bookmarked) ...[
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
        // [AKHIR]
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
        Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 28),
            const SizedBox(width: 8),
            Text(
              '${manga.rating.toStringAsFixed(1)} / 5',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              '${manga.view} pembaca',
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chapterSearch,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(
                    'Cari nomor chapter',
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
          if (_visibleChapters.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Chapter belum tersedia.',
                style: TextStyle(color: Colors.white60),
              ),
            )
          else
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
                        return Container(
                          clipBehavior: Clip.hardEdge,
                          padding: const EdgeInsets.fromLTRB(12, 9, 8, 7),
                          decoration: BoxDecoration(
                            color: const Color(0xff242426),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Chapter $chapter',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color:
                                            chapter < 4
                                                ? Colors.white38
                                                : Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Rilis ${_currentManga.release}',
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
                              if (chapter < 4)
                                const Icon(
                                  Icons.visibility,
                                  size: 16,
                                  color: Colors.white30,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _communitySection() {
    const comments = <(String, String)>[];
    return _sectionShell(
      title: 'Community & Review',
      child: Column(
        children: [
          TextField(
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              'Tulis komentar tanpa spoiler...',
              Icons.chat_bubble_outline,
            ),
          ),
          const SizedBox(height: 14),
          ...comments.take(_visibleComments).map(_commentTile),
          if (_visibleComments < comments.length)
            TextButton(
              onPressed: () => setState(() => _visibleComments += 3),
              child: const Text('Muat Komentar Lainnya'),
            ),
        ],
      ),
    );
  }

  Widget _commentTile((String, String) comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff1d1d1f),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(child: Icon(Icons.person, size: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.$1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Baru saja',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Text(comment.$2, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(
                      Icons.thumb_up_alt_outlined,
                      size: 15,
                      color: Colors.white54,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Like',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    SizedBox(width: 14),
                    Icon(
                      Icons.thumb_down_alt_outlined,
                      size: 15,
                      color: Colors.white54,
                    ),
                  ],
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
    final chapterNumber = int.tryParse(chapter);
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
    super.dispose();
  }
}
