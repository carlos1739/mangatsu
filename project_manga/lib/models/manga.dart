class Manga {
  final String id;
  final String title;
  final String linkGambar;
  final String? mangaDexUrl;
  final String chapter;
  final String status;
  final String sinopsis;
  final String release;
  final List<String> genre;
  final String author;
  final bool bookmark;
  final int likes;
  final int view;
  final double rating;

  const Manga({
    required this.id,
    required this.title,
    required this.linkGambar,
    this.mangaDexUrl,
    required this.chapter,
    required this.status,
    required this.sinopsis,
    required this.release,
    required this.genre,
    required this.author,
    this.bookmark = false,
    required this.likes,
    required this.view,
    required this.rating,
  });

  factory Manga.fromApiJson(Map<String, dynamic> json) {
    final rawGenres = json['genre'];
    final genres =
        rawGenres is List
            ? rawGenres
                .map((genre) => genre.toString().trim())
                .where((genre) => genre.isNotEmpty)
                .toSet()
                .toList()
            : rawGenres is String
            ? rawGenres
                .split(',')
                .map((genre) => genre.trim())
                .where((genre) => genre.isNotEmpty)
                .toSet()
                .toList()
            : const <String>[];
    final mangaId = json['id']?.toString() ?? '';

    return Manga(
      id: mangaId,
      title: json['title']?.toString() ?? 'Unknown',
      mangaDexUrl:
          json['mangadex_url']?.toString() ??
          (mangaId.isEmpty ? null : 'https://mangadex.org/title/$mangaId'),
      linkGambar:
          json['link_gambar']?.toString() ??
          json['cover_url']?.toString() ??
          '',
      chapter: json['chapter']?.toString() ?? 'N/A',
      status: json['status']?.toString() ?? 'Unknown',
      sinopsis: json['synopsis']?.toString() ?? '',
      release: json['release']?.toString() ?? 'Unknown',
      genre: genres,
      author: json['author']?.toString() ?? 'Unknown',
      bookmark: json['bookmark'] as bool? ?? false,
      likes: json['likes'] as int? ?? 0,
      view: json['view'] as int? ?? 0,
      rating: (json['rating'] ?? 0.0).toDouble(),
    );
  }

  String get cardImageUrl => linkGambar;
}

class MangaChapter {
  final String id;
  final String chapter;
  final String title;
  final String language;
  final int pages;

  const MangaChapter({
    required this.id,
    required this.chapter,
    required this.title,
    required this.language,
    required this.pages,
  });

  factory MangaChapter.fromApiJson(Map<String, dynamic> json) {
    return MangaChapter(
      id: json['id']?.toString() ?? '',
      chapter: json['chapter']?.toString() ?? '?',
      title: json['title']?.toString() ?? '',
      language: json['language']?.toString() ?? '',
      pages: json['pages'] as int? ?? 0,
    );
  }

  String get displayTitle {
    final chapterLabel = chapter == '?' ? 'Chapter' : 'Chapter $chapter';
    return title.isEmpty ? chapterLabel : '$chapterLabel · $title';
  }
}

class MangaChapterPage {
  final List<MangaChapter> chapters;
  final int page;
  final int total;

  const MangaChapterPage({
    required this.chapters,
    required this.page,
    required this.total,
  });

  factory MangaChapterPage.fromApiJson(Map<String, dynamic> json) {
    final chapters =
        (json['data'] as List<dynamic>? ?? [])
            .map(
              (item) => MangaChapter.fromApiJson(item as Map<String, dynamic>),
            )
            .toList();
    return MangaChapterPage(
      chapters: chapters,
      page: json['page'] as int? ?? 1,
      total: json['total'] as int? ?? chapters.length,
    );
  }
}
