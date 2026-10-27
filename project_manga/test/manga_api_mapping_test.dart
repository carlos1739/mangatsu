import 'package:flutter_test/flutter_test.dart';
import 'package:project_manga/models/manga.dart';

void main() {
  test('mapping respons MangaDex ke model Flutter', () {
    final manga = Manga.fromApiJson({
      'id': '6b3bfc9e-4e78-4c12-8dcb-dc5e0bb682cf',
      'title': 'Manga Contoh',
      'mangadex_url':
          'https://mangadex.org/title/6b3bfc9e-4e78-4c12-8dcb-dc5e0bb682cf',
      'author': 'Penulis',
      'chapter': '12',
      'status': 'ongoing',
      'synopsis': 'Ringkasan',
      'release': '2026',
      'genre': ['Action', 'Drama'],
      'link_gambar': 'https://uploads.mangadex.org/covers/example/cover.jpg',
      'rating': 0.0,
    });

    expect(manga.id, '6b3bfc9e-4e78-4c12-8dcb-dc5e0bb682cf');
    expect(manga.title, 'Manga Contoh');
    expect(
      manga.mangaDexUrl,
      'https://mangadex.org/title/6b3bfc9e-4e78-4c12-8dcb-dc5e0bb682cf',
    );
    expect(manga.author, 'Penulis');
    expect(manga.chapter, '12');
    expect(
      manga.linkGambar,
      'https://uploads.mangadex.org/covers/example/cover.jpg',
    );
    expect(manga.genre, ['Action', 'Drama']);
  });

  test('mapping chapter MangaDex', () {
    final chapter = MangaChapter.fromApiJson({
      'id': 'b6d84fb1-5a9c-48ee-9d7c-c0dc87b73a29',
      'chapter': '1',
      'title': 'Awal Cerita',
      'language': 'id',
      'pages': 24,
    });

    expect(chapter.chapter, '1');
    expect(chapter.displayTitle, 'Chapter 1 · Awal Cerita');
    expect(chapter.pages, 24);
  });
}
