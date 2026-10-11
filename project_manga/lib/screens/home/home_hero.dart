// ignore_for_file: library_private_types_in_public_api
part of 'home.dart';

mixin HomeHero on _HomeStateBase {
  Widget _buildHero() {
    if (_releasedManga.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: ValueListenableBuilder<int>(
        valueListenable: _heroIndex,
        builder: (context, heroIndex, child) {
          final manga = _releasedManga[heroIndex % _releasedManga.length];
          return Align(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Container(
                height: 286,
                margin: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      manga.linkGambar,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.low,
                      cacheWidth: 960,
                      cacheHeight: 572,
                    ),
                    Container(color: Colors.black.withValues(alpha: .28)),
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xee100d15),
                            Color(0x99100d15),
                            Color(0x22100d15),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 22, 22, 20),
                      child: Row(
                        children: [
                          Expanded(child: _heroInfo(manga)),
                          const SizedBox(width: 18),
                          Transform.rotate(
                            angle: .08,
                            child: Container(
                              width: 112,
                              height: 170,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black87,
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(
                                manga.cardImageUrl,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.low,
                                cacheWidth: 224,
                                cacheHeight: 340,
                                errorBuilder:
                                    (_, __, ___) => const ColoredBox(
                                      color: Colors.black26,
                                      child: Icon(Icons.image_not_supported),
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _heroInfo(Manga manga) {
    final genres = manga.genre.take(3).toList();
    final hasChapter =
        manga.chapter.trim().isNotEmpty && manga.chapter.toLowerCase() != 'n/a';
    final chapterLabel =
        hasChapter ? 'Mulai Baca Ch. ${manga.chapter}' : 'Mulai Baca';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REKOMENDASI UNTUKMU',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .7),
            letterSpacing: 1.4,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          manga.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 29,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          children: [
            ...genres.map((genre) => _genreBadge(genre)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 17),
                const SizedBox(width: 3),
                Text(
                  manga.rating.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          manga.sinopsis.isEmpty
              ? 'Temukan petualangan baru dalam manga pilihan ini.'
              : manga.sinopsis,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => _openMangaDetail(manga),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(chapterLabel),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff9a5bea),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _genreBadge(String label) => Container(
    margin: const EdgeInsets.only(right: 2),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: const TextStyle(color: Colors.white, fontSize: 11),
    ),
  );
}
