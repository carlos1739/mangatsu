class Manga {
  final int id;
  final String title;
  final String linkGambar;
  final String? thumbnailUrl;
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
    this.thumbnailUrl,
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
    final images = json['images'];
    final jpg =
        images is Map<String, dynamic>
            ? images['jpg']
            : images is Map<dynamic, dynamic>
            ? images['jpg']
            : null;
    final imageUrl =
        jpg is Map<String, dynamic>
            ? jpg['image_url']
            : jpg is Map<dynamic, dynamic>
            ? jpg['image_url']
            : null;
    final smallImageUrl =
        jpg is Map<String, dynamic>
            ? jpg['small_image_url']
            : jpg is Map<dynamic, dynamic>
            ? jpg['small_image_url']
            : null;
    List<String> readNames(dynamic rawValue) {
      final values =
          rawValue is String
              ? rawValue.split(',')
              : rawValue is List
              ? rawValue
              : const <dynamic>[];
      return values
          .map(
            (value) =>
                value is Map
                    ? value['name']?.toString().trim() ?? ''
                    : value.toString().trim(),
          )
          .where((name) => name.isNotEmpty)
          .toList();
    }

    final genreNames = <String>[];
    final seenGenres = <String>{};
    for (final key in const [
      'genres',
      'genre',
      'themes',
      'theme',
      'demographics',
      'demographic',
      'explicit_genres',
    ]) {
      for (final name in readNames(json[key])) {
        if (seenGenres.add(name.toLowerCase())) {
          genreNames.add(name);
        }
      }
    }

    return Manga(
      id: json['id'] as int? ?? json['mal_id'] as int? ?? 0,
      title: json['title']?.toString() ?? 'Unknown',
      linkGambar:
          json['linkGambar']?.toString() ??
          json['link_gambar']?.toString() ??
          imageUrl?.toString() ??
          '',
      thumbnailUrl:
          json['thumbnail_url']?.toString() ??
          json['thumbnailUrl']?.toString() ??
          smallImageUrl?.toString(),
      chapter:
          json['chapter']?.toString() ?? json['chapters']?.toString() ?? 'N/A',
      status: json['status']?.toString() ?? 'Unknown',
      sinopsis: json['synopsis']?.toString() ?? '',
      release:
          json['release']?.toString() ?? json['year']?.toString() ?? 'Unknown',
      genre: genreNames,
      author: json['author']?.toString() ?? 'Unknown',
      bookmark: json['bookmark'] as bool? ?? false,
      likes: json['likes'] as int? ?? 0,
      view: json['view'] as int? ?? 0,
      rating: (json['rating'] ?? json['score'] ?? 0.0).toDouble(),
    );
  }

  String get cardImageUrl {
    final thumbnail = thumbnailUrl?.trim() ?? '';
    return thumbnail.isEmpty ? linkGambar : thumbnail;
  }
}

// Empty - Data dari API
final allGenre = <String>[];
final allKomik = <Manga>[];
