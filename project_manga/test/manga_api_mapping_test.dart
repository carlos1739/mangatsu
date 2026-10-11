import 'package:flutter_test/flutter_test.dart';
import 'package:project_manga/models/manga.dart';

void main() {
  test('mapping respons manga backend ke model Flutter', () {
    final manga = Manga.fromApiJson({
      'mal_id': 42,
      'title': 'Manga Contoh',
      'author': 'Penulis',
      'chapter': 12,
      'status': 'Publishing',
      'synopsis': 'Ringkasan',
      'year': 2026,
      'genres': [
        {'name': 'Action'},
        {'name': 'Drama'},
      ],
      'score': 8.5,
      'images': {
        'jpg': {
          'image_url': 'https://example.com/cover.jpg',
          'small_image_url': 'https://example.com/cover-small.jpg',
        },
      },
    });

    expect(manga.id, 42);
    expect(manga.title, 'Manga Contoh');
    expect(manga.author, 'Penulis');
    expect(manga.chapter, '12');
    expect(manga.linkGambar, 'https://example.com/cover.jpg');
    expect(manga.cardImageUrl, 'https://example.com/cover-small.jpg');
    expect(manga.genre, ['Action', 'Drama']);
    expect(manga.rating, 8.5);
  });

  test('mapping payload tenrai dengan genre string', () {
    final manga = Manga.fromApiJson({
      'mal_id': 2,
      'title': 'Berserk',
      'author': 'Miura, Kentarou',
      'chapter': 'N/A',
      'status': 'Publishing',
      'synopsis': 'Ringkasan',
      'release': 'Unknown',
      'genre': 'Action,Adventure,Drama,Fantasy',
      'link_gambar': 'https://cdn.myanimelist.net/images/manga/1/157897.jpg',
      'rating': 9.46,
    });

    expect(manga.id, 2);
    expect(
      manga.linkGambar,
      'https://cdn.myanimelist.net/images/manga/1/157897.jpg',
    );
    expect(manga.cardImageUrl, manga.linkGambar);
    expect(manga.genre, ['Action', 'Adventure', 'Drama', 'Fantasy']);
    expect(manga.rating, 9.46);
  });
}
