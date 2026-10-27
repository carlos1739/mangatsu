import 'package:flutter/material.dart';
import 'package:project_manga/models/manga.dart';
import 'package:project_manga/services/api_service.dart';

class ChapterReader extends StatefulWidget {
  final String mangaTitle;
  final MangaChapter chapter;

  const ChapterReader({
    super.key,
    required this.mangaTitle,
    required this.chapter,
  });

  @override
  State<ChapterReader> createState() => _ChapterReaderState();
}

class _ChapterReaderState extends State<ChapterReader> {
  late Future<List<String>> _pagesFuture;

  @override
  void initState() {
    super.initState();
    _pagesFuture = ApiService.getChapterPages(widget.chapter.id);
  }

  void _retry() {
    setState(() {
      _pagesFuture = ApiService.getChapterPages(widget.chapter.id);
    });
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
          return ListView.builder(
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
          );
        },
      ),
    );
  }
}
