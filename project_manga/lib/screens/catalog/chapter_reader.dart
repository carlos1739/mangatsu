import 'package:flutter/material.dart';
import 'package:project_manga/models/manga.dart';
import 'package:project_manga/services/api_service.dart';

class ChapterReader extends StatefulWidget {
  final String mangaTitle;
  final MangaChapter chapter;
  final Future<int> Function(int currentPage, int totalPages)? onPageProgress;
  final Future<MangaChapter?> Function(bool next)? onNavigateChapter;
  final Widget Function(MangaChapter chapter)? readerBuilder;
  final bool hasPreviousChapter;
  final bool hasNextChapter;

  const ChapterReader({
    super.key,
    required this.mangaTitle,
    required this.chapter,
    this.onPageProgress,
    this.onNavigateChapter,
    this.readerBuilder,
    this.hasPreviousChapter = false,
    this.hasNextChapter = false,
  });

  @override
  State<ChapterReader> createState() => _ChapterReaderState();
}

class _ChapterReaderState extends State<ChapterReader> {
  late Future<List<String>> _pagesFuture;
  final ScrollController _scrollController = ScrollController();
  int _lastRequestedPage = 0;
  int _progressPercent = 0;
  bool _navigatingChapter = false;
  bool _atChapterEnd = false;

  @override
  void initState() {
    super.initState();
    _pagesFuture = ApiService.getChapterPages(widget.chapter.id);
  }

  void _retry() {
    setState(() {
      _lastRequestedPage = 0;
      _atChapterEnd = false;
      _pagesFuture = ApiService.getChapterPages(widget.chapter.id);
    });
  }

  void _showReaderError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _savePageProgress(int currentPage, int totalPages) async {
    final saveProgress = widget.onPageProgress;
    if (saveProgress == null ||
        currentPage <= _lastRequestedPage ||
        totalPages < 1) {
      return;
    }
    _lastRequestedPage = currentPage;
    try {
      final percent = await saveProgress(currentPage, totalPages);
      if (mounted) setState(() => _progressPercent = percent);
    } catch (error) {
      if (_lastRequestedPage == currentPage) {
        _lastRequestedPage = currentPage - 1;
      }
      _showReaderError('Progres baca gagal disimpan: $error');
    }
  }

  Future<void> _navigateChapter(bool next) async {
    final navigate = widget.onNavigateChapter;
    final buildReader = widget.readerBuilder;
    if (navigate == null || buildReader == null || _navigatingChapter) return;

    setState(() => _navigatingChapter = true);
    try {
      final chapter = await navigate(next);
      if (!mounted) return;
      if (chapter == null) {
        _showReaderError(
          next
              ? 'Chapter berikutnya tidak tersedia.'
              : 'Chapter sebelumnya tidak tersedia.',
        );
        return;
      }
      await Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute<void>(builder: (_) => buildReader(chapter)),
      );
    } catch (error) {
      _showReaderError('Gagal membuka chapter: $error');
    } finally {
      if (mounted) setState(() => _navigatingChapter = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff101014),
      appBar: AppBar(
        backgroundColor: const Color(0xff17131d),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.mangaTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            Text(
              '${widget.chapter.displayTitle} · ${widget.chapter.language.toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
            if (widget.onPageProgress != null)
              Text(
                'Progres manga: $_progressPercent%',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
          ],
        ),
      ),
      body: FutureBuilder<List<String>>(
        future: _pagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xffb77cff)),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 44,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Halaman chapter gagal dimuat: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final pages = snapshot.data ?? const <String>[];
          if (pages.isEmpty) {
            return const Center(
              child: Text(
                'Halaman untuk chapter ini tidak tersedia.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_scrollController.hasClients || !mounted) return;
            final metrics = _scrollController.position;
            final atEnd = metrics.extentAfter <= 1;
            if (_atChapterEnd != atEnd) {
              setState(() => _atChapterEnd = atEnd);
            }
            final initialPage =
                atEnd
                    ? pages.length
                    : pages.length == 1
                    ? 0
                    : 1;
            _savePageProgress(initialPage, pages.length);
          });
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification ||
                  notification is ScrollEndNotification) {
                final metrics = notification.metrics;
                final atEnd = metrics.extentAfter <= 1;
                if (_atChapterEnd != atEnd) {
                  setState(() => _atChapterEnd = atEnd);
                }
                if (atEnd) {
                  _savePageProgress(pages.length, pages.length);
                  return false;
                }
              }
              if (notification is ScrollUpdateNotification) {
                final metrics = notification.metrics;
                final currentPage =
                    pages.length == 1
                        ? (metrics.extentAfter <= 1 ? 1 : 0)
                        : metrics.maxScrollExtent == 0
                        ? pages.length
                        : (1 +
                                (metrics.pixels /
                                        metrics.maxScrollExtent *
                                        (pages.length - 1))
                                    .floor())
                            .clamp(1, pages.length - 1)
                            .toInt();
                _savePageProgress(currentPage, pages.length);
              }
              return false;
            },
            child: ListView.builder(
              controller: _scrollController,
              itemCount: pages.length,
              itemBuilder:
                  (context, index) => Image.network(
                    pages[index],
                    fit: BoxFit.fitWidth,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return SizedBox(
                        height: 360,
                        child: Center(
                          child: CircularProgressIndicator(
                            value:
                                progress.expectedTotalBytes == null
                                    ? null
                                    : progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!,
                            color: const Color(0xffb77cff),
                          ),
                        ),
                      );
                    },
                    errorBuilder:
                        (context, error, stackTrace) => const SizedBox(
                          height: 240,
                          child: Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white54,
                              size: 40,
                            ),
                          ),
                        ),
                  ),
            ),
          );
        },
      ),
      floatingActionButton:
          widget.hasNextChapter && _atChapterEnd
              ? FloatingActionButton.extended(
                onPressed:
                    _navigatingChapter ? null : () => _navigateChapter(true),
                backgroundColor: const Color(0xff9b5de5),
                foregroundColor: Colors.white,
                icon:
                    _navigatingChapter
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.chevron_right),
                label: const Text('Chapter berikutnya'),
              )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar:
          widget.hasPreviousChapter
              ? SafeArea(
                child: Container(
                  color: const Color(0xff17131d),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _navigatingChapter
                                  ? null
                                  : () => _navigateChapter(false),
                          icon: const Icon(Icons.chevron_left),
                          label: const Text('Chapter sebelumnya'),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : null,
    );
  }
}
