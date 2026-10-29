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
  late Future<MangaGenrePage> _mangaFuture;
  static const _pageSize = 25;

  @override
  void initState() {
    super.initState();
    _mangaFuture =
        widget.manga != null
            ? Future.value(
              MangaGenrePage(
                manga: widget.manga!,
                page: 1,
                total: widget.manga!.length,
              ),
            )
            : ApiService.getMangaByGenre(widget.genreName);
  }

  void _goToPage(int page) {
    setState(() {
      _mangaFuture = ApiService.getMangaByGenre(widget.genreName, page: page);
    });
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
      body: FutureBuilder<MangaGenrePage>(
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
          final result = snapshot.data!;
          final manga = result.manga;
          final pageCount = (result.total / _pageSize).ceil();
          final safePage = pageCount == 0 ? 1 : result.page;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Text(
                      '${result.total} manga dalam genre ${widget.genreName}',
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
                AnimeGrid(komik: manga),
              if (manga.isNotEmpty && pageCount > 1)
                SliverToBoxAdapter(child: _pagination(pageCount, safePage)),
            ],
          );
        },
      ),
    );
  }

  Widget _pagination(int pageCount, int currentPage) {
    final visiblePages =
        <int>{
            1,
            pageCount,
            for (var page = currentPage - 2; page <= currentPage + 2; page++)
              if (page > 1 && page < pageCount) page,
          }.toList()
          ..sort();
    final children = <Widget>[];
    var previousPage = 0;
    for (final page in visiblePages) {
      if (previousPage > 0 && page - previousPage > 1) {
        children.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              child: Text('…', style: TextStyle(color: Colors.white70)),
            ),
          ),
        );
      }
      children.add(
        OutlinedButton(
          onPressed: page == currentPage ? null : () => _goToPage(page),
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
      );
      previousPage = page;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed:
                currentPage > 1 ? () => _goToPage(currentPage - 1) : null,
            child: const Text('Sebelumnya'),
          ),
          ...children,
          OutlinedButton(
            onPressed:
                currentPage < pageCount
                    ? () => _goToPage(currentPage + 1)
                    : null,
            child: const Text('Berikutnya'),
          ),
        ],
      ),
    );
  }
}
