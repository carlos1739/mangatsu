import 'package:flutter/material.dart';

import 'package:project_manga/widgets/anime_grid.dart';
import 'package:project_manga/models/manga.dart';
import 'package:project_manga/services/api_service.dart';

class Bygenre extends StatefulWidget {
  final String genreName;
  final List<Manga>? manga;

  const Bygenre({super.key, required this.genreName, this.manga});

  @override
  State<Bygenre> createState() => _BygenreState();
}

class _BygenreState extends State<Bygenre> {
  late final Future<List<Manga>> _mangaFuture;
  static const _pageSize = 30;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _mangaFuture =
        widget.manga != null
            ? Future.value(widget.manga)
            : ApiService.getMangaByGenre([widget.genreName]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff101014),
      appBar: AppBar(
        backgroundColor: const Color(0xff17131d),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          widget.genreName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<List<Manga>>(
        future: _mangaFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xffb77cff)),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Genre gagal dimuat: ${snapshot.error}',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            );
          }
          final manga = snapshot.data ?? <Manga>[];
          final pageCount = (manga.length / _pageSize).ceil();
          final safePage =
              pageCount == 0 ? 1 : _currentPage.clamp(1, pageCount);
          final start = (safePage - 1) * _pageSize;
          final pageManga = manga
              .skip(start)
              .take(_pageSize)
              .toList(growable: false);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Text(
                      '${manga.length} manga dalam genre ${widget.genreName}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
              if (manga.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'Tidak ditemukan manga untuk genre ini.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              else
                AnimeGrid(komik: pageManga),
              if (manga.isNotEmpty && pageCount > 1)
                SliverToBoxAdapter(child: _pagination(pageCount, safePage)),
            ],
          );
        },
      ),
    );
  }

  Widget _pagination(int pageCount, int currentPage) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var page = 1; page <= pageCount; page++)
            OutlinedButton(
              onPressed:
                  page == currentPage
                      ? null
                      : () => setState(() => _currentPage = page),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                backgroundColor:
                    page == currentPage
                        ? const Color(0xff9a5bea)
                        : Colors.transparent,
                side: BorderSide(
                  color:
                      page == currentPage
                          ? const Color(0xff9a5bea)
                          : Colors.white24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Text('$page'),
            ),
        ],
      ),
    );
  }
}
